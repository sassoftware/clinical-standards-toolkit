%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutillookupvalues                                                       *;
%*                                                                                *;
%* Determines whether metadata column values are in the StandardLookup data set.  *;
%*                                                                                *;
%* This macro determines whether metadata column values for discrete columns are  *;
%* in the StandardLookup data set.                                                *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (for      *;
%*       example, a full DATA step or PROC SQL invocation). It creates and        *;
%*       populates work._cstproblems to return to the calling check macro for     *;
%*       reporting purposes.                                                      *;
%*                                                                                *;
%* @macvar _cstValidationStd Standard of the StandardLookup data set              *;
%* @macvar _cstValidationStdVer StandardVersion of the StandardLookup data set    *;
%*                                                                                *;
%* @param _cstStdsDS  - optional - The list of supported standards to use for     *;
%*            this check. If this parameter is not specified, all records in the  *;
%*            glmeta.standards data set are used.                                 *;
%*            Default: glmeta.standards                                           *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutillookupvalues(
    _cstStdsDS=glmeta.standards
    ) / des="CST: Checks column values against standardlookup";

  %local
    _cstCol
    _cstDiscCnt
    _cstDiscList
    _cstDS
    _cstDSCnt
    _cstDSList
    _cstDSName
    _cstexit_error
    _cstLib
    _cstLKUPCnt
    _cstLookupDS
  ;
  
  %let _cstexit_error=0;
  %let _cstDiscCnt=0;
  %let _cstDSCnt=0;
  %let _cstLKUPCnt=0;
  
  %if %length(&_cstStdsDS)=0 %then
  %do;
    %let _cstStdsDS=work._cstAllStds;
    %cst_getRegisteredStandards(_cstOutputDS=&_cstStdsDS);
  %end;
  %if ^%sysfunc(exist(&_cstStdsDS)) %then
  %do;
    %let _cst_MsgID=CST0008;
    %let _cst_MsgParm1=&_cstStdsDS;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstactual=;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  * Limit files to selected standards *;
  proc sql noprint;
    create table work._cstLKUPs as
    select ref.*
    from &_cstStdsDS (keep=standard standardversion 
                      where=(upcase(standard)=upcase("&_cstValidationStd") and
                             upcase(standardversion)=upcase("&_cstValidationStdVer"))) std
          left join
    work._csttablemetadata (keep=standard standardversion sasref table type where=(upcase(type)='LOOKUP')) ref
    on upcase(std.standard)=upcase(ref.standard) and upcase(std.standardversion)=upcase(ref.standardversion)
    where ref.standard ne ''
    order by ref.standard, ref.standardversion;
    select count(*) into :_cstLKUPCnt 
    from work._cstLKUPs;
  quit;

  data work._cstproblems;
    attrib
      SASref format=$8. label="SAS libref "
      table format=$32. label="CST table name"
      column format=$32. label="CST column name"
      _value_ format=$200. label="Unique CST column value"
    ;
    call missing(of _all_);
    if _n_=1 then stop;
  run;

  %do _lkup_=1 %to &_cstLKUPCnt;

    %if %length(&_cstLookupSource)=0 %then
    %do;
      data _null_;
        set work._cstLKUPs (firstObs=&_lkup_ obs=&_lkup_);
        call symputx("_cstLib",sasref);
        call symputx("_cstDS",table);
      run;
      %let _cstLookupDS=&_cstLib..&_cstDS;
    %end;
    %else %do;
      %let _cstLookupDS=&_cstLookupSource;
    %end;
    
    %let _cstDSList=;
    %let _cstDSCnt=0;

    proc sql noprint;
      create table work._cstDSList as
      select ref.*
      from 
        work._csttablemetadata ref,
           (select distinct sasref, table
           from &_cstLookupDS (where=(missing(refcolumn)))) lk
      where upcase(ref.sasref)=upcase(lk.sasref) and upcase(ref.table)=upcase(lk.table) and ref.table ne '';
      select catx(".",sasref,table) into :_cstDSList separated by " "
      from work._cstDSList;
      select count(*) into :_cstDSCnt
      from work._cstDSList;
    quit;
    %**put &=_cstDSList;
    %**put &=_cstDSCnt;

    proc datasets lib=work nolist;
      delete _cstDSList;
    quit;

    %do _ds_=1 %to &_cstDSCnt;
      %let _cstDSName=%upcase(%scan(&_cstDSList,&_ds_," "));
      %**put &=_cstDSName;
      %if %sysfunc(exist(&_cstDSName)) %then
      %do;
        proc sql noprint;
          select distinct column into :_cstDiscList separated by " "
          from &_cstLookupDS (where=(upcase(sasref)=scan("&_cstDSName",1,".") and upcase(table)=scan("&_cstDSName",2,".")));
          select count(distinct column) into :_cstDiscCnt
          from &_cstLookupDS (where=(upcase(sasref)=scan("&_cstDSName",1,".") and upcase(table)=scan("&_cstDSName",2,".")));
        quit;
        %**put &=_cstDiscList;
        %**put &=_cstDiscCnt;

        %do _dis_=1 %to &_cstDiscCnt;
          %let _cstCol=%scan(&_cstDiscList,&_dis_," ");
          %let _cstColVType=;
          
          data _null_;
            set work._cstcolumnmetadata (where=(upcase(sasref)=scan("&_cstDSName",1,".") and 
                                                upcase(table)=scan("&_cstDSName",2,".") and
                                                upcase(column)=upcase("&_cstCol")));
              call symputx('_cstColVType',type);
          run;

          %if %length(&_cstColVType)>0 %then
          %do;

            proc sql noprint;
              create table work._cstProbValues as 
              select distinct scan("&_cstDSName",1,".") as sasref length=8 format=$8., 
                              scan("&_cstDSName",2,".") as table length=32 format=$32.,
                              upcase("&_cstCol") as column length=32 format=$32., 
%if &_cstColVType=C %then %do;
                              upcase(src.&_cstCol) as _value_ length=200 format=$200.
%end;
%else %do;
                              strip(put(src.&_cstCol,best.)) as _value_ length=200 format=$200.
%end;
              from &_cstDSName src
                left join
                   &_cstLookupDS (where=(upcase(column)=upcase("&_cstCol") and missing(refcolumn) and upcase(sasref)=scan("&_cstDSName",1,".") and upcase(table)=scan("&_cstDSName",2,"."))) lk
                on upcase(src.&_cstCol) = upcase(lk.value)
                where missing(lk.value) and not missing(src.&_cstCol);
            quit;

            proc append base=work._cstproblems data=work._cstProbValues;
            run;
          
            proc datasets lib=work nolist;
              delete _cstProbValues;
            quit;
          %end;
        %end;
      %end;
    %end;
  %end;

%exit_error:

  %if &_cstexit_error %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                   _cstResultID=&_cst_MsgID
                   ,_cstValCheckID=&_cstCheckID
                   ,_cstResultParm1=&_cst_MsgParm1
                   ,_cstResultParm2=&_cst_MsgParm2
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=&_cstSrcData
                   ,_cstResultFlagParm=&_cstResultFlag
                   ,_cstRCParm=&_cst_rc
                   ,_cstResultsDSParm=&_cstResultsDS
                   );

  %end;

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(exist(work._cstLKUPs)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstLKUPs;
      quit;
    %end;
  %end;


%mend cstcheckutillookupvalues;
