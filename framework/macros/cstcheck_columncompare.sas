%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_columncompare                                                         *;
%*                                                                                *;
%* Compares column values.                                                        *;
%*                                                                                *;
%* This macro is similar to cstcheck_multicolumn, but provides additional         *;
%* functionality in the form of step-level code (for example, optional reference  *;
%* to column metadata).                                                           *;
%*                                                                                *;
%* NOTE: This macro requires use of _cstCodeLogic at a SAS DATA step level (that  *;
%*       is, a full DATA step or PROC SQL invocation). _cstCodeLogic creates a    *;
%*       Work file (_cstproblems) that contains records in error.                 *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    **DOSE and **DOSU inconsistencies for Expected columns                      *;
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
%* @macvar _cstSubjectColumns Standard-specific set of columns that identify a    *;
%*             subject                                                            *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*             check-specific metadata.                                           *;
%*                                                                                *;
%* @history 2016-03-18 Added file presence conditional checking (1.6.1 and 1.7.1) *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_columncompare(_cstControl=)
    / des='CST: Column comparisons';

  %local
    _csttempds

    _cstColCnt
    _cstDomainOnly
    _cstDSName
    _cstRefOnly
    _cstColumn
    _cstDSKeys
    _cstKey
    _cstDataRecords
    _cstSubjectKeys
    _cstSQLKeys
    _cstKeyCnt
    _cstDSName1
    _cstDSName2
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
    _cstCheckMsgParm

    _cstSubCnt
    _cstSubCnt1
    _cstSubCnt2
    _cstexit_error
    _cstexit_loop

    _cstColumnSublistCnt
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

  %if %length(%superq(_cstCodeLogic))=0 %then
  %do;
    %* Required parameter not found  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=Codelogic must be specified;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
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

  %let _cstColumnSublistCnt=0;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
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
    if 0 then set work._cstcolumnmetadata nobs=_numobs;
    call symputx('_cstColCnt',_numobs);
    stop;
  run;

  %if &_cstColCnt=0 %then
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

  %if &_cstColumnSublistCnt ^=2 %then
  %do;
    %* Problems with tableScope  *;
    %let _cst_MsgID=CST0099;
    %let _cst_MsgParm1=A sublist count other than 2;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  proc sql noprint;
    create table work._cstsublists (label="Joined sublist work file") as
    select sub1.sasref,
           sub1.table,
           kstrip(sub1.sasref) || '.' || kstrip(sub1.table) as _cstDSName1,
           sub1.column as _cstColumn1,
           _cstSubOrder1,
           kstrip(sub2.sasref) || '.' || kstrip(sub2.table) as _cstDSName2,
           sub2.column as _cstColumn2,
           _cstSubOrder2,
           coalesce(sub1._cstSubOrder1,sub2._cstSubOrder2) as suborder
    from work._cstcolumnmetadata (rename=(suborder=_cstSubOrder1) where=(sublist=1)) sub1
            full join
         work._cstcolumnmetadata (rename=(suborder=_cstSubOrder2) where=(sublist=2)) sub2
            on sub1._cstSubOrder1 = sub2._cstSubOrder2 ;
    select count(*) into :_cstSubCnt1 from work._cstsublists (where=(_cstSubOrder1 ne .));
    select count(*) into :_cstSubCnt2 from work._cstsublists (where=(_cstSubOrder2 ne .));
  quit;
  %if (&sqlrc gt 0) %then
  %do;
    %* Check failed - SAS error  *;
    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Proc SQL sublist derivation from work._cstcolumnmetadata;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstSrcData=&sysmacroname;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if &_cstSubCnt1 ne &_cstSubCnt2 %then
  %do;
    %* Problems with columnScope  *;
    %let _cst_MsgID=CST0023;
    %let _cst_MsgParm1=columnScope;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(Sublist1=&_cstSubCnt1,Sublist2=&_cstSubCnt2);
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %do i=1 %to &_cstSubCnt1;
    %let _cst_rc=0;

    data _null_;
      set work._cstsublists (firstObs=&i);
        call symputx('_cstDSName',_cstDSName1);
        call symputx('_cstDSName1',_cstDSName1);
        call symputx('_cstDSName2',_cstDSName2);
        call symputx('_cstColumn1',_cstColumn1);
        call symputx('_cstColumn2',_cstColumn2);
        call symputx('_cstRefOnly',sasref);
        call symputx('_cstDomainOnly',table);
      stop;
    run;

    %if &_cstDSName1 ne &_cstDSName2 %then
    %do;
      %* Problems with columnScope  *;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=Columns from multiple data sets;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(DSName1=&_cstDSName1,DSName2=&_cstDSName2);
      %let _cstexit_loop=1;
      %goto exit_subloop;
    %end;

    %if %sysfunc(exist(&_cstDSName)) %then
    %do;
      %if &_cstMetrics %then
      %do;
        %if &_cstMetricsNumRecs %then
        %do;
          * Set metrics record count to # records in domain *;
          data _null_;
            if 0 then set &_cstDSName nobs=_numobs;
            call symputx('_cstMetricsCntNumRecs',_numobs);
            stop;
          run;
        %end;
        %if &_cstMetricsNumSubj %then
        %do;
          %let _cstMetricsCntNumSubj=.;
          %cstutil_getsubjectcount(_cstDS=&_cstDSName,_cstsubid=&_cstSubjectColumns);
        %end;
      %end;

      data _null_;
        set work._csttablemetadata (keep=sasref table keys where=(upcase(sasref)=upcase("&_cstRefOnly") and upcase(table)=upcase("&_cstDomainOnly")));
          call symputx('_cstDSKeys',keys);
          call symputx('_cstKeyCnt',countw(keys,' '));
        stop;
      run;

      %* Note _cstSQLKeys will exclude the target columns ;
      %let _cstSQLKeys=;
      %if &_cstKeyCnt > 0 %then
      %do;
        %do scnt=1 %to &_cstKeyCnt;
          %let _cstColumn = %SYSFUNC(kscan(&_cstDSKeys,&scnt,' '));
          %if &_cstColumn ne &_cstColumn1 and &_cstColumn ne &_cstColumn2 %then
          %do;
            %if &_cstSQLKeys= %then
              %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstColumn));
            %else
              %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstSQLKeys,&_cstColumn));
          %end;
        %end;
      %end;

      %*************************************************************************
      %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
      %*  expected result is a work._cstproblems data set of records in error. *
      %*  If there are no errors, the data set should have 0 observations.     *
      %*                                                                       *;
      %* Macro variables available to codeLogic:                               *;
      %*  _cstDSName1                        _cstDSName2                       *;
      %*  _cstDSKeys                         _cstSQLKeys                       *;
      %*  _cstRefOnly                        _cstDomainOnly                    *;
      %*                                                                       *;
      %*  _cstDSName (should be the same as _cstSDName1 and _cstDSName2)       *;
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

      * Create a temporary results data set. *;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttempds',_csttemp);
      run;

      * Add the record to the temporary results data set. *;
      data &_csttempds (label='Work error data set');
        %cstutil_resultsdskeep;
          set work._cstproblems (keep=&_cstDSKeys &_cstColumn1 &_cstColumn2 &_cstReportingColumns) end=last;

            attrib
              _cstSeqNo format=8. label="Sequence counter for result column"
              _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
              _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
            ;

            retain _cstSeqNo 0;
            if _n_=1 then _cstSeqNo=&_cstSeqCnt;

            keep _cstMsgParm1 _cstMsgParm2;

            * Set results data set attributes *;
            %cstutil_resultsdsattr;
            retain message resultseverity resultdetails '';

            resultid="&_cstCheckID";
            _cstMsgParm1='';
            _cstMsgParm2='';
            resultseq=&_cstResultSeq;
            resultflag=1;
            srcdata = "&_cstDSName";
            _cst_rc=0;

            * Calculate keyvalues column.  *;
            %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));
            %if &_cstSubCnt=0 %then
            %do;
              keyvalues='<No key information available>';
            %end;
            %else
            %do _currentKey = 1 %to &_cstSubCnt;
              %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys,&_currentKey,' '));
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

            * Calculate actual column.  *;
            %if &_cstReportingColumns = %str() %then
            %do;
              actual = cats("&_cstColumn1","=",&_cstColumn1,",","&_cstColumn2","=",&_cstColumn2);
            %end;
            %else
            %do;
              actual = cats("&_cstColumn1","=",&_cstColumn1,",","&_cstColumn2","=",&_cstColumn2);
              %let _cstSubCnt=%SYSFUNC(countw(&_cstReportingColumns,' '));
              %do _currentCol = 1 %to &_cstSubCnt;
                %let _cstRptCol=%SYSFUNC(kscan(&_cstReportingColumns,&_currentCol,' '));
                if vtype(&_cstRptCol)='C' then
                do;
                  if actual='' then
                    actual = cats("&_cstRptCol","=",&_cstRptCol);
                  else
                    actual = cats(actual,",","&_cstRptCol","=",&_cstRptCol);
                end;
                else
                do;
                  if actual='' then
                    actual = cats("&_cstRptCol","=",put(&_cstRptCol,8.));
                  else
                    actual = cats(actual,",","&_cstRptCol","=",put(&_cstRptCol,8.));
                end;
              %end;
            %end;

            _cstSeqNo+1;
            seqno=_cstSeqNo;

            checkid="&_cstCheckID";

        if last then
        do;
          call symputx('_cstSeqCnt',_cstSeqNo);
        end;
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

      %* Write applicable metrics *;
      %if &_cstMetrics %then %do;

        %if &_cstMetricsNumSubj %then
          %cstutil_writemetric(
                      _cstMetricParameter=# of subjects
                     ,_cstResultID=&_cstCheckID
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstMetricCnt=&_cstMetricsCntNumSubj
                     ,_cstSrcDataParm=&_cstDSName
                    );
        %if &_cstMetricsNumRecs %then
          %cstutil_writemetric(
                      _cstMetricParameter=# of records tested
                     ,_cstResultID=&_cstCheckID
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstMetricCnt=&_cstMetricsCntNumRecs
                     ,_cstSrcDataParm=&_cstDSName
                    );
      %end;


    %end;  %* ends if _cstDSName exists loop ;
    %else
    %do;
      %* Check not run - source data set could not be found  *;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstDSName;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %let _cstSrcData=&sysmacroname;
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
      %let _cstexit_error=0;
    %end;

    %if %length(&_csttempds)>0 and %sysfunc(exist(&_csttempds)) %then
    %do;
      data _null_;
        if 0 then set &_csttempds nobs=_numobs;
        call symputx('_cstDataRecords',_numobs);
        stop;
      run;

      %if &_cstDataRecords %then
      %do;
        %* Parameters passed are check-level -- not record-level -- values *;
        %cstutil_appendresultds(
                           _cstErrorDS=&_csttempds
                          ,_cstVersion=&_cstStandardVersion
                          ,_cstSource=&_cstCheckSource
                          ,_cstStdRef=&_cstStandardRef
                          );

      %end;
      %else
      %do;
        %* No errors detected in source data set  *;
        %let _cst_MsgID=CST0100;
        %let _cst_MsgParm1=&_cstDSName;
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
                     ,_cstActualParm=
                     ,_cstKeyValuesParm=
                     ,_cstResultsDSParm=&_cstResultsDS
                         );
        %let _cstexit_error=0;
      %end;

    %end;  %* end if _csttempds (errors) exist loop ;

%exit_subloop:

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

    %if %symexist(_csttempds) %then
    %do;
      %if %length(&_csttempds)>0 and %sysfunc(exist(&_csttempds)) %then
      %do;
        proc datasets lib=work nolist;
          delete &_csttempds;
        quit;
      %end;
    %end;
    %if %sysfunc(exist(work._cstproblems)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstproblems;
      quit;
    %end;

  %end;  %* end do i=1 to _cstSubCnt1 (processing sublist) loop  ;

  %if %sysfunc(exist(work._cstsublists)) %then
  %do;
    proc datasets lib=work nolist;
      delete _cstsublists;
    quit;
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
  %end;
  %else
  %do;
    %put <<< cstcheck_columncompare;
  %end;


%mend cstcheck_columncompare;
