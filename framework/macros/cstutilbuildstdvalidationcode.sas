%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilbuildstdvalidationcode                                                  *;
%*                                                                                *;
%* Generates the validation-specific macro _cstreadStds to build the workflow.    *;
%*                                                                                *;
%* This macro is called in the internal validation driver programs. This macro    *;
%* generates the validation-specific macro _cstreadStds to build a job stream for *;
%* all registered standards that are passed to cstutilbuildstdvalidationcode() in *;
%* the data set that is specified in _cstStdDS.                                   *;
%*                                                                                *;
%* NOTE: An external filename INCCODE statement is required before invoking this  *;
%*       macro. For example:                                                      *;
%*           filename incCode CATALOG "work._cstCode.stds.source" &_cstLRECL      *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%*                                                                                *;
%* @param _cstStdDS - optional - The set of standards to validate, using the      *;
%*            the structure of the <global standards library>/standards/          *;
%*            cst-framework-1.5/templates/standards                               *;
%*            data set.                                                           *;
%*            Default: work._cstStandardsforIV                                    *;
%* @param _cstSampleRootPath - optional - The root path to a study-specific       *;
%*            location that contains study files. To valide multiple standards,   *;
%*            this path must be generic (valid) across those standards. If this   *;
%*            path is unique to each standard, this macro must be called for each *;
%*            standard, and _cstStdDS must contain only the one record for that   *;
%*            standard.                                                           *;
%*            To use the studylibraryrootpath folder hierarchy convention, as     *;
%*            defined in the <global standards library>/metadata standards data   *;
%*            set, specify the value _DEFAULT_. If this parameter is specified,   *;
%*            specify non-null values for _cstSampleSASRefDSPath and              *;
%*            _cstSampleSASRefDSName. If either  _cstSampleSASRefDSPath or        *;
%*            _cstSampleSASRefDSName is specified, _cstSampleRootPath must be     *;
%*            non-null.                                                           *;
%* @param _cstSampleSASRefDSPath - optional - The path to a study-specific        *;
%*            location that contains the SASReferences data set to use. If this   *;
%*            parameter is specified, specify the value of either _DEFAULT_ or the*;
%*            full path to the data set (excluding the name of the file). If the  *;
%*            SASReferences data set is created in this macro, you can specify the*;
%*            value &workpath.                                                    *;
%*            To validate multiple standards, this path must be generic (valid)   *;
%*            across those standards. If this path is unique to each standard,    *;
%*            this macro must be called for each standard, and _cstStdDS must     *;
%*            contain only the one record for that standard.                      *;
%*            To use the studylibraryrootpath/control folder hierarchy convention *;
%*            that is used with the cstSampleLibrary, specify the value _DEFAULT_.*;
%* @param _cstSampleSASRefDSName - optional - The name of the SASReferences data  *;
%*            set within _cstSampleSASRefDSPath. The rules that apply to          *;
%*            _cstSampleSASRefDSPath apply to this parameter, too.                *;
%*            To use stdvalidation_sasrefs.sas7bdat that is used with the         *;
%*            cstSampleLibrary, specify the value _DEFAULT_.                      *;
%* @param _cstCallingDriver - optional - The name of the driver module calling    *;
%*            this macro.                                                         *;
%*                                                                                *;
%* @history 2013-11-15 Abort with any prior fatal error (1.6)                     *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilbuildstdvalidationcode(
    _cstStdDS=work._cstStandardsforIV,
    _cstSampleRootPath=,
    _cstSampleSASRefDSPath=,
    _cstSampleSASRefDSName=,
    _cstCallingDriver=Unspecified
    ) / des='CST: Generate Internal Validation Code';

  %local
    _cstexit_error
    _defaultcstSASRefs
  ;

  %let _cstactual=;
  %let _cstResultFlag=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _defaultcstSASRefs=&_cstSASRefs;

  %* Abort if we have encountered a prior fatal error *;
  %if &_cst_rc>0 %then
  %do;
    %let _cst_MsgID=CST0200;
    %let _cst_MsgParm1=Exiting %upcase(&sysmacroname) prematurely;
    %let _cstResultFlag=1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if %klength(&_cstStdDS)<1 %then
  %do;
    %**************************************************************;
    %* Assume default of running against all registered standards *;
    %**************************************************************;
    %cst_getRegisteredStandards(_cstOutputDS=work._cstStandardsforIV);
    %let _cstStdDS=&_cstOutputDS;
  %end;

  %if %klength(&_cstSampleRootPath)>0 and (%klength(&_cstSampleSASRefDSPath)<1 or %klength(&_cstSampleSASRefDSName)<1) %then
  %do;
    %let _cst_MsgID=CST0005;
    %let _cst_MsgParm1=cstutilbuildstdvalidationcode;
    %let _cstResultFlag=1;
    %let _cstactual=%str(_cstSampleRootPath=&_cstSampleRootPath,_cstSampleSASRefDSPath=&_cstSampleSASRefDSPath,_cstSampleSASRefDSName=&_cstSampleSASRefDSName);
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %else %if %klength(&_cstSampleSASRefDSPath)>0 and (%klength(&_cstSampleRootPath)=0 or %klength(&_cstSampleSASRefDSName)=0) %then
  %do;
    %let _cst_MsgID=CST0005;
    %let _cst_MsgParm1=cstutilbuildstdvalidationcode;
    %let _cstResultFlag=1;
    %let _cstactual=%str(_cstSampleRootPath=&_cstSampleRootPath,_cstSampleSASRefDSPath=&_cstSampleSASRefDSPath,_cstSampleSASRefDSName=&_cstSampleSASRefDSName);
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %else %if %klength(&_cstSampleSASRefDSName)>0 and (%klength(&_cstSampleRootPath)=0 or %klength(&_cstSampleSASRefDSPath)=0) %then
  %do;
    %let _cst_MsgID=CST0005;
    %let _cst_MsgParm1=cstutilbuildstdvalidationcode;
    %let _cstResultFlag=1;
    %let _cstactual=%str(_cstSampleRootPath=&_cstSampleRootPath,_cstSampleSASRefDSPath=&_cstSampleSASRefDSPath,_cstSampleSASRefDSName=&_cstSampleSASRefDSName);
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    set &_cstStdDS end=last;

      attrib tempref  format=$200.
             tempref2 format=$200.
             tempvar  format=$200.
             tempvar2 format=$200.;

    file incCode;

    if _n_=1 then do;
      put '%macro _cstreadStds;';
      put;
      put @3 '%let _cstStdRefsVar=;';
      put @3 '%cst_getStatic(_cstName=CST_DSTYPE_STANDARDSASREFS,_cstVar=_cstStdRefsVar);';
      put @3 '%let save_cstSASRefs=&_cstSASRefs;';
      put @3 '%let workPath=%sysfunc(pathname(work));';
      put;
      put @3 '* Initialize cumulative SASReferences data set (for debugging and documentation);';
      put @3 'data work._cstALLSASRefs;';
      put @5 'set &_cstSASRefs;';
      put @3 'run;';
      put;
      put @3 'proc optSave out=work._cstivsessionoptions;';
      put @3 'run;';
      put;
    end;

    tempvar=catx(' ','Validating',standard,standardversion);
    tempvar=catx(' ','%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS WORKFLOW:',tempvar,',_cstSeqNoParm=0,_cstSrcDataParm=',standard,standardversion,')');
    put @3 tempvar;
    tempvar=catx(' ','* Starting',standard,standardversion,'  *;');
    tempvar2=cats(repeat('*',length(tempvar)-2),';');
    put @3 tempvar2;
    put @3 tempvar;
    put @3 tempvar2;
    put;

    put @3 '%let _cst_rc=0;';
    tempvar=cats('%let _cstValidationStd=',standard,';');
    put @3 tempvar;
    tempvar=cats('%let _cstValidationStdVer=',standardversion,';');
    put @3 tempvar;
    put;
    tempref=catx('/',rootpath,'control');
    tempvar=cats('libname gl_cntl "',kstrip(tempref),'";');
    put @3 tempvar;

    %if %klength(&_cstSampleRootPath)>0 %then
    %do;
      %****************************************************************;
      %* This signals the intended validation of study-level metadata *;
      %****************************************************************;
      %if %upcase("&_cstSampleRootPath")="_DEFAULT_" %then
      %do;
        if studylibraryrootpath ne '' then
        do;
          tempvar=cats('%let studyRootPath=',studylibraryrootpath,';');
          put @3 tempvar;
          tempvar=cats('%let studyOutputPath=',studylibraryrootpath,';');
          put @3 tempvar;
        end;
      %end;
      %else
      %do;
        put @3 '%let studyRootPath=&_cstSampleRootPath;';
        put @3 '%let studyOutputPath=&_cstSampleRootPath;';
      %end;

      %if %klength(&_cstSampleSASRefDSPath)>0 %then
      %do;
        %if %upcase("&_cstSampleSASRefDSPath")="_DEFAULT_" %then
        %do;
          if studylibraryrootpath ne '' then
          do;
            tempref2=catx('/',studylibraryrootpath,'control');
            tempvar=cats('libname sl_cntl "','&studyRootPath/control";');
            put @3 tempvar;
            put;
          end;
        %end;
        %else
        %do;
          tempref2="&_cstSampleSASRefDSPath";
          tempvar=cats('libname sl_cntl "',"&_cstSampleSASRefDSPath",'";');
          put @3 tempvar;
          put;
        %end;

      %end;
    %end;

    put @3 '%*Initialize SASReferences to include framework messages *;';
    put @3 '%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=control,_cstSubType=reference,_cstOutputDS=work._cstTempStdSASRefDS);';
    put @3 'proc sql;';
    put @5 'insert into work._cstTempStdSASRefDS';
    put @7 'values ("CST-FRAMEWORK" "1.2" "messages" "" "cstmsg" "libref" "input" "dataset" "N" "rootpath" "messages" 1 "messages" "");';
    put @3 'quit;';
    put;

    put @3 '%let _cstFoundStd=;';
    put @3 '%* Go find Global Library standardSASReferences data set for this standard;';
    put @3 '%cstutilfindvalidfile(_cstfiletype=DATASET,_cstfileref=gl_cntl.&_cstStdRefsVar);';
    put @3 '%cstutilcheckforproblem(_cstRsltID=CST0200,_cstType=STD);';
    put;

    put @3 '%if &_cstFoundStd=Y %then %do;';
    put @5 '%let _cstReallocateSASRefs=1;';
    put @5 '%include "&_cstGRoot/standards/cst-framework-&_cstVersion/programs/resetautocallpath.sas";';
    put;
    put @5 '%* Add framework messages to SASReferences data set if not present *;';
    put @5 'data work._cstTempStdSASRefDS;';
    put @7 'update gl_cntl.&_cstStdRefsVar work._cstTempStdSASRefDS;';
    put @9 'by standard standardversion type subtype sasref;';
    put @5 'run;';
    tempvar=cats('%cstutil_processsetup(_cstSASReferencesSource=STANDARDSASREFERENCES,_cstSASReferencesLocation=&workpath,_cstSASReferencesName=_cstTempStdSASRefDS);');
    put @5 tempvar;
    put @5 'data work._cstTempSASRefDS;';
    put @7 'set work.stdvalidation_sasrefs';
    put @7 '    &_cstSASRefs (in=new);';
    put @11 '* Standard-specific standard sasreferences:   *;';
    put @11 "if new then _srcfile='STD';";
    put @5 'run;';
    put @5 '%if &_cst_rc < 1 %then %do;';

    %if %klength(&_cstSampleSASRefDSName)>0 %then
    %do;
      put @7 '%let _cstFoundSample=;';
      put @7 '%* Go find Sample Library validation SASReferences data set for this standard;';
      %if %upcase(&_cstSampleSASRefDSName)=_DEFAULT_ %then
      %do;
        %let _cstSampleSASRefDSName=stdvalidation_sasrefs;
      %end;
      tempvar=cats('%cstutilfindvalidfile(_cstfiletype=DATASET,_cstfileref=sl_cntl.',"&_cstSampleSASRefDSName",');');
      put @7 tempvar;
      put @7 '%cstutilcheckforproblem(_cstRsltID=CST0200,_cstType=SAMPLE);';
      put;
    %end;

    put @7 '%if &_cstFoundSample=Y %then %do;';
    put @9 '%let _cstReallocateSASRefs=1;';
    put @9 '%include "&_cstGRoot/standards/cst-framework-&_cstVersion/programs/resetautocallpath.sas";';
    tempvar=cats('%cstutil_processsetup(_cstSASReferencesLocation=',tempref2,',_cstSASReferencesName=',"&_cstSampleSASRefDSName",');');
    put @9 tempvar;
    put @9 'data work._cstTempSASRefDS;';
    put @11 'set work._cstTempSASRefDS';
    put @11 '    &_cstSASRefs (in=new);';
    put @13 '* Standard-specific study sasreferences:   ;';
    put @13 "if new then _srcfile='STUDY';";
    put @9 'run;';
    put @9 'data work._cstALLSASRefs;';
    put @11 'set work._cstALLSASRefs';
    put @11 '    &_cstSASRefs';
    tempvar=cats('(where=(standard = "',standard,'" and standardversion = "',standardVersion,'"));');
    put @13 tempvar;
    put @9 'run;';
    put @9 '%if &_cst_rc < 1 %then %do;';
%if (&_cstDebug) %then %do;
  put @1 'data work.savebeforenodupkey; set work._cstTempSASRefDS; run;';
%end;
    put @11 'proc sort data=work._cstTempSASRefDS nodupkey;';
    put @13 'by standard standardversion type subtype;';
    put @11 'run;';
    put @9 '%end;';
    put @7 '%end;';
    put @7 '%else %do;';
%if (&_cstDebug) %then %do;
  put @1 'data work.savebeforenodupkey; set work._cstTempSASRefDS; run;';
%end;
    put @9 'proc sort data=work._cstTempSASRefDS nodupkey;';
    put @11 'by standard standardversion type subtype;';
    put @9 'run;';
    put @7 '%end;';
    put;
    put @7 '%* Now dynamically build table and column metadata for all data sets defined in the combined SASReferences data set;';
    put @7 '%let _cstStandard=CST-FRAMEWORK;';
    put @7 '%let _cstStandardVersion=1.2;';
    put @7 '%cstutilbuildmetadatafromsasrefs(cstSRefsDS=work._cstTempSASRefDS,cstSrcTabDS=work.source_tables,cstSrcColDS=work.source_columns);';

    put @7 '%*Reset _cstSASRefs to be combined SASReferences from all sources  *;';
    put @7 '%let _cstSASRefs=work._cstTempSASRefDS;';

    put @7 'data _null_;';
    tempvar=cats('call symput("studyOutputPath",cats("','&_cstSRoot","/cst-framework-&_cstVersion"));');
    put @9 tempvar;
    tempvar=cats('call symput("studyRootPath",cats("','&_cstSRoot","/cst-framework-&_cstVersion"));');
    put @9 tempvar;
    put @7 'run;';


%if %klength(&_cstCallingDriver)<1 %then
%do;
    if not last then
    do;
      put @7 '%cstvalidate(_cstReportOverride=Y);';
    end;
    else
    do;
      put @7 '%cstvalidate;';
    end;
%end;
%else
%do;
    if not last then
    do;
      tempvar=cats('%cstvalidate(_cstCallingPgm=',"&_cstCallingDriver",',_cstReportOverride=Y);');
    end;
    else
    do;
      tempvar=cats('%cstvalidate(_cstCallingPgm=',"&_cstCallingDriver",');');
    end;
    put @7 tempvar;
%end;

    put @5 '%end;';
    put @3 '%end;';
    put;
    put @3 'libname gl_cntl;';
    if studylibraryrootpath ne '' then
      put @3 'libname sl_cntl;';
    put;
    if not last then
    do;
      put @3 '* Reset options to those at the beginning of the IV session;';
      put @3 'data work._cstsessionoptions;';
      put @5 'set work._cstivsessionoptions;';
      put @3 'run;';
      put @3 '* Deallocate standard-specific librefs and filerefs and reset fmtsearch path;';
      tempvar=cats('%cstutil_cleanupcstsession(_cstClearLibRefs=1,_cstResetFmtSearch=1,_cstDeleteFiles=0,_cstStd=',standard,',_cstStdVer=',standardversion,');');
      put @3 tempvar;
    end;
    put @3 '%let _cstSASRefs=work._cstSASRefs;';

%if (&_cstDebug) %then %do;
  put @1 'data work.SAVED_cstTempSASRefDS; set work._cstTempSASRefDS; run;';
  put @1 'data work.SAVED_cstSASRefs; set work._cstSASRefs; run;';
%end;

    if upcase(standard) ne 'CST-FRAMEWORK' then
    do;
      put @3 'data work._cstTempSASRefDS;';
      put @5 'set work._cstTempSASRefDS';
      tempvar=cats('(where=(standard ne "',standard,'" and standardversion ne "',standardVersion,'"));');
      put @10 tempvar;
      put @3 'run;';
    end;
    put;

    if last then
    do;
      put '%mend;';
      put '%_cstreadStds;';
    end;

  run;

%exit_error:

  %if &_cstexit_error %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=%upcase(&sysmacroname)
                  ,_cstResultFlagParm=&_cstResultFlag
                  ,_cstRCParm=1
                  ,_cstActualParm=%str(&_cstactual)
                  );

  %end;

%mend cstutilbuildstdvalidationcode;
