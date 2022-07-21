%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_column                                                                *;
%*                                                                                *;
%* Identifies invalid column values or attributes.                                *;
%*                                                                                *;
%* NOTE: This macro requires use of _cstCodeLogic at a statement level in a SAS   *;
%*       DATA step context. _cstCodeLogic identifies records in error by setting  *;
%*       _cstError=1.                                                             *;
%*                                                                                *;
%* Example validation checks that use this macro include:                         *;
%*    Value of Visit Number is formatted to > 3 decimal places                    *;
%*    A column character value is not left-justified                              *;
%*    Study day of Visit/Collection/Exam (**DY) equals 0                          *;
%*    Length of **TEST > 40                                                       *;
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
%* @exposure external                                                             *;
%* @version  1.2                                                                  *;

%macro cstcheck_column(_cstControl=)
    / des='CST: Checks column values and attributes';


  %local
    _csttempds

    _csttemp
    _cstColCnt
    _cstDomainOnly
    _cstDSName
    _cstRefOnly
    _cstColStr
    _cstColumn
    _cstDSKeys
    _cstKey
    _cstCol
    _cstSubCnt
    _cstTableScope
    _cstColumnScope
    _cstReportingColumns
    _cstStandardVersion
    _cstReportAll

    _cstCheckID
    _cstCheckSource
    _cstCodeLogic
    _cstUseSourceMetadata
    _cstStandardRef
    _cstLastError
    _cstLastErrorKeys
    _cstexit_error
  ;

  %cstutil_readcontrol;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;
  %let _cstLastError=;
  %let _cstLastErrorKeys=;
  %let _cstexit_error=0;

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
      put "reportAll=&_cstReportAll";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax.;
  %end;

  %* Single call to cstutil_buildcollist does all domain and column processing *;
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

  /*  This section of code removed because it interfered with internal validation
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
  */

  data _null_;
    if 0 then set work._cstcolumnmetadata nobs=_numobs;
    call symputx('_cstColCnt',_numobs);
    stop;
  run;
  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %************************************;
  %* Cycle through requested columns  *;
  %************************************;
  %if &_cstColCnt > 0 %then
  %do;
    %do i=1 %to &_cstDomCnt;
      data _null_;
        attrib _csttemp format=$41. label="Temp variable";
        set work._csttablemetadata (keep=sasref table keys firstObs=&i);
        _csttemp = catx('.',sasref,table);
        call symputx('_cstDSName',kstrip(_csttemp));
        call symputx('_cstRefOnly',sasref);
        call symputx('_cstDomainOnly',table);
        call symputx('_cstDSKeys',keys);
        stop;
      run;

      %let _cstColStr=;
      %let _cstColCnt=0;

      %if %sysfunc(exist(&_cstDSName)) %then
      %do;

        data _null_;
          set work._cstcolumnmetadata (keep=sasref table column where=(upcase(sasref)=upcase("&_cstRefOnly") and upcase(table)=upcase("&_cstDomainOnly")))
                        nobs=_numobs end=last;
          retain _cstColStr;
          attrib _cstColStr format=$char2000. label="list of columns";
          attrib _cstRecCnt format=8. label="Record counter";

          if _n_=1 then _cstRecCnt=1;
          else _cstRecCnt+1;

          if _cstColStr ne '' then
            _cstColStr = catx(" ",_cstColStr,column);
          else
            _cstColStr = column;


          if last then
          do;
            call symputx('_cstColStr',_cstColStr);
            call symputx('_cstColCnt',_cstRecCnt);
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
          %let _cstexit_error=1;
          %goto exit_error;
        %end;

        %let _cstMetricsCntNumSubj=0;
        %let _cstMetricsCntNumRecs=0;

        * Create a temporary results data set. *;
        data _null_;
          attrib _csttemp label="Text string field for file names"  format=$char12.;
          _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
          call symputx('_csttempds',_csttemp);
        run;

        * Add the record to the temporary results data set. *;
        data &_csttempds (label='Work error data set');
          %cstutil_resultsdskeep;
             set &_cstDSName (keep=&_cstDSKeys &_cstColStr &_cstReportingColumns) end=last;
               attrib
                _cstSeqNo format=8. label="Sequence counter for result column"
                _cstError format=8. label="Codelogic detected error (0/1)"
                _cstRecordCount format=8. label="Record counter"
                _cstMsgParm1 format=$char100. label="Message parameter value 1 (temp)"
                _cstMsgParm2 format=$char100. label="Message parameter value 2 (temp)"
                _cstDetails format=$char200. label="Message details"
                _cstLastKeyValues format=$char2000. label="Last keyvalues"
              ;

              retain _cstSeqNo _cstRecordCount 0;
              retain _cstDetails _cstLastKeyValues;
              if _n_=1 then _cstSeqNo=&_cstSeqCnt;

              keep _cstMsgParm1 _cstMsgParm2;

              * Set results data set attributes *;
              %cstutil_resultsdsattr;
              retain message resultseverity resultdetails '';
              keyvalues='';
              %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));

              %do k=1 %to &_cstColCnt;
                %let _cstColumn = %SYSFUNC(kscan(&_cstColStr,&k,' '));
                _cstError=0;

                * Referenced code logic must run in the context of the middle of a data step  *;
                *  and may use any available macro variable, especially &_cstColumn.          *;
                _cstMsgParm1='';
                _cstMsgParm2='';

                &_cstCodeLogic;

                _cstMsgParm1=kstrip(_cstMsgParm1);
                _cstMsgParm2=kstrip(_cstMsgParm2);

                * A reportable error condition was found  *;
                if _cstError then
                do;
                  resultid="&_cstCheckID";
                  resultseq=&_cstResultSeq;
                  resultflag=1;
                  srcdata = "&_cstDSName";
                  _cst_rc=0;

                  * Calculate keyvalues column.  *;
                  if keyvalues='' then do;
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
                  end;

                  * Calculate actual column.  *;
                  %if &_cstReportingColumns = %str() %then
                  %do;
                    actual = cats("&_cstColumn","=",&_cstColumn);
                  %end;
                  %else
                  %do;
                    actual = cats("&_cstColumn","=",&_cstColumn);
                    %let _cstSubCnt=%SYSFUNC(countw(&_cstReportingColumns,' '));
                    %do _currentCol = 1 %to &_cstSubCnt;
                      %let _cstCol=%SYSFUNC(kscan(&_cstReportingColumns,&_currentCol,' '));
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
                  _cstDetails=actual;
                  _cstLastKeyValues=keyvalues;

                  _cstSeqNo+1;
                  seqno=_cstSeqNo;

                  checkid="&_cstCheckID";

                  * _cstError set for source data record column, output record *;
                  output;
                end;

                * Metrics count of # records (column-level evaluations) tested *;
                %if &_cstMetricsNumRecs %then
                %do;
                  _cstRecordCount+1;
                %end;
              %end;

              if last then
              do;
                call symputx('_cstSeqCnt',_cstSeqNo);
                call symputx('_cstMetricsCntNumRecs',_cstRecordCount);
                call symputx('_cstLastError',catx(' ','Last invalid result:',_cstDetails));
                call symputx('_cstLastErrorKeys',cats('%nrstr( ',_cstLastKeyValues,' )'));
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
          %let _cstSrcData=&sysmacroname;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;

        %* Write applicable metrics *;
        %if &_cstMetrics %then
        %do;
          %if &_cstMetricsNumSubj %then
          %do;
            %cstutil_getsubjectcount(_cstDS=&_cstDSName,_cstsubid=&_cstSubjectColumns);

            %cstutil_writemetric(
                            _cstMetricParameter=# of subjects
                           ,_cstResultID=&_cstCheckID
                           ,_cstResultSeqParm=&_cstResultSeq
                           ,_cstMetricCnt=&_cstMetricsCntNumSubj
                           ,_cstSrcDataParm=&_cstDSName
                          );
          %end;
          %if &_cstMetricsNumRecs %then
            %cstutil_writemetric(
                            _cstMetricParameter=# of records tested
                           ,_cstResultID=&_cstCheckID
                           ,_cstResultSeqParm=&_cstResultSeq
                           ,_cstMetricCnt=&_cstMetricsCntNumRecs
                           ,_cstSrcDataParm=&_cstDSName
                          );
        %end;

      %end;
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
                ,_cstActualParm=%str(&_cstactual)
                ,_cstKeyValuesParm=
                ,_cstResultsDSParm=&_cstResultsDS
                );
        %let _cstexit_error=0;
      %end;

      %if %length(&_csttempds)>0 %then
      %do;
        %let _cstErrorRecords=0;
        data _null_;
          if 0 then set &_csttempds nobs=_numobs;
          if _numobs > 0 then
          call symputx('_cstErrorRecords',_numobs);
          stop;
        run;

        %if &_cstErrorRecords %then
        %do;
          %* Write only one record to the results data set for the domain in error *;
          %if %upcase(&_cstReportAll)=N %then
          %do;

            %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
            %cstutil_writeresult(
                     _cstResultID=&_cstCheckID
                    ,_cstValCheckID=&_cstCheckID
                    ,_cstResultParm1=
                    ,_cstResultParm2=
                    ,_cstResultSeqParm=&_cstResultSeq
                    ,_cstSeqNoParm=&_cstSeqCnt
                    ,_cstSrcDataParm=&_cstDSName
                    ,_cstResultFlagParm=1
                    ,_cstActualParm=%str(&_cstLastError)
                    ,_cstKeyValuesParm=%str(&_cstLastErrorKeys)
                    ,_cstResultDetails=%str(All results may not be reported because reportAll=N)
                    ,_cstResultsDSParm=&_cstResultsDS
            );

          %end;
          %else
          %do;
            %* Parameters passed are check-level -- not record-level -- values *;
            %cstutil_appendresultds(
                       _cstErrorDS=&_csttempds
                       ,_cstVersion=&_cstStandardVersion
                       ,_cstSource=&_cstCheckSource
                       ,_cstStdRef=&_cstStandardRef
                       );
          %end;

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
                ,_cstActualParm=%str(&_cstactual)
                ,_cstKeyValuesParm=
                ,_cstResultsDSParm=&_cstResultsDS
                );
          %let _cstexit_error=0;
        %end;

        proc datasets lib=work nolist;
          delete &_csttempds;
        quit;
        %let _csttempds=;
      %end;

    %end;
  %end;
  %else
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0004;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstSrcData=&sysmacroname;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstResultFlag=-1;
    %let _cst_rc=0;
    %let _cstexit_error=1;
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


  %if &_cstDebug %then
  %do;
    %put <<< cstcheck_column;
  %end;


%mend cstcheck_column;

