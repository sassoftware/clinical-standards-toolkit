%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilsqlgeneratetable                                                        *;
%*                                                                                *;
%* Builds SQL code to generate SAS data sets derived from another SAS data set.   *;
%*                                                                                *;
%* Given a SAS data set, this macro generates SQL code to create the SAS data set.*;
%* This generated SQL code can then be modified with any needed changes. For      *;
%* example, you might need to create a new messages data set for a new study.     *;
%*                                                                                *;
%* A pre-existing Messages data set from another study can be used to act as a    *;
%* pattern for the new data set.                                                  *;
%*                                                                                *;
%* This macro generates sql code using the data and  metadata from the existing   *;
%* data set. This sql code, stored in _cstSQLFile, can be modifed for the new     *;
%* study and then submitted to create a new data set.                             *;
%*                                                                                *;
%* This macro can generate either SAS PROC SQL or ANSI SQL code.                  *;
%*                                                                                *;
%* Here is an example:                                                            *;
%* cstutilsqlgeneratetable(_cstDSName=messages,                                   *;
%*                         _cstDSLibraryIn=study1,                                *;
%*                         _cstDSLibraryOut=study2,                               *;
%*                         _cstSQLFile=c:\newstudy\generate_messages.sas,         *;
%*                         _cstSQLType=SAS);                                      *;
%*                                                                                *;
%* In this example, the study1.messages data set is used to generate the PROC SQL *;
%* code that creates a study2.messages data set. The PROC SQL code resides in the *;
%* C:\NEWSTUDY\GENERATE_MESSAGES.SAS file. This file can be edited prior to       *;
%* submission to reflect any changes needed for the new study.                    *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code. If 1, error exists               *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstDSName - required - The source data set. This is also used as the   *;
%*        name of the generated data set in the SQL code. This data set must      *;
%*        exist in the library specified by the _cstDSLibraryIn libref parameter. *;
%* @param _cstDSLibraryIn - required - The libname for the _cstDSName parameter.  *;
%*        NOTE: This libref must be initialized prior to running this macro.      *;
%* @param _cstDSLibraryOut - required - The libname for the generated SQL code.   *;
%*        If this parameter is not specified, this values defaults to the work    *;
%*        directory.                                                              *;
%*        NOTE: It is NOT necessary for this libref to be initialized. However,   *;
%*              it is required before submitting the generated PROC SQL code.     *;
%*        Default: work                                                           *;
%* @param _cstSQLFile - required - The file that contains the generated SQL code, *;
%*        in the form C:/dir1/dir2/your_filename_here.sas                         *;
%* @param _cstSQLType - required - The type of code to generate.                  *;
%*        Values: SAS | ANSI | ORACLE                                             *;
%*        Default: SAS                                                            *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilsqlgeneratetable(
  _cstDSName=,
  _cstDSLibraryIn=,
  _cstDSLibraryOut=work,
  _cstSQLFile=,
  _cstSQLType=SAS
  )/ des='CST: Build PROC SQL Table Generation Code';

  %if ^%symexist(_cst_rc) %then 
  %do;
    %global _cst_rc _cst_rcmsg;
  %end;
 
  %local _cstColDef
         _cstColList
         _cstQuoteExist
         _cstRandom
         _cstTempDS1
         _cstTLabel
         nvars
         vcolumn
         vname
         vtype
  ;
  
  %let _cstRandom=;
  %let _cstTempDS1=;
  %let _cst_rc=0;
  
  %****************************************************;
  %*  Check for missing parameters that are required  *;
  %****************************************************;
  %if (%length(&_cstDSName)=0) or
      (%length(&_cstDSLibraryIn)=0) or
      (%length(&_cstSQLFile)=0) or 
      (%length(&_cstSQLType)=0) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: One or more REQUIRED parameters (_cstDSName, _cstDSLibraryIn, _cstSQLFile or _cstSQLType) are missing.;
    %goto EXIT_MACRO;
  %end;

  %*****************************************************;
  %*  Check for incorrect _cstSQLType parameter value  *;
  %*  Current values are SAS and ANSI                  *;
  %*****************************************************;
  %if (%upcase(&_cstSQLType) ne SAS) and (%upcase(&_cstSQLType) ne ANSI) and (%upcase(&_cstSQLType) ne ORACLE) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: Incorrect value for _cstSQLType parameter [&_cstSQLType] must be SAS, ANSI or ORACLE.;
    %goto EXIT_MACRO;
  %end;
  
  %*************************************************;
  %*  Pre-requisite: Check that the input libref,  *;
  %*  the SQL file, and the input data set exists  *;
  %*************************************************;
  %if (%sysfunc(libref(&_cstDSLibraryIn))) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The input libref parameter(_cstDSLibraryIn = &_cstDSLibraryIn) is not assigned.;
  %end;

  data _null_;
    file "&_cstSQLFile";
  run;
  %if %eval(&syserr) gt 0 %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The SQL File parameter(_cstSQLFile = &_cstSQLFile) is incorrect. Check that directory exists.;
  %end;
  
  %if not %sysfunc(exist(&_cstDSLibraryIn..&_cstDSName)) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The input data set (&_cstDSLibraryIn..&_cstDSName) does not exist.;
  %end;

  %if &_cst_rc=1 %then %goto EXIT_MACRO;
  
  %**************************************;
  %*  Generate temporary data set name  *;
  %**************************************;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %if %upcase(&_cstSQLType)=SAS 
    %then %let _cstTempDS1=work.cst&_cstRandom;
    %else %let _cstTempDS1=cst&_cstRandom;

  %************************************************************;
  %*  Create macro variables for data set metadata variables  *;
  %************************************************************;
  proc contents data=&_cstDSLibraryIn..&_cstDSName out=&_cstTempDS1 noprint;
  run;

  proc sort data=&_cstTempDS1;
    by varnum;
  run;

  data _null_;
   set &_cstTempDS1 end=end;
   length cstColumn $32;
   cstColumn=name;
   
   %******************************************;
   %*  Check for ANSI/ORACLE reserved words  *;
   %******************************************;
   if upcase(name) in ("ACCESS"     "ADD"      "ALL"        "ALTER"     "AND"      "ANY"        "AS"      "ASC"      "AUDIT"    "BETWEEN" "BY"        "CHAR"       
                       "CHECK"      "CLUSTER"  "COLUMN"     "COMMENT"   "COMPRESS" "CONNECT"    "CREATE"  "CURRENT"  "DATE"     "DECIMAL" "DEFAULT"   "DELETE"
                       "DESC"       "DISTINCT" "DOMAIN"     "DROP"      "ELSE"     "EXCLUSIVE"  "EXISTS"  "FILE"     "FLOAT"    "FOR"     "FROM"      "GRANT"
                       "GROUP"      "HAVING"   "IDENTIFIED" "IMMEDIATE" "IN"       "INCREMENT"  "INDEX"   "INITIAL"  "INSERT"   "INTEGER" "INTERSECT" "INTO"
                       "IS"         "LEVEL"    "LIKE"       "LOCK"      "LONG"     "MAXEXTENTS" "MINUS"   "MLSLABEL" "MODE"     "MODIFY"  "NOAUDIT"   "NOCOMPRESS" 
                       "NOT"        "NOWAIT"   "NULL"       "NUMBER"    "OF"       "OFFLINE"    "ON"      "OPTION"   "OR"       "ORDER"   "PCTFREE"   "PRIOR" 
                       "PRIVILEGES" "PUBLIC"   "RAW"        "RENAME"    "REVOKE"   "ROW"        "ROWID"   "ROWNUM"   "ROWS"     "SELECT"  "SESSION"   "SET"
                       "SHARE"      "SIZE"     "SMALLINT"   "START"     "STATE"    "SUCCESSFUL" "SYNONYM" "SYSDATE"  "TABLE"    "THEN"    "TO"        "TRIGGER"
                       "UID"        "UNION"    "UNIQUE"     "UPDATE"    "USER"     "VALIDATE"   "VALUES"  "VARCHAR"  "VARCHAR2" "VIEW"    "WHENEVER"  "WHERE"
                       "WITH")
     then cstColumn=cats(cstColumn,"__SQL1");

   call symputx (cats('vtype', _n_), type);
   call symputx (cats('vname', _n_), name);
   call symputx (cats('vcolumn', _n_), cstColumn);
   if end then call symputx('nvars', _n_);
  run;
  
  %***********************************;
  %*  Create column list for ORACLE  *;
  %***********************************;
  %if %upcase(&_cstSQLType)=ORACLE %then 
  %do;
    %let _cstColList=(;
    %do i = 1 %to %eval(&nvars);
      %if &i=1 
        %then %let _cstColList=&_cstColList &vcolumn1;
  %else %let _cstColList=&_cstColList, %str(&&vcolumn&i);
    %end; 
    %let _cstColList=&_cstColList );
  %end;
  
  %*****************************************************************;
  %*  Prepare to Generate SAS Proc SQL, ANSI SQL or ORACLE PL/SQL  *;
  %*****************************************************************;
  %cstutilsqlcolumndefinition(_cstSourceDS=&_cstDSLibraryIn..&_cstDSName,_cstSQLColDef=_cstColDef,_cstSQLType=&_cstSQLType);
  %if &_cst_rc %then %goto EXIT_MACRO; 

  %let _cstQuoteExist=0;
  
  %***************************;
  %*  Generate SAS Proc SQL  *;
  %***************************;
  %if %upcase(&_cstSQLType=SAS) %then 
  %do;
    data _null_;
      set &_cstDSLibraryIn..&_cstDSName end=end;
      length __temp _cstVValue $32767 _cstTLabel _cstSortVars $500;
      _cstTLabel='';

      %*****************************;
      %*  Retrieve data set label  *;
      %*****************************;
      %let _cstTlabel=%cstutilgetattribute(_cstDataSetName=&_cstDSLibraryIn..&_cstDSName, _cstAttribute=LABEL);
      _cstTLabel=symget("_cstTLabel");
      if ^missing(_cstTLabel) then 
      do;
        if kindex(_cstTLabel,'"') 
          then _cstTLabel=catt(" (label='",_cstTLabel,"')");
          else _cstTLabel=catt(' (label="',_cstTLabel,'")');
      end;
    
      %*******************************************;
      %*  Retrieve data set sorted by variables  *;
      %*******************************************;
      _cstSortVars="%cstutilgetattribute(_cstDataSetName=&_cstDSLibraryIn..&_cstDSName, _cstAttribute=SORTEDBY)";
      if ^missing(_cstSortVars) 
        then _cstSortVars=catx(" ","order by",(tranwrd(ktrim(_cstSortVars),"  ",", ")));
    
      file "&_cstSQLFile" lrecl=32767 ;
      __temp=symget("_cstColDef");
    
      %*********************************;
      %*  Start building the SQL code  *;
      %*********************************;
      if _n_=1 then 
      do;
        put "proc sql;";
        put "  create table &_cstTempDS1 " @;
        if missing(_cstTLabel) 
          then put;
          else put _cstTLabel;
        put @3 __temp;
        put "  insert into &_cstTempDS1";
      end;
  
      %*********************************;
      %*  Build the VALUES statements  *:
      %*********************************;
      put "  values (" @;
      %do i=1 %to %eval(&nvars);
        format &&vname&i;
        _cstVValue=strip(%nrbquote(&&vname&i));
        _cstQuoteExist=kindex(_cstVValue,"'");
        %if &&vtype&i ne 1 %then
        %do; 
          if _cstQuoteExist=0 
            then __temp = cats("'",_cstVValue,"'");
            else __temp = cats('"',_cstVValue,'"');
          put  __temp  @;;
        %end;
        %else 
        %do;
          if not missing(&&vname&i) 
            then put &&vname&i +(-1) @;
            else put "NULL" @;
        %end;
        %if &i lt &nvars 
          %then put ", " @;
          %else put ")";;
      %end;  
      if end then 
      do;
        put "  ;";
        put "  create table &_cstDSLibraryOut..&_cstDSName " @;
        if missing(_cstTLabel) 
          then put;
          else put _cstTLabel;
        put "  as select * from &_cstTempDS1 " @;
        if missing (_cstSortVars) 
          then put;
          else put _cstSortVars;      
        put "  ;";
        put "  drop table &_cstTempDS1";
        put "  ;";  
        put "quit;";
      end;  
    run;
  %end;
  
  %***********************;
  %*  Generate ANSI SQL  *;
  %***********************;
  %if %upcase(&_cstSQLType=ANSI) %then 
  %do;
    data _null_;
      set &_cstDSLibraryIn..&_cstDSName end=end;
      length __temp _cstVValue $32767;
    
      file "&_cstSQLFile" lrecl=32767;
      __temp=symget("_cstColDef");
    
      %*********************************;
      %*  Start building the SQL code  *;
      %*********************************;
      if _n_=1 then 
      do;
        put "  create table &_cstDSName";
        put @3 __temp;
        put "  insert into &_cstDSName";
      end;
  
      %*********************************;
      %*  Build the VALUES statements  *:
      %*********************************;
      put "  values (" @;
      %do i=1 %to %eval(&nvars);
        format &&vname&i;
        _cstVValue=strip(%nrbquote(&&vname&i));
        _cstVValue=tranwrd(ktrim(_cstVValue),"'","''");
        %if &&vtype&i ne 1 %then
        %do; 
          __temp = cats("'",kstrip(_cstVValue),"'");
          put  __temp  @;;
        %end;
        %else 
        %do;
          if not missing(&&vname&i) 
            then put &&vname&i +(-1) @;
            else put "NULL" @;
        %end;
        %if &i lt &nvars 
          %then put ", " @;
          %else put ")";;
      %end;  
      if end then put "  ;";
     run;
  %end;

  %*************************;
  %*  Generate ORACLE SQL  *;
  %*************************;
  %if %upcase(&_cstSQLType=ORACLE) %then 
  %do;
    data _null_;
      set &_cstDSLibraryIn..&_cstDSName end=end;
      length __temp _cstVValue _cstCList $32767;

      file "&_cstSQLFile" lrecl=32767;
      __temp=symget("_cstColDef");
      _cstCList=symget("_cstColList");
    
      %*********************************;
      %*  Start building the SQL code  *;
      %*********************************;
      if _n_=1 then 
      do;
        put "create table &_cstDSName";
        put @3 __temp;
      end;
  
      %*********************************;
      %*  Build the VALUES statements  *:
      %*********************************;
      put @3 "insert into &_cstDSName "@; 
      put _cstCList;
      
      put @3 "values (" @;
      %do i=1 %to %eval(&nvars);
        format &&vname&i;
        _cstVValue=strip(%nrbquote(&&vname&i));
        _cstVValue=tranwrd(ktrim(_cstVValue),"'","''");
        %if &&vtype&i ne 1 %then
        %do; 
          __temp = cats("'",kstrip(_cstVValue),"'");
          put  __temp  @;;
        %end;
        %else 
        %do;
          if not missing(&&vname&i) 
            then put &&vname&i +(-1) @;
            else put "NULL" @;
        %end;
        %if &i lt &nvars 
          %then 
          %do;
            put ", " @;
          %end;
          %else 
          %do;
            put ");";;
          %end;
      %end;  
      if end then put "  ;";
    run;
  %end;

  %************************************;
  %*  Delete any temporary data sets  *;
  %************************************;
  %cstutil_deleteDataSet(_cstDataSetName=&_cstTempDS1);

  %**********;
  %*  Exit  *;
  %**********;
  %EXIT_MACRO:

%mend cstutilsqlgeneratetable;