%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportsetup                                                            *;
%*                                                                                *;
%* Sets up process and metadata reporting.                                        *;
%*                                                                                *;
%* This macro is run before generating several sample cross-standard SAS Clinical *;
%* Standards Toolkit reports.                                                     *;
%*                                                                                *;
%* If _cstSetupSrc=RESULTS, the code interprets the information in a Results data *;
%* set that is referenced by _cstRptResultsDS. Otherwise, the code interprets     *;
%* the information in the SASReferences data set that is referenced by            *;
%* _cstSASRefs.                                                                   *;
%*                                                                                *;
%* This macro is called by the drivers cst_report.sas and cst_metadatareport.sas. *;
%*                                                                                *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstMetricsDS Metrics data set                                         *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstRptControl Run-time validation control (check) data set            *;
%* @macvar _cstRptLib SAS library destination for report output file              *;
%* @macvar _cstRptOutputFile Path and name of report output file                  *;
%* @macvar _cstRptMetricsDS Metrics data set created by a SAS Clinical Standards  *;
%*             Toolkit process                                                    *;
%* @macvar _cstRptResultsDS Results data set created by a SAS Clinical Standards  *;
%*             Toolkit process                                                    *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSASRefsName SASReferences file name                                *;
%* @macvar _cstSASRefsLoc SASReferences file location                             *;
%* @macvar _cstSetupSrc Initial source on which to base the setup. In this        *;
%*             context, usually set based on the value of the                     *;
%*             _cstSASReferencesSource macro variable.                            *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstStdRef Data set (libref.dataset) that specifies supplemental       *;
%*             reference metadata                                                 *;
%* @macvar _cstStdTitle Main derived standard-specific title of report            *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstValDSType Validation check file as a DATA set or VIEW              *;
%* @macvar workpath Path to the SAS session work library                          *;
%*                                                                                *;
%* @param _cstRptType - optional- The type of report to generate:                 *;
%*                 Metadata: Report on the validation check metadata.             *;
%*                 Results: Report on the process results and metrics.            *;
%*            Values:  Metadata | Results                                         *;
%*            Default: Metadata                                                   *;
%*                                                                                *;
%* @since  1.3                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportsetup(
    _cstRptType=Metadata
    ) / des='CST: Perform reporting processe setup';

  %* Do not attempt to run if there has been a set-up error  *;
  %if &_cst_rc %then
  %do;
    %put ******************************************************************;
    %put ERROR: Fatal error encountered, report process setup cannot start.;
    %put ******************************************************************;
    %goto exit_macro;
  %end;

  %global 
    _cstSrcMetadataDS
    _cstValDSType;

  %local
    _cstHasGRoot
    _cstHasSRoot
    _cstNextCode
    _cstOldGLRootPath
    _cstOldStudyRootPath
    _cstRandom
    _cstSASmesLib
    _cstSASrefLib
    _cstSrpError
  ;

  %let _cstOldGLRootPath=;
  %let _cstOldStudyRootPath=;
  %let _cstSASrefLib=;
  %let _cstSrpError=0;
  %let _cstValDSType=DATA;

  ********************************************************;
  * Set general options and multi-use report formats     *;
  ********************************************************;
  options source source2 nodate nonumber orientation=landscape label;

  * Build formats used by multiple report panels *;
  proc format library=work.formats;
    value  YN 0='No'
              1='Yes'
             -1='Not Run'
          other='UNKNOWN';
    value  $YesNo  'n'='No'
                   'N'='No'
                   'y'='Yes'
                   'Y'='Yes'
                 other='N/A';
  run;


  %* If the macro variable _cstSetupSrc is set to RESULTS, this means we        *;
  %*  must read and interpret a results data set to set reporting macros.       *;

  %if %symexist(_cstSetupSrc) %then
  %do;
    %if &_cstSetupSrc=RESULTS %then
    %do;

      %if %symexist(_cstRptResultsDS) %then
      %do;
        %* The results data set is required  *;
        %if &_cstRptResultsDS= %then
        %do;
          %put;
          %put ERROR: Use of the cstutil_processsetup macro parameter _cstSetupSource (value=RESULTS) requires that the results data set be specified in _cstRptResultsDS;
          %put;
          %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Use of the cstutil_processsetup macro parameter _cstSetupSource (value=RESULTS) requires that the results data set be specified in _cstRptResultsDS,
                      _cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
          %goto exit_macro;
        %end;
        %else %if not %sysfunc(exist(&_cstRptResultsDS)) %then
        %do;
          %put;
          %put ERROR: The results data set &_cstRptResultsDS does not exist;
          %put;
          %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=The results data set &_cstRptResultsDS does not exist,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
          %goto exit_macro;
        %end;
      %end;
      %else
      %do;
        %put;
        %put ERROR: The macro variable _cstRptResultsDS has not been defined;
        %put;
        %cstutil_writeresult(
               _cstResultID=CST0009
              ,_cstResultParm1=_cstRptResultsDS
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcDataParm=CSTUTIL_REPORTSETUP
              ,_cstResultFlagParm=1
              ,_cstRCParm=1
              );
        %goto exit_macro;
      %end;


      %let _cstRandom=1;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstNextCode=_cst&_cstRandom;

      ***********************************************************;
      *  Assign a filename for the code that will be generated  *;
      ***********************************************************;
      filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source";

      data _null_;
        file &_cstNextCode;

        set &_cstRptResultsDS (where=(checkid='' and ksubstr(message,1,7)="PROCESS")) end=last;

        attrib _cstpath format=$256. label="Path"
               _cstname format=$48. label="Name"
               _csttemp format=$200.;

        _csttemp = ktranslate(kscan(message,2,''),'',':');
        select(_csttemp);
          when("STANDARD") call symputx('_cstStandard',kscan(message,3,''));
          when("STANDARDVERSION")
          do;
            call symputx('_cstStandardVersion',kscan(message,3,''));
            put '%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);';
            put '%cst_setStandardProperties(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,_cstSubType=initialize);';
          end;
          when("SASREFERENCES")
          do;
            _csttemp = kscan(message,3,'');
            _cstpath = kstrip(kreverse(_csttemp));
            _cstname = kreverse(kscan(ksubstr(_cstpath,1,kindexc(_cstpath,'/\')-1),2,'.'));
            _cstpath = kreverse(ksubstr(_cstpath,kindexc(_cstpath,'/\')+1));
            _csttemp = '%let _cstSASRefsLoc=' ||  kstrip(_cstpath) || ';';
            put _csttemp;
            _csttemp = '%let _cstSASRefsName=' ||  kstrip(_cstname) || ';';
            put _csttemp;
            put '%cstutil_allocatesasreferences;';
          end;
          when("STUDYROOTPATH") call symputx('_cstOldStudyRootPath',kscan(message,3,''));
          when("GLOBALLIBRARY") call symputx('_cstOldGLRootPath',kscan(message,3,''));
          otherwise;
        end;
      run;

      %include &_cstNextCode;
      filename &_cstNextCode;

      proc datasets lib=work nolist;
        delete &_cstNextCode / memtype=catalog;
      quit;

      %* Now check for potential problems with the derived _cstSASRefs data set.  *;
      %* Potential problems addressed here:                                       *;
      %*   (1) studyRootPath not currently defined, and the _cstSASRefs data set  *;
      %*       uses studyRootPath in a library or file path                       *;
      %*   (2) current studyRootPath does not match the studyRootPath value used  *;
      %*       in the process (CST 1.3)                                           *;
      %*   (3) current Global Library (_cstGRoot)) does not match the _cstGRoot   *;
      %*       value used in the process (CST 1.3)                                *;
      %*                                                                          *;
      %* The report process cannot complete successfully if any of these          *;
      %*  problems is detected.                                                   *;

      %let _cstHasSRoot=0;
      data _null_;
        set &_cstSASRefs (keep=path where=(upcase(path) =: '&STUDYROOTPATH')) end=last;
        if last then
          call symputx('_cstHasSRoot',_n_);
      run;
      %let _cstHasGRoot=0;
      data _null_;
        set &_cstSASRefs (keep=path where=(upcase(path) =: '&_CSTGROOT')) end=last;
        if last then
          call symputx('_cstHasGRoot',_n_);
      run;

      %if &_cstHasSRoot>0 %then
      %do;
        %if %symexist(studyRootPath) %then
        %do;
          %if "&studyRootPath"="" %then
          %do;
            %let _cstSrpError=1;
          %end;
          %else
          %do;
            %if "&studyRootPath" ne "&_cstOldStudyRootPath"  and "&_cstOldStudyRootPath" ne ""  %then
            %do;
              %put;
              %put WARNING: studyRootPath specified in results data set does not match current value of studyRootPath;
              %put WARNING: Library allocations may be invalid or may point to unexpected libraries;
              %put;
              %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=studyRootPath specified in results data set does not match current value of studyRootPath,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
              %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Library allocations may be invalid or may point to unexpected libraries,_cstSeqNoParm=2,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
              %goto exit_macro;
            %end;
          %end;
        %end;
        %else
          %let _cstSrpError=1;
      %end;

      %if &_cstSrpError=1 %then
      %do;
        %put;
        %put WARNING: studyRootPath specified in prior _cstSASRefs but studyRootPath value has not been specified in the current process;
        %put WARNING: Library allocations may be invalid or may point to unexpected libraries;
        %put;
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=studyRootPath specified in prior _cstSASRefs but studyRootPath value has not been specified in the current process,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Library allocations may be invalid or may point to unexpected libraries,_cstSeqNoParm=2,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
        %goto exit_macro;
      %end;

      %if "&_cstGRoot" ne "&_cstOldGLRootPath"  and "&_cstOldGLRootPath" ne ""  %then
      %do;
        %put;
        %put WARNING: Global Library path specified in results data set does not match current value of _cstGRoot;
        %put WARNING: Library allocations may be invalid or may point to unexpected libraries;
        %put;
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Global Library path specified in results data set does not match current value of _cstGRoot,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Library allocations may be invalid or may point to unexpected libraries,_cstSeqNoParm=2,_cstSrcDataParm=CSTUTIL_REPORTSETUP);
        %goto exit_macro;
      %end;

    %end;
  %end;

  %if ^%symexist(_cstSASRefs) %then
  %do;
    %put;
    %put ERROR: The macro variable _cstSASRefs required to support this functionality has not been defined;
    %put ERROR: Has the setup call to cst_setStandardProperties been made?;
    %put;
    %cstutil_writeresult(
               _cstResultID=CST0009
              ,_cstResultParm1=_cstSASRefs
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcDataParm=CSTUTIL_REPORTSETUP
              ,_cstResultFlagParm=1
              ,_cstRCParm=1
              );
    %goto exit_macro;
  %end;
  %if ^%sysfunc(exist(&_cstSASRefs)) %then
  %do;
    %put;
    %put ERROR: The data set &_cstSASRefs required to support this functionality could not be found;
    %put ERROR: Has the setup call to cstutil_allocatesasreferences or cstutil_processsetup been made?;
    %put;
    %cstutil_writeresult(
               _cstResultID=CST0008
              ,_cstResultParm1=&_cstSASRefs
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcDataParm=CSTUTIL_REPORTSETUP
              ,_cstResultFlagParm=1
              ,_cstRCParm=1
              );
    %goto exit_macro;
  %end;

  %* What type of report has been requested?  *;
  %if &_cstRptType=Metadata %then
  %do;
    data _null_;
      attrib _csttemp format=$200.
             _cstrefcntl format=$200.
             _cstStdTitle format=$200.
             _cstStd format=$20.
             _cstStdVer format=$20.;

      retain _csttemp _cstrefcntl _cstStdTitle _cstStd _cstStdVer;

        set &_cstSASRefs (keep=type subtype sasref path memname filetype standard standardversion) end=last;

        select (upcase(type));
          when("CONTROL")
          do;
            if upcase(subtype)="VALIDATION" then
            do;
              call symputx('_cstRptControl',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
              if missing(_cstStdTitle) then
              do;
                _cstStdTitle=catx(' ',strip(standard),strip(standardversion),'Validation Check Metadata');
                call symputx('_cstStandard',strip(standard));
                call symputx('_cstStandardVersion',strip(standardversion));
                call symputx('_cstStdTitle',_cstStdTitle);
              end;
              select(upcase(filetype));
                when('DATASET') call symputx('_cstValDSType','DATA');
                otherwise       call symputx('_cstValDSType',upcase(filetype));
              end;
            end;
          end;
          when("REFERENCECONTROL")
          do;
            if upcase(subtype)="VALIDATION" then
            do;
              * By default, the reference validation_master data set is used and will override any run-time validation_control data set  *;
              call symputx('_cstRptControl',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
              if missing(_cstrefcntl) then
              do;
                _cstrefcntl = catx(' ',strip(standard),strip(standardversion),'Validation Check Metadata');
                _cstStd     = standard;
                _cstStdVer  = standardversion;
              end;
            end;
            if upcase(subtype)="STANDARDREF" then
              call symputx('_cstStdRef',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
          end;
          otherwise 
          do;
            if upcase(type)="REPORT" then
            do;
              * Note use of default report name and format.  *;
              if upcase(subtype)="LIBRARY" then
                call symputx('_cstRptLib',kstrip(path));
              if upcase(subtype)="OUTPUTFILE" then
                call symputx('_cstRptOutputFile',catx('/',kstrip(path),kstrip(memname)));
            end;
            if missing(_csttemp) and upcase(standard) ne 'CST-FRAMEWORK' then
            do;
              _csttemp = catx(' ',strip(standard),strip(standardversion),'Validation Check Metadata');
              _cstStd=standard;
              _cstStdVer=standardversion;
            end;
          end;
        end;
        
        if last then
        do;
          if missing(_cstStdTitle) then
          do;
            if not missing(_cstrefcntl) then
            do;
              call symputx('_cstStandard',_cstStd);
              call symputx('_cstStandardVersion',_cstStdVer);
              call symputx('_cstStdTitle',_cstrefcntl);
            end;
            else if not missing(_csttemp) then
            do;
              call symputx('_cstStandard',_cstStd);
              call symputx('_cstStandardVersion',_cstStdVer);
              call symputx('_cstStdTitle',_csttemp);
            end;
            else
            do;
              call symputx('_cstStandard','CST-FRAMEWORK');
              call symputx('_cstStandardVersion','1.2');
              call symputx('_cstStdTitle','Validation Check Metadata');
            end;
          end;
        end;
      run;


    ******************************************************;
    * Set default values for any missing information     *;
    ******************************************************;

    %let _cstSASrefLib=;
    %cstutil_getsasreference(_cstStandard=&_cstStandard,
                             _cstStandardVersion=&_cstStandardVersion,
                             _cstSASRefType=referencecontrol,
                             _cstSASRefSubtype=validation,
                             _cstSASRefsasref=_cstSASrefLib);
    %let _cstSASmesLib=;
    %cstutil_getsasreference(_cstStandard=&_cstStandard,
                             _cstStandardVersion=&_cstStandardVersion,
                             _cstSASRefType=messages,
                             _cstSASRefsasref=_cstSASmesLib);

    data _null_;
      attrib _csttemp format=$200.
             _cstOK format=8.;

      _cstOK=0;
      _csttemp = symget('_cstRptControl');
      if _csttemp ne '' then _cstOK=1;

      if _cstOK=0 then
      do;
        %if %klength(&_cstSASrefLib)>0 %then
        %do;
          if pathname("&_cstSASrefLib",'L')='' then
            call execute('"libname &_cstSASrefLib &_cstStandardPath/validation/control";');
          call symputx('_cstRptControl',"&_cstSASrefLib..validation_master");
        %end;
      end;

      _cstOK=0;
      _csttemp = symget('_cstStdRef');
      if _csttemp ne '' then _cstOK=1;
      if _cstOK=0 then
      do;
        %if %klength(&_cstSASrefLib)>0 %then
        %do;
          if pathname("&_cstSASrefLib",'L')='' then
            call execute('"libname &_cstSASrefLib &_cstStandardPath/validation/control";');
          call symputx('_cstStdRef',"&_cstSASrefLib..validation_stdref");
        %end;
      end;

      _cstOK=0;
      _csttemp = symget('_cstRptOutputFile');
      if _csttemp ne '' then _cstOK=1;
      if _cstOK=0 then
      do;
        _csttemp = symget('_cstRptLib');
        if _csttemp ne '' then
          call symputx('_cstRptOutputFile',catx('/',kstrip("&_cstRptLib"),'cstcheckmetadatareport.pdf'));
        else
          call symputx('_cstRptOutputFile',catx('/',kstrip("&workPath"),'cstcheckmetadatareport.pdf'));
      end;

      _cstOK=0;
      if symexist("_cstMessages") then
      do;
        _csttemp = symget('_cstMessages');
        if _csttemp ne '' then _cstOK=1;
      end;
      if _cstOK=0 then
      do;
        %if %klength(&_cstSASmesLib)>0 %then
        %do;
          if pathname("&_cstSASmesLib",'L')='' then
            call execute('"libname &_cstSASmesLib &_cstStandardPath/messages";');
          call symputx('_cstMessages',"&_cstSASmesLib..messages");
        %end;
      end;

      _cstOK=0;
      _csttemp = symget('_cstStdTitle');
      if _csttemp ne '' then _cstOK=1;
      if _cstOK=0 then
        call symputx('_cstStdTitle',catx(' ',"&_cstStandard","&_cstStandardVersion",'Validation Check Metadata'));

    run;

  %end;
  %else %if &_cstRptType=Results %then
  %do;
    data _null_;
      attrib _csttemp format=$200.;

        set &_cstSASRefs (keep=type subtype sasref path memname filetype standard standardversion);

        select (upcase(type));
          when("CONTROL")
          do;
            if upcase(subtype)="VALIDATION" then
            do;
              call symputx('_cstRptControl',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
              select(upcase(filetype));
                when('DATASET') call symputx('_cstValDSType','DATA');
                otherwise       call symputx('_cstValDSType',upcase(filetype));
              end;
            end;
          end;
          when("SOURCEMETADATA")
          do;
            if upcase(subtype)="TABLE" then
              call symputx('_cstSrcMetadataDS',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
          end;
/*
          when("REFERENCECONTROL")
          do;
            if upcase(subtype)="STANDARDDOM" then
              call symputx('_cstDomListDS',catx('.',strip(sasref),strip(scan(memname,1,'.'))));
          end;
*/
          when("RESULTS")
          do;
            if upcase(subtype) in ("RESULTS" "VALIDATIONRESULTS") then
            do;
              if symget('_cstRptResultsDS')='' then do;
                _csttemp=catx('.',strip(sasref),strip(scan(memname,1,'.')));
                if exist(_csttemp) then
                  call symputx('_cstRptResultsDS',_csttemp);
              end;
            end;
            else if upcase(subtype) in ("METRICS" "VALIDATIONMETRICS") then
            do;
              if symget('_cstRptMetricsDS')='' then do;
                _csttemp=catx('.',strip(sasref),strip(scan(memname,1,'.')));
                if exist(_csttemp) then
                  call symputx('_cstRptMetricsDS',_csttemp);
              end;
            end;
          end;
          when("REPORT")
          do;
            * Note use of default report name and format.                             *;
            * Note only last values retained if multiple REPORT records are present.  *;
            *  (We have no way of associating specific records with specific reports) *;
            if upcase(subtype)="LIBRARY" then
              call symputx('_cstRptLib',kstrip(path));
            if upcase(subtype)="OUTPUTFILE" then
              call symputx('_cstRptOutputFile',catx('/',kstrip(path),kstrip(memname)));
          end;
          otherwise;
        end;

    run;

    ******************************************************;
    * Set default values for any missing information     *;
    ******************************************************;

    * Do we have sufficient metadata from &_cstSASRefs?  *;
    * If not, use the back-up from the current session.  *;
    data _null_;
      attrib _csttemp format=$200.;

      %if %symexist(_cstRptResultsDS) %then
      %do;
        _csttemp = symget('_cstRptResultsDS');
      %end;
      %else
      %do;
        _csttemp = '';
      %end;
      if _csttemp='' then
        call symput('_cstRptResultsDS',"&_cstResultsDS");

      %if %symexist(_cstRptMetricsDS) %then
      %do;
        _csttemp = symget('_cstRptMetricsDS');
      %end;
      %else
      %do;
        _csttemp = '';
      %end;
      %if %symexist(_cstMetricsDS) %then
      %do;
        if _csttemp='' then
          call symput('_cstRptMetricsDS',"&_cstMetricsDS");
      %end;

      %if %symexist(_cstRptLib) %then
      %do;
        _csttemp = symget('_cstRptLib');
      %end;
      %else
      %do;
        _csttemp = '';
      %end;
      if _csttemp = '' then
        call symputx('_cstRptLib',kstrip("&workPath"));

      %if %symexist(_cstRptOutputFile) %then
      %do;
        _csttemp = symget('_cstRptOutputFile');
      %end;
      %else
      %do;
        _csttemp = '';
      %end;
      if _csttemp = '' then
        call symputx('_cstRptOutputFile',kstrip("&workPath/cstreport.pdf"));

    run;

  %end;

  %exit_macro:
  
%mend cstutil_reportsetup;
