%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_crossstdcomparedomains                                                *;
%*                                                                                *;
%* Compares column values in one table with the columns in another domain.        *;
%*                                                                                *;
%* This mcro compares the values for one or more columns in one table against     *;
%* either the same columns in another domain in another standard, or compares     *;
%* values against metadata from the comparison standard.                          *;
%*                                                                                *;
%* NOTE: This macro requires the use of _cstCodeLogic as a full DATA step or PROC *;
%*       SQL invocation. This DATA step or PROC SQL invocation assumes as input a *;
%*       Work copy of the column metadata data set that is returned by the        *;
%*       cstutil_buildcollist macro. Any resulting records in the derived data    *;
%*       set represent errors to report.                                          *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    ADaM subject not found in SDTM dm domain                                    *;
%*    ADaM SDTM domain reference (for traceability) but SDTM domain in unknown    *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstMetrics Enables or disables metrics reporting                      *;
%* @macvar _cstMetricsNumRecs Validation metrics: calculate number of records     *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumRecs Validation metrics: number of records evaluated  *;
%* @macvar _cstrunstd Primary standard                                            *;
%* @macvar _cstrunstdver Version of the primary standard                          *;
%* @macvar _cstcrossstd  Name of the comparison standard                          *;
%* @macvar _cstcrossstdver Version of the comparison standard                     *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_crossstdcomparedomains(_cstControl=)
    / des='CST: Cross-std Matching column values not found';

  %local

    _csttemp
    _cstDomainOnly
    _cstDSName
    _cstDSKeys
    _cstSubCnt
    _cstTableScope
    _cstColumnScope
    _cstUniqueColumns
    _cstUniqueSQLColumns
    _cstUniqueColumnCnt

    _cstTableSublistCnt

    _cstCheckID
    _cstCheckSource
    _cstCodeLogic
    _cstUseSourceMetadata
    _cstStandardRef
    _cstStandardVersion

    _cstexit_error
    _cstexit_loop

    _cstCrMne
    _cstStMne
    _cstCrossDataLib
    _cstDataLib
    _cstColCnt
    _cstDomCnt
    _cstDomList
    _cstColList
    _cstSQLColList
    _cstUseBadVar

  ;

  %cstutil_readcontrol;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstexit_loop=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;

  %let _cstUniqueColumnCnt=0;

  %if &_cstDebug %then
  %do;
    %local _cstRestoreQuoteLenMax;
    %let _cstRestoreQuoteLenMax=%sysfunc(getoption(QuoteLenMax));
    options NoQuoteLenMax;
    data _null_;
      put ">>> &sysmacroname.";
      put '****************************************************';
      put "checkID=&_cstCheckID";
      put "standardVersion=&_cstStandardVersion";
      put "checkSource=&_cstCheckSource";
      put "tableScope=&_cstTableScope";
      put "columnScope=&_cstColumnScope";
      put "codeLogic=%superq(_cstCodeLogic)";
      put "useSourceMetadata=&_cstUseSourceMetadata";
      put "standardref=&_cstStandardRef";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;


    %let _cstCrMne=;
    %let _cstStMne=;
    %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);

    data _null_;
      set work._cstStandards;
      if upcase(standard)=upcase("&_cstcrossstd") then
        call symputx('_cstCrMne',mnemonic);
      else if upcase(standard)=upcase("&_cstrunstd") then
        call symputx('_cstStMne',mnemonic);
    run;
    proc datasets lib=work nolist;
      delete _cstStandards;
    quit;

    %if %symexist(_cstcrossstd) %then %do;
      %if %length(&_cstcrossstd)>0 %then
      %do;

        %* Because we only have one tableScope and columnScope containing values specific to the primary standard,  *;
        %* we cannot call cstutil_buildcollist to get comparison standard table and column metadata.  Instead, it   *;
        %* is necessary to call cstutil_setmodel and return/keep ALL comparison standard metadata.                  *;

        %cstutil_setmodel(_cstStd=&_cstcrossstd,_cstStdVer=&_cstcrossstdver);
        %if &_cst_rc  or ^%sysfunc(exist(work._cstsrccolumnmetadata))  or ^%sysfunc(exist(work._cstrefcolumnmetadata)) %then
        %do;
          %let _cst_MsgID=CST0002;
          %let _cst_MsgParm1=;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstSrcData=&sysmacroname;
          %let _cstactual=%str(_cstStd=&_cstcrossstd,_cstStdVer=&_cstcrossstdver,tableScope=_ALL_,columnScope=_ALL_);
          %let _cstexit_error=1;
          %goto exit_error;
        %end;

        * Clean up and reset things for the primary standard *;
        %if %sysfunc(exist(work._cstsrccrosscolmeta)) or %sysfunc(exist(work._cstrefcrosscolmeta)) or
            %sysfunc(exist(work._cstsrccrosstabmeta)) or %sysfunc(exist(work._cstrefcrosstabmeta)) or
            %sysfunc(exist(work._cstcrosstablemetadata)) or %sysfunc(exist(work._cstcrosscolumnmetadata)) %then
        %do;
          proc datasets lib=work nolist;
            delete _cstsrccrosscolmeta _cstrefcrosscolmeta _cstsrccrosstabmeta _cstrefcrosstabmeta
                   _cstcrosstablemetadata _cstcrosscolumnmetadata;
          quit;
        %end;

        proc datasets lib=work nolist;
          change _cstsrccolumnmetadata=_cstsrccrosscolmeta
                 _cstrefcolumnmetadata=_cstrefcrosscolmeta
                 _cstsrctablemetadata=_cstsrccrosstabmeta
                 _cstreftablemetadata=_cstrefcrosstabmeta
                 _csttablemetadata=_cstcrosstablemetadata
                 _cstcolumnmetadata=_cstcrosscolumnmetadata;
        quit;

        %cstutil_getsasreference(_cstStandard=&_cstcrossstd,_cstStandardVersion=&_cstcrossstdver,_cstSASRefType=sourcedata,
                           _cstSASRefsasref=_cstCrossDataLib);
        %if &_cst_rc %then
        %do;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=A sourcedata reference for the comparison standard &_cstcrossstd;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstSrcData=&sysmacroname;
          %let _cstactual=;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;
      %end;
      %else
      %do;
          %let _cst_MsgID=CST0035;
          %let _cst_MsgParm1=;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstSrcData=&sysmacroname;
          %let _cstactual=%str(_cstStd=&_cstcrossstd,_cstStdVer=&_cstcrossstdver);
          %let _cstexit_error=1;
          %goto exit_error;
      %end;
    %end;

    %* Call to cstutil_buildcollist to get primary standard table and column metadata *;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
    %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if ^%sysfunc(exist(work._cstsrccolumnmetadata))  or ^%sysfunc(exist(work._cstrefcolumnmetadata)) %then
    %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %cstutil_getsasreference(_cstStandard=&_cstrunstd,_cstStandardVersion=&_cstrunstdver,_cstSASRefType=sourcedata,
                             _cstSASRefsasref=_cstDataLib);
    %if &_cst_rc %then
    %do;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=A sourcedata reference for the standard &_cstStandard;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstactual=;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

  proc sql noprint;
    select catx('.',upcase("&_cstDataLib"),upcase(table)) into :_cstDomList separated by ' ' from work._csttablemetadata;
    select count(*) into :_cstDomCnt from work._csttablemetadata;
  quit;

  data _null_;
    set work._cstcolumnmetadata end=last;
      attrib tempvar format=$2000.;
      retain tempvar;
      if indexw(tempvar,kstrip(column),', ')=0 then
        tempvar=catx(',',tempvar,column);
      if last then
      do;
        call symputx('_cstSQLColList',tempvar);
        call symputx('_cstColList',tranwrd(tempvar,',',' '));
        call symputx('_cstColCnt',_n_);
      end;
  run;

  %if &_cstDomCnt<1 or &_cstColCnt<1 %then
  %do;
    %* No tables evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %do i=1 %to &_cstDomCnt;
    %let _cstDSName=%SYSFUNC(kscan(&_cstDomList,&i,' '));
    %let _cstDomainOnly=%scan(&_cstDSName,2,.);

    %if ^%sysfunc(exist(&_cstDSName)) %then
    %do;
      %******************************************************;
      %*  Check not run - data set could not be found       *;
      %******************************************************;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstDSname;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_loop=1;
      %goto exit_loop;
    %end;

/*
    %if ^%sysfunc(exist(&_cstCrossDataLib..dm)) %then
    %do;
      %******************************************************;
      %*  Check not run - data set could not be found       *;
      %******************************************************;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstCrossDataLib..dm;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_loop=1;
      %goto exit_loop;
    %end;
*/

    data _null_;
      set work._csttablemetadata (keep=sasref table keys firstObs=&i obs=&i);
        call symputx('_cstDSKeys',keys);
    run;

    * This data step reports an error if any column in the varlist does not exist  *;
    data _null_;
      attrib _cstMsg format=$80.
             _cstError format=8.
             column format=$32.
             varlist format=$2000.
             invalidList format=$500.;
      _cstError=0;
      varlist=symget('_cstColList');
      dsid=open("&_cstDSName.","i");
      if dsid=0 then
      do;
        _cstError=1;
        _cstMsg="Could not open data set &_cstDSName.";
      end;
      else do i=1 to countw(varlist,' ');
        column=kscan(varlist, i, ' ');
        if varnum(dsid, column)=0 then
        do;
          _cstError=1;
          invalidList=catx(' ',invalidList,column);
        end;
      end;
      dsid=close(dsid);
      if _cstError=1 then
      do;
        call symputx('_cstexit_error', _cstError);
        call symputx('_cst_MsgParm1', "&_cstDSName");
        call symputx('_cst_MsgParm2', invalidList);
      end;
    run;
    %if &_cstexit_error %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %let _cstSrcData=&sysmacroname;
      %cstutil_writeresult(
                   _cstResultID=CST0021
                   ,_cstValCheckID=&_cstCheckID
                   ,_cstResultParm1=&_cst_MsgParm1
                   ,_cstResultParm2=&_cst_MsgParm2
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=&_cstSrcData
                   ,_cstResultFlagParm=-1
                   ,_cstRCParm=0
                   ,_cstActualParm=
                   ,_cstKeyValuesParm=
                   ,_cstResultsDSParm=&_cstResultsDS
                   );
      %let _cstexit_error=0;
      %goto exit_loop;
    %end;

    * Write applicable metrics *;
    %if &_cstMetrics %then %do;

      data _null_;
        if 0 then set &_cstDSName nobs=_numobs;
        call symputx('_cstMetricsCntNumRecs',_numobs);
        stop;
      run;

      %if &_cstMetricsNumRecs %then
        %cstutil_writemetric(
                      _cstMetricParameter=# of records tested
                     ,_cstResultID=&_cstCheckID
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstMetricCnt=&_cstMetricsCntNumRecs
                     ,_cstSrcDataParm=&_cstDSName
                    );
    %end;

    %*************************************************************************
    %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
    %*  expected result is a work._cstproblems data set of records in error. *
    %*  If there are no errors, the data set should have 0 observations.     *
    %*                                                                       *;
    %* Macro variables available to codeLogic:                               *;
    %*  _cstDSName                        _cstDomainOnly                     *;
    %*  _cstCrossDataLib                                                     *;
    %*  _cstSQLColList                                                       *;
    %*                                                                       *;
    %*************************************************************************;

    %let _cstUseBadVar=0;
    &_cstCodeLogic;


    %if %symexist(sqlrc) %then %do;
      %if (&sqlrc gt 0) %then
      %do;
        %* Check failed - SAS error  *;
        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=Codelogic processing failed;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_loop=1;
        %goto exit_loop;
      %end;
    %end;
    %if (&syserr gt 4) %then
    %do;
      %* Check failed - SAS error  *;

      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Codelogic processing failed;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_loop=1;
      %goto exit_loop;
    %end;

    %if &_cstexit_error %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %let _cstSrcData=&sysmacroname;
      %cstutil_writeresult(
                   _cstResultID=CST0021
                   ,_cstValCheckID=&_cstCheckID
                   ,_cstResultParm1=&_cst_MsgParm1
                   ,_cstResultParm2=&_cst_MsgParm2
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=&_cstSrcData
                   ,_cstResultFlagParm=-1
                   ,_cstRCParm=0
                   ,_cstActualParm=
                   ,_cstKeyValuesParm=
                   ,_cstResultsDSParm=&_cstResultsDS
                   );
      %let _cstexit_error=0;
      %goto exit_loop;
    %end;
    %let _cstDataRecords=0;

    %if %sysfunc(exist(work._cstproblems)) %then
    %do;
      data _null_;
        if 0 then set work._cstproblems nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    %**************************************;
    %* One or more errors were found  *;
    %**************************************;

    %if &_cstDataRecords %then
    %do;

      %****************************************;
      %* Create a temporary results data set. *;
      %****************************************;
      %local
        _csttemp
      ;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttemp',_csttemp);
      run;

      %******************************************************;
      %* Add the records to the temporary results data set. *;
      %******************************************************;
      data &_csttemp (label='Work error data set');
        %cstutil_resultsdskeep;

        set work._cstproblems end=last;

        attrib
          _cstSeqNo format=8. label="Sequence counter for result column"
        ;

        keep _cstMsgParm1 _cstMsgParm2;

        retain _cstSeqNo 0 resultid resultseq resultflag _cst_rc;

        %***********************************;
        %* Set results data set attributes *;
        %***********************************;
        %cstutil_resultsdsattr;
        retain message resultseverity resultdetails '';

        if _n_=1 then
        do;
          _cstSeqNo=&_cstSeqCnt;
          resultid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
        end;

        _cstMsgParm1='';
        _cstMsgParm2='';
        srcdata ="&_cstDSName";
        _cstSeqNo+1;
        seqno=_cstSeqNo;
        keyvalues='';

        * Calculate keyvalues column.  *;
        %do _currentCol = 1 %to %SYSFUNC(countw(&_cstDSKeys,' '));
          %let _cstCol=%SYSFUNC(kscan(&_cstDSKeys,&_currentCol,' '));
          if vtype(&_cstCol)='C' then
          do;
            if keyvalues='' then
              keyvalues = cats("&_cstCol","=",&_cstCol);
            else
              keyvalues = cats(keyvalues,",","&_cstCol","=",&_cstCol);
          end;
          else
          do;
            if keyvalues='' then
              keyvalues = cats("&_cstCol","=",put(&_cstCol,8.));
            else
              keyvalues = cats(keyvalues,",","&_cstCol","=",put(&_cstCol,8.));
          end;
        %end;

        %do _currentCol = 1 %to %SYSFUNC(countw(&_cstColList,' '));
          %let _cstCol=%SYSFUNC(kscan(&_cstColList,&_currentCol,' '));
          %if &_cstUseBadVar=1 %then
          %do;
            if _cstBadColumn="&_cstCol" then
            do;
              if vtype(&_cstCol)='C' then
              do;
                actual = cats("&_cstCol","=",&_cstCol,",","&_cstCrMne._&_cstCol","=",&_cstCrMne._&_cstCol);
              end;
              else
              do;
                actual = cats("&_cstCol","=",put(&_cstCol,8.),",","&_cstCrMne._&_cstCol","=",put(&_cstCrMne._&_cstCol,8.));
              end;
            end;
          %end;
          %else
          %do;
            if vtype(&_cstCol)='C' then
            do;
              if actual='' then
                actual = cats("&_cstCol","=",&_cstCol);
              else
                actual = cats(actual,",","&_cstCol","=",&_cstCol);
            end;
            else
            do;
              if actual='' then
                actual = cats("&_cstCol","=",put(&_cstCol,8.));
              else
                actual = cats(actual,",","&_cstCol","=",put(&_cstCol,8.));
            end;
          %end;
        %end;

        checkid="&_cstCheckID";

        if last then
          call symputx('_cstSeqCnt',_cstSeqNo);
      run;
      %if (&syserr gt 4) %then
      %do;
        %* Check failed - SAS error  *;

        * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
        options nosyntaxcheck obs=max replace;

        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      %*******************************************************************;
      %* Parameters passed are check-level -- not record-level -- values *;
      %*******************************************************************;
      %cstutil_appendresultds(
                     _cstErrorDS=&_csttemp
                    ,_cstVersion=&_cstStandardVersion
                    ,_cstSource=&_cstCheckSource
                    ,_cstStdRef=&_cstStandardRef
                    );

      proc datasets lib=work nolist;
        delete &_csttemp;
      quit;
    %end;
    %else
    %do;
      %**************************************;
      %* No errors detected in source data  *;
      %**************************************;
      %let _cst_MsgID=CST0100;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
              _cstResultID=&_cst_MsgID
             ,_cstValCheckID=&_cstCheckID
             ,_cstResultParm1=&_cst_MsgParm1
             ,_cstResultParm2=&_cst_MsgParm2
             ,_cstResultSeqParm=&_cstResultSeq
             ,_cstSeqNoParm=&_cstSeqCnt
             ,_cstSrcDataParm=&_cstDSName
             ,_cstResultFlagParm=0
             ,_cstRCParm=&_cst_rc
             ,_cstActualParm=%str(&_cstactual)
             ,_cstKeyValuesParm=
             ,_cstResultsDSParm=&_cstResultsDS
             );
    %end;

%exit_loop:

    %if &_cstDebug<1 %then
    %do;
      %if %sysfunc(exist(work._cstproblems)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstproblems;
        quit;
      %end;
      %if %length(&_csttemp)>0 %then
      %do;
        %if %sysfunc(exist(&_csttemp)) %then
        %do;
          proc datasets lib=work nolist;
            delete &_csttemp;
          quit;
        %end;
      %end;
    %end;

    %if &_cstexit_loop %then
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
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                );

      %let _cstexit_loop=0;
      %let _cstexit_error=0;
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
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug=0 %then
  %do;
    proc datasets lib=work nolist;
      delete _cstsrccrosscolmeta _cstrefcrosscolmeta _cstsrccrosstabmeta _cstrefcrosstabmeta _cstcrosstablemetadata _cstcrosscolumnmetadata;
    quit;

    %if %sysfunc(exist(work._csttablesubset1)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablesubset1;
      quit;
    %end;
    %if %sysfunc(exist(work._csttablesubset2)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablesubset2;
      quit;
    %end;
  %end;
  %else
    %put <<< cstcheck_crossstdcomparedomains;

%mend cstcheck_crossstdcomparedomains;
