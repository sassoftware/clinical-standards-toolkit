%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_metamismatch                                                          *;
%*                                                                                *;
%* Identifies inconsistencies between study and reference column metadata.        *;
%*                                                                                *;
%* This macro performs one of the following three assessments:                    *;
%*   1: Using columnScope [][] sublist syntax, for the column specified in        *;
%*      sublist1, determines whether the corresponding column specified in        *;
%*      sublist2 exists. This assessment expects codeLogic to create              *;
%*      work._cstsublists.                                                        *;
%*      Examples:                                                                 *;
%*        [TRT##PN][TRT##P] - If TRT01PN exists, TRT01P should exist              *;
%*        [STARTDT][CNSR] - STARTDT is present and CNSR is not present            *;
%*   2: Using any columnScope syntax OTHER THAN [][] sublist syntax, determines   *;
%*      whether columns with characteristics defined by columnScope syntax or in  *;
%*      codeLogic exist. This assessment expects codeLogic to create              *;
%*      work._cstnonmatch.                                                        *;
%*      Example:                                                                  *;
%*         TRT**A - For columns starting with TRT and ending with A, some         *;
%*                  condition specified in codeLogic occurs                       *;
%*   3: When columnScope is null, processing is governed by codeLogic that        *;
%*      references the available table and column metadata. Either work._cstmatch *;
%*      or work._cstnonmatch must be created by the check codeLogic.              *;
%*                                                                                *;
%*                                                                                *;
%* NOTE: This macro requires use of _cstCodeLogic as a full SAS DATA step or PROC *;
%*       SQL invocation. This DATA step or PROC SQL invocation assumes as input a *;
%*       Work copy of the column metadata data set that is returned by the        *;
%*       cstutil_buildcollist macro. Any resulting records in the derived data    *;
%*       set represent errors to report.                                          *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*  1. No data content is accessed for this check.                                *;
%*  2. Both study and reference metadata must be present to assess compliance.    *;
%*  3. Current coding approach assumes:                                           *;
%*         - no reporting of non-errors                                           *;
%*         - reporting of study and reference metadata mismatches that prevent    *;
%*           compliance assessment                                                *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    Required column not found (Error)                                           *;
%*    Expected column not found (Warning)                                         *;
%*    Permissible column not found (Note)                                         *;
%*    Column found in data set but not in specification                           *;
%*    Supplemental Qualifier data set without USUBJID column                      *;
%*    Column metadata attribute differences (type, length, label, order, CT)      *;
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

%macro cstcheck_metamismatch(_cstControl=)
    / des='CST: Column metadata inconsistencies';

  %local
    _cstAttr
    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstTableScope
    _cstColumnScope
    _cstCodeLogic
    _cstUseSourceMetadata
    _cstStandardRef
    _cstBase
    _cstCompare
    _cstDataRecords
    _cstNMRecords
    _cstRptLevel
    _cstexit_error
    _cstactual

    _cstColCnt
    _cstDSName
    _cstDSName1
    _cstDSName2
    _cstRefOnly
    _cstColumn
    _cstColumn1
    _cstColumn2
    _cstDSKeys
    _cstKeyCnt

    _cstColumnSublistCnt
    _cstSubCnt1
    _cstSubCnt2
    _cstSQLKeys
    _cstTempSource
  ;

  %cstutil_readcontrol;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstAttr=;
  %let _cstactual=;
  %let _cstSrcData=&sysmacroname;
  %let _cstResultFlag=0;
  %let _cstexit_error=0;
  %let _cstRptLevel=COLUMN;
  %let _cstTempSource=;


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

  %***********************;
  %* Function 1          *;
  %***********************;

  %if %SYSFUNC(countc(&_cstColumnScope,'['))>0 %then
  %do;
    %let _cstColCnt=0;
    %let _cstColumnSublistCnt=0;
    %let _cstSubCnt1=0;
    %let _cstSubCnt2=0;

    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstColSubOverride=Y);

    %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    data _null_;
      if 0 then set work._cstcolumnmetadata nobs=_numobs;
      call symputx('_cstColCnt',_numobs);
      stop;
    run;

    %if &_cstColCnt=0 %then
    %do;
      %* Problems with columnScope  *;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if &_cstColumnSublistCnt>2 %then
    %do;
      %* Problems with tableScope  *;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=More than two sublists;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* codeLogic must be non-null and must produce the following data set:  *;
    %*   - work._cstsublists                                                *;

    %if %length(&_cstCodeLogic)<1 %then
    %do;
      %* _cstCodeLogic is required with columnScope sublist comparisons *;
      %let _cst_MsgID=CST0005;
      %let _cst_MsgParm1=CSTCHECK_METAMISMATCH;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* Write applicable metrics *;
    %if &_cstMetrics %then
      %if &_cstMetricsNumRecs %then
      %do;
        %let _cst_src=%upcase(work._cstcolumnmetadata);
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstColCnt
                         ,_cstSrcDataParm=&_cst_src
                        );
      %end;

    %let _cstError=0;
    %* This function expects codeLogic to create work._cstsublists  *;
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
      %* Check failed - SAS error  *;

      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Codelogic processing failed;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
    %else %if &_cstError=1 %then
    %do;
      %let _cst_MsgID=CST0015;
      %let _cst_MsgParm1=codeLogic;
      %let _cst_MsgParm2=CSTCHECK_METAMISMATCH;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %let _cstDataRecords=0;

    %if %sysfunc(exist(work._cstsublists)) %then
    %do;
      data _null_;
        if 0 then set work._cstsublists nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    * One or more records were found*;
    %if &_cstDataRecords %then
    %do;
      %* Create a temporary results data set. *;
      %local _csttemp;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttemp',_csttemp);
      run;

      %* Add the records to the temporary results data set. *;
      data &_csttemp (label='Work error data set');
        %cstutil_resultsdskeep;
        set work._cstsublists (where=(/* _cstsubOrder1=. or */ _cstsubOrder2=.)) end=last;

          attrib
              _cstSeqNo format=8. label="Sequence counter for result column"
              _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
              _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
          ;

          retain _cstSeqNo 0 ;
          if _n_=1 then _cstSeqNo=&_cstSeqCnt;

          keep _cstMsgParm1 _cstMsgParm2;
          _cstMsgParm1='';
          _cstMsgParm2='';

          * Set results data set attributes *;
          %cstutil_resultsdsattr;
          retain message resultseverity resultdetails '';

          resultid="&_cstCheckID";
          srcdata=catx('.',upcase(sasref),upcase(table));
          checkid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
          keyvalues='';
          actual=_cstColumn1;

          _cstSeqNo+1;
          seqno=_cstSeqNo;

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


      %* Parameters passed are check-level -- not record-level -- values *;
      %cstutil_appendresultds(
                         _cstErrorDS=&_csttemp
                        ,_cstVersion=&_cstStandardVersion
                        ,_cstSource=&_cstCheckSource
                        ,_cstStdRef=
                       );

      %let _cstDataRecords=0;
      data _null_;
        if 0 then set &_csttemp nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;

      %if &_cstDataRecords=0 %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                  _cstResultID=CST0100
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=WORK._CSTCOLUMNMETADATA
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
      %end;

      %if &_cstDebug=0 %then
      %do;
        proc datasets lib=work nolist;
          delete _cstsublists &_csttemp;
        quit;
      %end;
    %end;
    %* No problems were found*;
    %else %if &_cstError=0 %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0100
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=WORK._CSTCOLUMNMETADATA
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;
    %let _cstError=0;

  %end;

  %***********************;
  %* Function 2          *;
  %***********************;

  %else %if %length(&_cstColumnScope)>0 %then
  %do;
    %let _cstColCnt=0;

    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);

    %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    data _null_;
      if 0 then set work._cstcolumnmetadata nobs=_numobs;
      call symputx('_cstColCnt',_numobs);
      stop;
    run;

    %if &_cstColCnt=0 %then
    %do;
      %* Problems with columnScope  *;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if %length(&_cstCodeLogic)<1 %then
    %do;
      %* _cstCodeLogic is required with columnScope sublist comparisons *;
      %let _cst_MsgID=CST0005;
      %let _cst_MsgParm1=CSTCHECK_METAMISMATCH;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* Write applicable metrics *;
    %if &_cstMetrics %then
      %if &_cstMetricsNumRecs %then
      %do;
        %let _cst_src=%upcase(work._cstcolumnmetadata);
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstColCnt
                         ,_cstSrcDataParm=&_cst_src
                        );
      %end;

    %let _cstError=0;
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
      %* Check failed - SAS error  *;

      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
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

    %if %sysfunc(exist(work._cstnonmatch)) %then
    %do;
      data _null_;
        if 0 then set work._cstnonmatch nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    %* One or more records were found*;
    %if &_cstDataRecords %then
    %do;
      %* Create a temporary results data set. *;
      %local _csttemp;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttemp',_csttemp);
      run;

      %* Add the records to the temporary results data set. *;
      data &_csttemp (label='Work error data set');
        %cstutil_resultsdskeep;
        set work._cstnonmatch end=last;

          attrib
              _cstSeqNo format=8. label="Sequence counter for result column"
              _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
              _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
          ;

          retain _cstSeqNo 0 ;
          if _n_=1 then _cstSeqNo=&_cstSeqCnt;

          keep _cstMsgParm1 _cstMsgParm2;
          _cstMsgParm1='';
          _cstMsgParm2='';

          * Set results data set attributes *;
          %cstutil_resultsdsattr;
          retain message resultseverity resultdetails '';

          resultid="&_cstCheckID";
          srcdata=catx('.',upcase(sasref),upcase(table));
          checkid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
          keyvalues='';
          actual=column;

          _cstSeqNo+1;
          seqno=_cstSeqNo;

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


      %* Parameters passed are check-level -- not record-level -- values *;
      %cstutil_appendresultds(
                         _cstErrorDS=&_csttemp
                        ,_cstVersion=&_cstStandardVersion
                        ,_cstSource=&_cstCheckSource
                        ,_cstStdRef=
                       );

      %let _cstDataRecords=0;
      data _null_;
        if 0 then set &_csttemp nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;

      %if &_cstDataRecords=0 %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                  _cstResultID=CST0100
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=WORK._CSTCOLUMNMETADATA
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
      %end;

      %if &_cstDebug=0 %then
      %do;
        proc datasets lib=work nolist;
          delete _cstnonmatch &_csttemp;
        quit;
      %end;
    %end;

    %* No problems were found*;
    %else
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0100
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=WORK._CSTCOLUMNMETADATA
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

  %end;

  %***********************;
  %* Function 3          *;
  %***********************;

  %else %do;

    %* Single call to cstutil_buildcollist that does all domain and column processing *;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
    %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
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
      %let _cstSrcData=CSTCHECK_METAMISMATCH;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* Set up macros available for use within codeLogic   *;
    %if %upcase(&_cstUseSourceMetadata)=Y %then
    %do;
       %let _cstBase=work._cstsrccolumnmetadata;
       %let _cstCompare=work._cstrefcolumnmetadata;
    %end;
    %else
    %do;
       %let _cstBase=work._cstrefcolumnmetadata;
       %let _cstCompare=work._cstsrccolumnmetadata;
    %end;

    %* Upcase table and column names to make comparisons easier in code that follows  *;
    data work._cstsrccolumnmetadata;
      set work._cstsrccolumnmetadata;
        table=upcase(table);
        column=upcase(column);
    run;
    data work._cstrefcolumnmetadata;
      set work._cstrefcolumnmetadata;
        table=upcase(table);
        column=upcase(column);
    run;

    %* codeLogic checks for differences between observed and expected.   *;
    %* It attempts to reduce the input column metadata to only those     *;
    %* records (columns) inconsistent between the study and reference    *;
    %* models.                                                           *;
    %* codeLogic may produce two possible data sets processed below:     *;
    %*   - work._cstnonmatch   mismatches that prevent assessment        *;
    %*   - work._cstmatch      reportable problems found                 *;

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
      %* Check failed - SAS error  *;

      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Codelogic processing failed;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* codeLogic may create a _cstnonmatch data set  *;

    %let _cstNMRecords=0;

    %if %sysfunc(exist(work._cstnonmatch)) %then
    %do;
      data _null_;
        if 0 then set work._cstnonmatch nobs=_numobs;
        call symputx('_cstNMRecords',_numobs);
        stop;
      run;
    %end;

    * One or more errors were found*;
    %if &_cstTempSource= %then
      %let _cstTempSource=CST;
    %if &_cstNMRecords %then
    %do;
      %* Create a temporary results data set. *;
      %local _csttemp;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttemp',_csttemp);
      run;

      %* Add the records to the temporary results data set. *;
      data &_csttemp (label='Work error data set');
        %cstutil_resultsdskeep;
        set work._cstnonmatch end=last;

          attrib
              _cstSeqNo format=8. label="Sequence counter for result column"
              _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
              _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
          ;

          retain _cstSeqNo 0 ;
          if _n_=1 then _cstSeqNo=&_cstSeqCnt;

          keep _cstMsgParm1 _cstMsgParm2;
          _cstMsgParm1='';
          _cstMsgParm2='';

          * Set results data set attributes *;
          %cstutil_resultsdsattr;
          retain message resultseverity resultdetails '';

          %* Reporting level is either by column or by table, based on the derivation of *;
          %*  work._cstnonmatch in codeLogic.  Different messaging is used.              *;

          %if %upcase(&_cstRptLevel)=TABLE %then
          %do;
            resultid="CST0025";
          %end;
          %else %if %upcase(&_cstRptLevel)=MULTICOLUMN %then
          %do;
            resultid="&_cstCheckID";
            %if &_cstTempSource=CST %then
              %let _cstTempSource=CDISC;
          %end;
          %else
          %do;
            resultid="CST0024";
            _cstMsgParm1=column;
            _cstMsgParm2="&_cstCompare";
          %end;

          srcdata=catx('.',upcase(sasref),upcase(table));
          checkid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
          keyvalues='';
          actual='';

          _cstSeqNo+1;
          seqno=_cstSeqNo;

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


      %* Parameters passed are check-level -- not record-level -- values *;
      %cstutil_appendresultds(
                         _cstErrorDS=&_csttemp
                        ,_cstVersion=&_cstStandardVersion
                        ,_cstSource=&_cstTempSource
                        ,_cstStdRef=
                       );

      proc datasets lib=work nolist;
        delete _cstnonmatch &_csttemp;
      quit;
    %end;

    %* codeLogic may create a _cstmatch data set  *;

    %let _cstDataRecords=0;

    %if %sysfunc(exist(work._cstmatch)) %then
    %do;
      data _null_;
        if 0 then set work._cstmatch nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    * One or more errors were found*;
    %if &_cstDataRecords %then
    %do;

      %* Create a temporary results data set. *;
      %local
        _csttemp
      ;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttemp',_csttemp);
      run;

      %* Add the records to the temporary results data set. *;
      data &_csttemp (label='Work error data set');
        %cstutil_resultsdskeep;

        set work._cstmatch end=last;

        attrib
          _cstSeqNo format=8. label="Sequence counter for result column"
        ;

        keep _cstMsgParm1 _cstMsgParm2;

        retain _cstSeqNo 0 resultid resultseq resultflag _cst_rc;

        * Set results data set attributes *;
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

        _cstMsgParm1= column;
        _cstMsgParm2='';
        keyvalues='';

        * Depending on the check, a specific sasref may be unavailable in the input _csttempds file.  *;
        if (sasref) ne '' then
          srcdata = upcase(catx('.',sasref,table));
        else
          srcdata = upcase(catx(' ','[reference]',table));

        %if %length(&_cstAttr)=0 %then
        %do;
          actual='';
        %end;
        %else
        %do;
          actual = cats("(base) &_cstAttr","=",&_cstAttr,", (comp) &_cstAttr","=",_compColumn);
        %end;

        _cstSeqNo+1;
        seqno=_cstSeqNo;
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


      %* Parameters passed are check-level -- not record-level -- values *;
      %cstutil_appendresultds(
                         _cstErrorDS=&_csttemp
                        ,_cstVersion=&_cstStandardVersion
                        ,_cstSource=&_cstCheckSource
                        ,_cstStdRef=
                       );

      proc datasets lib=work nolist;
        delete _cstmatch &_csttemp;
      quit;
    %end;
    %else %if &_cstNMRecords=0 %then
    %do;
      %* No errors detected in source data  *;
      %let _cst_MsgID=CST0100;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_src=%upcase(&_cstBase);
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
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

    %* Write applicable metrics *;
    %if &_cstMetrics %then
      %if &_cstMetricsNumRecs %then
      %do;
        data _null_;
          if 0 then set &_cstBase nobs=_numobs;
          call symputx('_cstMetricsCntNumRecs',_numobs);
          stop;
        run;

        %let _cst_src=%upcase(&_cstBase);
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstMetricsCntNumRecs
                         ,_cstSrcDataParm=&_cst_src
                        );
      %end;
  %end;


%exit_error:

  %if %sysfunc(exist(work._csttempds)) %then
  %do;
    proc datasets lib=work nolist;
      delete _csttempds;
    quit;
  %end;

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

%if &_cstDebug %then
%do;
  %put <<< cstcheck_metamismatch;
%end;

%mend cstcheck_metamismatch;
