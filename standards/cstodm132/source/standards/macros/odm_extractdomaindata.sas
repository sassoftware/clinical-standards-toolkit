%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* odm_extractdomaindata                                                          *;
%*                                                                                *;
%* Extract a SAS data set from the SAS representation of CDISC-ODM.               *;
%*                                                                                *;
%* This macro extracts clinical data from ODM XML to serve as source data for     *;
%* transformations that derive SDTM domain data sets. This macro builds a table   *;
%* shell (0 observations) from ODM metadata (FormDef, ItemGroupDef and ItemDef)   *;
%* and populates (with each call) a single data set from the ClinicalData or      *;
%* ReferenceData sections of an ODM file.                                         *;
%* In case _cstOnlyTemplates has the value Yes, onlt table shells will be created *;
%* without data set keys (__StudyOID, __MetaDataVersionOID, __SubjectKey, etc.)   *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The original source ODM XML file contains sufficient metadata and content *;
%*      to extract clinical and reference data.                                   *;
%*   2. A full SAS representation of the ODM file is available. (For example,     *;
%*      odm_read has been run against the XML file.)                              *;
%*                                                                                *;
%* Limitations:                                                                   *;
%*   1. The scope is limited to processing a single XML file. (For example, use   *;
%*      of PriorFileOID to reference another file is not permitted.)              *;
%*   2. A full MetaDataVersion section must be provided.                          *;
%*   3. This implementation does not support reference to multiple                *;
%*      MetaDataVersions within the files(s) to be extracted.                     *;
%*   4. ODM.FileType should equal Snapshot, thereby supporting only               *;
%*      TransactionType values of "Insert".                                       *;
%*   5. Any annotations, audit records, and signatures associated with the        *;
%*      extracted data are not processed.                                         *;
%*   6. Custom extensions to the XML file are excluded.                           *;
%*   7. MeasurementUnit information associated with specific columns and values   *;
%*      is ignored.                                                               *;
%*                                                                                *;
%* This macro sets the _cst_rc and _cst_rcmsg global macro variables to indicate  *;
%* that there were issues (_cst_rc ne 0).                                         *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstSourceMetadata - optional - The SAS libref for the SAS ODM          *;
%*            metadata representation. If this parameter is not specified, the    *;
%*            code looks in the SASReferences data set for type=sourcedata. If    *;
%*            this is not specified, the data set or data sets source is assumed  *;
%*            to be WORK.                                                         *;
%* @param _cstSourceData - optional - The SAS libref for the SAS ODM              *;
%*            representation (data). If this parameter is not specified, the code *;
%*            looks in the SASReferences data set for type=sourcedata. If this is *;
%*            not specified, the data set(s) source is be assumed to be WORK.     *;
%* @param _cstIsReferenceData - optional - The extracted data is ReferenceData.   *;
%*            If this parameter is not provided, No is assumed.                   *;
%*            Values: Yes | No                                                    *;
%*            Default:  No                                                        *;
%* @param _cstSelectAttribute - optional - The ItemGroup attribute that identifies*;
%*            the ItemGroup to extract.                                           *;
%*            If this parameter is not specified, Name is assumed.                *;
%*            Values: OID | Name | SASDatasetName | Domain                        *;
%*            Default:  Name                                                      *;
%* @param _cstSelectAttributeValue - required - The value of _cstSelectAttribute  *;
%*            that identifies the ItemGroup to extract.                           *;
%*            This value is case insensitive.                                     *;
%* @param _cstLang - optional - The language tag to use for associated            *;
%*            TranslatedText.                                                     *;
%*            Default: en                                                         *;
%* @param _cstMaxLabelLength - optional - The maximum number of labels to create. *;
%*            If this parameter is not specified, 256 is assumed.                 *;
%*            Default: 256                                                        *;
%* @param _cstAttachFormats - optional - Attach formats to data.                  *;
%*            If this parameter is not specified, Yes is assumed.                 *;
%*            Values: Yes | No                                                    *;
%*            Default:  Yes                                                       *;
%* @param _cstODMMinimumKeyset - optional - Limit the creation of data set keys.  *;
%*            If this parameter is not specified, No is assumed.                  *;
%*            Values: Yes | No                                                    *;
%*            Default:  No                                                        *;
%* @param _cstOutputLibrary - optional - The SAS libref in which the extracted    *;
%*            data set or data sets are written. If this parameter is not         *;
%*            specified, the code looks in the SASReferences data set for         *;
%*            type=targetdata. If this is not specified, the data set or data     *;
%*            data set are written to WORK.                                       *;
%* @param _cstOutputDS - required - The name of the extracted data set. If this   *;
%*            value is an invalid SAS data set name, an error is generated.       *;
%* @param _cstOnlyTemplates - optional - Only create 0-observation data set       *;
%*            templates If this parameter is not specified, No is assumed.        *;
%*            In case of templates, no data set keys will be created.             *;
%*            Values: Yes | No                                                    *;
%*            Default:  No                                                        *;
%*                                                                                *;
%* @history 2014-04-30  Added _cstOnlyTemplates parameter                         *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro odm_extractdomaindata(
  _cstSourceMetadata=,
  _cstSourceData=,
  _cstIsReferenceData=No,
  _cstSelectAttribute=Name,
  _cstSelectAttributeValue=,
  _cstLang=en,
  _cstMaxLabelLength=256,
  _cstAttachFormats=Yes,
  _cstODMMinimumKeyset=No,
  _cstOutputLibrary=,
  _cstOutputDS=,
  _cstOnlyTemplates=No
  ) / des='CST: Extract SAS data set from CDISC-ODM';


  %local
    _cstSaveOptions
    _cstErrorFlag
    _cstCounter
    _cstList
    _cstListItem
    _cstIGCount
    _cstIGOIDs
    _cst_MsgID
    _cstRecordCount
    _cstSrcDataLibrary
    _cstSrcMetaDataLibrary
    _cstTypeSourceData
    _cstTableLabel
    _cstTempLib
    _cstTempDS
    _cstTrgDataLibrary
    _cstTrgDS
    _cstrundt
    _cstrunsasref
    _cstrunstd
    _cstrunstdver
    _cstItemGroup
    _cstItemGroupKeep
    _cstItemGroupVar
    _cstODMFileType
    _cstNobs
    _cstThisMacroRC
    _cstThisMacroRCMsg

  ;

  %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] *** START *** ;

  %let _cstSaveOptions=%sysfunc(getoption(fmterr));

  %let _cstIGCount=0;
  %let _cst_MsgID=;
  %let _cstParam1=;
  %let _cstParam2=;
  %let _cstRecordCount=0;
  %let _cstTableLabel=;
  %let _cstTempLib=;
  %let _cstTempDS=;
  %let _cstTrgDataLibrary=;
  %let _cstTrgDS=;
  %let _cstThisMacro=&sysmacroname;
  %let _cstrundt=;
  %let _cstrunsasref=;
  %let _cstrunstd=;
  %let _cstrunstdver=;
  %let _cstODMFileType=;
  %let _cstThisMacroRC=0;
  %let _cstThisMacroRCMsg=;

  data _null_;
    attrib _csttemp format=$500. label='Temporary variable string';
    call symputx('_cstrundt',put(datetime(),is8601dt.));
    set &_cstSASrefs (where=(upcase(type) in ("CONTROL" "REFERENCECONTROL")));

    if upcase(type)="CONTROL" and upcase(subtype)="REFERENCE" then
    do;
      if path ne '' and memname ne '' then
      do;
        if kindexc(ksubstr(kreverse(path),1,1),'/\') then
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
    else do;
      call symputx('_cstrunstd',"&_cstStandard");
      call symputx('_cstrunstdver',"&_cstStandardVersion");
    end;
  run;

  %if %length(&_cstrunsasref)=0 %then
  %do;
    %if %sysfunc(indexc(&_cstsasrefs,'.')) %then
    %do;
      %let _cstTempLib=%SYSFUNC(scan(&_cstsasrefs,1,'.'));
      %let _cstTempDS=%SYSFUNC(scan(&_cstsasrefs,2,'.'));
    %end;
    %else
    %do;
      %let _cstTempLib=work;
      %let _cstTempDS=&_cstsasrefs;
    %end;
    %let _cstrunsasref=%sysfunc(pathname(&_cstTempLib))/&_cstTempDS..sas7bdat;
  %end;

  %*************************************************************;
  %* Write information to the results data set about this run. *;
  %*************************************************************;
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstrunstd,_cstSeqNoParm=1,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstrunstdver,_cstSeqNoParm=2,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: ODM_EXTRACTSASDATA,_cstSeqNoParm=3,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: FILE I/O,_cstSeqNoParm=5,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstThisMacro);
  %if %symexist(studyRootPath) %then
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
  %else
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstThisMacro);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstThisMacro);
  %let _cstSeqCnt=9;

  %***************************;
  %* Check parameter values  *;
  %***************************;

  %*********************************;
  %* Check _cstSourceMetadata      *;
  %*********************************;
  %if %length(&_cstSourceMetadata)<1 %then
  %do;
    %* retrieve static variables;
    %cst_getStatic(_cstName=CST_SASREF_TYPE_SOURCEDATA,_cstVar=_cstTypeSourceData);
    %* Get the libref of the sourcedata ;
    %cstutil_getSASReference(_cstStandard=%upcase(&_cstStandard),_cstStandardVersion=&_cstStandardVersion,_cstSASRefType=&_cstTypeSourceData,
                  _cstSASRefsasref=_cstSrcMetaDataLibrary,_cstAllowZeroObs=1);
    %if (&_cst_rc) %then %do;
      %let _cstParam1=&_cstTypeSourceData;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: libname was not assigned for &_cstParam1 in the SASReferences file;
      %goto MISSING_SASREF;
    %end;
    %if %length(&_cstSrcMetaDataLibrary)>0 %then
    %do;
      %if (%sysfunc(libref(&_cstSrcMetaDataLibrary))) %then %do;
        %let _cstParam1=&_cstSrcMetaDataLibrary;
        %let _cstParam2=&_cstTypeSourceData;
        %let _cst_MsgID=ODM0005;
        %let _cstThisMacroRCMsg=%STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %goto MISSING_ASSIGNMENT;
      %end;
      %let _cstSourceMetadata=&_cstSrcMetaDataLibrary;
    %end;
    %else
      %let _cstSourceMetadata=WORK;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstSourceMetaData parameter value was set to &_cstSourceMetadata..;
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstSourceMetadata parameter value was set to &_cstSourceMetadata,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%sysfunc(libref(&_cstSourceMetadata))) %then %do;
      %let _cstParam1=&_cstSourceMetadata;
      %let _cst_MsgID=ODM0007;
      %let _cstThisMacroRCMsg=%STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %goto MISSING_ASSIGNMENT;
    %end;
  %end;

  %***************************;
  %* Check _cstSourceData    *;
  %***************************;
  %if %length(&_cstSourceData)<1 %then
  %do;
    %* retrieve static variables;
    %cst_getStatic(_cstName=CST_SASREF_TYPE_SOURCEDATA,_cstVar=_cstTypeSourceData);
    %* Get the libref of the sourcedata ;
    %cstutil_getSASReference(_cstStandard=%upcase(&_cstStandard),_cstStandardVersion=&_cstStandardVersion,_cstSASRefType=&_cstTypeSourceData,
                  _cstSASRefsasref=_cstSrcDataLibrary,_cstAllowZeroObs=1);
    %if (&_cst_rc) %then %do;
      %let _cstParam1=&_cstTypeSourceData;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: libname was not assigned for &_cstParam1 in the SASReferences file;
      %goto MISSING_SASREF;
    %end;
    %if %length(&_cstSrcDataLibrary)>0 %then
    %do;
      %if (%sysfunc(libref(&_cstSrcDataLibrary))) %then %do;
        %let _cstParam1=&_cstSrcDataLibrary;
        %let _cstParam2=&_cstTypeSourceData;
        %let _cst_MsgID=ODM0005;
        %let _cstThisMacroRCMsg=%STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %goto MISSING_ASSIGNMENT;
      %end;
      %let _cstSourceData=&_cstSrcDataLibrary;
    %end;
    %else
      %let _cstSourceData=WORK;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstSourceData parameter value was set to &_cstSourceData..;
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstSourceData parameter value was set to &_cstSourceData,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%sysfunc(libref(&_cstSourceData))) %then %do;
      %let _cstParam1=&_cstSourceData;
      %let _cst_MsgID=ODM0007;
      %let _cstThisMacroRCMsg=%STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %goto MISSING_ASSIGNMENT;
    %end;
  %end;


  %*************************************************;
  %*  Check existence of required Source Data Sets *;
  %*************************************************;
  %let _cstList=&_cstSourceMetadata..codelists|%str
              ()&_cstSourceMetadata..itemdeftranslatedtext|%str
              ()&_cstSourceMetadata..itemdefs|%str
              ()&_cstSourceMetadata..itemgroupdeftranslatedtext|%str
              ()&_cstSourceMetadata..itemgroupdefitemrefs|%str
              ()&_cstSourceMetadata..itemgroupdefs|%str
              ()&_cstSourceMetadata..metadataversion|%str
              ()&_cstSourceMetadata..study|%str
              ()&_cstSourceMetadata..odm|;
  %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq N %then            
     %let _cstList=&_cstList|%str
              ()&_cstSourceData..subjectdata|%str
              ()&_cstSourceData..studyeventdata|%str
              ()&_cstSourceData..formdata|%str
              ()&_cstSourceData..itemgroupdata|%str
              ()&_cstSourceData..itemdata|%str
              ()&_cstSourceData..clinicaldata|%str
              ()&_cstSourceData..referencedata
              ;
              
  %let _cstCounter=1;
  %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));
  %do %while (%length(&_cstListItem));

    %if not %sysfunc(exist(&_cstListItem)) %then
    %do;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): The &_cstListItem data set does not exist.;
      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %cstutil_writeresult(_cstResultID=CST0202,
                               _cstResultParm1=The &_cstListItem data set does not exist.,
                               _cstResultFlagParm=1,
                               _cstSeqNoParm=&_cstSeqCnt,
                               _cstSrcDataParm=&_cstThisMacro);
        %end;
        %let _cstErrorFlag=1;
    %end;

    %let _cstCounter = %eval(&_cstCounter + 1);
    %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));

  %end;

  %if &_cstErrorFlag=1 %then %do;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCMsg=%STR(ERR)OR: Source dataset(s) missing;
    %goto CLEANUP;
  %end;

  %**************************************************************;
  %* Do we detect any FileType=Transactional?                   *;
  %* If so, we will ignore TransactionTypes.                    *;
  %**************************************************************;
  data _null_;
    set &_cstSourceMetadata..odm;
    put FileType=;
    call symputx('_cstODMFileType', strip(FileType));
    %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq N %then %do;
      if upcase(FileType) = "TRANSACTIONAL" then
        putlog "[CSTLOG" "MESSAGE.&sysmacroname] WAR" "NING: ODM FileType: " FileType ", not supported.";
    %end;
  run;

  %if (%upcase(&_cstODMFileType) = TRANSACTIONAL) and
      (%upcase(%substr(&_cstOnlyTemplates,1,1)) eq N) %then %do;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Not supported: The current version of this module only supports ODM FileType Snapshot.;
      %let _cstParam1=The current version of this module does not support TransactionType records other than Insert;
      %goto UNSUPPORTED;

  %end;
  %else %do;
    %cstutil_writeresult(_cstResultID=CST0200,
                         _cstResultParm1=ODM FileType: &_cstODMFileType,
                         _cstSeqNoParm=1,
                         _cstSrcDataParm=&_cstThisMacro);
  %end;

  %*****************************;
  %* Check _cstIsReferenceData *;
  %*****************************;
  %if %length(&_cstIsReferenceData)<1 %then
  %do;
    %let _cstIsReferenceData=No;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstIsReferenceData parameter value was set to &_cstIsReferenceData..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstIsReferenceData parameter value was set to &_cstIsReferenceData,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%upcase(%substr(&_cstIsReferenceData,1,1)) ^= N and %upcase(%substr(&_cstIsReferenceData,1,1)) ^= Y) %then %do;
      %let _cstParam1=_cstIsReferenceData;
      %let _cstParam2=&_cstIsReferenceData;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstIsReferenceData for _cstIsReferenceData parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %******************************;
  %* Check _cstSelectAttribute  *;
  %******************************;
  %if %length(&_cstSelectAttribute)<1 %then
  %do;
    %let _cstSelectAttribute=Name;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstSelectAttribute parameter value was set to &_cstSelectAttribute..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstSelectAttribute parameter value was set to &_cstSelectAttribute,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%upcase(&_cstSelectAttribute) ^= OID and
         %upcase(&_cstSelectAttribute) ^= NAME and
         %upcase(&_cstSelectAttribute) ^= SASDATASETNAME and
         %upcase(&_cstSelectAttribute) ^= DOMAIN) %then
    %do;
      %let _cstParam1=_cstSelectAttribute;
      %let _cstParam2=&_cstSelectAttribute;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstSelectAttribute for _cstSelectAttribute parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %***************************************;
  %* Check _cstSelectAttributeValue      *;
  %***************************************;
  %if %length(&_cstSelectAttributeValue)<1 %then
  %do;
    %let _cstParam1=_cstSelectAttributeValue;
    %let _cstParam2=(not specified);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: The _cstSelectAttributeValue parameter was not specified.;
    %goto MISSING_PARAM_VALUE;
  %end;


  %****************************;
  %* Check _cstMaxLabelLength *;
  %****************************;
  %if %length(&_cstMaxLabelLength)<1 %then
  %do;
    %let _cstMaxLabelLength=256;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstMaxLabelLength parameter value was set to &_cstMaxLabelLength..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstMaxLabelLength parameter value was set to &_cstMaxLabelLength,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if %sysfunc(compress(&_cstMaxLabelLength, %str(1234567890))) NE %then %do; %* Not an integer;
      %let _cstParam1=_cstMaxLabelLength;
      %let _cstParam2=&_cstMaxLabelLength;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid integer value &_cstMaxLabelLength for _cstMaxLabelLength parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %***************************;
  %* Check _cstAttachFormats *;
  %***************************;
  %if %length(&_cstAttachFormats)<1 %then
  %do;
    %let _cstAttachFormats=Yes;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstAttachFormats parameter value was set to &_cstAttachFormats..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstAttachFormats parameter value was set to &_cstAttachFormats,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%upcase(%substr(&_cstAttachFormats,1,1)) ^= N and %upcase(%substr(&_cstAttachFormats,1,1)) ^= Y) %then %do;
      %let _cstParam1=_cstAttachFormats;
      %let _cstParam2=&_cstAttachFormats;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstAttachFormats for _cstAttachFormats parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %******************************;
  %* Check _cstODMMinimumKeySet *;
  %******************************;
  %if %length(&_cstODMMinimumKeySet)<1 %then
  %do;
    %let _cstODMMinimumKeySet=No;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstODMMinimumKeySet parameter value was set to &_cstODMMinimumKeySet..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstODMMinimumKeySet parameter value was set to &_cstODMMinimumKeySet,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%upcase(%substr(&_cstODMMinimumKeySet,1,1)) ^= N and %upcase(%substr(&_cstODMMinimumKeySet,1,1)) ^= Y) %then %do;
      %let _cstParam1=_cstODMMinimumKeySet;
      %let _cstParam2=&_cstODMMinimumKeySet;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstODMMinimumKeySet for _cstODMMinimumKeySet parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %********************************;
  %* Check _cstOutputLibrary      *;
  %********************************;
  %if %length(&_cstOutputLibrary)<1 %then
  %do;
    %* Get the libref of the targetdata ;
    %cstutil_getSASReference(_cstStandard=%upcase(&_cstTrgStandard),_cstStandardVersion=&_cstTrgStandardVersion,_cstSASRefType=targetdata,
                  _cstSASRefsasref=_cstTrgDataLibrary,_cstAllowZeroObs=1);
    %if (&_cst_rc) %then
    %do;
      %let _cstParam1=targetdata;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: libname was not assigned for &_cstParam1 in the SASReferences file;
      %goto MISSING_SASREF;
    %end;
    %if %length(&_cstTrgDataLibrary)>0 %then
    %do;
      %if (%sysfunc(libref(&_cstTrgDataLibrary))) %then
      %do;
        %let _cstParam1=&_cstTrgDataLibrary;
        %let _cstParam2=targetdata;
        %let _cst_MsgID=ODM0005;
        %let _cstThisMacroRCMsg=%STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: &_cstParam1 was not assigned for &_cstParam2 in the SASReferences file;
        %goto MISSING_ASSIGNMENT;
      %end;
      %let _cstOutputLibrary=&_cstTrgDataLibrary;
    %end;
    %else
      %let _cstOutputLibrary=WORK;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstOutputLibrary parameter value was set to &_cstOutputLibrary..;
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstOutputLibrary parameter value was set to &_cstOutputLibrary,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%sysfunc(libref(&_cstOutputLibrary))) %then
    %do;
      %let _cstParam1=&_cstOutputLibrary;
      %let _cst_MsgID=ODM0007;
      %let _cstThisMacroRCMsg=%STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: The libname &_cstParam1 was referenced but is not assigned;
      %goto MISSING_ASSIGNMENT;
    %end;
  %end;

  %******************************;
  %* Check _cstOnlyTemplates    *;
  %******************************;
  %if %length(&_cstOnlyTemplates)<1 %then
  %do;
    %let _cstOnlyTemplates=No;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstOnlyTemplates parameter value was set to &_cstOnlyTemplates..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstOnlyTemplates parameter value was set to &_cstOnlyTemplates,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %else %do;
    %if (%upcase(%substr(&_cstOnlyTemplates,1,1)) ^= N and %upcase(%substr(&_cstOnlyTemplates,1,1)) ^= Y) %then %do;
      %let _cstParam1=_cstOnlyTemplates;
      %let _cstParam2=&_cstOnlyTemplates;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstOnlyTemplates for _cstOnlyTemplates parameter was specified.;
      %goto INVALID_PARAM_VALUE;
    %end;
  %end;

  %****************************;
  %* Check _cstOutputDS       *;
  %****************************;
  %* If not specified as a parameter, look in SASReferences for a memname value. ;
  %if %length(&_cstOutputDS)<1 %then
  %do;
    %cstutil_getSASReference(_cstStandard=%upcase(&_cstTrgStandard),_cstStandardVersion=&_cstTrgStandardVersion,_cstSASRefType=targetdata,
                  _cstSASRefsasref=_cstTrgDataLibrary,_cstSASRefmember=_cstTrgDS,_cstAllowZeroObs=1);
    %if (&_cst_rc) %then
    %do;
      %let _cstParam1=_cstOutputDS;
      %let _cstParam2=: issue with SASReferences lookup.;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Requested _cstOutputDS not specified.;
      %goto INVALID_PARAM_VALUE;
    %end;

    %if (%length(&_cstTrgDS)<1) %then
    %do;
      %let _cstParam1=_cstOutputDS;
      %let _cstParam2=(not specified).;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Requested _cstOutputDS not specified.;
      %goto MISSING_PARAM_VALUE;
    %end;

    %if %sysfunc(indexc(&_cstTrgDS,'.')) %then
    %do;
      %let _cstTrgDS=%SYSFUNC(scan(&_cstTrgDS,1,'.'));
    %end;
    %let _cstOutputDS=&_cstTrgDS;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstOutputDS parameter value was set to &_cstOutputDS..;
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The _cstOutputDS parameter value was set to &_cstOutputDS,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
  %end;
  %let _cstThisMacroRC=0;
  data _null_;
    _cstvalid=nvalid("&_cstOutputDS",'v7');
    if _cstvalid < 1 then
    do;
      call symputx('_cstThisMacroRC',1);
    end;
  run;
  %if (&_cstThisMacroRC) %then
  %do;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid _cstOutputDS=&_cstOutputDS specified.;
    %let _cstParam1=_cstOutputDS;
    %let _cstParam2=&_cstOutputDS;
    %goto INVALID_PARAM_VALUE;
  %end;

  %******************************************;
  %* Lets see if we can extract a dataset.  *;
  %******************************************;

  %* Confirm _cstSelectAttribute/_cstSelectAttributeValue against the available ODM metadata  *;
  proc sql noprint;
    create table work._cstItemGroup as
    select OID, Name, isReferenceData, SASDatasetname, Domain, FK_MetaDataVersion
    from &_cstSourceMetadata..itemgroupdefs
    %if %upcase(%substr(&_cstIsReferenceData,1,1)) ^= Y %then
    %do;
        where (upcase(isReferenceData) ^= 'YES' and (upcase(&_cstSelectAttribute) = upcase("&_cstSelectAttributeValue")));
    %end;
    %else %if %upcase(%substr(&_cstIsReferenceData,1,1)) = Y %then
    %do;
        where (upcase(isReferenceData) = 'YES' and (upcase(&_cstSelectAttribute) = upcase("&_cstSelectAttributeValue")));
    %end;
  ;
  quit;

  %let _cstRecordCount=%cstutilnobs(_cstDataSetName=work._cstItemGroup);

  %if &_cstRecordCount=0 %then
  %do;
    %*** Requested _cstSelectAttribute/_cstSelectAttributeValue not found in ODM metadata  *;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Requested &_cstSelectAttribute="&_cstSelectAttributeValue" not found in ODM ItemGroupDefs metadata.;
    %let _cstParam1=&_cstSelectAttribute;
    %let _cstParam2=&_cstSelectAttributeValue;
    %goto INVALID_PARAM_VALUE;
  %end;
  %else %if &_cstRecordCount>1 %then
    %do;
      %*** More than 1 record found in the ODM metadata for the specified _cstSelectAttribute/_cstSelectAttributeValue value   *;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: More than one (&_cstRecordCount) records found in the ODM ItemGroupDefs metadata for the specified &_cstSelectAttribute="&_cstSelectAttributeValue" value.;
      %let _cstParam1=&_cstSelectAttribute;
      %let _cstParam2=&_cstSelectAttributeValue: More than one (&_cstRecordCount) records found in the ODM ItemGroupDefs metadata ;
      %goto INVALID_PARAM_VALUE;
    %end;
  %let _cstRecordCount=0;


  %************************;
  %* Begin extraction     *;
  %************************;

  %* Extract/Count unique ItemGroupDef.OID ;
  proc sql noprint;
    create table work._cstUniqueIGs as
    select distinct OID as IGOID
    from work._cstItemGroup;
    select IGOID into :_cstIGOIDs separated by ','
    from work._cstUniqueIGs;
    select count(*) into :_cstIGCount separated by ''
    from work._cstUniqueIGs;
  quit;

  %if &_cstDebug %then
  %do;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(*** Start of extraction.);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstSourceMetadata       = &_cstSourceMetadata (%sysfunc(pathname(&_cstSourceMetadata))));
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstSourceData           = &_cstSourceData (%sysfunc(pathname(&_cstSourceData))));
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstIsReferenceData      = &_cstIsReferenceData);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstSelectAttribute      = &_cstSelectAttribute);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstSelectAttributeValue = &_cstSelectAttributeValue);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstLang                 = &_cstLang);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstMaxLabelLength       = &_cstMaxLabelLength);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstAttachFormats        = &_cstAttachFormats);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstODMMinimumKeySet     = &_cstODMMinimumKeySet);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstOutputLibrary        = &_cstOutputLibrary (%sysfunc(pathname(&_cstOutputLibrary))));
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstOutputDS             = &_cstOutputDS);
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(_cstOnlyTemplates        = &_cstOnlyTemplates);
    %put;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: %str(&_cstIGCount unique ItemGroup OID(s) in metadata: &_cstIGOIDs);
  %end;

  %****************************************************;
  %* Get all the metadata for a designated ItemGroup  *;
  %****************************************************;
  proc sql;
    create table _cstItemGroupMetaData
    as select
      odm.fileoid          as __ODMFileOID,
      std.OID              as __StudyOID,
      mdv.OID              as __MetaDataVersionOID,
      igd.OID              as __ItemGroupOID,
      igd.Name             as igName,
      igd.Repeating,
      igd.IsReferenceData,
      igd.SASDatasetName,
      igd.Domain,
      igd.Comment as igComment,
      igdtt.TranslatedText as igText,
      igdir.ItemOID,
      igdir.OrderNumber,
      igdir.KeySequence,
      itd.Name as ItemName,
      itd.DataType,
      itd.Length,
      itd.SignificantDigits,
      itd.SASFieldname,
      itd.Comment as ItemComment,
      itd.CodeListRef,
      cl.SASFormatName,
      idtt.TranslatedText as itText
    from &_cstSourceMetadata..odm odm
       inner join &_cstSourceMetadata..study std
     on std.fk_odm = odm.fileoid
       inner join &_cstSourceMetadata..metadataversion mdv
     on mdv.fk_study = std.oid
       inner join &_cstSourceMetadata..itemgroupdefs igd
     on igd.fk_metadataversion = mdv.oid
       inner join &_cstSourceMetadata..itemgroupdefitemrefs igdir
     on igdir.fk_itemgroupdefs = igd.oid
       inner join &_cstSourceMetadata..itemdefs itd
     on (itd.oid = igdir.itemoid and itd.fk_metadataversion = mdv.oid)
       inner join work._cstUniqueIGs uig
     on uig.IGOID = igd.OID
       left join &_cstSourceMetadata..codelists cl
     on (cl.fk_metadataversion = mdv.oid and itd.codelistref = cl.oid)
       left join &_cstSourceMetadata..itemgroupdeftranslatedtext(where=(lang="&_cstLang")) igdtt
     on igdtt.fk_itemgroupdefs = igd.oid
       left join &_cstSourceMetadata..itemdeftranslatedtext(where=(lang="&_cstLang")) idtt
     on idtt.fk_itemdefs = itd.oid
     order by ordernumber;
     ;
  quit;

  %****************************************************;
  %* Build labels and attributes                      *;
  %****************************************************;

  %* Build dataset label *;
  data work._cstItemGroupMetaData (drop=_cstvalid x);
    set work._cstItemGroupMetaData;
      attrib columnName  length=$32
             columnLabel length=$1000
             tableName   length=$32
             tableLabel  length=$1000;
      retain tableName tableLabel;

    %* Derive usable data set name and label *;
    if _n_=1 then
    do;

      if missing(SASDatasetName) then tableName=IGName;
                                 else tableName=SASDatasetName;
      if missing(igText) then tableLabel=IGName;
                         else tableLabel=igText;
      if length(tableLabel) > &_cstMaxLabelLength then
          tableLabel = cats(substr(tableLabel,1, &_cstMaxLabelLength.-3), '...');
      tableLabel=tranwrd(tableLabel,'"',"'");
      call symputx('_cstTableLabel',tableLabel);

      %* Currently the output dataset name will be specified by the user *;
      _cstvalid=nvalid(tableName,'v7');
      if not _cstvalid then
      do;
        x=nvalid(substr(tableName,1,1));
        if x=0 then substr(tableName,1,1)='_';
        do until(x=0 or _cstvalid=1);
          x=notName(tableName);
          if x > 0 then
            tableName=translate(strip(tableName),'_', substr(tableName,x,1));
          _cstvalid=nvalid(tableName,'v7');
        end;
        _cstvalid=nvalid(tableName,'v7');
        putlog "[CSTLOG" "MESSAGE.&sysmacroname] NOTE: Modified tableName: " SASDatasetName= IGName= tableName= _cstvalid=;
      end;
    end;


    %* Derive usable column name and label *;
    if missing(SASFieldName) then columnName=itemname;
                             else columnName=SASFieldName;
    if missing(itText) then columnLabel=ItemComment;
                       else columnLabel=itText;
    if missing(columnLabel) then columnLabel=itemname;

    if length(columnLabel) > &_cstMaxLabelLength then
        columnLabel = cats(substr(columnLabel,1, &_cstMaxLabelLength.-3), '...');
    columnLabel=tranwrd(columnLabel,'"',"'");

    _cstvalid=nvalid(columnName,'v7');
    if not _cstvalid then
    do;
      x=nvalid(substr(columnName,1,1));
      if x=0 then substr(columnName,1,1)='_';
      do until(x=0 or _cstvalid=1);
        x=notName(columnName);
        if x > 0 then
          columnName=translate(strip(columnName),'_', substr(columnName,x,1));
        _cstvalid=nvalid(columnName,'v7');
      end;
      _cstvalid=nvalid(columnName,'v7');
      putlog "[CSTLOG" "MESSAGE.&sysmacroname] NOTE: Modified columnName: " SASFieldName= itemName= columnName= _cstvalid=;
    end;

  run;
  %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: _cstTableLabel = %str(&_cstTableLabel);

  filename _cstattr CATALOG "work._cstextract.colattr.source";
  filename _cstwr   CATALOG "work._cstextract.writedata_&_cstOutputDS..source";

  %* Build the column attribute code for later use  *;
  data _null_;
    set work._cstItemGroupMetaData end=last;
      attrib tempvar length=$2000;
    file _cstattr;

    select(upcase(datatype));
      when ("TEXT", "STRING")
        do;
          tempvar=catx(' ',columnName, cats('length=$',length));
          %if %upcase(%substr(&_cstAttachFormats,1,1)) = Y %then %do;
            %* Attach formats;
            if not missing(CodeListRef) and not missing(SASFormatName) then do;
              tempvar=catx(' ',tempvar, cats('format=', SASFormatName, '.'));
              tempvar=tranwrd(tempvar, "..", ".");
            end;
          %end;
          tempvar=catx(' ',tempvar,cats('label="',columnLabel,'"'));
        end;
      %* We are reading DATE, TIME and DATETIME as TEXT since we are not supporting partial *;
      %* DATETIME, DATE and TIME yet.                                                       *;
      when ("DATE", "TIME", "DATETIME", "PARTIALDATE", "PARTIALTIME", "PARTIALDATETIME", "INTERVALDATETIME",
            "DURATIONDATETIME", "INCOMPLETEDATETIME", "INCOMPLETEDATE", "INCOMPLETETIME")
        do;
          if missing(length) then tempvar=catx(' ', columnName, cats('length=$64'));
                             else tempvar=catx(' ', columnName, cats('length=$',length));
          tempvar=catx(' ',tempvar,cats('label="',columnLabel,'"'));
        end;
      when ("FLOAT", "INTEGER")
        do;
          tempvar=catx(' ', columnName, 'length=8');
          if not missing(length) then do;
            tempvar=catx(' ', tempvar, cats('informat=',length,'.'));
            if not missing(significantdigits) then tempvar=cats(tempvar,significantdigits);
          end;
          %if %upcase(%substr(&_cstAttachFormats,1,1)) = Y %then %do;
            %* Attach formats;
            if not missing(CodeListRef) and not missing(SASFormatName) then do;
              tempvar=catx(' ',tempvar, cats('format=', SASFormatName, '.'));
              tempvar=tranwrd(tempvar, "..", ".");
            end;
          %end;
          tempvar=catx(' ',tempvar,cats('label="',columnLabel,'"'));
        end;
      otherwise
        do;
          if missing(length)
            then tempvar=catx(' ', columnName, cats('length=$2000'),cats('label="',columnLabel,'"'));
            else tempvar=catx(' ', columnName, cats('length=$',length),cats('label="',columnLabel,'"'));
        end;
    end;
    put @5 tempvar;
  run;


  %**************************************;
  %* Get ClinicalData and ReferenceData *;
  %**************************************;

  %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq N %then
  %do;
    %* We are getting data, not just templates;
    
    %****************************;
    %* Get all the ClinicalData *;
    %****************************;
    %if %upcase(%substr(&_cstIsReferenceData,1,1)) = N %then %do;
      proc sql;
        create table _cstItemData
        as select
         cda.StudyOID             as __StudyOID,
         cda.MetadataVersionOID   as __MetaDataVersionOID,
         sda.SubjectKey           as __SubjectKey,
         seda.StudyEventOID       as __StudyEventOID,
         seda.StudyEventRepeatKey as __StudyEventRepeatKey,
         fda.FormOID              as __FormOID,
         fda.FormRepeatKey        as __FormRepeatKey,
         igda.ItemGroupOID        as __ItemGroupOID,
         igda.ItemGroupRepeatKey  as __ItemGroupRepeatKey,
         itda.ItemOID,
         itda.Value,
         itda.IsNull,
         itda.ItemDataType,
         itda.TransactionType     as itdaTransactionType,
         itda.TransactionOrder,
         igda.TransactionType     as igdTransactionType,
         fda.TransactionType      as fdTransactionType,
         seda.TransactionType     as sedTransactionType,
         sda.TransactionType      as sdTransactionType,
         sda.InvestigatorRefOID   as __UserOID,
         sda.SiteRefOID           as __LocationOID
  
        from &_cstSourceData..itemdata itda
           inner join &_cstSourceData..itemgroupdata igda
         on itda.fk_itemgroupdata = igda.oid
           inner join &_cstSourceData..formdata fda
         on igda.fk_formdata = fda.oid
           inner join &_cstSourceData..studyeventdata seda
         on fda.fk_studyeventdata = seda.oid
           inner join &_cstSourceData..subjectdata sda
         on seda.fk_subjectdata = sda.oid
           inner join &_cstSourceData..clinicaldata cda
         on sda.fk_clinicaldata = cda.oid
           inner join work._cstUniqueIGs uig
         on uig.IGOID = igda.ItemGroupOID
         order by __StudyOID, __MetaDataVersionOID, __SubjectKey,
                  __StudyEventOID, __StudyEventRepeatKey,
                  __FormOID, __FormRepeatKey,
                  __ItemGroupOID, __ItemGroupRepeatKey,
                  TransactionOrder
        ;
      quit;
  
      proc sql;
        create table work._cstFinal
        as select metd.*,
                  clind.__SubjectKey,
                  clind.__StudyEventOID, clind.__StudyEventRepeatKey,
                  clind.__FormOID, clind.__FormRepeatKey,
                  clind.__ItemGroupRepeatKey,
                  clind.__LocationOID, clind.__UserOID,
                  clind.Value, clind.ItemDataType, clind.IsNull,
                  clind.itdaTransactionType, clind.igdTransactionType,
                  clind.fdTransactionType, clind.sedTransactionType,
                  clind.sdTransactionType
        from work._cstItemGroupMetaData metd
           inner join work._cstItemData clind
        on (metd.__StudyOID           = clind.__StudyOID and
            metd.__MetaDataVersionOID = clind.__MetaDataVersionOID and
            metd.__ItemGroupOID       = clind.__ItemGroupOID and
            metd.ItemOID              = clind.ItemOID
           )
        ;
      quit;
  
      data work._cstFinal;
      retain __StudyOID __MetaDataVersionOID __SubjectKey
             __StudyEventOID __StudyEventRepeatKey
             __FormOID __FormRepeatKey igdTransactionType
             __LocationOID __UserOID
             __ItemGroupOID __ItemGroupRepeatKey;
        set work._cstFinal;
        attrib __TransactionType length=$7 label="Transaction type";
        __TransactionType = itdaTransactionType;
        if missing(__TransactionType) then __TransactionType=igdTransactionType;
        if missing(__TransactionType) then __TransactionType=fdTransactionType;
        if missing(__TransactionType) then __TransactionType=sedTransactionType;
        if missing(__TransactionType) then __TransactionType=sdTransactionType;
      run;
  
  
      %let _cstItemGroup=__StudyOID  __MetaDataVersionOID __SubjectKey __StudyEventOID __StudyEventRepeatKey %str
                     ()__FormOID __FormRepeatKey __ItemGroupOID __ItemGroupRepeatKey  __LocationOID __UserOID;
      %let _cstItemGroupKeep=;
       %if %upcase(%substr(&_cstODMMinimumKeySet,1,1)) = N %then
         %let _cstItemGroupKeep=&_cstItemGroupKeep __StudyOID __MetaDataVersionOID __SubjectKey __StudyEventOID __StudyEventRepeatKey __FormOID %str
                                             ()__FormRepeatKey __ItemGroupOID __ItemGroupRepeatKey __TransactionType __LocationOID __UserOID;
      %let _cstItemGroupVar=__ItemGroupRepeatKey;
  
      proc sort data = work._cstFinal;
      by &_cstItemGroup;
      run;
  
  
      %***************************************************************;
      %* Do we detect any TransactionType ne Insert records?  If so, *;
      %*  we need to stop because this is not intended to be a       *;
      %*  transactional processing tool and we cannot be certain we  *;
      %*  are extracting the correct data.                           *;
      %***************************************************************;
      %let _cstRecordCount=0;
      proc sql noprint;
        select count(*) into:_cstRecordCount from
        ( select sdTransactionType from work._cstFinal (where=(not missing(sdTransactionType) and upcase(sdTransactionType) ne "INSERT"))
          union all
          select sedTransactionType from work._cstFinal (where=(not missing(sedTransactionType) and upcase(sedTransactionType) ne "INSERT"))
          union all
          select fdTransactionType from work._cstFinal (where=(not missing(fdTransactionType) and upcase(fdTransactionType) ne "INSERT"))
          union all
          select igdTransactionType from work._cstFinal (where=(not missing(igdTransactionType) and upcase(igdTransactionType) ne "INSERT"))
          union all
          select itdaTransactionType from work._cstFinal (where=(not missing(itdaTransactionType) and upcase(itdaTransactionType) ne "INSERT"))
        );
      quit;
      %if &_cstRecordCount>0 %then
      %do;
          %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Not supported: The current version of this module does not support TransactionType records other than Insert.;
          %let _cstParam1=The current version of this module does not support TransactionType records other than Insert;
          %goto UNSUPPORTED;
      %end;
  
    %end;
  
    %******************************;
    %* Get all the ReferenceData  *;
    %******************************;
    %if %upcase(%substr(&_cstIsReferenceData,1,1)) = Y %then %do;
      proc sql;
        create table _cstItemData
        as select
         refda.StudyOID           as __StudyOID,
         refda.MetadataVersionOID as __MetaDataVersionOID,
         igda.ItemGroupOID        as __ItemGroupOID,
         igda.ItemGroupRepeatKey  as __ItemGroupRepeatKey,
         itda.ItemOID,
         itda.Value,
         itda.IsNull,
         itda.ItemDataType,
         itda.TransactionType     as itdaTransactionType,
         itda.TransactionOrder,
         igda.TransactionType     as igdTransactionType
  
        from &_cstSourceData..itemdata itda
           inner join &_cstSourceData..itemgroupdata igda
         on itda.fk_itemgroupdata = igda.oid
           inner join &_cstSourceData..referencedata refda
         on igda.fk_referencedata = refda.generatedid
           inner join work._cstUniqueIGs uig
         on uig.IGOID = igda.ItemGroupOID
        ;
      quit;
  
      proc sql;
        create table work._cstFinal
        as select metd.*,
                  refd.__ItemGroupRepeatKey,
                  refd.Value, refd.ItemDataType, refd.IsNull,
                  refd.itdaTransactionType, refd.igdTransactionType
        from work._cstItemGroupMetaData metd
           inner join work._cstItemData refd
        on (metd.__StudyOID           = refd.__StudyOID and
            metd.__MetaDataVersionOID = refd.__MetaDataVersionOID and
            metd.__ItemGroupOID       = refd.__ItemGroupOID and
            metd.ItemOID              = refd.ItemOID
           )
        ;
      quit;
  
      data work._cstFinal;
      retain __StudyOID __MetaDataVersionOID
             __ItemGroupOID __ItemGroupRepeatKey igdTransactionType;
        set work._cstFinal;
        attrib __TransactionType length=$7 label="Transaction type";
        __TransactionType = itdaTransactionType;
        if missing(__TransactionType) then __TransactionType=igdTransactionType;
      run;
  
      %let _cstItemGroup=__StudyOID __MetaDataVersionOID __ItemGroupOID __ItemGroupRepeatKey;
      %let _cstItemGroupKeep=;
       %if %upcase(%substr(&_cstODMMinimumKeySet,1,1)) = N %then
         %let _cstItemGroupKeep=&_cstItemGroup __StudyOID __MetaDataVersionOID __ItemGroupOID __ItemGroupRepeatKey __TransactionType;
      %let _cstItemGroupVar=__ItemGroupRepeatKey;
  
      proc sort data = work._cstFinal;
      by &_cstItemGroup;
      run;
  
      %***************************************************************;
      %* Do we detect any TransactionType ne Insert records?  If so, *;
      %*  we need to stop because this is not intended to be a       *;
      %*  transactional processing tool and we cannot be certain we  *;
      %*  are extracting the correct data.                           *;
      %***************************************************************;
      %let _cstRecordCount=0;
      proc sql noprint;
        select count(*) into:_cstRecordCount from
        ( select igdTransactionType from work._cstFinal (where=(not missing(igdTransactionType) and upcase(igdTransactionType) ne "INSERT"))
          union all
          select itdaTransactionType from work._cstFinal (where=(not missing(itdaTransactionType) and upcase(itdaTransactionType) ne "INSERT"))
        );
      quit;
      %if &_cstRecordCount>0 %then
      %do;
          %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Not supported: The current version of this module does not support TransactionType records other than Insert.;
          %let _cstParam1=The current version of this module does not support TransactionType records other than Insert;
          %goto UNSUPPORTED;
      %end;
    %end;
  %end;
  %else %do;
    %* We are only creating templates;
    
    %let _cstItemGroup=__StudyOID  __MetaDataVersionOID;
    proc sort data=work._cstItemGroupMetaData out= work._cstFinal;
      by &_cstItemGroup;
    run;
      
  %end;  

  %* Turn off format errors;
  options nofmterr;

  %if %cstutilnobs(_cstDatasetName=work._cstFinal) %then %do;

    %*****************;
    %* Generate code *;
    %*****************;
    %let _cstThisMacroRC=0;
    %let _cstThisMacroRCMsg=;
    data _null_;
      length tempvar $2000 tempvar2 8 _cstinvalid 8;
      retain _cstinvalid 0;
      set work._cstFinal end=last;
      by &_cstItemGroup;
      file _cstwr;
      tempvar="";
      tempvar2=.;
      if _n_=1 then do;
        put @1 "data &_cstOutputLibrary..&_cstOutputDS (label=" '"' "&_cstTableLabel" '"' ");";

        %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq N %then
        %do;
          length _cst $400;
          %* Only when we are not just creating templates;
            %let _cstList=&&_cstItemGroupKeep;
            %let _cstCounter=1;
            %let _cstListItem=%scan(&_cstList, &_cstCounter, %str( ));
            %if %length(&_cstListItem) %then %do;
              put @3 'attrib';          
            %end;  
            %do %while (%length(&_cstListItem));
              _cst=cat("&_cstListItem length=$", vlength(&_cstListItem), ' label="', vlabel(&_cstListItem), '"');
              put @5 _cst;
              %let _cstCounter = %eval(&_cstCounter + 1);
              %let _cstListItem=%scan(&_cstList, &_cstCounter, %str( ));
            %end;
        %end; 

        put @3 ';';
        put @3 'attrib';
        put @3 "%include _cstattr;";
        put @3 ';';
        %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq Y %then
        %do;
          put @3 'call missing(of _all_);';
          put @3 'delete;';
        %end;
      end;

      %if %upcase(%substr(&_cstOnlyTemplates,1,1)) eq N %then
      %do;
        %* Only when we are not just creating templates;

        if first.&_cstItemGroupVar then do;
          put @3 'call missing(of _all_);';
          %let _cstList=&&_cstItemGroupKeep;
          %let _cstCounter=1;
          %let _cstListItem=%scan(&_cstList, &_cstCounter, %str( ));
          %do %while (%length(&_cstListItem));
            put @3 "&_cstListItem=" '"' &_cstListItem +(-1) '";';
            %let _cstCounter = %eval(&_cstCounter + 1);
            %let _cstListItem=%scan(&_cstList, &_cstCounter, %str( ));
          %end;
        end;
  
        %* Itemdatatype comes from ItemData and Datatype comes from ItemDefs *;
        if missing(DataType) then do;
          DataType = ItemDataType;
          putlog "[CSTLOG" "MESSAGE.&sysmacroname] WARNING: DataType was missing: " itemName= columnName= DataType= ItemDataType= value=;
        end;
        put @3 '* ' Domain= itemName= columnName= DataType= ' ;';
  
        %* We are reading everything as TEXT except INTEGER and FLOAT *;
        select(upcase(DataType));
          when ("FLOAT", "INTEGER")
            do;
              if missing(value) then do;
                value='.';
                tempvar=catx(' ',columnName,'=',value,';');
              end;
              else do;
                tempvar1=input(value, ?? best.);
                if missing(tempvar1) then do;
                  putlog "[CSTLOG" "MESSAGE.&sysmacroname] WARNING: Datapoint could not be converted: " itemName= columnName= DataType= value=;
                  putlog "[CSTLOG" "MESSAGE.&sysmacroname]          Value will be missing.";
                  putlog "WAR" "NING: Datapoint could not be converted: " itemName= columnName= DataType= value=;
  
                  putlog _all_;
                  value='.';
                  _cstinvalid=1;
                end;
                tempvar=catx(' ',columnName,'=',value,';');
              end;
            end;
          otherwise
            do;
              value=quote(value);
              tempvar=cats(columnName,'=',value,'";');
            end;
        end;
        put @3 tempvar;
        if last.&_cstItemGroupVar then do;
          put @3 'output;';
        end;
        if last then do;
          put @1 'run;';
          if _cstinvalid then call symputx('_cstThisMacroRC',1);
        end;
        
      %end;
        
    run;

    %if (&_cstThisMacroRC) %then
    %do;
      %let _cstThisMacroRCMsg=%STR(WARN)ING: There were data conversion issues;
      %goto DATA_CONVERSION_ISSUE;
    %end;

    %include _cstwr;
    run;

    %if %sysfunc(exist(&_cstOutputLibrary..&_cstOutputDS)) %then
    %do;
      %let _cstNobs=%cstutilnobs(_cstDatasetName=&_cstOutputLibrary..&_cstOutputDS);
      %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: data set &_cstOutputLibrary..&_cstOutputDS was successfully created (&_cstNobs obs).;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
          _cstResultID=CST0200,
          _cstResultParm1=The data set &_cstOutputLibrary..&_cstOutputDS was successfully created (&_cstNobs obs),
          _cstSeqNoParm=&_cstSeqCnt,
          _cstSrcDataParm=&_cstThisMacro);
    %end;
    %else
    %do;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted.;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
          _cstResultID=CST0200,
          _cstResultParm1=No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted,
          _cstSeqNoParm=&_cstSeqCnt,
          _cstSrcDataParm=&_cstThisMacro);
      %put No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted;
    %end;

  %end;
  %else %do; %* There was no data to be extracted.;

    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted.;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisMacro);
    %put No data was found for &_cstSelectAttribute=&_cstSelectAttributeValue - no data set was extracted;

  %end;

  %goto CLEANUP;


%MISSING_SASREF:
  %if (&_cstDebug) %then %do;
     %put In MISSING_SASREF;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCMsg=%STR(ERR)OR: The following information was missing from the SASReferences file: &_cstParm1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=ODM0004
                ,_cstResultParm1=&_cstParam1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%MISSING_ASSIGNMENT:
  %if (&_cstDebug) %then %do;
     %put In MISSING_ASSIGNMENT;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=&_cst_MsgID
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%INVALID_PARAM_VALUE:
  %if (&_cstDebug) %then %do;
     %put In INVALID_PARAM_VALUE;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCMsg=%STR(ERR)OR: The parameter &_cstParam1 had an invalid value &_cstParam2;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=ODM0006
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%DATA_CONVERSION_ISSUE:
  %if (&_cstDebug) %then %do;
     %put In DATA_CONVERSION_ISSUE;
  %end;

  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=ODM0098
                ,_cstResultParm1=There were Data Conversion Issues; please check the LOG
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );

  %let _cstThisMacroRC=0;
  %let _cstThisMacroRCMsg=;

  %goto CLEANUP;

%MISSING_PARAM_VALUE:
  %if (&_cstDebug) %then %do;
     %put In MISSING_PARAM_VALUE;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCMsg=%STR(ERR)OR: The parameter &_cstParam1 had a missing value;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=ODM0006
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%UNSUPPORTED:
  %if (&_cstDebug) %then %do;
     %put In UNSUPPORTED;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCMsg=%STR(ERR)OR: &_cstParam1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=ODM0099
                ,_cstResultParm1=&_cstParam1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%CLEANUP:

  %* Restore options  *;
  options &_cstSaveOptions;

  %************************************;
  %* Start tasks to complete process  *;
  %************************************;

  %cstutil_saveresults();

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(cexist(work._cstextract)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstextract / memtype=catalog;
      quit;
      filename _cstattr;
      filename _cstwr;
    %end;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstItemGroup);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstUniqueIGs);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstItemGroupMetaData);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstItemData);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstFinal);

  %end;
  %else
  %do;
    %put <<< odm_extractsasdata;
    %put _all_;
  %end;

  %if &_cstThisMacroRC=1 %then
  %do;
    %let _cst_rc=&_cstThisMacroRC;
    %let _cst_rcmsg=&_cstThisMacroRCmsg;
  %end;
  %else
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=;
  %end;

  %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname] *** END   *** ;


%mend odm_extractdomaindata;
