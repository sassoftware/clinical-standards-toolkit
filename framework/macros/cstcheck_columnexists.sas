%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_columnexists                                                          *;
%*                                                                                *;
%* Determines whether columnScope columns exist in the tableScope tables.         *;
%*                                                                                *;
%* This macro determines whether one or more of the columns defined in            *;
%* columnScope exist in each of the tables defined in tableScope.                 *;
%*                                                                                *;
%* NOTE: By default, this check does not require the use of codeLogic. If the     *;
%*       check metadata includes a non-null value of codeLogic, it is used. If    *;
%*       codeLogic is used, it must populate the macro variable _cstDataRecords   *;
%*       with a count that represents the number of columns found in the specific *;
%*       table defined by _cstDSName and _cstDomainOnly. A _cstDataRecords count  *;
%*       of 0 is reported as an error.                                            *;
%*                                                                                *;
%* NOTE: Care must be exercised when columnScope contains either multiple         *;
%*       columns (for example, TRTP+TRTPn) or a column with wildcarding (for      *;
%*       example, TRT**P).  In both cases, the default code reports an error ONLY *;
%*       if NONE of the columns are found.                                        *;
%*                                                                                *;
%* NOTE: This is a metadata-only check against column and table metadata files.   *;
%*       No source data sets are referenced.                                      *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    ADAM0090 - (for BDS data sets) does the column TRTP exist?                  *;
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
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_columnexists(_cstControl=)
    / des='CST: Column does not exist';

  %local
    _csttempds

    _cstColCnt
    _cstDomCnt
    _cstDSList
    _cstDSName
    _cstDomainOnly
    _cstDataRecords


    _cstColumn
    _cstDSKeys
    _cstKey
    _cstColumn1
    _cstColumn2

    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstCodeLogic
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstStandardRef
    _cstReportingColumns

    _cstSubDSList
    _cstSubVarList
    _cstBypassExist
    _cstRptLevel
    _cstResultReported


    _cstSubCnt
    _cstexit_error
    _cstexit_loop

    _cstVarlistCnt
    _cstSubVarDriver
    _cstSubVarDriverCnt
    _cstDriverDSList
    _cstSubVarWC
    _cstSubVarDriver1Pre
    _cstSubVarDriver1Suf
    _cstSubVarDriver1WCType
    _cstSubVarDriver1WCCnt
    _cstSubVarDriver2Pre
    _cstSubVarDriver2Suf
    _cstSubVarDriver2WCType
    _cstSubVarDriver2WCCnt
  ;

  %cstutil_readcontrol;

  %let _cstactual=;
  %let _cstSrcData=&sysmacroname;
  %let _cstResultFlag=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstexit_loop=0;

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
      put "reportingColumns=&_cstReportingColumns";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;

  %if %length(&_cstColumnScope)=0 %then
  %do;
    %* Required parameter not found  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=ColumnScope must be specified;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %let _cstVarlistCnt=0;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstDomSubOverride=Y,_cstColSubOverride=Y);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._cstalltablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._cstalltablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %if &_cstDomCnt=0 %then
  %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  %* columnScope syntax such as {TRTP+TRTPn} is permitted, but not two or more sublists *;
  %if &_cstVarlistCnt>1 %then
  %do;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=More than one sublist for this macro;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  * Note reference to _cstalltablemetadata rather than _csttablemetadata *;
  proc sql noprint;
    select distinct(catx('.',sasref,table)) into :_cstDSList  separated by ' '
    from work._cstalltablemetadata;
    select count(*) into :_cstMetricsCntNumRecs
    from work._cstalltablemetadata;
  quit;

  %do i=1 %to %SYSFUNC(countw(&_cstDSList,' '));
    %let _cstDSName=%scan(&_cstDSList,&i,' ');
    %let _cstDomainOnly=%scan(&_cstDSName,2,'.');
    %let _cstDataRecords=0;

    %* codeLogic is optional for this check macro.  If not used, the following default processing is used *;
    %if %length(&_cstCodeLogic)=0 %then
    %do;
      data work._cstColumns;
        set work._cstcolumnmetadata (where=(upcase(table)=upcase("&_cstDomainOnly"))) end=last;
          if last then
            call symputx('_cstDataRecords',_n_);
      run;
    %end;
    %else
    %do;

      %*************************************************************************;
      %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *;
      %*  expected result is a work._cstColumns data set.  If this data set    *;
      %*  has 0 observations, this will be interpreted as an error condition.  *;
      %*************************************************************************;

      &_cstCodeLogic;

      %if %symexist(sqlrc) %then %do;
        %if (&sqlrc gt 0) %then
        %do;
          %let _cstResultReported=1;
          %* Check failed - SAS error  *;
          %let _cst_MsgID=CST0050;
          %let _cst_MsgParm1=Codelogic processing failed;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;
      %end;
      %if (&syserr gt 4) %then
      %do;
        %* Check failed - SAS error  *;

        * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
        options nosyntaxcheck obs=max replace;

        %let _cstResultReported=1;
        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=Codelogic processing failed;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;

    %if &_cstDataRecords %then
    %do;
      %* No errors detected in source data  *;
      %let _cst_MsgID=CST0100;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_src=%upcase(&_cstDSName);
      %let _cst_rc=0;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cst_src
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;
    %else
    %do;
      %* Column(s) not found in source data  *;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_src=%upcase(&_cstDSName);
      %let _cst_rc=0;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cstCheckID
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cst_src
                  ,_cstResultFlagParm=1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

    %if &_cstDebug=0 %then
    %do;
      %if %sysfunc(exist(work._cstColumns)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstColumns;
        quit;
      %end;
    %end;

  %end;  %* end of DS loop  *;

  %* Write applicable metrics *;
  %if &_cstMetrics %then %do;

    %if &_cstMetricsNumRecs %then
      %cstutil_writemetric(
                  _cstMetricParameter=# of records tested
                 ,_cstResultID=&_cstCheckID
                 ,_cstResultSeqParm=&_cstResultSeq
                 ,_cstMetricCnt=&_cstMetricsCntNumRecs
                 ,_cstSrcDataParm=%upcase(work._cstcolumnmetadata)
                );
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
    %if %sysfunc(exist(work._cstcolumnmetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstcolumnmetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._csttablemetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablemetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._cstalltablemetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstalltablemetadata;
      quit;
    %end;
  %end;
  %else
  %do;
    %put <<< cstcheck_columnexists;
  %end;

%mend cstcheck_columnexists;
