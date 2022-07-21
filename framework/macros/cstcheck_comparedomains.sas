%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_comparedomains                                                        *;
%*                                                                                *;
%* Compares column values in one domain with the values in another domain.        *;
%*                                                                                *;
%* This macro compares values for one or more columns in one domain with the      *;
%* values for the same columns in another domain. For example, the USUBJID value  *;
%* in any domain does not have a matching USUBJID value in the DM domain.         *;
%*                                                                                *;
%* Note: This macro requires use of _cstCodeLogic at a DATA step level (for       *;
%*       example, a full DATA step or PROC SQL invocation). _cstCodeLogic         *;
%*       creates a work file (_cstproblems) that contains records in error.       *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    Unique USUBJID+VISIT+VISITNUM combinations in each domain not found in SV   *;
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
%* @macvar _cstrunstdver Version of the primary standard                         *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_comparedomains(_cstControl=)
    / des='CST: Matching column values not found';

  %local

    _csttemp
    _cstDSName1
    _cstDSName2
    _cstDom1
    _cstDom2
    _cstDSKeys1
    _cstDSKeys2
    _cstSQLColumns1
    _cstSQLColumns2
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

  %* Single call to cstutil_buildcollist that does all domain and column processing *;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstDomSubOverride=Y);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %if %upcase(&_cstUseSourceMetadata)=N %then
  %do;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=UseSourceMetadata;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if &_cstTableSublistCnt ne 2 %then
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0023;
    %let _cst_MsgParm1=tableScope;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  * Count the number of unique resolved columnScope columns *;
  proc sql noprint;
    select distinct column into :_cstUniqueColumns separated by ' ' from work._cstcolumnmetadata;
    select distinct column into :_cstUniqueSQLColumns separated by ',' from work._cstcolumnmetadata;
    select count(distinct column) into :_cstUniqueColumnCnt from work._cstcolumnmetadata;
  quit;

  %if &_cstUniqueColumnCnt <= 0 %then
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0004;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %do i=1 %to &_cstUniqueColumnCnt;
    %let _cstColumn&i=%SYSFUNC(kscan(&_cstUniqueColumns,&i,' '));
  %end;

  data work._csttablesubset1
       work._csttablesubset2;
    merge work._csttablemetadata (in=tab keep=sasref table keys tsublist)
          work._cstcolumnmetadata (in=col keep=sasref table suborder) end=last;
      by sasref table;
    if last.table then do;
      if tsublist=1 and suborder=&_cstUniqueColumnCnt then output work._csttablesubset1;
      else if tsublist=2 and suborder=&_cstUniqueColumnCnt then output work._csttablesubset2;
    end;
  run;
  %if (&syserr gt 4) %then
  %do;
    %* Check failed - SAS error  *;

    * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
    options nosyntaxcheck obs=max replace;

    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Subsetting _cstTableMetadata failed;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._csttablesubset1 nobs=_numobs;
    call symputx('_cstSubCnt1',_numobs);
    stop;
  run;
  data _null_;
    if 0 then set work._csttablesubset2 nobs=_numobs;
    call symputx('_cstSubCnt2',_numobs);
    stop;
  run;

  %if &_cstSubCnt1 <= 0 or &_cstSubCnt2 <= 0 %then
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

  %do i=1 %to &_cstSubCnt1;

    data _null_;
      set work._csttablesubset1 (keep=sasref table keys firstObs=&i obs=&i);
        attrib _csttemp format=$41. label="Temp variable";
        _csttemp = catx('.',sasref,table);
        call symputx('_cstDSName1',_csttemp);
        call symputx('_cstDom1',table);
        call symputx('_cstDSKeys1',keys);
    run;

    %if ^%sysfunc(exist(&_cstDSName1)) %then
    %do;
      %******************************************************;
      %*  Check not run - data set could not be found       *;
      %******************************************************;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstDSname1;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_loop=1;
      %goto exit_loop;
    %end;

    %do j=1 %to &_cstSubCnt2;

      data _null_;
        set work._csttablesubset2 (keep=sasref table keys firstObs=&j obs=&i);
          attrib _csttemp format=$41. label="Temp variable";
          _csttemp = catx('.',sasref,table);
          call symputx('_cstDSName2',_csttemp);
          call symputx('_cstDom2',table);
          call symputx('_cstDSKeys2',keys);
      run;

      %if ^%sysfunc(exist(&_cstDSName2)) %then
      %do;
        %******************************************************;
        %*  Check not run - data set could not be found       *;
        %******************************************************;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=&_cstDSname2;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstSrcData=&sysmacroname;
        %let _cstexit_loop=1;
        %goto exit_loop;
      %end;

      %* Output metric only once for each target domain _cstDSName1) *;
      %if &i=1 %then %do;
        * Write applicable metrics *;
        %if &_cstMetrics %then %do;

          data _null_;
            if 0 then set &_cstDSName2 nobs=_numobs;
            call symputx('_cstMetricsCntNumRecs',_numobs);
            stop;
          run;

          %if &_cstMetricsNumRecs %then
            %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstMetricsCntNumRecs
                         ,_cstSrcDataParm=&_cstDSName2
                        );
        %end;
      %end;

      %let _cstSrcData=&_cstDSname1 (&_cstDSname2);


      %*************************************************************************
      %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
      %*  expected result is a work._cstproblems data set of records in error. *
      %*  If there are no errors, the data set should have 0 observations.     *
      %*                                                                       *;
      %* Macro variables available to codeLogic:                               *;
      %*  _cstDSName1                        _cstDSName2                       *;
      %*  _cstDom1                           _cstDom2                          *;
      %*  _cstDSKeys1                        _cstDSKeys2                       *;
      %*                                                                       *;
      %*  _cstUniqueColumns (column list from columnScope, space delimited)    *;
      %*  _cstUniqueSQLColumns (column list from columnScope, comma delimited) *;
      %*  _cstColumn1-_cstColumnn (column names from _cstUniqueColumns)        *;
      %*                                                                       *;
      %*************************************************************************;

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
          srcdata ="&_cstSrcData";
          _cstSeqNo+1;
          seqno=_cstSeqNo;
          keyvalues='';

          %let _subCnt=%SYSFUNC(countw(&_cstDSKeys1,' '));
          * Calculate keyvalues column.  *;
          %do _currentKey = 1 %to &_subCnt;
            %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys1,&_currentKey,' '));
            if vtype(&_cstKey)='C' then
            do;
              if keyvalues='' then
                keyvalues = cats("&_cstKey","=",&_cstKey);
              else
                keyvalues = cats(keyvalues,",","&_cstKey","=",&_cstKey);
            end;
            else
            do;
              if keyvalues='' then
                keyvalues = cats("&_cstKey","=",put(&_cstKey,8.));
              else
                keyvalues = cats(keyvalues,",","&_cstKey","=",put(&_cstKey,8.));
            end;
          %end;

          %if &_cstActual ne _CODELOGIC_ %then
          %do;
            %do _currentCol = 1 %to &_cstUniqueColumnCnt;
              %let _cstCol=%SYSFUNC(kscan(&_cstUniqueColumns,&_currentCol,' '));
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
               ,_cstSrcDataParm=&_cstSrcData
               ,_cstResultFlagParm=0
               ,_cstRCParm=&_cst_rc
               ,_cstActualParm=
               ,_cstKeyValuesParm=
               ,_cstResultsDSParm=&_cstResultsDS
               );
      %end;

    %end;  %* End of sublist 2 loop *;

    * Write applicable metrics *;
    %if &_cstMetrics %then %do;

      data _null_;
        if 0 then set &_cstDSName1 nobs=_numobs;
        call symputx('_cstMetricsCntNumRecs',_numobs);
        stop;
      run;

      %if &_cstMetricsNumRecs %then
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstMetricsCntNumRecs
                         ,_cstSrcDataParm=&_cstDSName1
                        );
    %end;

%exit_loop:

    %if &_cstDebug=0 %then
    %do;
      %if %sysfunc(exist(work._cstproblems)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstproblems;
        quit;
      %end;
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

  %end;  %* End of sublist 1 loop *;



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
    %put <<< cstcheck_comparedomains;


%mend cstcheck_comparedomains;
