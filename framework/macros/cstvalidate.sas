%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstvalidate                                                                    *;
%*                                                                                *;
%* Validates SAS Clinical Standards Toolkit metadata.                             *;
%*                                                                                *;
%* This macro iterates through the validation checks to be run and writes         *;
%* validation results to the process Results data set. The results are then       *;
%* persisted to any permanent location based on type=results records in           *;
%* SASReferences.                                                                 *;
%*                                                                                *;
%* Process cleanup is based on the _cstDebug global macro variable.               *;
%*                                                                                *;
%* Required file inputs:                                                          *;
%*   run-time (type=control,subtype=validation in sasreferences) check data set   *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstSRoot Root path of the sample library                              *;
%* @macvar _cstStudyRootPath Physical path location of the study                  *;
%* @macvar _cstCTDescription Description of controlled terminology packet         *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstCheckSortOrder Order in which validation checks are run            *;
%* @macvar _cstDeBug       Turns debugging on or off for the session              *;
%* @macvar _cstMessages    Cross-standard work messages data set                  *;
%* @macvar _cst_MsgID      Results: Result or validation check ID                 *;
%* @macvar _cst_MsgParm1   Messages: Parameter 1                                  *;
%* @macvar _cst_MsgParm2   Messages: Parameter 2                                  *;
%* @macvar _cst_rc         Task error status                                      *;
%* @macvar _cst_rcmsg      Message associated with _cst_rc                        *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstCallingPgm - optional - The name of the driver module calling       *;
%*            this macro.                                                         *;
%* @param _cstReportOverride - optional - Override the process reporting summary  *;
%*            (in the call to %cstutilvalidationsummary) to NOT include the       *;
%*            summary (Y).                                                        *;
%*            Values: N | Y                                                       *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @history 2014-07-02  Removed reference to validation_exclusions data set and   *;
%*                       replaced with use of SASReferences type/subtype =        *;
%*                       referencecontrol/internalvalidation and local macro      *;
%*                       variables _cstIVLib and _cstIVDS.                        *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstvalidate(_cstCallingPgm=Unspecified,_cstReportOverride=N)
    / des='CST: Validate CST metadata files';


  %* Do not attempt to run if there has been a set-up error  *;
  %if &_cst_rc %then
  %do;
    %put ****************************************************************;
    %put ERROR: Fatal error encountered, validation process cannot start.;
    %put ****************************************************************;
    %let _cstexit_error=0;
    %goto exit_error;
  %end;


  %local
    _cstChecksDS
    _cstControlLib
    _cstControlDS
    _cstCheckID
    _cstCodeSource
    _cstCTCnt
    _cstCTLibrary
    _cstCTMember
    _cstCTPath
    _cstCurrentCheck
    _cstIVLib
    _cstIVDS
    _cstNumChecks
    _cstexit_error
    _cstThisSeqCnt
    _cstTimer
    _cstTimerResult
    _cstTempLib
    _cstResultsDS2
    _cstrundt
    _cstrunsasref
    _cstrunstd
    _cstrunstdver
    _cstrun_v_c
    _cstStd
    _cstStdVsn
    _cstWriteMsg
  ;

  %let _cstexit_error=0;
  %let _cstCheckID=;
  %let _cstCodeSource=;
  %let _cstCTCnt=0;
  %let _cstCTLibrary=;
  %let _cstCTMember=;
  %let _cstCTPath=;
  %let _cstTimer=;
  %let _cstTimerResult=;
  %let _cstSrcData=&sysmacroname;

  %let _cstrundt=;
  %let _cstrunsasref=<not specified>;
  %let _cstrunstd=;
  %let _cstrunstdver=;
  %let _cstrun_v_c=;

  %* Make copy of global macro variables;
  %let _cstStd=&_cstStandard;
  %let _cstStdVsn=&_cstStandardVersion;
  %let _cstWriteMsg=0;

  data _null_;
    attrib _csttemp format=$500. label='Temporary variable string'
           _cstNonFW format=8.
           _cstEverControl format=8.;
    retain _cstNonFW _cstEverControl 0;
    call symputx('_cstrundt',put(datetime(),is8601dt.));
    set &_cstSASrefs (where=(upcase(type) in ("CONTROL" "REFERENCECONTROL"))) end=last;

    if upcase(subtype)="REFERENCE" then
    do;
      * Keep any non-Framework standard info if found *;
      if upcase(standard) ne 'CST-FRAMEWORK' then
      do;
        _cstNonFW=1;
        call symputx('_cstrunstd',standard);
        call symputx('_cstrunstdver',standardversion);
      end;
      call symputx('_cstrunsasref',"&_cstsasrefs");
    end;
    if upcase(subtype)="VALIDATION" then
    do;
      _csttemp="Undetermined";
      * Keep any non-Framework standard info if found *;
      if upcase(standard) ne 'CST-FRAMEWORK' then
      do;
        _cstNonFW=1;
        call symputx('_cstrunstd',standard);
        call symputx('_cstrunstdver',standardversion);
      end;
      else
      do;
        if path ne '' and memname ne '' then
        do;
          if kindexc(ksubstr(kreverse(path),1,1),'/\') then
            _csttemp=catx('',path,memname);
          else
            _csttemp=catx('/',path,memname);
        end;
      end;
      if upcase(type)="CONTROL" then
      do;
        if upcase(standard) = 'CST-FRAMEWORK' then
        do;
          call symputx('_cstrun_v_c',_csttemp);
          _cstEverControl=1;
        end;
      end;
      else if _cstEverControl=0 then
        call symputx('_cstrun_v_c',_csttemp);
    end;
    
    if last and _cstNonFW=0 then
    do;
      _csttemp=upcase("&_cstCallingPgm");
      if _csttemp not in ('VALIDATE_DATA.SAS' 'VALIDATE_NEW_STANDARD.SAS') then
        call symputx('_cstWriteMsg',1);
      call symputx('_cstrunstd','CST-FRAMEWORK');
      call symputx('_cstrunstdver','1.2');
    end;

  run;
  
  %if &_cstWriteMsg %then
  %do;
     %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=CST-FRAMEWORK standard assumed because no non-Framework standard detected,_cstSeqNoParm=0,_cstSrcDataParm=&_cstSrcData); 
  %end;
  
  %* Write information to the results data set about this run. *;
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstrunstd,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstrunstdver,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: &_cstCallingPgm,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: VALIDATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS VALIDATION CONTROL DATA SET: &_cstrun_v_c,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &_cstSRoot./cst-framework-&_cstVersion,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYLIBRARY: &_cstSRoot,_cstSeqNoParm=10,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=11,_cstSrcDataParm=&_cstSrcData);
  %let _cstSeqCnt=11;

  %cstutil_getsasreference(_cstStandard=CDISC-TERMINOLOGY,_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,
                           _cstSASRefmember=_cstCTMember,_cstAllowZeroObs=1,_cstConcatenate=1);
  %let _cstSrcData=&sysmacroname;

  %if %length(&_cstCTLibrary)>0 %then
  %do;
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
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CONTROLLED TERMINOLOGY SOURCE: &_cstCTPath,_cstSeqNoParm=12,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=12;
  %end;

  %* Get control libref. *;
  %cstutil_getsasreference(_cstStandard=CST-FRAMEWORK,_cstStandardVersion=1.2,_cstSASRefType=control,
           _cstSASRefSubtype=validation,_cstSASRefsasref=_cstControlLib,_cstSASRefmember=_cstControlDS);
    %if &_cst_rc %then
    %do;
      * Fatal error encountered, process cannot continue  *;
      %let _cst_MsgID=CST0001;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
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

    %* Get libref.member for standard-specific IV checks *;
    %cstutil_getsasreference(_cstStandard=&_cstrunstd,_cstStandardVersion=&_cstrunstdver,_cstSASRefType=referencecontrol,
             _cstSASRefSubtype=internalvalidation,_cstSASRefsasref=_cstIVLib,_cstSASRefmember=_cstIVDS,
             _cstAllowZeroObs=1);
    %if &_cst_rc %then
    %do;
      * Fatal error encountered, process cannot continue  *;
      %let _cst_MsgID=CST0001;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;


    %if %length(&_cstIVLib)>0 and %length(&_cstIVDS)>0 %then
    %do;

      %if %sysfunc(exist(&_cstIVLib..&_cstIVDS)) %then
      %do;

        proc sql noprint;
          create table &_cstChecksDS as
          select *,substr(uniqueid,1,9) as shortID length=9 label="Short unique ID prefix"
          from &_cstControlLib..&_cstControlDS chk
          order by checkid, standard, standardversion, checksource, uniqueid;
        quit;

        data &_cstChecksDS;
          merge &_cstIVLib..&_cstIVDS (in=std)
                &_cstChecksDS (in=cntl);
            by checkid standard standardversion checksource shortID;
          attrib exstandard format=8. label="Not supported for this standard";
          exstandard=0;
          if cntl and index(upcase(checktype),"STD")=0 then exstandard=0;
          else if cntl and not std then exstandard=1;
        run;
        
        proc sql noprint;
          select count(*) into:_cstNumChecks
            from &_cstChecksDS (where=(exstandard=0));
        quit;
        %let _cstNumChecks=&_cstNumChecks;

        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=%str(PROCESS INTERNAL VALIDATION CHECK SOURCE: Using &_cstrunstd &_cstrunstdver &_cstIVLib..&_cstIVDS (&_cstNumChecks obs) as check source),_cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=CSTVALIDATE);
      
        proc sql noprint;
          select count(*) into:_cstNumChecks
            from &_cstChecksDS;
        quit;
        %let _cstNumChecks=&_cstNumChecks;
      %end;
      %else
      %do;
        %let _cst_MsgID=CST0008;
        %let _cst_MsgParm1=&_cstIVLib..&_cstIVDS;
        %let _cst_MsgParm2=;
        %let _cstSrcData=CSTVALIDATE;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;
    %else
    %do;
      * Determine how many checks there are to be attempted. *;
      data &_cstChecksDS (label="All checks to be run");
        set &_cstControlLib..&_cstControlDS end=last;
          exstandard=0;
          if last then
            call symputx('_cstNumChecks',_n_);
      run;
    %end;

    %* Remainder of run Framework-centric, using Framework metadata for looping and lookups *;
    %let _cstrunstd=CST-FRAMEWORK;
    %let _cstrunstdver=1.2;

    %if &_cstNumChecks=0 %then
    %do;
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=No checks found in specified validation control data set,_cstSeqNoParm=1,_cstSrcDataParm=CSTVALIDATE);
      %let _cstexit_error=0;
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
      data &_cstThisCheckDS (label="Current check single obs DS" drop=_cstCheckMacroName _cstResultSeq _cstStatusText tempvar);
        set &_cstChecksDS(firstObs=&_cstCurrentCheck);

          attrib _cstCheckMacroName format=$char100. label="Check macro code name"
                 _cstResultSeq format=8. label="Global counter for checkid invocations"
                 _cstStatusText format=$40. label="Checkstatus text"
                 tempvar format=$200. label="Temporary variable"
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

          if checkstatus > 0 and exstandard=0 then
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
            put "/*****************************************************/";
            put "/* Skipping checkID=  " checkid "                      */";
            put "/*****************************************************/";

            file nextcode;

            if exstandard=1 then
            do;
              _cstResultSeq = input(substr(uniqueid,8,2),8.);
              call symputx('_cstResultSeq',_cstResultSeq);
              tempvar=strip(upcase(tableScope));
              put @1 '%cstutil_writeresult(_cstResultID=CST0017';
              put @10 ',_cstValCheckID=' checkid;
              put @10 ',_cstResultSeqParm=' _cstResultSeq;
              put @10 ',_cstSrcDataParm=' tempvar;
              put @10 ',_cstSeqNoParm=1,_cstResultFlagParm=-1,_cstRCParm=0';
              put @10 ');';
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

              put @1 '%cstutil_writeresult(_cstResultID=CST0019';
              put @10 ',_cstValCheckID=' checkid;
              put @10 ",_cstResultSeqParm=&_cstResultSeq,_cstSrcDataParm=CSTVALIDATE";
              put @10 ",_cstSeqNoParm=1,_cstResultFlagParm=-1,_cstRCParm=0";
              put @10 ',_cstActualParm=%str(checkstatus=)' _cstStatusText;
              put @10 ');';
              output;
            end;
          end;
        end;
        stop;
      run;

      %* execute the next macro;
      %if &_cst_rc=0 and %length(&_cstCodeSource)>0 %then
      %do;
        %include nextCode;
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
        %let _cstexit_error=1;
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
      %let _cstexit_error=0;
    %end;
    %let _cstSrcData=&sysmacroname;

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
    %if %upcase(&_cstReportOverride)=N %then
    %do;
      %cstutilvalidationsummary(_cstProcessSummary=Y,_cstSeverityList=Warning Error);
    %end;

    %if %sysfunc(exist(&_cstResultsDS)) %then
    %do;

      data work._cstTempResults;
        set &_cstResultsDS;
          attrib line sortvar group format=8.;
          retain line sortvar group 0;
        if message =: 'PROCESS WORKFLOW' then
        do;
          sortvar+1;
          group=0;
        end;
        if ^missing(checkid) and missing(lag(strip(checkid)))=1 then
          group+1;
        if missing(strip(checkid)) and missing(lag(checkid))=0 then
          group+1;
        line+1;
      run;
      
      * Sort validation check results, but maintain order of pre-validation results  *;
      data work._cstTempResultsCore;
        set work._cstTempResults (where=(checkid=''));
      run;
      proc sort data=work._cstTempResultsCore;
        by sortvar group line;
      run;
      proc sort data=work._cstTempResults out=work._cstTempResultsChecks (where=(checkid ne ''));
        by sortvar group checkid resultseq seqno;
      run;
        
      data &_cstResultsDS (drop=sortvar group line);
        set work._cstTempResultsCore
            work._cstTempResultsChecks;
          by sortvar group;
      run;

      proc datasets lib=work nolist;
        delete _cstTempResults _cstTempResultsCore _cstTempResultsChecks;
      quit;

    %end;

    %cstutil_saveresults;

    * Delete the temporary catalog and generic work data sets*;
    proc datasets lib=work nolist;
        delete &_cstChecksDS &_cstThisCheckDS / memtype=data;
        delete &_cstNextCode / memtype=catalog;
    quit;

%exit_error:

    %if &_cstexit_error %then
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
    %if &_cstexit_error=0 %then
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
    %put <<< cstvalidate;
    %put _all_;
  %end;


%mend cstvalidate;

