%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_saveresults                                                            *;
%*                                                                                *;
%* Saves process results to the file or files specified in SASReferences.         *;
%*                                                                                *;
%* This macro saves process results to the file or files that are specified in    *;
%* SASReferences with type= RESULTS values. If no SASReferences is available, no  *;
%* save is attempted.                                                             *;
%*                                                                                *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstMetricsDS Metrics data set                                         *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstIncludeValidationMetrics - optional - Include process results in the*;
%*            validation metrics.                                                 *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_saveresults(
    _cstIncludeValidationMetrics=0
    ) / des='CST: Save process results';

  %local
    _cstExitError
    _cstMetricsDSet
    _cstResults
    _cstResultsDSet
    _cstSaveRC
    _cstSaveRCmsg
  ;

  %let _cstExitError=0;
  %let _cstMetricsDSet=;
  %let _cstResults=;
  %let _cstResultsDSet=;

  %let _cstSaveRC=&_cst_rc;
  %let _cstSaveRCmsg=&_cst_rcmsg;
  %let _cst_rc=0;
  %let _cst_rcmsg=;


  %if %symexist(_cstSASRefs) %then
  %do;
    %if %sysfunc(exist(&_cstSASRefs)) %then
    %do;

      %if &_cstIncludeValidationMetrics %then
      %do;
        %if %symexist(_cstMetricsDS) %then
        %do;
          %if %sysfunc(exist(&_cstMetricsDS)) %then
          %do;
            %cstutil_getsasreference(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                                     _cstSASRefType=results,_cstSASRefSubtype=metrics,_cstSASRefsasref=_cstResults,
                                     _cstSASRefmember=_cstMetricsDSet,_cstAllowZeroObs=1);
            %if &_cst_rc %then
            %do;
              %let _cst_MsgID=CST0001;
              %let _cst_MsgParm1=;
              %let _cst_MsgParm2=;
              %let _cstExitError=1;
              %goto exit_error;
            %end;

            %if %klength(&_cstResults)<1 and %klength(&_cstMetricsDSet)<1 %then
            %do;
              %cstutil_getsasreference(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                                       _cstSASRefType=results,_cstSASRefSubtype=validationmetrics,_cstSASRefsasref=_cstResults,
                                       _cstSASRefmember=_cstMetricsDSet,_cstAllowZeroObs=1);
            %end;

            %* If SASReferences contains a type=results subtype=validationmetrics record, write to that file *;
            %if %klength(&_cstResults)>0 and %klength(&_cstMetricsDSet)>0 %then
            %do;
              * Test save for reporting purposes *;
              data &_cstResults..&_cstMetricsDSet;
                set &_cstMetricsDS;
                if _n_=1;
              run;
              %if (&syserr le 4) %then 
              %do;
                %cstutil_writeresult(
                           _cstResultId=CST0102
                          ,_cstResultParm1=&_cstResults..&_cstMetricsDSet
                          ,_cstResultSeqParm=1
                          ,_cstSeqNoParm=1
                          ,_cstSrcDataParm=CSTUTIL_SAVERESULTS
                          ,_cstResultFlagParm=0
                          ,_cstRCParm=0
                          ,_cstResultsDSParm=&_cstResultsDS
                          );
                * Final, complete save *;
                data &_cstResults..&_cstMetricsDSet;
                  set &_cstMetricsDS;
                run;
              %end;
              %else
              %do;
                %cstutil_writeresult(
                           _cstResultId=CST0077
                          ,_cstResultParm1=&_cstResults..&_cstMetricsDSet data set
                          ,_cstResultSeqParm=1
                          ,_cstSeqNoParm=1
                          ,_cstSrcDataParm=CSTUTIL_SAVERESULTS
                          ,_cstResultFlagParm=-1
                          ,_cstRCParm=0
                          ,_cstResultsDSParm=&_cstResultsDS
                          );
              %end;
            %end;
          %end;
        %end;
      %end;

      %let _cstResults=;

      %* Get information from sasreferences about where process results are to be saved.    *;
      %* It is not necessary that this information be specified if all results are written  *;
      %*  only to WORK.                                                                     *;
      %cstutil_getsasreference(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                               _cstSASRefType=results,_cstSASRefSubtype=results,_cstSASRefsasref=_cstResults,
                               _cstSASRefmember=_cstResultsDSet,_cstAllowZeroObs=1);
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0001;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cstExitError=1;
        %goto exit_error;
      %end;
      %if %klength(&_cstResults)<1 and %klength(&_cstResultsDSet)<1 %then
      %do;
        %cstutil_getsasreference(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                                 _cstSASRefType=results,_cstSASRefSubtype=validationresults,_cstSASRefsasref=_cstResults,
                                 _cstSASRefmember=_cstResultsDSet,_cstAllowZeroObs=1);
      %end;

      %* If SASReferences contains a type=results subtype=results record, write to that file *;
      %if %klength(&_cstResults)>0 and %klength(&_cstResultsDSet)>0 %then
      %do;
        * Test save for reporting purposes *;
        data &_cstResults..&_cstResultsDSet;
          set &_cstResultsDS;
            if _n_=1;
        run;
        %if (&syserr le 4) %then 
        %do;
          %cstutil_writeresult(
                     _cstResultId=CST0102
                    ,_cstResultParm1=&_cstResults..&_cstResultsDSet
                    ,_cstResultSeqParm=1
                    ,_cstSeqNoParm=1
                    ,_cstSrcDataParm=CSTUTIL_SAVERESULTS
                    ,_cstResultFlagParm=0
                    ,_cstRCParm=0
                    ,_cstResultsDSParm=&_cstResultsDS
                    );
          * Final, complete save *;
          data &_cstResults..&_cstResultsDSet;
            set &_cstResultsDS;
          run;
        %end;
        %else
        %do;
          %cstutil_writeresult(
                     _cstResultId=CST0077
                    ,_cstResultParm1=&_cstResults..&_cstResultsDSet data set
                    ,_cstResultSeqParm=1
                    ,_cstSeqNoParm=1
                    ,_cstSrcDataParm=CSTUTIL_SAVERESULTS
                    ,_cstResultFlagParm=-1
                    ,_cstRCParm=0
                    ,_cstResultsDSParm=&_cstResultsDS
                    );
        %end;
      %end;
    %end;
  %end;

%exit_error:

  %if &_cstExitError %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                 _cstResultID=&_cst_MsgID
                ,_cstResultParm1=&_cst_MsgParm1
                ,_cstResultParm2=&_cst_MsgParm2
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CSTUTIL_SAVERESULTS
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cst_rc
                ,_cstResultsDSParm=&_cstResultsDS
                );
  %end;
  %else %do;
    %let _cst_rc=&_cstSaveRC;
    %let _cst_rcmsg=&_cstSaveRCmsg;
  %end;


%mend cstutil_saveresults;