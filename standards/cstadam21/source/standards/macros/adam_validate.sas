%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* adam_validate                                                                  *;
%*                                                                                *;
%* Validates CDISC ADAM model files.                                              *;
%*                                                                                *;
%* This macro cycles through the validation checks to be run and writes           *;
%* validation results to the process Results and Metrics data sets. These results *;
%* are persisted to any permanent location based on type=results records in       *;
%* SASReferences. Process cleanup is based on the _cstDebug global macro          *;
%* variable.                                                                      *;
%*                                                                                *;
%* @macvar studyRootPath Root path to the sample source study                     *;
%* @macvar _cstCaseMgmt Validation: Consider case sensitivity when comparing      *;
%*             values                                                             *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstCheckSortOrder Order in which validation checks are to be run      *;
%* @macvar _cstCTDescription Description of controlled terminology packet         *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstMetrics Enables or disables metrics reporting                      *;
%* @macvar _cstMetricsDS Data set used to accumulate metrics for a validation     *;
%*             process                                                            *;
%* @macvar _cstMetricsCntNumBadChecks Validation metrics: validation checks not   *;
%*             run                                                                *;
%* @macvar _cstMetricsCntNumChecks Validation metrics: distinct validation check  *;
%*             invocations                                                        *;
%* @macvar _cstMetricsCntNumContent Validation metrics: number of content         *;
%*             problems detected                                                  *;
%* @macvar _cstMetricsCntNumErrors Validation metrics: number of errors detected  *;
%* @macvar _cstMetricsCntNumNotes Validation metrics: number of notes detected    *;
%* @macvar _cstMetricsCntNumStructural Validation metrics: number of structural   *;
%*             problems detected                                                  *;
%* @macvar _cstMetricsCntNumWarnings Validation metrics: number of warnings       *;
%*             detected                                                           *;
%* @macvar _cstMetricsNumBadChecks Validation metrics: calculate validation       *;
%*             checks not run                                                     *;
%* @macvar _cstMetricsNumChecks Validation metrics: calculate distinct validation *;
%*             check invocations                                                  *;
%* @macvar _cstMetricsNumContent Validation metrics: calculate number of content  *;
%*             problems detected                                                  *;
%* @macvar _cstMetricsNumErrors Validation metrics: calculate number of errors    *;
%*             detected                                                           *;
%* @macvar _cstMetricsNumNotes Validation metrics: calculate number of notes      *;
%*             detected                                                           *;
%* @macvar _cstMetricsNumStructural Validation metrics: calculate number of       *;
%*             structural problems detected                                       *;
%* @macvar _cstMetricsNumWarnings Validation metrics: calculate number of         *;
%*             warnings detected                                                  *;
%* @macvar _cstMetricsTimer Validation metrics: estimate the elapsed time to      *;
%*             perform each action                                                *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstCallingPgm - optional - The name of the driver module calling       *;
%*            this macro.                                                         *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure external                                                             *;

%macro adam_validate(_cstCallingPgm=Unspecified
    ) / des='CST: Validate CDISC ADAM model files';


  %* Do not attempt to run if there has been a set-up error  *;
  %if &_cst_rc %then
  %do;
    %put ****************************************************************;
    %put ERROR: Fatal error encountered, validation process cannot start.;
    %put ****************************************************************;
    %let _cstExitError=0;
    %goto exit_error;
  %end;


  %local
    _cstChecksDS
    _cstCheckID
    _cstCodeSource
    _cstControlLib
    _cstControlDS
    _cstcrossstd
    _cstcrossstdver
    _cstCTCnt
    _cstCTLibrary
    _cstCTMember
    _cstCTPath
    _cstCurrentCheck
    _cstExitError
    _cstNextCode
    _cstNumChecks
    _cstrundt
    _cstrunsasref
    _cstrunstd
    _cstrunstdver
    _cstStd
    _cstStdVsn
    _cstThisCheckDS
    _cstThisSeqCnt
    _cstTimer
    _cstTimerResult
    _cstWorkDir
  ;

  %let _cstCTCnt=0;
  %let _cstCTLibrary=;
  %let _cstCTMember=;
  %let _cstCTPath=;

  %let _cstExitError=0;
  %let _cstCheckID=;
  %let _cstCodeSource=;
  %let _cstTimer=;
  %let _cstTimerResult=;
  %let _cstSrcData=&sysmacroname;

  %let _cstrundt=;
  %let _cstrunsasref=;
  %let _cstrunstd=;
  %let _cstrunstdver=;

  %* Make copy of global macro variables;
  %let _cstStd=&_cstStandard;
  %let _cstStdVsn=&_cstStandardVersion;

  data _null_;
    attrib _csttemp format=$500. label='Temporary variable string';
    call symputx('_cstrundt',put(datetime(),is8601dt.));
    set &_cstSASrefs;

    if upcase(type)="CONTROL" and upcase(subtype)="REFERENCE" then
    do;
      if path ne '' and memname ne '' then
      do;
        if kindexc(substr(kreverse(path),1,1),'/\') then
          _csttemp=catx('',path,memname);
        else
          _csttemp=catx('/',path,memname);
      end;
      else
        _csttemp="&_cstsasrefs";
      call symputx('_cstrunsasref',_csttemp);
      call symputx('_cstrunstd',standard);
      call symputx('_cstrunstdver',standardversion);
    end;
    else if upcase(type) in ("CONTROL" "REFERENCECONTROL") and upcase(subtype)="VALIDATION" then
    do;
      call symputx('_cstrunstd',standard);
      call symputx('_cstrunstdver',standardversion);
    end;
    else if upcase(type) in ("SOURCEDATA" "SOURCEMETADATA") then
    do;
      * determine if there is a secondary standard specified to support cross-standard validation *;
      if upcase(standard) ne upcase("&_cstStandard") and upcase(standardversion) ne upcase("&_cstStandardVersion") then
      do;
        call symputx('_cstcrossstd',upcase(standard));
        call symputx('_cstcrossstdver',upcase(standardversion));
      end;
    end;
  run;

  %* Write information to the results data set about this run. *;
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstrunstd,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstrunstdver,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: &_cstCallingPgm,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: VALIDATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
  %if %symexist(studyRootPath) %then
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
  %else
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
  %let _cstSeqCnt=9;

  %cstutil_getsasreference(_cstStandard=CDISC-TERMINOLOGY,_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,
                           _cstSASRefmember=_cstCTMember,_cstAllowZeroObs=1,_cstConcatenate=1);
  %let _cstSrcData=&sysmacroname;

  %if %length(&_cstCTLibrary)>0 %then
  %do;

    %local _cstRestoreQuoteLenMax;
    %let _cstRestoreQuoteLenMax=%sysfunc(getoption(QuoteLenMax));
    options NoQuoteLenMax;

    %let _cstCTCnt=%SYSFUNC(countw(&_cstCTLibrary,' '));
    %do _cstIter=1 %to &_cstCTCnt;
      %let _cstCTPath=&_cstCTPath %sysfunc(ktranslate(%sysfunc(kstrip(%sysfunc(pathname(%scan(&_cstCTLibrary,&_cstIter,' '))))),'/','\'));
      %if %length(&_cstCTMember)>0 %then
        %let _cstCTPath=&_cstCTPath/%scan(&_cstCTMember,&_cstIter,' ');
    %end;
    
    %if %symexist(_cstCTDescription) %then
    %do;
      %if %length(&_cstCTDescription)>0 %then
        %let _cstCTPath=&_cstCTPath (&_cstCTDescription);
    %end;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CONTROLLED TERMINOLOGY SOURCE: &_cstCTPath,_cstSeqNoParm=10,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=10;
    %let _cstThisSeqCnt=&_cstSeqCnt;
    
    options &_cstRestoreQuoteLenMax;
  %end;

  %* Get control libref. *;
  %cstutil_getsasreference(_cstSASRefType=control,_cstSASRefSubtype=validation,_cstSASRefsasref=_cstControlLib,_cstSASRefmember=_cstControlDS);
    %if &_cst_rc %then
    %do;
      * Fatal error encountered, process cannot continue  *;
      %let _cst_MsgID=CST0001;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstExitError=1;
      %goto exit_error;
    %end;

    * Populate local macro variables *;
    data _null_;
      set sashelp.vslib(where=(libname="WORK"));
      call symputx('_cstWorkDir',path);

      attrib _csttemp label="Text string field for file names"  format=$char12.;

      * data set containing the checks to run *;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstChecksDS',_csttemp);

      * data set containing the single check that is about to run *;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstThisCheckDS',_csttemp);

    run;

    %if %length(&_cstResultsDS)=0 %then
    %do;
      %let _cstResultsDS=work._cstresults;

      * Create work results data set.  *;
      data &_cstResultsDS;
        %cstutil_resultsdsattr;
        stop;
        call missing(of _all_);
      run;
    %end;

    %if &_cstMetrics %then
    %do;
      %if %length(&_cstMetricsDS)=0 %then
      %do;
        %let _cstMetricsDS=work._cstmetrics;

        * Create work metrics data set.  *;
        data work.&_cstMetricsDS;
          %cstutil_metricsdsattr;
          stop;
          call missing(of _all_);
        run;
      %end;
    %end;

    * Determine how many checks there are to run. *;
    data &_cstChecksDS (label="All checks to be run");
      set &_cstControlLib..&_cstControlDS end=last;
        if last then
          call symputx('_cstNumChecks',_n_);
    run;
    %if (&syserr gt 4) %then
    %do;
      %* Check failed - SAS error  *;
      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Unable to create control file of all checks;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cst_rc=1;
      %let _cstExitError=1;
      %goto exit_error;
    %end;

    %if %symexist(_cstCheckSortOrder) %then
    %do;
      %if %upcase(&_cstCheckSortOrder)=_DATA_ %then
      %do;
        %* Do nothing - accept input sort order of the validation check data set as set by the user *;
      %end;
      %else
      %do;
        %* Use sort order for the validation check data set as set by the user in _cstCheckSortOrder  *;
        %* Example:  checkid checksource                                                              *;
        proc sort data=&_cstChecksDS;
          by &_cstCheckSortOrder;
        run;
      %end;
    %end;

    %if ^%symexist(_cstCaseMgmt) %then
    %do;
      %let _cstCaseMgmt=;
    %end;

    %*************************************************************************;
    %* Create work catalog source entry to accumulate code in the following  *;
    %*  data step to run at the conclusion of the data step.                 *;
    %*************************************************************************;
    data _null_;
      attrib _csttemp label="Text string field for file names"  format=$char12.;

      * catalog name for generated info - enabling multi-threaded data steps *;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstNextCode',_csttemp);
    run;

    * Cycle through each of the checks  *;
    %let _cstCurrentCheck=1;
    %do %until(&_cst_rc or (&_cstCurrentCheck>&_cstNumChecks));

      %let _cstTimer = %sysfunc(time(),12.3);

      filename nextCode CATALOG "work.&_cstNextCode..nextCheck.source";
      data work.&_cstThisCheckDS (label="Current check single obs DS" drop=_cstCheckMacroName _cstResultSeq _cstStatusText);
        set work.&_cstChecksDS(firstObs=&_cstCurrentCheck);

          attrib _cstCheckMacroName format=$char100. label="Check macro code name"
                 _cstResultSeq format=8. label="Global counter for checkid invocations"
                 _cstStatusText format=$40. label="Checkstatus text"
          ;

        call symputx('_cstSeqCnt',0);

        if upcase(checkid) = upcase("&_cstCheckID") then
        do;
          _cstResultSeq = input(symget('_cstResultSeq'),8.);
          call symputx('_cstResultSeq',_cstResultSeq+1);
        end;
        else
          call symputx('_cstResultSeq',1);

        call symputx('_cstCheckID',checkid);
        call symputx('_cstCodeSource',codeSource);

        _cstCheckMacroName = '%' || strip(codeSource);

        if kstrip(codeSource) ne '' then
        do;

          if checkstatus > 0 then
          do;
            put "/*****************************************************/";
            put "/* Running checkID=  " checkid "                       */";
            put "/*****************************************************/";
            
            file nextcode;

            put _cstCheckMacroName"(_cstControl=&_cstThisCheckDS);";
            output;
          end;
          else
          do;
            select(checkstatus);
              when(0) _cstStatusText='0 (inactive)';
              when(-1) _cstStatusText='-1 (deprecated/archived)';
              when(-2) _cstStatusText='-2 (not implemented in this release)';
              otherwise;
            end;
            put "/*****************************************************/";
            put "/* Skipping checkID=  " checkid "                      */";
            put "/*****************************************************/";
            
            file nextcode;

            put @1 '%cstutil_writeresult(_cstResultID=CST0019';
            put @10 ',_cstValCheckID=' checkid;
            put @10 ",_cstResultSeqParm=&_cstResultSeq,_cstSrcDataParm=ADAM_VALIDATE";
            put @10 ",_cstSeqNoParm=1,_cstResultFlagParm=-1,_cstRCParm=0";
            put @10 ',_cstActualParm=%str(checkstatus=)' _cstStatusText;
            put @10 ');';
            output;
          end;
        end;
        stop;
      run;

      %* execute the next macro;
      %if &_cst_rc=0 and %length(&_cstCodeSource)>0 %then
      %do;
        %include nextCode;

        %if &_cstMetrics %then
        %do;
          %if &_cstMetricsNumChecks %then
            %let _cstMetricsCntNumChecks=%eval(&_cstMetricsCntNumChecks+1);
        %end;
      %end;
      %* clear the filename;
      filename nextCode;

      %if &_cst_rc %then
      %do;
        * Fatal error encountered, process cannot continue  *;
        %let _cst_MsgID=CST0001;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstExitError=1;
        %goto exit_error;
      %end;

      %let _cstCurrentCheck=%eval(&_cstCurrentCheck+1);

      data _null_;
        length _csttimediff $200;
        _csttimediff = cat("Elapsed time to run check: ",put(time() - input(symget('_cstTimer'),12.3),time8.));

        %if &_cstDebug %then
        %do;
          put '***********************************';
          put _csttimediff;
          put '***********************************';
        %end;
          call symputx('_cstTimerResult',_csttimediff);
      run;

      * Write applicable metrics *;
      %if &_cstMetrics %then %do;

        %if &_cstMetricsTimer %then
          %cstutil_writemetric(
                  _cstMetricParameter=&_cstTimerResult
                  ,_cstResultID=&_cstCheckID
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=.
                  ,_cstSrcDataParm=%upcase(&_cstCodeSource)
                  );

      %end;
      %let _cstExitError=0;
    %end;
    %let _cstSrcData=&sysmacroname;

    %if %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      * Sort validation check results, but maintain order of pre-validation results  *;
      data work._cstTempResults;
        set &_cstResultsDS (where=(checkid=''));
      run;
      proc sort data=&_cstResultsDS (where=(checkid ne ''));
        by checkid resultseq seqno;
      run;
      data &_cstResultsDS;
        set work._cstTempResults
            &_cstResultsDS;
      run;
      proc datasets lib=work nolist;
        delete _cstTempResults;
      quit;
      
      %* Did process succeed or fail?  *;
      %if %cstutilprocessfailed(_cstResDS=&_cstResultsDS)=1 %then
        %let _cst_MsgParm2=failed to complete;
      %else
        %let _cst_MsgParm2=completed;

      %let _cstSeqCnt=%eval(&_cstThisSeqCnt+1);
      %cstutil_writeresult(
          _cstResultID=CST0203
         ,_cstResultParm1=Validation process
         ,_cstResultParm2=&_cst_MsgParm2
         ,_cstResultSeqParm=1
         ,_cstSeqNoParm=&_cstSeqCnt
         ,_cstSrcDataParm=&_cstSrcData
         ,_cstResultFlagParm=0
         ,_cstRCParm=0
          );
          
      %* Report summary assessment of validation process  *;
      %cstutilvalidationsummary;
    %end;

    * Write applicable metrics *;
    %if &_cstMetrics %then %do;

      %let _cstSrcData=&sysmacroname;
      %if &_cstMetricsNumChecks %then
        %cstutil_writemetric(
                  _cstMetricParameter=# of distinct check invocations
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumChecks
                  ,_cstSrcDataParm=&_cstSrcData
                  );

      %if %sysfunc(exist(&_cstMetricsDS)) %then
      %do;
        %if %sysfunc(exist(&_cstResultsDS)) %then
        %do;

          %let _cstSrcData=&sysmacroname;
          proc sql noprint;

            %if &_cstMetricsNumErrors %then
            %do;
              select count(*) into:_cstMetricsCntNumErrors
                from &_cstResultsDS (where=(upcase(resultseverity)='ERROR'));
            %end;
            %if &_cstMetricsNumWarnings %then
            %do;
              select count(*) into:_cstMetricsCntNumWarnings
                from &_cstResultsDS (where=(upcase(resultseverity)='WARNING'));
            %end;
            %if &_cstMetricsNumNotes %then
            %do;
              select count(*) into:_cstMetricsCntNumNotes
                from &_cstResultsDS (where=(upcase(resultseverity)='NOTE'));
            %end;
            %if &_cstMetricsNumStructural %then
            %do;
              select count(*) into:_cstMetricsCntNumStructural
                from &_cstResultsDS (where=(upcase(resultseverity)^='INFO'))
                  where checkid in (select distinct checkid from &_cstChecksDS (where=(upcase(checktype)="METADATA")));
            %end;
            %if &_cstMetricsNumContent %then
            %do;
              select count(*) into:_cstMetricsCntNumContent
                from &_cstResultsDS (where=(upcase(resultseverity)^='INFO'))
                  where checkid in (select distinct checkid from &_cstChecksDS (where=(upcase(checktype)^="METADATA")));
            %end;
            %if &_cstMetricsNumBadChecks %then
            %do;
              select count(*) into : _cstMetricsCntNumBadChecks from (select distinct checkid, resultseq from &_cstResultsDS
                 (where=(checkid ne '' and resultflag<0)));
            %end;

          quit;
        %end;

        %if &_cstMetricsNumBadChecks %then
          %cstutil_writemetric(
                  _cstMetricParameter=# check invocations not run
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumBadChecks
                  ,_cstSrcDataParm=&_cstSrcData
                  );
        %if &_cstMetricsNumErrors %then
          %cstutil_writemetric(
                  _cstMetricParameter=Errors (severity=High) reported
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumErrors
                  ,_cstSrcDataParm=&_cstSrcData
                  );
        %if &_cstMetricsNumWarnings %then
          %cstutil_writemetric(
                  _cstMetricParameter=Warnings (severity=Medium) reported
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumWarnings
                  ,_cstSrcDataParm=&_cstSrcData
                  );
        %if &_cstMetricsNumNotes %then
          %cstutil_writemetric(
                  _cstMetricParameter=Notes (severity=Low) reported
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumNotes
                  ,_cstSrcDataParm=&_cstSrcData
                  );
        %if &_cstMetricsNumStructural %then
          %cstutil_writemetric(
                  _cstMetricParameter=%str(Structural errors, warnings and notes)
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumStructural
                  ,_cstSrcDataParm=&_cstSrcData
                  );
        %if &_cstMetricsNumContent %then
          %cstutil_writemetric(
                  _cstMetricParameter=%str(Content errors, warnings and notes)
                  ,_cstResultID=METRICS
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstMetricCnt=&_cstMetricsCntNumContent
                  ,_cstSrcDataParm=&_cstSrcData
                  );

      %end;

    %end;

    %* Reset global macro variables;
    %let _cstStandard=&_cstStd;
    %let _cstStandardVersion=&_cstStdVsn;

    %cstutil_saveresults(_cstIncludeValidationMetrics=1);


    * Delete the temporary catalog and generic work data sets*;
    proc datasets lib=work nolist;
        delete &_cstChecksDS &_cstThisCheckDS / memtype=data;
        delete &_cstNextCode / memtype=catalog;
    quit;

%exit_error:

    %if &_cstExitError %then
    %do;
      %put ********************************************************;
      %put ERROR: Fatal error encountered, process cannot continue.;
      %put ********************************************************;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
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
    %end;

  %if &_cstDebug=0 %then
  %do;
    %* Delete these two key files only if we have not halted the process *;
    %if &_cstExitError=0 %then
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
    %if %sysfunc(exist(work._cstsrccolumnmetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstsrccolumnmetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._cstrefcolumnmetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstrefcolumnmetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._cstsrctablemetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstsrctablemetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._cstreftablemetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstreftablemetadata;
      quit;
    %end;
  %end;
  %else
  %do;
    %put <<< adam_validate;
    %put _all_;
  %end;


%mend adam_validate;
