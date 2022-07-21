%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_zeroobs                                                               *;
%*                                                                                *;
%* Identifies a data set that contains zero observations.                         *;
%*                                                                                *;
%* Required file inputs:                                                          *;
%*   Single-record control data set identified by control input parameter         *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstMetrics Enables or disables metrics reporting                      *;
%* @macvar _cstMetricsNumRecs Validation metrics: calculate number of records     *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumRecs Validation metrics: number of records evaluated  *;
%* @macvar _cstMetricsNumSubj Validation metrics: calculate number of subjects    *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumSubj Validation metrics: number of subjects evaluated *;
%* @macvar _cstrunstd Primary standard                                            *;
%* @macvar _cstrunstdver Version of the primary standard                          *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_zeroobs(_cstControl=)
    / des='CST: Does data set contain 0 records?';

  %local
    _cstCheckID
    _cstCodeLogic
    _cstColumnScope
    _cstSourceData
    _cstTableCnt
    _cstTableScope
    _cstUseSourceMetadata
    _cstexit_error
    ;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstDomCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;
  %let _cstSeqCnt=0;
  %let _cstResultFlag=-1;
  %let _cstexit_error=0;

  %******************************************************************;
  %*  Read Control data set to retrieve information for the check.  *;
  %******************************************************************;

  %cstutil_readcontrol;

  %if &_cstDebug %then
  %do;
    data _null_;
      put ">>> &sysmacroname.";
      put '****************************************************';
      put "checkID=&_cstCheckID";
      put "tablescope=&_cstTableScope";
      put "useSourceMetadata =&_cstUseSourceMetadata";
      put '****************************************************';
    run;
  %end;

  %***************************************************************************;
  %* Call cstutil_builddomlist to populate work._cstTableMetadata by default *;
  %***************************************************************************;

  %cstutil_builddomlist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %if &_cst_rc  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope);
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %if %upcase(&_cstUseSourceMetadata)=N %then
  %do;
    %* The _cstAllowZeroObs parameter has been added with v1.5 to accommodate the scenario     *;
    %*  where to-be-evaluated tables may be any data set, not necessarily a sourcedata table.  *;
    %cstutil_getsasreference(_cstStandard=&_cstrunstd,_cstStandardVersion=&_cstrunstdver,_cstSASRefType=sourcedata,
       _cstSASRefsasref=_cstSourceData,_cstConcatenate=1,_cstAllowZeroObs=1);
    %if &_cst_rc %then
    %do;
      %let _cst_MsgID=CST0006;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
  %end;

  %**************************************************;
  %* Cycle through requested or applicable domains  *;
  %**************************************************;
  %if &_cstDomCnt > 0 %then
  %do;
    %***************************************;
    %*  Metrics count of # domains tested  *;
    %***************************************;
    %if &_cstMetrics %then
    %do;
      %if &_cstMetricsNumRecs %then
      %do;
        %let _cstMetricsCntNumRecs=&_cstDomCnt;
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


    %*************************************************************;
    %*  Check for multiple sasrefs if not using source metadata  *;
    %*************************************************************;
    %if %upcase(&_cstUseSourceMetadata)=N %then
    %do;

      %if %klength(&_cstSourceData)>0 %then
      %do;
        data work._csttemptablemetadata (drop=_cstLibCnt j);
          set work._csttablemetadata;
          _cstLibCnt = countw(symget('_cstSourceData'),' ');
          do j= 1 to _cstLibCnt;
            sasref = kscan(symget('_cstSourceData'),j,' ');
            output;
          end;
        run;

        data _null_;
          set work._csttemptablemetadata nobs=_numobs;
          call symputx('_cstTableCnt',_numobs);
          stop;
        run;
      %end;
      %else
      %do;
        %* Loop added for v1.5 -- see note above *;
        %let _cstTableCnt=&_cstDomCnt;
        data work._csttemptablemetadata;
          set work._csttablemetadata;
        run;
      %end;
    %end;
    %else
    %do;
      %let _cstTableCnt=&_cstDomCnt;
    %end;

    %do i=1 %to &_cstTableCnt;

      data _null_;
        %if %upcase(&_cstUseSourceMetadata)=N %then
        %do;
          set work._csttemptablemetadata (keep=sasref table firstObs=&i);
        %end;
        %else
        %do;
          set work._csttablemetadata (keep=sasref table firstObs=&i);
        %end;
        length _csttemp $200;
        _csttemp = catx('.',sasref,table);
        call symputx('_cstDSName',upcase(kstrip(_csttemp)));
        stop;
      run;

      %if %sysfunc(exist(&_cstDSName)) %then
      %do;

        data _null_;
          dsid=open("&_cstDSName");
          _numobs=attrn(dsid,"nlobs");
          call symputx('_cstDataRecords',_numobs);
          dsid=close(dsid);
        run;

        %if &_cstDataRecords = 0 %then
        %do;
          %************************************************************;
          %* Error Condition exists - data set with zero observations *;
          %************************************************************;
          %let _cst_MsgID=&_cstCheckID;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=&_cstDataRecords;
          %let _cstSrcData=&_cstDSName;
          %let _cst_rc=0;
          %let _cstResultFlag=1;
          %let _cstexit_error=0;
        %end;
        %else
        %do;
          %**************************************************;
          %* No Error Condition - data set has observations *;
          %**************************************************;
          %let _cst_MsgID=CST0100;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=;
          %let _cstSrcData=&_cstDSName;
          %let _cst_rc=0;
          %let _cstResultFlag=0;
          %let _cstexit_error=0;
        %end;

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

        %******************************;
        %*  Write applicable metrics  *;
        %******************************;
        %if &_cstMetrics %then
        %do;
          %if &_cstMetricsNumSubj %then
          %do;
            %cstutil_writemetric(
                  _cstMetricParameter=# of observations
                  ,_cstResultID=&_cstCheckID
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstDataRecords
                  ,_cstSrcDataParm=&_cstDSName
                  );
          %end;
        %end;
      %end;
      %else
      %do;
        %**********************************************************;
        %*  Check not run - &_cstDSName could not be found        *;
        %*  Shares same logic as data set with zero observations  *;
        %**********************************************************;
        %let _cst_MsgID=&_cstCheckID;
        %let _cst_MsgParm1=&_cstDSname;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstSrcData=&_cstDSname;
        %let _cstResultFlag=1;
        %let _cstexit_error=0;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                  _cstResultID=&_cstCheckID
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

  %* This is a catch-all for singly-occurring errors (only one of which can occur   *;
  %*  within this code module because of placement within non-overlapping else      *;
  %*  code blocks).                                                                 *;
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

%mend cstcheck_zeroobs;
