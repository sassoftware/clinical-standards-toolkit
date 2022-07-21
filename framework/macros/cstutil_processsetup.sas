%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_processsetup                                                           *;
%*                                                                                *;
%* Sets up model-specific study metadata.                                         *;
%*                                                                                *;
%* This macro sets up model-specific study metadata when using the various SAS    *;
%* Clinical Standards Toolkit driver programs (for example, validate_data,        *;
%* cst_reports, and so on).                                                       *;
%*                                                                                *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSASRefsName SASReferences file name                                *;
%* @macvar _cstSASRefsLoc SASReferences file location                             *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSetupSrc Setup source type (RESULTS or SASREFERENCES)              *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstStandardPath Rootpath associated with any given standard and       *;
%*             standardversion                                                    *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstSASReferencesSource - optional - The initial source on which to base*;
%*            the set up. If the value is RESULTS:                                *;
%*              1. No other parameters are required, and setup responsibility is  *;
%*                 passed to the cstutil_reportsetup macro.                       *;
%*              2. The results data set name must be passed to                    *;
%*                 cstutil_reportsetup as libref.memname.                         *;
%*            Values:  SASREFERENCES | RESULTS                                    *;
%*            Default: SASREFERENCES                                              *;
%* @param _cstSASReferencesName - optional - The name of the SASReferences data   *;
%*            set.                                                                *;
%*            Default: sasreferences                                              *;
%* @param _cstSASReferencesLocation - optional - The path (folder location) of    *;
%*            the SASReferences data set. If this parameter is not specified, the *;
%*            path to the WORK library is used.                                   *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro  cstutil_processsetup(
    _cstSASReferencesSource=SASREFERENCES,
    _cstSASReferencesName=sasreferences,
    _cstSASReferencesLocation=
    ) / des='CST: Setup Process Metadata';

  %local
    _cstErrCode
    _cstInitSASAutos
    _cstInitCmplib
  ;

  %let _cstErrCode=0;

  %**********************************************************************************;
  %* Capture SAS system options so we can append to any user-set values and         *;
  %* so that we can reset these later.                                              *;
  %**********************************************************************************;
  proc optSave out=work._cstsessionoptions;
  run;
  data _null_;
    call symputx('_cstInitSASAutos',getoption('sasautos'));
    call symputx('_cstInitCmplib',getoption('cmplib'));
  run;

  %**********************************************************************************;
  %* Determine whether this is a batch or interactive process.  If batch, we reset  *;
  %*  the system option syntaxcheck to allow processing to continue if an error is  *;
  %*  detected.  This simply mimicks interactive behavior for consistency.          *;
  %**********************************************************************************;

  data _null_;
    select("&sysenv");
     when("BACK") call execute('options nosyntaxcheck obs=max replace;');
     otherwise;
    end;
  run;

  %**********************************************************************************;
  %* Special case, generally for reporting processes based on RESULTS data sets     *;
  %**********************************************************************************;

  %if %upcase(&_cstSASReferencesSource) = RESULTS %then %do;
    %* In this special case, we only have a CST results data set as our source for metadata. *;
    %* This means we will look in the results data set in an attempt to find the             *;
    %*  sasreferences data set used in the process that created the results data set.        *;
    %*  Here, we want to skip setting properties and allocating librefs and filerefs, and    *;
    %*  let the reporting setup (see the cstutil_reportsetup macro) do these tasks.          *;
    %let _cstSetupSrc=RESULTS;
    %goto exit_macro;
  %end;

  %**********************************************************************************;
  %*  Get files supporting reporting in place                                       *;
  %**********************************************************************************;
  %if %length(&_cstResultsDS)=0 %then
    %let _cstResultsDS=work._cstresults;

  %if ^%sysfunc(exist(&_cstResultsDS)) %then
  %do;
    * Create work results data set.  *;
    data &_cstResultsDS;
      %cstutil_resultsdsattr;
      stop;
      call missing(of _all_);
    run;
  %end;

  %if (not %symexist(_cstMessages)) %then %do;
    %global _cstMessages;
  %end;
  %if (%length(&_cstMessages)<1) %then %do;
    %let _cstMessages=work._cstMessages;
  %end;
  %cstutil_createTempMessages();

  %**********************************************************************************;
  %*  Check Macro Parameter Values - set defaults as needed                         *;
  %**********************************************************************************;
  %if "&_cstSASReferencesLocation" = "" %then %do;
    %if (%symexist(workpath)=0) %then
      %global workpath;
    %if (%klength(&workpath)<1) %then
      %let workPath=%sysfunc(pathname(work));
    %let _cstSASReferencesLocation=&workpath;
    %let _cstErrCode=1 ;
  %end;

  %if %length(&_cstSASReferencesName)<1 %then
  %do;
    %let _cstSASReferencesName=sasreferences;
    %let _cstErrCode=1 ;
  %end;
  %if %length(&_cstSASReferencesSource)<1 %then
    %let _cstSASReferencesSource=SASREFERENCES;

  %if &_cstErrCode>0 %then
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Process setup is using this SASReferences: &_cstSASReferencesLocation/&_cstSASReferencesName,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_PROCESSSETUP);

  * Assign a temporary libname to the _cstSASReferencesLocation library;
  libname _csttlib "&_cstSASReferencesLocation";
  %if ^%sysfunc(exist(_csttlib.&_cstSASReferencesName))%then
  %do;
    %cstutil_writeresult(
                  _cstResultID=CST0008
                  ,_cstResultParm1=%nrbquote(SASReferences file &_cstSASReferencesLocation/&_cstSASReferencesName)
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_PROCESSSETUP
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  );
    %goto exit_macro;
  %end;

  %* Try to set _cstStandard and _cstStandardVersion if not known at this point *;
  %let _cstErrCode=0;
  %if %symexist(_cstStandard) %then %do;
    %if %length(&_cstStandard)<1 and %length(&_cstStandardVersion)<1 %then
      %let _cstErrCode=1 ;
  %end;
  %else
    %let _cstErrCode=1 ;

  %if &_cstErrCode>0 %then
  %do;
    data _null_;
      set _csttlib.&_cstSASReferencesName (keep=type subtype standard standardversion);
        *Set _cstStandard and _cstStandardVersion to first non-framework standard encountered in sasreferences  *;
        if upcase(standard) ne 'CST-FRAMEWORK' then
        do;
          call symputx('_cstStandard',strip(standard));
          call symputx('_cstStandardVersion',strip(standardversion));
        end;
    run;
    %let _cstErrCode=0;
  %end;

  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);
  data _null_;
    set work._cstStandards (where=(standard=upcase("&_cstStandard") and standardversion=upcase("&_cstStandardVersion")));
      call symputx('_cstStandardPath',kstrip(rootpath));
  run;
  proc datasets lib=work nolist;
    delete _cstStandards;
  quit;



  **********************************************************************************;
  * Set properties supplied as part of the CST-FRAMEWORK standard.                 *;
  * This sets session CST-FRAMEWORK global variables.                              *;
  * We will do this here only if it has not already happened.  Our test for this   *;
  * is the existence of 4 key/representative macro variables.                      *;
  **********************************************************************************;
  %if %symexist(_cstSASRefs) and %symexist(_cstMessages) and %symexist(_cstResultsDS) and
      %symexist(_cst_rc) %then;
  %else
    %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);


  **********************************************************************************;
  * Set global macro variables for the location of the sasreferences file          *;
  *  (overrides default properties initialized above                               *;
  **********************************************************************************;
  %let _cstSASRefsName=&_cstSASReferencesName;
  %let _cstSASRefsLoc=&_cstSASReferencesLocation;


  **********************************************************************************;
  * Allocate all the SAS references specified in the sasreferences data set        *;
  * Set autocall and fmtsearch paths                                               *;
  * Build message lookup data set defined by _cstMessages global macro variable    *;
  **********************************************************************************;
  %cstutil_allocatesasreferences(_cstSASRefsType=&_cstSASReferencesSource);



%exit_macro:

  %if %klength(%sysfunc(pathname(_csttlib)))>0 %then
  %do;
    libname _csttlib;
  %end;

%mend cstutil_processsetup;