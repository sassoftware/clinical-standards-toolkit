%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilsqlcolumndefinition                                                     *;
%*                                                                                *;
%* Builds SQL column definitions based on columns in the input data set.          *;
%*                                                                                *;
%* This macro builds SQL column definitions based on the columns identified in    *;
%* the data set referenced in _cstSourceDS. It can generate SAS proc SQL or ANSI  *;
%* SQL.                                                                           *;
%*                                                                                *;
%* Here is an example:                                                            *;
%*  The PT data set located in the STUDY1 libref contains one column named        *;
%*  STUDYID that is character with a length of 40, has a format &STUDYID, has an  *;
%*  informat of $CHAR40, and has a label. The call to the macro is:               *;
%*                                                                                *;
%*  %cstutilsqlcolumndefinition(_cstSourceDS=STUDY1.PT,_cstSQLColDef=_cstColDef)  *;
%*                                                                                *;
%*  The column definition string is returned to the macro variable _cstColDef as: *;
%*                                                                                *;
%*  For SAS Proc SQL:                                                             *;
%*                                                                                *;
%*  (STUDYID char(40) label="Study Identifier" format=$STUDYID informat=$CHAR40.) *;
%*                                                                                *;
%*  For ANSI/ORACLE SQL:                                                          *;
%*                                                                                *;
%*  (STUDYID varchar(40) "Study Identifier")                                      *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code. If 1, error exists.              *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstSourceDS - required - The source data set <libref.dset>.            *;
%* @param _cstSQLColDef - required - The macro variable to contain the SQL column *;
%*        definition content.                                                     *;
%* @param _cstSQLType - required - The type of code to generate.                  *;
%*        Values: SAS | ANSI | ORACLE                                             *;
%*        Default: SAS                                                            *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilsqlcolumndefinition(
    _cstSourceDS=,
    _cstSQLColDef=,
    _cstSQLType=SAS
    ) / des='CST: Build SQL Column Definition content';

  %local
    _cstCheckVal
    _cstLabelLen
    _cstNumeric
    _cstTemp1
    nvars
    vcolumn
    vlabel
    vlength
    vname
    vtype
    vcolumn
  ;

  %let _cst_rc=0;
  %let _cst_rcmsg=;
  
  %************************************************;
  %*  One or more missing parameter values for    *;
  %*  _cstSourceDS, _cstSQLColDef or _cstSQLType  *;
  %************************************************;
  %if (%klength(&_cstSourceDS)=0) or (%klength(&_cstSQLColDef)=0) or (%klength(&_cstSQLType)=0)%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=One or more of the following parameters is missing _cstSourceDS, _cstSQLColDef or _cstSQLType.;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: &_cst_rcmsg;
    %goto EXIT_MACRO;
  %end;
  
  %************************************;
  %*  Improper value for _cstSQLType  *;
  %*  Must be SAS, ANSI or ORACLE     *;
  %************************************;
  %if (%upcase(&_cstSQLType) ne ANSI and %upcase(&_cstSQLType) ne SAS and %upcase(&_cstSQLType) ne ORACLE) %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Incorrect parameter value [&_cstSQLType] for _cstSQLType. Must be SAS, ANSI or ORACLE.;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: &_cst_rcmsg;
    %goto EXIT_MACRO;
  %end;

  %***********************************************************************;
  %*  Parameter _cstSourceDS not in required form of <libname>.<dsname>  *;
  %***********************************************************************;
  %let _cstCheckVal=%sysfunc(countc("&_cstSourceDS",'.'));
  %if &_cstCheckVal=1 %then
  %do;
    %********************************************;
    %*  Check for a leading or trailing period  *;
    %********************************************;
    %let _cstTemp1=%sysfunc(kindexc(%str(&_cstSourceDS),%str(.)));
    %if &_cstTemp1=1 or &_cstTemp1=%klength(&_cstSourceDS) %then
    %do;
      %let _cstCheckVal=0;
    %end;
  %end;
  %else %if &_cstCheckVal=0 %then
  %do;
    %***********************************************;
    %* Single level data set assumed to be in WORK *;
    %***********************************************;
    %let _cstSourceDS=work.&_cstSourceDS;
    %let _cstCheckVal=1;
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstSourceDS] macro parameter does not follow <libname>.<dsname> construct.;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: &_cst_rcmsg;
    %goto EXIT_MACRO;
  %end;

  %if not %sysfunc(exist(&_cstSourceDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstSourceDS] specified in the _cstSourceDS macro parameter does not exist.;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: &_cst_rcmsg;
    %goto EXIT_MACRO;
  %end;

  %if (%symexist(&_cstSQLColDef)=0) %then %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The macro variable [&_cstSQLColDef] specified in the _cstSQLColDef macro parameter does not exist.;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: &_cst_rcmsg;
    %goto EXIT_MACRO;
  %end;

  %*****************************;
  %*  Start column processing  *;
  %*****************************;

  proc contents data=&_cstSourceDS out=work._cstContents (keep=name type length varnum label formatl formatd) noprint;
  run;
  
  proc sort data=work._cstContents;
    by varnum;
  run;

  data _null_;
    set work._cstContents end=end;
    length cstColumn $32;
    name=kstrip(name);
    cstColumn=name;
    
    %**************************************;
    %*  Warn the user about any ANSI SQL  *; 
    %*  reserved words that are present   *;
    %*  as variable names.                *;
    %**************************************;
    %if %upcase(&_cstSQLType) ne SAS %then
    %do;
      if upcase(name) in ("ADD" "ALL" "ALTER" "AND" "ANY" "AS" "ASC" "BETWEEN" "BY" "CHAR" "CHECK" "CONNECT" "CREATE" "CURRENT" "DATE" "DECIMAL" "DEFAULT" "DELETE" "DESC"
                          "DISTINCT" "DROP" "ELSE" "FLOAT" "FOR" "FROM" "GRANT" "GROUP" "HAVING" "IMMEDIATE" "IN" "INSERT" "INTEGER" "INTERSECT" "INTO" "IS" "LEVEL" "LIKE"
                          "NOT" "NULL" "OF" "ON" "OPTION" "OR" "ORDER" "PRIOR" "PRIVILEGES" "PUBLIC" "REVOKE" "ROWS" "SELECT" "SESSION" "SET" "SIZE" "SMALLINT" "TABLE" "THEN"
                          "TO" "UNION" "UNIQUE" "UPDATE" "USER" "VALUES" "VARCHAR" "VIEW" "WHENEVER" "WITH") then
      do;
        cstColumn=cats(cstColumn,"__SQL1");
        cstColumn=kstrip(cstColumn);
        put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR%str(NING): Column [" name "] is an ANSI SQL RESERVED WORD - This column may need to be changed in the contributing SAS data set.";
        put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR%str(NING): Column [" name "] is being renamed to " cstColumn ".";
      end;
    %end;

    %****************************************;
    %*  Warn the user about any ORACLE SQL  *; 
    %*  reserved words that are present     *;
    %*  as variable names.                  *;
    %****************************************;
    %if %upcase(&_cstSQLType) eq ORACLE %then
    %do;
      if upcase(name) in ("ACCESS" "AUDIT" "CLUSTER" "COLUMN" "COMMENT" "COMPRESS" "DOMAIN" "EXCLUSIVE" "EXISTS" "FILE" "IDENTIFIED" "INCREMENT" "INDEX" "INITIAL" "LOCK" "LONG" "MAXEXTENTS"
                          "MINUS" "MLSLABEL" "MODE" "MODIFY" "NOAUDIT" "NOCOMPRESS" "NOWAIT" "NUMBER" "OFFLINE" "PCTFREE" "RAW" "RENAME" "ROW" "ROWID" "ROWNUM" "SHARE" "START" "STATE" 
                          "SUCCESSFUL" "SYNONYM" "SYSDATE" "TRIGGER" "UID" "VALIDATE" "VARCHAR2" "WHERE") then
      do;
        cstColumn=cats(cstColumn,"__SQL1");
        cstColumn=kstrip(cstColumn);
        put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR%str(NING): Column [" name "] is an ORACLE SQL RESERVED WORD - This column may need to be changed in the contributing SAS data set.";
        put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR%str(NING): Column [" name "] is being renamed to " cstColumn ".";
      end;
    %end;

    call symputx (cats('vtype', _n_), type);
    call symputx (cats('vlength', _n_), length);
    call symputx (cats('vname', _n_), name);
    call symputx (cats('vlabel', _n_), label);
    call symputx (cats('vformatl', _n_), formatl);
    call symputx (cats('vformatd', _n_), formatd);
    call symputx (cats('vcolumn', _n_), cstColumn);
    if end then call symputx('nvars', _n_);
  run;
  
  %****************************************;
  %*  Build the Column Definition string  *;
  %****************************************;
  data _null_;
   set &_cstSourceDS end=end;
    length string1 _cstVValue _cstVFormat _cstVInformat $500 cstSQLAttrs $32767 _cstQuoteExist 8.;
    retain cstSQLAttrs;
    _cstVValue='';
    _cstVFormat='';
    _cstVInformat='';
    _cstQuoteExist=.;
    
    %*****************************;
    %*  Build SAS Proc SQL code  *;
    %*****************************;
    %if %upcase(&_cstSQLType)=SAS %then
    %do;
      %let _cstLabelLen=256;
      length _cstLabel $&_cstLabelLen;
      if _n_=1 then 
      do;
        %do i=1 %to %eval(&nvars);
          _cstVValue="%nrbquote(&&vlabel&i)";
          _cstQuoteExist=kindex(_cstVValue,'"');
          if lengthn(_cstVValue) gt &_cstLabelLen then
          do;
            put;
            put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR%str(NING): Label for column [%upcase(&&vname&i)] exceeds &_cstLabelLen characters and is being truncated.";
            put;
            _cstLabel=substr(_cstVValue,1,&_cstLabelLen);
          end;
          else _cstLabel=_cstVValue;

          %****************************;
          %*  Retrieve Column Format  *;
          %****************************;
          _cstVFormat="%cstutilgetattribute(_cstDataSetName=&_cstSourceDS, _cstVarName=&&vname&i,_cstAttribute=VARFMT)";
          if ^missing(_cstVFormat) then _cstVFormat=catt(" format=",_cstVFormat);

          %******************************;
          %*  Retrieve Column Informat  *;
          %******************************;
          _cstVInFormat="%cstutilgetattribute(_cstDataSetName=&_cstSourceDS, _cstVarName=&&vname&i,_cstAttribute=VARINFMT)";
          if ^missing(_cstVInFormat) then _cstVInFormat=catt(" informat=",_cstVInFormat);

          %*******************************************;
          %*  Build Numeric vs Character attributes  *;
          %*******************************************;
          %if &&vtype&i eq 1 %then 
          %do;
            if _cstQuoteExist > 0 
              then string1=catt("&&vcolumn&i"," numeric label='",_cstLabel,"'", _cstVFormat, _cstVInformat);
              else string1=catt("&&vcolumn&i",' numeric label="',_cstLabel,'"', _cstVFormat, _cstVInformat);
          %end;
          %else 
          %do;
            if _cstQuoteExist > 0 
            then string1=catt("&&vcolumn&i",' char(',"&&vlength&i",") label='",_cstLabel,"'", _cstVFormat, _cstVInformat);
            else string1=catt("&&vcolumn&i",' char(',"&&vlength&i",') label="',_cstLabel,'"', _cstVFormat, _cstVInformat);
          %end;

          %if &i lt &nvars %then 
          %do;
            string1=catt("",string1,",");
          %end;
          cstSQLAttrs=catx(" ",cstSQLAttrs,string1);
        %end;
        cstSQLAttrs=catx(" ","(",cstSQLAttrs,");");
        call symputx("&_cstSQLColDef",cstSQLAttrs);
      end;
      else stop;
    %end;
    
    %********************************;
    %*  Build ANSI/ORACLE SQL code  *;
    %********************************;
    %if %upcase(&_cstSQLType)=ANSI or %upcase(&_cstSQLType)=ORACLE %then
    %do;
      if _n_=1 then 
      do;
        %do i=1 %to %eval(&nvars);
 
          %****************************;
          %*  Retrieve Column Format  *;
          %****************************;
          %if %eval(&&vformatd&i) gt 0 
            %then %let _cstNumeric=(&&vformatl&i,&&vformatd&i);
            %else %let _cstNumeric=;

          %*******************************************;
          %*  Build Numeric vs Character attributes  *;
          %*******************************************;
          %if &&vtype&i eq 1 %then 
          %do;
            string1=catt("&&vcolumn&i"," numeric &_cstNumeric");
          %end;
          %else 
          %do;
            %if %upcase(&_cstSQLType)=ANSI %then
            %do;
              string1=catt("&&vcolumn&i"," varchar(&&vlength&i)");
            %end;
            %else
            %do;
              string1=catt("&&vcolumn&i"," varchar2(&&vlength&i)");
            %end;
          %end;

          %if &i lt &nvars %then 
          %do;
            string1=catt("",string1,",");
          %end;
          cstSQLAttrs=catx(" ",cstSQLAttrs,string1);
        %end;
        cstSQLAttrs=catx(" ","(",cstSQLAttrs,");");
        call symputx("&_cstSQLColDef",cstSQLAttrs);
      end;
      else stop;
    %end;
  run;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstContents);

  %EXIT_MACRO:

%mend cstutilsqlcolumndefinition;