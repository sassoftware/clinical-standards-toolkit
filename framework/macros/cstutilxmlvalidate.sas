%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilxmlvalidate                                                             *;
%*                                                                                *;
%* Performs XML schema-level validation on a supported XML standard file.         *;
%*                                                                                *;
%* General use of this macro is in combination with another macro (such as        *;
%* reading or writing an XML file). If this macro is run independently,           *;
%* either a valid SASReferences data set is required, or the XML file, XML        *;
%* standard and XML standard version need to be specified.                        *;
%* In case the the XML file, XML standard and XML standard version are specified  *;
%* the SASReferences data set will not be used to look up the XML file.           *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar studyOutputPath Study-specific output root path                        *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstSASReferences - required - The SASReferences data set that specifies*;
%*            the location of the XML file to evaluate and that is associated     *;
%*            with a registered standard and standardversion.                     *;
%*            Default: &_cstSASRefs global macro variable value                   *;
%* @param _cstLogLevel - required - The level of error reporting.                 *;
%*            Values: info | warning | error | fatal error                        *;
%*            Default: info                                                       *;
%* @param _cstXMLPath - optional - The complete path to the XML file to be        *;
%*            validated.                                                          *;
%* @param _cstXMLStandard - optional - The standard associated with the XML file. *;
%* @param _cstXMLStandardVersion  - optional - The standard version associated    *;
%*            with the XML file.                                                  *;
%* @param _cstCallingPgm - optional - The name of the driver module calling       *;
%*            this macro.                                                         *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutilxmlvalidate(
    _cstSASReferences=&_cstSASRefs,
    _cstLogLevel=info,
    _cstXMLPath=,
    _cstXMLStandard=,
    _cstXMLStandardVersion=,
    _cstCallingPgm=None or unspecified
    ) / des='CST: XML schema validation';

  %* declare local variables used in the macro;
  %local
    filrf
    rc
    _cstAbort
    _cstAction
    _cstAvailableTransformsPath
    _cstExternalXMLPath
    _cstLogLevelValue
    _cstLogXMLName
    _cstLogXMLPath
    _cstLogXMLScope
    _cstNewProcess
    _cstParamsClass
    _cstParam1
    _cstParam2
    _cstRandom
    _cstrundt
    _cstrunsasref
    _cstSaveSASRefs
    _cstSrcData
    _cstStd
    _cstStdFound
    _cstStdVsn
    _cstSubtypeXML
    _cstTempDS
    _cstTempFilename1
    _cstTempLib
    _cstThisMacro
    _cstThisMacroRC
    _cstThisMacroRCMsg
    _cstTransformsClass
    _cstTypeExtXML
    _cstWorkPath
    _cstXMLEngine
    _cstXsdReposPath
    _cstUseSASReferences
    ;

  %let _cstAbort=0;
  %let _cstResultSeq=1;
  %let _cstrunsasref=Unspecified;
  %let _cstSaveSASRefs=&_cstSASRefs;
  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstStdFound=0;
  %let _cstThisMacroRC=0;
  %let _cstThisMacro=&sysmacroname;

  %* If we have a prior failure in the job stream (typically validating the SASReferences)  *;
  %*  bail out here and report what we are doing.                                           *;
  %if (&_cst_rc) %then %do;
    %let _cstAbort=1;
    %goto EXIT_ABORT;
  %end;

  %* Create a temporary messages data set if required;
  %local _cstNeedToDeleteMsgs;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Check to see if we need to use a SASReferences dataset *;
  %if %sysevalf(%superq(_cstXMLPath)=, boolean) or
      %sysevalf(%superq(_cstXMLStandard)=, boolean) or
      %sysevalf(%superq(_cstXMLStandardVersion)=, boolean) %then 
  %do;
    %let _cstUseSASReferences=1;
    %if &_cstSASRefs ne &_cstSASReferences %then
      %let _cstSASRefs=&_cstSASReferences;
  %end;
  %else 
  %do;
    %let _cstUseSASReferences=0;
    
    %let filrf=myfile;
    %let rc=%sysfunc(filename(filrf, &_cstXMLPath));
    %if &rc ne 0 %then %put %sysfunc(sysmsg());
    %let _cstExternalXMLPath=%sysfunc(pathname(myfile));
    %let rc=%sysfunc(filename(filrf));  
    
    %let _cstStd=&_cstXMLStandard;
    %let _cstStdVsn=&_cstXMLStandardVersion;
    
    %if not %sysfunc(fileexist(&_cstExternalXMLPath)) %then
    %do;
       %let _cstParam1=&_cstExternalXMLPath;
       %let _cst_rcmsg=&_cstParam1 could not be found;
       %goto MISSING_FILE;
    %end;
    
  %end;

  data _null_;
    if kupcase("&_cstLogLevel") in ("INFO", "ERROR" , "WARNING", "FATAL ERROR") then
      call symput('_cstLogLevelValue',"&_cstLogLevel");
    else call symput('_cstLogLevelValue',"INFO");
    
    call symputx('_cstWorkPath',pathname('work'),'L');
    call symputx('_cstrundt',put(datetime(),is8601dt.));
  run;

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstLogXMLName=_log&_cstRandom;

  %* Determine XML engine;
  %let _cstXMLEngine=xml;
  %if %eval(&SYSVER EQ 9.2) %then %let _cstXMLEngine=xml92;
  %if %eval(&SYSVER GE 9.3) %then %let _cstXMLEngine=xmlv2;

  %* Determine XML Log Scope;
  %if &_cstDebug %then %let _cstLogXMLScope=_ALL_;
                 %else %let _cstLogXMLScope=USER;

  %if &_cstUseSASReferences %then %do;
    %* The SASReferences data set must exist;
    %if (^(%sysfunc(exist(&_cstSASReferences)))) %then %do;
       %let _cstParam1=The SASReferences data set (&_cstSASReferences);
       %let _cst_rcmsg=&_cstParam1 could not be found;
       %goto MISSING_DATASET;
    %end;

    %* These static variables provide the default type and subtype associated  *;
    %*  with the SASReferences reference to the to-be-validated XML file.      *;
    %cst_getStatic(_cstName=XML_SASREF_TYPE_EXTXML,_cstVar=_cstTypeExtXML);
    %cst_getStatic(_cstName=XML_SASREF_SUBTYPE_XML,_cstVar=_cstSubtypeXML);
  
    *********************************************************************************;
    * The following macro variables are derived from the SASReferences data set:    *;
    *   _cstExternalXMLPath - full path to the XML file to-be-validated             *;
    *   _cstStd - standard associated with XML file                                 *;
    *   _cstStdVsn - standardversion associated with XML file                       *;
    *********************************************************************************;
    
    data _null_;
      set &_cstSASReferences;
  
      attrib xmlpath format=$2000. label='Temporary variable string';
  
      if kupcase(type)=kupcase("&_cstTypeExtXML") and kupcase(subtype)=kupcase("&_cstSubtypeXML") then
      do;
        xmlpath=ktranslate(pathname(SASRef),'/','\');
        call symputx('_cstExternalXMLPath',xmlpath);
        call symputx('_cstStd',standard);
        call symputx('_cstStdVsn',standardversion);
        * xmlpath may be missing if the SASRef has not been allocated in this session *;
        if missing(xmlpath) then
        do;
          xmlpath=ktranslate(catx('/',path,memname),'/','\');
          call symputx('_cstExternalXMLPath',xmlpath);
        end;
      end;
    run;
  
    %* The SASReferences lookup encountered a problem: report and exit  *;
  
  ****Use correct k function here********************;
    %if %length(&_cstExternalXMLPath)=0 %then
    %do;
       %let _cstParam1=&_cstTypeExtXml/&_cstSubtypeXML;
       %let _cstParam2=this XML validation process;
       %let _cst_rcmsg=The type/subtype &_cstParam1 is not defined for &_cstParam2;
       %goto MISSING_SASREF;
    %end;
    %else %if (&_cstDebug=1) %then %do;
      %put XML file to validate from the SASReferences file: &_cstExternalXMLPath;
    %end;
  
    %if %sysfunc(kindexc(&_cstSASReferences,'.')) %then
    %do;
      %let _cstTempLib=%SYSFUNC(kscan(&_cstSASReferences,1,'.'));
      %let _cstTempDS=%SYSFUNC(kscan(&_cstSASReferences,2,'.'));
    %end;
    %else
    %do;
      %let _cstTempLib=work;
      %let _cstTempDS=&_cstSASReferences;
    %end;
    %let _cstrunsasref=%sysfunc(pathname(&_cstTempLib))/&_cstTempDS..sas7bdat;

  %end;
  

  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);
  data _null_;
    set work._cstStandards;
    * Confirm standard and standardversion are registered.                         *;
    *  This is necessary to do the proper availabletransforms schema lookup below. *;
    if kupcase(standard)=kupcase("&_cstStd") and kupcase(standardversion)=kupcase("&_cstStdVsn") then
      call symputx('_cstStdFound',1);
  run;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstStandards);
  
  %* Standard/standardversion associated with XML file is not registered *;
  %if &_cstStdFound=0 %then
  %do;
     %let _cstParam1=&_cstStdVsn;
     %let _cstParam2=&_cstStd;
     %let _cst_rcmsg=The version &_cstParam1 does not exist for &_cstParam2;
     %goto UNKNOWN_STD;
  %end;


  %**************************************************************************;
  %* All parameters and inputs OK, so proceed with reporting and validation *;
  %**************************************************************************;
  
  %* Check to see if the current results data set contains metadata about the current process;
  %* If so, this is a continuation of the process and the following metadata need not be     ;
  %*  written to the results data set.                                                       ;
  %let _cstNewProcess=1;
  %if (%sysfunc(exist(&_cstResultsDS))) %then
  %do;
    data _null_;
      attrib tempvar format=$200.;
      set &_cstResultsDS (where=(checkid='' and substr(message,1,7)="PROCESS")) end=last;
      tempvar=catx(': ',"PROCESS STANDARD","&_cstStd");
      if message =: tempvar then
        call symputx('_cstNewProcess',0);
    run;
  %end;

  %if (&_cstNewProcess) %then
  %do;
    %*************************************************************;
    %* Write information to the results data set about this run. *;
    %*************************************************************;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstStd,_cstSeqNoParm=1,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStdVsn,_cstSeqNoParm=2,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: &_cstCallingPgm,_cstSeqNoParm=3,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: XMLVALIDATE &_cstStd ,_cstSeqNoParm=5,_cstSrcDataParm=&_cstThisMacro);
    %if %length(&_cstrunsasref) < 1 %then
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: <not used>,_cstSeqNoParm=6,_cstSrcDataParm=&_cstThisMacro);
    %else
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstThisMacro);
    %if %symexist(studyRootPath) %then
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
    %else
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstThisMacro);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstThisMacro);
    %let _cstSeqCnt=9;
  %end;
  %else
  %do;
    %let _cstSeqCnt=1;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Starting XML Validation,_cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstThisMacro);
  %end;

  %* set up static-final style variables;
  %let _cstAction=EXPORT;
  %let _cstXsdReposPath=&_cstGRoot/schema-repository;
  %let _cstParamsClass=com/sas/ptc/transform/xml/StandardXMLTransformerParams;
  %let _cstTransformsClass=com/sas/ptc/transform/xml/StandardXMLExporter;
  %let _cstLogXMLPath=&_cstWorkPath./&_cstLogXMLName._xmlvalidate.xml;
  %let _cstAvailableTransformsPath=&_cstgroot/metadata/availabletransforms.xml;

  %* Print out debugging information;
  %if (&_cstDebug=1) %then %do;
    %put Note: Calling java with parameters:;
    %put       _cstParamsClass=&_cstParamsClass;
    %put       _cstTransformsClass=&_cstTransformsClass;
    %put       _cstAction=&_cstAction;
    %put       _cstStandard=&_cstStd;
    %put       _cstStandardVersion=&_cstStdVsn;
    %put       _cstXsdReposPath=&_cstXsdReposPath;
    %put       _cstExternalXMLPath=&_cstExternalXMLPath;
    %put       _cstAvailableTransformsPath=&_cstAvailableTransformsPath;
    %put       _cstLogXMLPath=&_cstLogXMLPath;
  %end;


  %* In the following, the logging level is set to info as the transform creates
     an empty XML doc if nothing is reported, which causes an error in the SAS libname;
  data _null_;

    dcl javaobj prefs("&_cstParamsClass");
    prefs.callvoidmethod('setImportOrExport',"&_cstAction");
    prefs.callvoidmethod('setStandardName',"&_cstStd");
    prefs.callvoidmethod('setStandardVersion',"&_cstStdVsn");
    prefs.callvoidmethod('setValidatingStandardXMLString', "true");
    prefs.callvoidmethod('setValidatingXMLOnlyString', "true");
    prefs.callvoidmethod('setStandardXMLPath', "&_cstExternalXMLPath");
    prefs.callvoidmethod('setSchemaBasePath',"&_cstXsdReposPath");
    prefs.callvoidmethod('setAvailableTransformsFilePath',"&_cstAvailableTransformsPath");
    prefs.callvoidmethod('setLogFilePath',"&_cstLogXMLPath");
    prefs.callvoidmethod('setLogLevelString',"&_cstLogLevelValue");

    dcl javaobj transformer("&_cstTransformsClass", prefs);
    transformer.exceptiondescribe(1);
    transformer.callvoidmethod('exec');

    * check the return values here and get results path;
    transformer.delete();
    prefs.delete();
  run;

  %* check to see if there are any Java issues;
  %cstutilcheckjava;
  %if (&_cstResultFlag) %then %do;
    %goto JAVA_ERRORS;
  %end;

  %* Process the XML LOG File;
  %cstutilprocessxmllog(
    _cstReturn=_cstThisMacroRC,
    _cstReturnMsg=_cstThisMacroRCMsg,
    _cstLogXMLPath=&_cstLogXMLPath,
    _cstScope=&_cstLogXMLScope
   ); 

  %* Cleanup XML Log File;
  %if &_cstDebug=0 %then %do;
    data _null_;
      rc=filename("&_cstLogXMLName","&_cstLogXMLPath");
      rc=fdelete("&_cstLogXMLName");
      rc=filename("&_cstLogXMLName");
    run;
  %end;

  %* Handle any errors generated during the java code;
  %if (&_cstThisMacroRC) %then %do;
    %goto GENERATION_ERRORS;
  %end;

  %* Everything was OK so report it;
  %let _cstParam1=the XML file;
  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0100
                ,_cstResultParm1=&_cstParam1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );

  %goto CLEANUP;


%MISSING_FILE:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=&_cstParam1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%MISSING_DATASET:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=&_cstParam1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%MISSING_SASREF:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0087
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%UNKNOWN_STD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%GENERATION_ERRORS:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0190
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%JAVA_ERRORS:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0202
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultParm1=PROCESS HALTED
                );
  %goto CLEANUP;

%CLEANUP:


  %* Persist the results if specified in sasreferences  *;
   %if %symexist(_cstStandard) %then
   %do;
****Use correct k function here********************;
     %if %klength(&_cstStandard)>0 %then
     %do;
       %cstutil_saveresults();
     %end;
   %end;

  %* Delete the temporary messages data set if it was created here;
  %if (&_cstNeedToDeleteMsgs=1) %then %do;
    %if %eval(%index(&_cstMessages,.)>0) %then %do;
      %let _cstTempLib=%kscan(&_cstMessages,1,.);
      %let _cstTempDS=%kscan(&_cstMessages,2,.);
    %end;
    %else %do;
      %let _cstTempLib=work;
      %let _cstTempDS=&_cstMessages;
    %end;
    %cstutil_deleteDataSet(_cstDataSetName=&_cstTempLib..&_cstTempDS);
  %end;

%EXIT_ABORT:

  %if (&_cstAbort) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0190
                ,_cstResultParm1=a predecessor method - processing was aborted
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %end;

  %let _cst_rc=&_cstThisMacroRC;

  %let _cstSASRefs=&_cstSaveSASRefs;


  %if %length(&_cst_rcmsg)>0 %then
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&_cstThisMacro] &_cst_rcmsg;

%mend cstutilxmlvalidate;
