%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_crossstdmetamismatch                                                  *;
%*                                                                                *;
%* Identifies inconsistencies between metadata across registered standards.       *;
%*                                                                                *;
%* NOTE: This macro requires the use of _cstCodeLogic as a full DATA step or PROC *;
%*       SQL invocation. This DATA step or PROC SQL invocation assumes as input a *;
%*       Work copy of the column metadata data set that is returned by the        *;
%*       cstutil_buildcollist macro. Any resulting records in the derived data    *;
%*       set represent errors to report.                                          *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*  1. No data content is accessed for this check.                                *;
%*  2. Both study and reference metadata are available to assess compliance.      *;
%*  3. _cstProblems includes two columns (or more, if needed):                    *;
%*        &_cstStMnemonic._value (for example, ADaM_value that contains the value *;
%*        of the column of interest from the primary standard)                    *;
%*        &_cstCrMnemonic._value (for example, SDTM_value that contains the value *;
%*        of the column of interest from the comparison standard)                 *;
%*     The mnemonics are from the global standards library data set.              *;
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
%* @macvar _cstcrossstd Name of the comparison standard                           *;
%* @macvar _cstcrossstdver Version of the comparison standard                     *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_crossstdmetamismatch(_cstControl=)
    / des='CST: Cross-std metadata inconsistencies';

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
    _cstDataRecords
    _cstRptLevel
    _cstexit_error
    _cstactual

    _cstDSKeys
    _cstKeyCnt

    _cstCrMne
    _cstStMne
    _cstColFound
    _cstSRef
    _cstSrcDataLib

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
  %let _cstRptLevel=;


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

    %* _cstSrcDataLib is made available to _cstCodeLogic if needed *;
    %cstutil_getsasreference(_cstStandard=&_cstStandard,_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSrcDataLib);
    
    %*****************************************************************************************;
    %* codeLogic attempts to identify those records (columns) inconsistent across standards. *;
    %* codeLogic should create work._cstproblems containing any observed inconsistencies.    *;
    %*****************************************************************************************;

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

    %if %sysfunc(exist(work._cstProblems)) %then
    %do;
      data _null_;
        if 0 then set work._cstProblems nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;
    %end;

    * One or more errors were found*;
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
        set work._cstProblems end=last;

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

          srcdata=catx('.',upcase(sasref),upcase(table),upcase(column));
          %if %upcase(&_cstRptLevel)=TABLE %then
          %do;
            srcdata=catx('.',upcase(sasref),upcase(table));
          %end;
          checkid="&_cstCheckID";
          resultid="&_cstCheckID";
          resultseq=&_cstResultSeq;
          resultflag=1;
          _cst_rc=0;
          keyvalues='';
          actual=catx(', ',cats("&_cstStMne=",&_cstStMne._value),cats("&_cstCrMne=",&_cstCrMne._value));

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

      %if &_cstDebug<1 %then
      %do;
        proc datasets lib=work nolist;
          delete _cstProblems;
        quit;
      %end;
    %end;

    %else %if &_cstDataRecords=0 %then
    %do;
      %* No errors detected in source data  *;
      %let _cst_MsgID=CST0100;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_src=%upcase(work._cstcolumnmetadata);
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

    %* Write applicable metrics *;
    %if &_cstMetrics %then
      %if &_cstMetricsNumRecs %then
      %do;
        data _null_;
          if 0 then set work._cstcolumnmetadata nobs=_numobs;
          call symputx('_cstMetricsCntNumRecs',_numobs);
          stop;
        run;

        %let _cst_src=%upcase(work._cstcolumnmetadata);
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstMetricsCntNumRecs
                         ,_cstSrcDataParm=&_cst_src
                        );
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

  proc datasets lib=work nolist;
    delete _cstsrccrosscolmeta _cstrefcrosscolmeta _cstsrccrosstabmeta _cstrefcrosstabmeta _cstcrosstablemetadata _cstcrosscolumnmetadata;
  quit;

  %if &_cstDebug %then
  %do;
    %put <<< cstcheck_crossstdmetamismatch;
  %end;

%mend cstcheck_crossstdmetamismatch;
