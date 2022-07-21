%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_dsmismatch                                                            *;
%*                                                                                *;
%* Identifies data set mismatches in study and template metadata and source data. *;
%*                                                                                *;
%* This macro identifies data set mismatches between study and template metadata  *;
%* and the source data library.                                                   *;
%*                                                                                *;
%* NOTE:  This macro ignores tableScope and columnScope in the _cstControl input  *;
%*        data set.                                                               *;
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
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_dsmismatch(_cstControl=)
    / des='CST: Source/Reference dataset mismatches';

  %local
    _cstCheckID
    _cstSourceData
    _cstSourceMember
    _cstSrcData
    _cstReferenceData
    _cstReferenceMember
    _cstTableScope
    _cstUseSourceMetadata
    _cstCodeLogic
    _cstColumnScope
    _cstStandardVersion
    _cstCheckSource
    _cstStandardRef
    _cstexit_error
    ;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstDomCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;
  %let _cstSourceData=;
  %let _cstSeqCnt=0;
  %let _cstResultFlag=-1;
  %let _cstexit_error=0;

  %******************************************************************;
  %*  Read Control data set to retrieve information for the check.  *;
  %******************************************************************;

  %cstutil_readcontrol;

  %if &_cstDebug %then
  %do;
    %local _cstRestoreQuoteLenMax;
    %let _cstRestoreQuoteLenMax=%sysfunc(getoption(QuoteLenMax));
    options NoQuoteLenMax;
    %put >>> &sysmacroname.;
    %put '****************************************************';
    %put checkID=&_cstCheckID;
    %put tablescope=&_cstTableScope;
    %put useSourceMetadata =&_cstUseSourceMetadata;
    %put '****************************************************';
    options &_cstRestoreQuoteLenMax;
  %end;
  %**********************************************************************************;
  %* Single call to cstutil_buildcollist that does all domain and column processing *;
  %**********************************************************************************;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);

  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %*************************************************;
  %* Cycle through requested or applicable domains *;
  %*************************************************;
  %if &_cstDomCnt > 0 %then
  %do;

    %let _cstMetricsCntNumRecs=&_cstDomCnt;

    %***********************************************************************;
    %*  _cstCodeLogic must be a self-contained data or proc sql step. The  *;
    %*  expected result is a work._problems data set of records in error.  *;
    %*  If there are no errors, the data set should have 0 observations.   *;
    %***********************************************************************;

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
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;
    %if (&syserr gt 4) %then
    %do;
      %****************************;
      %* Check failed - SAS error *;
      %******************************************************************************************;
      %* Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      %******************************************************************************************;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Codelogic processing failed;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %let _cstDataRecords=0;

    %if %sysfunc(exist(work._cstProblems)) %then
    %do;
      data _null_;
        if 0 then set work._cstProblems nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    %*********************************;
    %* One or more errors were found *;
    %*********************************;

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

        set work._cstProblems end=last;

        attrib
          _cstSeqNo format=8. label="Sequence counter for result column"
          _cstMsgParm1 format=$char50. label="Message parameter value 1 (temp)"
          _cstMsgParm2 format=$char50. label="Message parameter value 2 (temp)"
        ;

        keep _cstMsgParm1 _cstMsgParm2;

        retain _cstSeqNo 0 resultid checkid resultseq resultflag _cst_rc;

        %***********************************;
        %* Set results data set attributes *;
        %***********************************;
        %cstutil_resultsdsattr;
        retain message resultseverity resultdetails '';

        if _n_=1 then
        do;
          keyvalues='';
          _cstSeqNo=&_cstSeqCnt;
          resultid="&_cstCheckID";
          checkid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
        end;

        srcdata = upcase(catx('.',sasref,table));
        _cstSeqNo+1;
        seqno=_cstSeqNo;

        if last then
          call symputx('_cstSeqCnt',_cstSeqNo);
      run;
      %if (&syserr gt 4) %then
      %do;
        %****************************
        %* Check failed - SAS error *;
        %******************************************************************************************;
        %* Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
        %******************************************************************************************;
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
      %let _cst_src=%upcase(&_cstTableMetadata);
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
               ,_cstActualParm= %str(&_cstactual)
               ,_cstKeyValuesParm=
               ,_cstResultsDSParm=&_cstResultsDS
               );
    %end;

    %***************************************;
    %*  Metrics count of # domains tested  *;
    %***************************************;
    %if &_cstMetrics %then
    %do;
      %if &_cstMetricsNumRecs %then
      %do;
        %******************************;
        %*  Write applicable metrics  *;
        %******************************;
        %cstutil_writemetric(
                _cstMetricParameter=# of data sets tested
                ,_cstResultID=&_cstCheckID
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstMetricCnt=&_cstMetricsCntNumRecs
                ,_cstSrcDataParm=&_cstTableScope
                );
      %end;
    %end;

  %end;
  %else
  %do;
    %***********************************************************;
    %*  No tables evaluated-check validation control data set  *;
    %***********************************************************;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstSrcData=&sysmacroname;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
  %end;

  %exit_error:
  %**********************************************************************************;
  %* This is a catch-all for singly-occurring errors (only one of which can occur   *;
  %*  within this code module because of placement within non-overlapping else      *;
  %*  code blocks).                                                                 *;
  %**********************************************************************************;
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

%mend cstcheck_dsmismatch;
