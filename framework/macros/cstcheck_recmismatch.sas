%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_recmismatch                                                           *;
%*                                                                                *;
%* Identifies any record mismatches across domains.                               *;
%*                                                                                *;
%* NOTE: This macro requires use of _cstCodeLogic at a SAS DATA step level (that  *;
%*       is, a full DATA step or PROC SQL invocation). _cstCodeLogic creates a    *;
%*       Work file (_cstproblems) that contains the records in error.             *;
%*                                                                                *;
%* Example CDISC SDTM validation checks that use this macro:                      *;
%*    Comments, Relrec or Supplemental Qualifier RDOMAIN references to other      *;
%*      domains or domain records that do not exist                               *;
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
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_recmismatch(_cstControl=)
    / des='CST: Cross-domain record mismatches';

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
    _cstSQLKeys
    _cstKeyColumn
    _cstKeyCnt
    _cstFirstValue

    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstCodeLogic
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstStandardRef
    _cstReportAll
    _cstAllTableMetadata
    _cstAllColumnMetadata
    _cstCLCnt
    _cstCLRecs
    _cstLastError
    _cstLastErrorKeys

    _cstSubCnt
    _cstexit_error
    _cstexit_loop
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
  %let _cstCLCnt=0;
  %let _cstCLRecs=0;
  %let _cstLastError=;
  %let _cstLastErrorKeys=;

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
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0004;
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
    if 0 then set work._cstcolumnmetadata nobs=_numobs;
    call symputx('_cstColCnt',_numobs);
    stop;
  run;

  %if &_cstColCnt > 0 %then
  %do;

    %if ^%symexist(_cstSubjectColumns) %then
    %do;
      %* Global macro variable xxx could not be found or contains an invalid value ;
      %let _cst_MsgID=CST0027;
      %let _cst_MsgParm1=_cstSubjectColumns;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if %length(&_cstSubjectColumns)=0 %then
    %do;
      %* Global macro variable xxx could not be found or contains an invalid value ;
      %let _cst_MsgID=CST0027;
      %let _cst_MsgParm1=_cstSubjectColumns;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
    %let _cstSubjectColumns=%upcase(&_cstSubjectColumns);

    %do i=1 %to &_cstColCnt;

      data _null_;
        attrib _csttemp format=$41. label="Temp variable"; 
        set work._cstcolumnmetadata (keep=sasref table column firstObs=&i);
          _csttemp = catx('.',sasref,table);
          call symputx('_cstDSName',kstrip(_csttemp));
          call symputx('_cstRefOnly',sasref);
          call symputx('_cstDomainOnly',table);
          call symputx('_cstColumn',column);
        stop;
      run;

      %if %sysfunc(exist(&_cstDSName)) %then
      %do;
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
            %let _cstKeyColumn = %SYSFUNC(kscan(&_cstDSKeys,&scnt,' '));
            %if %upcase(&_cstKeyColumn) ne %upcase(&_cstColumn) %then
            %do;
              %if &_cstSQLKeys= %then
                %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstKeyColumn));
              %else
                %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstSQLKeys,&_cstKeyColumn));
            %end;
          %end;
        %end;

        data _null_;
          if 0 then set &_cstDSName nobs=_numobs;
          call symputx('_cstMetricsCntNumRecs',_numobs);
          stop;
        run;

        %let dsid = %sysfunc(open(&_cstDSName));
        %if %sysfunc(varnum(&dsid,&_cstColumn)) %then
        %do;
          %let dsid = %sysfunc(close(&dsid));

          %* Referenced code logic must run as a stand-alone data step and may use any            *;
          %*  available macro variables, notably &_cstColumn, &_cstDSName, and &_cstSQLKeys.      *;
          %*  The global macro variable _cstSubjectColumns is also available.                     *;

          %* This defines a macro used in codelogic to point to all available table metadata.  *;
          %if %upcase(&_cstUseSourceMetadata)=Y %then
          %do;
            %let _cstAllTableMetadata=work._cstsrctablemetadata;
            %let _cstAllColumnMetadata=work._cstsrccolumnmetadata;
          %end;
          %else
          %do;
            %let _cstAllTableMetadata=work._cstreftablemetadata;
            %let _cstAllColumnMetadata=work._cstrefcolumnmetadata;
          %end;

          %*************************************************************************
          %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
          %*  expected result is a work._cstproblems data set of records in error. *
          %*  If there are no errors, the data set should have 0 observations.     *
          %*                                                                       *;
          %* Macro variables available to codeLogic:                               *;
          %*  _cstDSName                        _cstDomainOnly                     *;
          %*  _cstColumn                        _cstRefOnly                        *;
          %*  _cstDSKeys                        _cstSQLKeys                        *;
          %*  _cstAllTableMetadata              _cstAllColumnMetadata              *;
          %*************************************************************************;

          &_cstCodeLogic;

          %if %sysfunc(exist(work._cstproblems)) %then
          %do;
            data _null_;
              if 0 then set work._cstproblems nobs=_numobs;
              call symputx('_cstDataRecords',_numobs);
              stop;
            run;

            %if &_cstDataRecords %then
            %do;
              %* Create a temporary results data set. *;
              data _null_;
                attrib _csttemp label="Text string field for file names"  format=$char12.;
                _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
                call symputx('_csttempds',_csttemp);
              run;

              %* Write multiple records to the results data set for the domain in error *;
              data &_csttempds (label='Work error data set');
                  %cstutil_resultsdskeep;

                set work._cstproblems end=last;

                attrib
                    _cstSeqNo format=8. label="Sequence counter for result column"
                    _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
                    _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
                    _cstDetails format=$char200. label="Message details"
                    _cstLastKeyValues format=$char2000. label="Last keyvalues"
                  ;

                  retain _cstSeqNo 0 ;
                  if _n_=1 then _cstSeqNo=&_cstSeqCnt;

                  keep _cstMsgParm1 _cstMsgParm2;

                  * Set results data set attributes *;
                  %cstutil_resultsdsattr;
                  retain message resultseverity resultdetails '';
                  retain _cstDetails _cstLastKeyValues;

                  resultid="&_cstCheckID";
                  _cstMsgParm1="- &_cstDataRecords inconsistencies were detected";
                  _cstMsgParm2='';
                  resultseq=&_cstResultSeq;
                  resultflag=1;
                  srcdata = "&_cstDSName";
                  _cst_rc=0;
                  keyvalues='';

                  * Calculate keyvalues column.  *;
                  %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));
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
                  if vtype(&_cstColumn)='C' then
                  do;
                    actual = catx('=',"&_cstColumn",&_cstColumn);
                  end;
                  else
                    actual = catx('=',"&_cstColumn",kstrip(put(&_cstColumn,8.)));

                  _cstDetails=actual;
                  _cstLastKeyValues=keyvalues;

                  _cstSeqNo+1;
                  seqno=_cstSeqNo;

                  checkid="&_cstCheckID";

                  if last then
                  do;
                    call symputx('_cstSeqCnt',_cstSeqNo);
                    call symputx('_cstLastError',cats('%nrstr( ','Last invalid result:',_cstDetails,' )'));
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

                %let _cstexit_loop=0;
                %goto exit_loop;
              %end;
              %else
              %do;
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
              %****************************************************;
              %* No Error Condition - no inconsistencies detected *;
              %****************************************************;
              %let _cst_MsgID=CST0100;
              %let _cst_MsgParm1=&_cstDSName;
              %let _cst_MsgParm2=;
              %let _cstSrcData=&_cstDSName;
              %let _cst_rc=0;
              %let _cstResultFlag=0;
              %let _cstexit_loop=1;
              %goto exit_loop;
            %end;
          %end;
          %else
          %do;
            %****************************************************;
            %*  Check not run - codelogic step failed           *;
            %****************************************************;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=work._cstproblems was not created;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstSrcData=&_cstDSname;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;

        %end;
        %else
        %do;
          %let dsid = %sysfunc(close(&dsid));
          %****************************************************;
          %*  Check not run - &_cstColumn could not be found  *;
          %****************************************************;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=&_cstDSname &_cstColumn;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstSrcData=&sysmacroname;
          %let _cstResultFlag=-1;
          %let _cstexit_loop=1;
        %end;
      %end;
      %else
      %do;
        %****************************************************;
        %*  Check not run - &_cstDSName could not be found  *;
        %****************************************************;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=&_cstDSname;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstSrcData=&sysmacroname;
        %let _cstMetricsCntNumRecs=.;
        %let _cstResultFlag=-1;
        %let _cstexit_loop=1;
      %end;

%exit_loop:

        %if %sysfunc(exist(work._cstproblems)) %then
        %do;
          proc datasets lib=work nolist;
            delete _cstproblems;
          quit;
        %end;
        %if %symexist(_csttempds) %then
        %do;
          %if %length(&_csttempds)>0 %then
          %do;
            %if %sysfunc(exist(&_csttempds)) %then
            %do;
              proc datasets lib=work nolist;
                delete &_csttempds;
              quit;
            %end;
          %end;
        %end;

        * Write applicable metrics *;
        %if &_cstMetrics %then %do;
          %if &_cstMetricsNumRecs %then
            %cstutil_writemetric(
                              _cstMetricParameter=# of records tested
                             ,_cstResultID=&_cstCheckID
                             ,_cstResultSeqParm=&_cstResultSeq
                             ,_cstMetricCnt=&_cstMetricsCntNumRecs
                             ,_cstSrcDataParm=&_cstDSName
                            );
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
  %end;
  %else
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
    %put <<< cstcheck_recmismatch;
  %end;


%mend cstcheck_recmismatch;
