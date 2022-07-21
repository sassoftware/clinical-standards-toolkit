%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckentitynotfound                                                         *;
%*                                                                                *;
%* Reports that a SAS Clinical Standards Toolkit entity cannot be found.          *;
%*                                                                                *;
%* This macro reports that a SAS Clinical Standards Toolkit entity (typically a   *;
%* file, folder, or column) cannot be found.                                      *;
%*                                                                                *;
%* NOTE: The file or folder reference might be embedded within a specific         *;
%*       SASReferences data set, too.                                             *;
%*                                                                                *;
%* NOTE: By default, this check does not require the use of codeLogic. If the     *;
%*       check metadata includes a non-null value of codeLogic, the value is used.*;
%*       If codeLogic is used, it must create work._cstproblems that has one      *;
%*       record per problem file or column. The macro variable _cstDataRecords    *;
%*       is populated based on the number of work._cstproblems records.           *;
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
%*            check-specific metadata                                             *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;
%macro cstcheckentitynotfound(_cstControl=)
    / des='CST: Entity not found';

  %local
    _csttempds

    _cstColCnt
    _cstColList
    _cstColumn
    _cstDomCnt
    _cstDSKeys
    _cstDSLibName
    _cstDSList
    _cstDSName
    _cstDomainOnly
    _cstDataRecords
    _cstEntities
    _cstTotalNotExist

    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstCodeLogic
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstStandardRef
    _cstReportingColumns
    _cstReportAll

    _cstexit_error
  ;

  %cstutil_readcontrol;

  %let _cstactual=;
  %let _cstColCnt=0;
  %let _cstDataRecords=0;
  %let _cstEntities=files;
  %let _cstTotalNotExist=0;
  %let _cstDomCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstResultFlag=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstMetricsCntNumRecs=0;

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

  %if %length(&_cstTableScope)=0 %then
  %do;
    %* Required parameter not found  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=_cstTableScope must be specified;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %if %length(&_cstColumnScope)=0 %then
  %do;
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
        %goto exit_error;
    %end;
  %end;
  %else
  %do;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstDomSubOverride=Y,_cstColSubOverride=Y);
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

    %if %length(%nrstr(&_cstCodeLogic))=0 %then
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

  %end;

  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
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

  proc sql noprint;
    select distinct(catx('.',sasref,table)) into :_cstDSList  separated by ' '
    from work._csttablemetadata;
    select count(distinct(catx('.',sasref,table))) into :_cstDomCnt
    from work._csttablemetadata;
  quit;

  %let _cstDataRecords=0;
  %do i=1 %to &_cstDomCnt;
    %let _cstDSName=%scan(&_cstDSList,&i,' ');
    %let _cstDomainOnly=%scan(&_cstDSName,2,'.');
    
    %if %sysfunc(exist(&_cstDSName)) %then
    %do;

      * Initialize problem data set *;
      data work._cstProblems;
        set &_cstDSName;
          attrib entitytype format=$8.
                 entityname format=$500.;
        if _n_=1 then stop;
        call missing(entitytype,entityname);
      run;

      %if &_cstColCnt > 0 %then
      %do;
        proc sql noprint;
          select column into :_cstColList  separated by ' '
          from work._cstcolumnmetadata
          where table="&_cstDomainOnly";
        quit;
        %let _cstColCnt=%SYSFUNC(countw(&_cstColList,' '));

        %if &_cstColCnt > 0 %then
        %do;
          %do j=1 %to &_cstColCnt;
            %let _cstColumn=%scan(&_cstColList,&j,' ');

            %**************************************************************************;
            %*  _cstCodeLogic must be a self-contained data or proc sql step. The     *;
            %*  expected result is a work._cstProblems data set.  If this data set    *;
            %*  has > 0 observations, this will be interpreted as an error condition. *;
            %**************************************************************************;

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
          %end;  %* end of ColList loop  *;

          data _null_;
            if 0 then set work._cstProblems nobs=_numobs;
            call symputx('_cstDataRecords',_numobs);
            stop;
          run;

          %if &_cstDataRecords %then
          %do;
          
            * Create a temporary results data set. *;
            data _null_;
              attrib _csttemp label="Text string field for file names"  format=$char12.;
              _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
              call symputx('_csttempds',_csttemp);
            run;

            * Add the record to the temporary results data set. *;
            data &_csttempds (label='Work error data set');
              %cstutil_resultsdskeep;
                set work._cstproblems end=last;

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
                  actual = cats('entitytype=',strip(entitytype),',entityname=',strip(entityname));
                  keyvalues='';
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

            %if %length(&_csttempds)>0 %then
            %do;
              data _null_;
                if 0 then set &_csttempds nobs=_numobs;
                call symputx('_cstDataRecords',_numobs);
                stop;
              run;

              %if &_cstDataRecords %then
              %do;
                %let _cstTotalNotExist=%eval(&_cstTotalNotExist + &_cstDataRecords);
                %cstutil_appendresultds(
                         _cstErrorDS=&_csttempds
                        ,_cstVersion=&_cstStandardVersion
                        ,_cstSource=&_cstCheckSource
                        ,_cstStdRef=&_cstStandardRef
                        );
              %end;
            %end;
          %end;
          %else
          %do;
            %if %upcase(&_cstReportAll)=Y %then
            %do;
              %* No errors detected  *;
              %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
              %cstutil_writeresult(
                     _cstResultID=CST0200
                     ,_cstValCheckID=&_cstCheckID
                     ,_cstResultParm1=%str(All &_cstEntities exist)
                     ,_cstResultParm2=
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstSeqNoParm=&_cstSeqCnt
                     ,_cstSrcDataParm=&_cstDSName
                     ,_cstResultFlagParm=0
                     ,_cstRCParm=0
                     ,_cstResultsDSParm=&_cstResultsDS
                         );
            %end;
          %end;

          %if &_cstDebug=0 %then
          %do;
            %if %sysfunc(exist(work._cstProblems)) %then
            %do;
              proc datasets lib=work nolist;
                delete _cstProblems;
              quit;
            %end;
          %end;
        %end; %* end of _cstColCnt > 0 in DS loop *;
      %end; %* end of _cstColCnt > 0 loop *;
      %else
      %do;
        %if %length(%superq(_cstCodeLogic))>0 %then
        %do;
          %**************************************************************************;
          %*  _cstCodeLogic must be a self-contained data or proc sql step. The     *;
          %*  expected result is a work._cstProblems data set.  If this data set    *;
          %*  has > 0 observations, this will be interpreted as an error condition. *;
          %*                                                                        *;
          %*  For this macro, work._cstProblems is assumed to have (at least) the   *;
          %*  following two columns:                                                *;
          %*    entitytype (file, dataset, column, folder, catalog)                 *;
          %*    entityname (e.g. sasref.member<.column>, path</memname>)            *;
          %**************************************************************************;

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
              set work._cstproblems end=last;

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
                actual = cats('entitytype=',strip(entitytype),',entityname=',strip(entityname));
                keyvalues='';
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

          %if %length(&_csttempds)>0 %then
          %do;
            data _null_;
              if 0 then set &_csttempds nobs=_numobs;
              call symputx('_cstDataRecords',_numobs);
              stop;
            run;

            %if &_cstDataRecords %then
            %do;
              %let _cstTotalNotExist=%eval(&_cstTotalNotExist + &_cstDataRecords);
              %cstutil_appendresultds(
                       _cstErrorDS=&_csttempds
                      ,_cstVersion=&_cstStandardVersion
                      ,_cstSource=&_cstCheckSource
                      ,_cstStdRef=&_cstStandardRef
                      );

            %end;
            %else
            %do;
              %if %upcase(&_cstReportAll)=Y %then
              %do;
                %* No errors detected  *;
                %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
                %cstutil_writeresult(
                     _cstResultID=CST0100
                     ,_cstValCheckID=&_cstCheckID
                     ,_cstResultParm1=&_cstDSName
                     ,_cstResultParm2=
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstSeqNoParm=&_cstSeqCnt
                     ,_cstSrcDataParm=&_cstDSName
                     ,_cstResultFlagParm=0
                     ,_cstRCParm=0
                     ,_cstResultsDSParm=&_cstResultsDS
                         );
              %end;
            %end;
            
            proc datasets lib=work nolist;
              delete &_csttempds;
            quit;
                
            %if &_cstDebug=0 %then
            %do;
              %if %sysfunc(exist(work._cstProblems)) %then
              %do;
                proc datasets lib=work nolist;
                  delete _cstProblems;
                quit;
              %end;
            %end;
          %end;
        %end;  %* end _cstCodeLogic>0 loop *;
      %end;
    %end; %* end of exist DS loop *;
    %else
    %do;
      %* Report non-existence of file or folder  *;
      %let _cstDataRecords=%eval(&_cstDataRecords+1);
      %let _cstTotalNotExist=%eval(&_cstTotalNotExist + &_cstDataRecords);
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                   _cstResultID=&_cstCheckID
                   ,_cstValCheckID=&_cstCheckID
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=&sysmacroname
                   ,_cstResultFlagParm=1
                   ,_cstRCParm=0
                   ,_cstResultsDSParm=&_cstResultsDS
                   );
    %end;
  %end;  %* end of 1 to _cstDomCnt loop  *;
  
  %* Tables only, all exist AND any files within SASRefs also exist *;
  %if &_cstColCnt < 1 and &_cstTotalNotExist < 1 %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                 _cstResultID=CST0100
                 ,_cstValCheckID=&_cstCheckID
                 ,_cstResultParm1=assessment of target &_cstEntities
                 ,_cstResultSeqParm=&_cstResultSeq
                 ,_cstSeqNoParm=&_cstSeqCnt
                 ,_cstSrcDataParm=CSTCHECKENTITYNOTFOUND
                 ,_cstResultFlagParm=0
                 ,_cstRCParm=0
                 ,_cstResultsDSParm=&_cstResultsDS
                 );
  %end;

  %* Write applicable metrics *;
  %if &_cstMetrics %then %do;

    %if &_cstMetricsCntNumRecs=0 %then
      %let _cstMetricsCntNumRecs=&_cstDomCnt;
    %if &_cstMetricsNumRecs %then
      %cstutil_writemetric(
                  _cstMetricParameter=# of records tested
                 ,_cstResultID=&_cstCheckID
                 ,_cstResultSeqParm=&_cstResultSeq
                 ,_cstMetricCnt=&_cstMetricsCntNumRecs
                 ,_cstSrcDataParm=CSTCHECKENTITYNOTFOUND
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
  %end;
  %else
  %do;
    %put <<< cstcheckentitynotfound;
  %end;

%mend cstcheckentitynotfound;
