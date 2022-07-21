%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcreatetablesfrommetadata                                                *;
%*                                                                                *;
%* Creates table shells from metadata.                                            *;
%*                                                                                *;
%* This macro generates all of the table shells that are defined in tables and    *;
%* columns metadata data sets. The table shells are stored in a library that is   *;
%* specified by the caller.                                                       *;
%*                                                                                *;
%* A table shell for metadata data sets can be created by calling these macros:   *;
%*                                                                                *;
%*  %cst_createdsfromtemplate(_cstStandard=CDISC-SDTM,                            *;
%*                            _cstType=referencemetadata,                         *;
%*                            _cstSubType=table,                                  *;
%*                            _cstOutputDS=work.source_tables);                   *;
%*                                                                                *;
%*  %cst_createdsfromtemplate(_cstStandard=CDISC-SDTM,                            *;
%*                            _cstType=referencemetadata,                         *;
%*                            _cstSubType=column,                                 *;
%*                            _cstOutputDS=work.source_columns);                  *;
%*                                                                                *;
%*  Required fields for the metadata input data sets are listed below. Variables  *;
%*  common to both data sets must match in data type and length.                  *;
%*                                                                                *;
%*            _cstTableMD  - requires TABLE and LABEL variables                   *;
%*            _cstColumnMD - requires TABLE, ORDER, COLUMN, LABEL, TYPE, and      *;
%*            DISPLAYFORMAT variables.                                            *;
%*                                                                                *;
%* @param _cstReturn - required - The macro variable that contains the return     *;
%*            value that is set by this macro: 0 (no error), 1 (error)            *;
%*            Default: _cst_rc                                                    *;
%* @param _cstReturnMsg - required - The macro variable that contains the return  *;
%*            message that is set by this macro. If _cstReturn=1, there is a      *;
%*            message.                                                            *;
%*            Default: _cst_rcmsg                                                 *;
%* @param _cstTableMD - required - The two-level data set name of the table that  *;
%*            contains the table metadata.                                        *;
%* @param _cstColumnMD - required - The two-level data set name of the table that *;
%*            contains the column metadata.                                       *;
%* @param _cstOutputLibrary - required - The libname in which the table shells    *;
%*            are created.                                                        *;
%* @param _cstNumObs - optional - The number of records in the data sets to       *;
%*            create. By default, zero-observation data sets are created. If you  *;
%*            specify a value other than 0, the data sets to create contain one   *;
%*            observation with all fields missing.                                *;
%*            Default: 0                                                          *;
%* @param _cstWhereClause - optional - A valid SAS WHERE clause used in the PROC  *;
%*            SORT to subset by table. By default, no WHERE clause is submitted.  *;
%*            This parameter relies on a syntactically valid WHERE statement.     *;
%*            Example:                                                            *;
%*            _cstWhereClause=%nrstr(WHERE table in ('AE','DM','TA'))             *;
%*            _cstWhereClause=%nrstr(WHERE table = 'AE')                          *;
%*            Default: <blank>                                                    *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcreatetablesfrommetadata(
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg,
    _cstTableMD=,
    _cstColumnMD=,
    _cstOutputLibrary=,
    _cstNumObs=0,
    _cstWhereClause=
    ) / des = 'CST: Creates table shells from metadata.';

  %***************************************************;
  %*  Check _cstReturn and _cstReturnMsg parameters  *;
  %***************************************************;
  %if (%length(&_cstReturn)=0) or (%length(&_cstReturnMsg)=0) %then 
  %do;
    %**********************************************************;
    %*  We are not able to communicate other than to the LOG  *;
    %**********************************************************;
    %put %str(ERR)OR:(&sysmacroname) %str
      ()macro parameters _CSTRETURN and _CSTRETURNMSG cannot be missing.;
    %goto EXIT_MACRO;
  %end;
  
  %if (%eval(not %symexist(&_cstReturn))) %then %global &_cstReturn;
  %if (%eval(not %symexist(&_cstReturnMsg))) %then %global &_cstReturnMsg;

  %local _cstNextCode  
         _cstRandom 
         _cstTempColumnMD
         _cstTempDS1
         _cstTempTableMD
         ;
 
  %*************************************************;
  %*  Set _cstReturn and _cstReturnMsg parameters  *;
  %*************************************************;
  %let &_cstReturn=0;
  %let &_cstReturnMsg=;

  %****************************************************;
  %*  Check for missing parameters that are required  *;
  %****************************************************;
  %if (%length(&_cstTableMD)=0) or
      (%length(&_cstColumnMD)=0) or
      (%length(&_cstOutputLibrary)=0) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=One or more REQUIRED parameters (_cstTableMD, _cstColumnMD, or _cstOutputLibrary) are missing.;
    %goto EXIT_MACRO;
  %end;

  %**************************************************************************************;
  %*  Pre-requisite: Check that the output libref is assigned and input datasets exist  *;
  %**************************************************************************************;
  %if (%sysfunc(libref(&_cstOutputLibrary))) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=The output libref(&_cstOutputLibrary) is not assigned.;
    %goto EXIT_MACRO;
  %end;
  %if not %sysfunc(exist(&_cstTableMD)) or not %sysfunc(exist(&_cstColumnMD)) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=One or both of the input metadata tables (&_cstTableMD and &_cstColumnMD) do not exist.;
    %goto EXIT_MACRO;
  %end;
 
  %***************************************;
  %*  Generate temporary data set names  *;
  %***************************************;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempTableMD=_cst&_cstRandom;
  
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempColumnMD=_cst&_cstRandom;
  
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;
  
  %*********************************************************************;
  %*  Merge the source table and column metadata and check for SYSERR  *;
  %*********************************************************************;
  proc sort data=&_cstTableMD (keep=table keys label rename=(label=tableLabel)) out=work.&_cstTempTableMD;
    by table;
  run;

  %if (&SYSERR) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Sort of &_cstTableMD failed. Please check that sort variables exist.;
    %goto CHECK_SYSERR;
  %end;

  proc sort data=&_cstColumnMD out=work.&_cstTempColumnMD;
    by table order column;
  run;

  %if (&SYSERR) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Sort of &_cstColumnMD failed. Please check that sort variables exist.;
    %goto CHECK_SYSERR;
  %end;

  data &_cstTempDS1;
    merge work.&_cstTempTableMD (in=x) work.&_cstTempColumnMD (in=y);
    by table;
    if (x and y);
    &_cstWhereClause;
  run;

  %***********************************************************;
  %*  Generate _cstError if invalid _cstWhereClause is used  *;
  %***********************************************************;
  %if (&SYSERR) %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Improperly coded WHERE Clause -> &_cstWhereClause;
    %goto CHECK_SYSERR;
  %end;

  %***********************************************************;
  %*  Assign a filename for the code that will be generated  *;
  %***********************************************************;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=code&_cstRandom;

  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source";
  
  %*********************************;
  %*  Create the code to run next  *;
  %*********************************;
  %let _cstError=0;
  
  data _null_;
    file &_cstNextCode;
    set &_cstTempDS1 end=eof;
    by table;

    if (first.table) then 
    do;
      put @3 "data &_cstOutputLibrary.." table +(-1)"(label='" tableLabel +(-1) "');";
      put @5 "attrib";
    end;

    put @7 column;
    put @9 "label='" label +(-1) "'";
    
    if (upcase(type)='C') then 
    do;
      put @9 "length=$" length;
    end;
    else 
    do;
      %***********************************************;
      %*  SAS requires a numeric length between 3-8  *;
      %***********************************************;
      if length<3 then length=3;
      else if length>8 then length=8;
      put @9 "length=" length;
    end;

    if (displayformat ne '') then 
    do;
      put @9 "format=" displayFormat;
    end;

    if (last.table) then 
    do;
      put @5 ';';
      %if &_cstNumObs=0 %then
      %do;
        put @5 'stop;';
      %end;
      put @5 'call missing(of _all_);';
      put @3 'run;' /;
      if ktrim(keys)^='' then
      do;
        put @3 "proc sort data=&_cstOutputLibrary.." table +(-1)';';
        put @5 'by ' keys ';';
        put @3 'run;' /;
      end;
      put '* Check the return code for the submitted code;';
      put '%let _cstLastSysErr=&sysErr;';
      put 'data _null_;';
      put @3 'syserr = input(symget("_cstLastSysErr"),8.);';
      put @3 'if (syserr > 0) then do;';
      put @5   'call symputx("_cstError",1,"L");';
      put @3 'end;' / 'run;' /;
    end;
  run;

  %********************************;
  %*  Include the generated code  *;
  %********************************;
   %include &_cstNextCode;

  %************************;
  %*  Clear the filename  *;
  %************************;
/*filename &_cstNextCode;

  %***********************************************;
  %* Clean up temporary data sets if they exist  *;
  %***********************************************;
  proc datasets nolist lib=work;
    delete &_cstNextCode / mt=catalog;
    quit;
  run;
*/
  %cstutil_deletedataset(_cstDataSetName=work.&_cstTempDS1);

  %********************;
  %*  Exit on SYSERR  *;
  %********************;
  
  %CHECK_SYSERR:
  %cstutil_deletedataset(_cstDataSetName=work.&_cstTempTableMD);
  %cstutil_deletedataset(_cstDataSetName=work.&_cstTempColumnMD);
  
  %**********;
  %*  Exit  *;
  %**********;
  
  %EXIT_MACRO:
  
%mend cstutilcreatetablesfrommetadata;