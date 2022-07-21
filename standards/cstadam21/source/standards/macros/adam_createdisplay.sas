%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* adam_createdisplay                                                             *;
%*                                                                                *;
%* Creates an analysis result display from ADaM analysis data sets.               *;
%*                                                                                *;
%* The path to the code to create the display is provided either directly in the  *;
%* macro parameters or is derived from a metadata source. Examples of metadata    *;
%* sources are analysis results metadata or Tables, Listings, and Figures data    *;
%* definition metadata (TLFDDT) that you maintain and reference in the            *;
%* SASReferences data set.                                                        *;
%*                                                                                *;
%* Two primary paths (parameter settings) are supported:                          *;
%*    1. A code source is specified. A fully qualified path is required. The      *;
%*       expectation is that this macro is %included below to generate an         *;
%*       analysis result (display).                                               *;
%*    2. Metadata provides the information necessary to generate an analysis      *;
%*       result (display). This metadata is in the form of the CDISC ADaM         *;
%*       analysis results metadata, supplemental Tables, Listings, and Figures    *;
%*       data definition metadata (TLFDDT), or both.                              *;
%*                                                                                *;
%* @macvar studyRootPath Root path to the sample source study                     *;
%* @macvar _cstCTDescription Description of controlled terminology packet         *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar cstDefaultReportFormat SAS ODS report destination                      *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*            Standards Toolkit                                                   *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%* @macvar _CSTTLF_MASTERCODEPATH Dynamically derived code segment path from      *;
%*            TLF metadata.                                                       *;
%* @macvar workpath Path to the SAS session work library                          *;
%*                                                                                *;
%* @param _cstDisplaySrc - required - Where information comes from to generate    *;
%*            the result.                                                         *;
%*            Values:  Code | Metadata                                            *;
%*            Default: Metadata                                                   *;
%* @param _cstDisplayCode - conditional - Either a valid filename or the fully    *;
%*            qualified path to code that produces an analysis result. If         *;
%*            _cstDisplaySrc=Code, this parameter is used and is required. All of *;
%*            the remaining parameters are ignored.                               *;
%* @param _cstUseAnalysisResults - conditional - The study-specific analysis      *;
%*            results metadata are used to provide report metadata.               *;
%*            If _cstDisplaySrc=Metadata, either this parameter or _cstUseTLFddt  *;
%*            must be set to Y. If both _cstUseAnalysisResults and _cstUseTLFddt  *;
%*            are set to Y, _cstUseAnalysisResults takes precedence.              *;
%*            Values:  N | Y                                                      *;
%*            Default: Y                                                          *;
%* @param _cstUseTLFddt - conditional - The study-specific mock table shell       *;
%*            metadata (known as Tables, Listings, and Figures data definition    *;
%*            metadata (TLFDDT)) are used to provide report metadata.             *;
%*            If _cstDisplaySrc=Metadata, either this parameter or                *;
%*            _cstUseAnalysisResults must be set to Y. If both                    *;
%*            _cstUseAnalysisResults and _cstUseTLFddt are set to Y,              *;
%*            _cstUseAnalysisResults takes precedence.                            *;
%*            Values:  N | Y                                                      *;
%*            Default: Y                                                          *;
%* @param _cstDisplayID - conditional - The ID of the display from the designated *;
%*            metadata source. If _cstDisplaySrc=Metadata, this parameter is      *;
%*            required.                                                           *;
%* @param _cstDisplayPath - optional - A valid filename or the fully qualified    *;
%*            path to the generated display. If not provided, the code looks in   *;
%*            SASReferences for type=report.                                      *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure external                                                             *;

%macro adam_createdisplay (
    _cstDisplaySrc=Metadata,
    _cstDisplayCode=,
    _cstUseAnalysisResults=,
    _cstUseTLFddt=,
    _cstDisplayID=,
    _cstDisplayPath=
    ) /des='CST: Create ADaM analysis result display';


  %local
    _cstactual
    _cstCTCnt
    _cstCTLibrary
    _cstCTMember
    _cstCTPath
    _cstDir
    _cstDispAnalvar
    _cstDispCode
    _cstDispDatasets
    _cstDispID
    _cstDisplayFormat
    _cstDispName
    _cstDispParam
    _cstDispParamcd
    _cstDispPath
    _cstDispProgstmt
    _cstDispSelcrit
    _cstError
    _cstExitError
    _cstFileref
    _cstrundt
    _cstRC
    _cstRecordCnt
    _cstReportFile
    _cstReportLib
    _cstSrcDataLib
    _cstSrcmetaAnalysisDS
    _cstSrcmetaLib
    _cstTLFLibrary
    _cstTLFmapRef
    _cstTLFxmlLib
    _cstTLFxmlRef
  ;

  %let _cstactual=;
  %let _cstCTCnt=0;
  %let _cstCTLibrary=;
  %let _cstCTMember=;
  %let _cstCTPath=;
  %let _cstDispCode=;
  %let _cstDisplayFormat=;
  %let _cstDispID=&_cstDisplayID;
  %let _cstDispPath=;
  %let _cstExitError=0;
  %let _cstRecordCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstSrcDataLib=;
  %let _cstSrcmetaAnalysisDS=;
  %let _cstSrcmetaLib=;
  %let _cstrundt=;
  %let _cstSeqCnt=0;
  %let _cstTLFLibrary=WORK;
  %let _cstTLFmapRef=;
  %let _cstTLFxmlLib=;
  %let _cstTLFxmlRef=;


  %* Write information about this process to the results data set  *;
  %if %symexist(_cstResultsDS) %then
  %do;

    data _null_;
      call symputx('_cstrundt',put(datetime(),is8601dt.));
    run;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstStandard,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStandardVersion,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: ADAM_CREATEDISPLAY,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: REPORTING,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstsasrefs,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
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
    %end;

  %end;

  %cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSrcDataLib,_cstAllowZeroObs=1);

  %if %length(&_cstDisplayPath)<1 %then
  %do;

    %* No output location is provided for the display, so we will go look in SASReferences *;
    %* First see if there is a record pointing to a specific output file - if so, use it.  *;
    %*  If not, see if there is a record pointing to a generic output folder.  If so, the  *;
    %*  display will be output there using _cstDispID as the display file name.         *;
    %* Otherwise, follow the same logic to create the display in the WORK folder.          *;
    %let _cstReportLib=;
    %let _cstReportFile=;
    %cstutil_getsasreference(_cstSASRefType=report,_cstSASRefSubtype=outputfile,_cstSASRefsasref=_cstReportLib,
        _cstSASRefmember=_cstReportFile,_cstAllowZeroObs=1);
    %if %length(&_cstReportFile)<1 %then
    %do;

      %if ^%symexist(_cstDefaultReportFormat) %then
      %do;
        %global _cstDefaultReportFormat;
        %let _cstDefaultReportFormat=pdf;
      %end;
      %else %if %length(&_cstDefaultReportFormat)<1 %then
        %let _cstDefaultReportFormat=pdf;

      %cstutil_getsasreference(_cstSASRefType=report,_cstSASRefSubtype=library,_cstSASRefsasref=_cstReportLib,_cstAllowZeroObs=1);
      %if %length(&_cstReportLib)<1 %then
        %let _cstDispPath=&workpath/&_cstDisplayID..&_cstDefaultReportFormat;
      %else
        %let _cstDispPath=%sysfunc(pathname(&_cstReportLib))/&_cstDisplayID..&_cstDefaultReportFormat;

      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=%str(No report destination specified so the default report output location has been set to &_cstDispPath),
                           _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&sysmacroname);
    %end;
    %else
      %let _cstDispPath=%sysfunc(pathname(&_cstReportLib));
    %let _cstDisplayFormat=&_cstDefaultReportFormat;
    %let _cstDisplayPath=&_cstDispPath;

  %end;
  %else
  %do;
    %* Does the parameter value contain path or file separators?   *;
    %* If so, treat it as a path.  If not, treat it as a fileref.  *;
    %if (%sysfunc(kindexc(&_cstDisplayPath,':\/.'))=0) %then %do;
      %* Assume this is a fileref  *;
      %let _cstDispPath=%sysfunc(pathname(&_cstDisplayPath));
    %end;
    %else %do;
      %* Assume this is a path  *;
      %let _cstDispPath=&_cstDisplayPath;
    %end;
    data _null_;
      fout=kreverse(kstrip(symget("_cstDispPath")));
      if kindexc(fout,'.')>0 then ffmt=kreverse(ksubstr(fout,1,kindexc(fout,".")-1));
      else ffmt='';
      call symput('_cstDisplayFormat',ffmt);
    run;
  %end;

  %if %upcase(&_cstDisplaySrc)=CODE %then
  %do;
    %if %length(&_cstDisplayCode)<1 %then
    %do;
      %*put ERROR:  Missing required parameter _cstDisplayCode;
      %let _cst_MsgID=CST0081;
      %let _cst_MsgParm1=%str( - _cstDisplayCode);
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstExitError=1;
      %goto exit_error;
    %end;
    %else
    %do;
      %* Does the parameter value contain path or file separators?   *;
      %* If so, treat it as a path.  If not, treat it as a fileref.  *;
      %if (%sysfunc(indexc(&_cstDisplayCode,':\/.'))=0) %then %do;
        %* Assume this is a fileref  *;
        %let _cstDir=%sysfunc(pathname(&_cstDisplayCode));
        %let _cstRC = %sysfunc(filename(_cstFileref,&_cstDir)) ;
        %if ^%sysfunc(fexist(&_cstFileref)) %then
        %do;
          %let _cst_MsgID=CST0202;
          %let _cst_MsgParm1=The fileref specified in the _cstDisplayCode parameter points to a file that cannot be found;
          %let _cst_MsgParm2=;
          %let _cstSrcData=&sysmacroname;
          %let _cstExitError=1;
          %goto exit_error;
        %end;
        %let _cstDispCode=&_cstDir;
        %include &_cstDisplayCode;
      %end;
      %else %do;
        %* Assume this is a path  *;
        %let _cstRC = %sysfunc(filename(_cstFileref,&_cstDisplayCode)) ;
        %if ^%sysfunc(fexist(&_cstFileref)) %then
        %do;
          %let _cst_MsgID=CST0202;
          %let _cst_MsgParm1=The path specified in the _cstDisplayCode parameter points to a file that cannot be found;
          %let _cst_MsgParm2=;
          %let _cstSrcData=&sysmacroname;
          %let _cstExitError=1;
          %goto exit_error;
        %end;
        %let _cstDispCode=&_cstDisplayCode;
        %include "&_cstDisplayCode";
      %end;

      %include &_cstFileref;

      %let _cst_MsgID=CST0200;
      %let _cst_MsgParm1=External code module specified or referenced in the _cstDisplayCode parameter has been included;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstactual=%str(&_cstDisplayCode);
      %let _cstExitError=2;
      %goto exit_error;

    %end;
  %end;
  %else
  %do;
    %if %upcase(&_cstDisplaySrc)^=METADATA %then
    %do;
      %put INFO:  _cstDisplaySrc parameter value is assumed to be METADATA;
    %end;
    %if &_cstUseAnalysisResults=N and &_cstUseTLFddt=N %then
    %do;
      %let _cst_MsgID=CST0202;
      %let _cst_MsgParm1=One or both of the _cstUseAnalysisResults and _cstUseTLFddt parameters must be set to Y;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstExitError=1;
      %goto exit_error;
    %end;
    %if %length(&_cstDisplayID)<1 %then
    %do;
      %*put ERROR:  Missing required parameter _cstDisplayID;
      %let _cst_MsgID=CST0081;
      %let _cst_MsgParm1=%str( - _cstDisplayID);
      %let _cst_MsgParm2=;
      %let _cstSrcData=&sysmacroname;
      %let _cstExitError=1;
      %goto exit_error;
    %end;

    %if &_cstUseAnalysisResults=Y %then
    %do;
      %* Get the libref.dataset of the analysis results metadata ;
      %cstutil_getsasreference(_cstSASRefType=sourcemetadata,_cstSASRefSubtype=analyses,_cstSASRefsasref=_cstSrcmetaLib,
          _cstSASRefmember=_cstSrcmetaAnalysisDS);
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0202;
        %let _cst_MsgParm1=A valid value for analysis results metadata could not be found in SASReferences;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstExitError=2;
        %goto exit_error;
      %end;

      %* Check that _cstDisplayID exists in the data set  *;
      data work.thisdisplay;
        set &_cstSrcmetaLib..&_cstSrcmetaAnalysisDS (where=(dispid="&_cstDisplayID")) end=last;
        call symputx('_cstRecordCnt',_n_);;
      run;
      %if &_cstRecordCnt=0 %then
      %do;
        %let _cst_MsgID=CST0201;
        %let _cst_MsgParm1=The specified display could not be found in the display metadata;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstactual=%str(&_cstDisplayID);
        %let _cstExitError=2;
        %goto exit_error;
      %end;
      %else %if &_cstRecordCnt>1 %then
      %do;
        %let _cst_MsgID=CST0201;
        %let _cst_MsgParm1=Multiple records found in the display metadata for the specified display;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstactual=%str(&_cstDisplayID);
        %let _cstExitError=2;
        %goto exit_error;
      %end;

      %*******************************************************************************************************;
      %* Use of the analysis results data set requires that certain conventions be accepted and followed :   *;
      %*  (1) DISPID contains the unique display identifier                                                  *;
      %*  (2) There is only one record per DISPID                                                            *;
      %*  (3) DATASETS may contain one or more space-delimited ADaM source data sets.  If there is more      *;
      %*      than 1 data set, it is assumed that the PROGSTMT code will correctly join/merge those files    *;
      %*      as needed.                                                                                     *;
      %*  (4) SELCRIT, if non-null, should be a valid SAS where clause that may be successfully applied to   *;
      %*      DATASETS.                                                                                      *;
      %*  (5) PROGSTMT may contain either executable SAS code OR a fully-qualified path to a code module     *;
      %*      that Toolkit can reach.  If the first segment of PROGSTMT (defined as all bytes prior to a     *;
      %*      space) contains at least two path delimiters (/\:.), it will be interpreted as the             *;
      %*      fully-qualified path to the code module to-be-used.  Otherwise, the entire field will be       *;
      %*      assumed to be an executable SAS code segment.                                                  *;
      %*  (6) If PARAM, PARAMCD and ANALVAR are non-null, it is assumed that they are columns in the data    *;
      %*      set identified in DATASETS.                                                                    *;
      %*******************************************************************************************************;

      %let _cstDispID=;
      %let _cstDispName=;
      %let _cstDispParam=;
      %let _cstDispParamcd=;
      %let _cstDispAnalvar=;
      %let _cstDispDatasets=;
      %let _cstDispSelcrit=;
      %let _cstDispProgstmt=;
      %let _cstError=0;

      data _null_;
        set work.thisdisplay;
        
          attrib _cstnewpath format=$2000.;

          * Read and make available relevant metadata fields to any code submitted below  *;
          call symputx('_cstDispID',cats('%nrstr( ',DISPID,' )'));
          call symputx('_cstDispName',cats('%nrstr( ',DISPNAME,' )'));
          call symputx('_cstDispParam',cats('%nrstr( ',PARAM,' )'));
          call symputx('_cstDispParamcd',PARAMCD);
          call symputx('_cstDispAnalvar',ANALVAR);
          call symputx('_cstDispDatasets',DATASETS);
          call symputx('_cstDispSelcrit',cats('%nrstr( ',SELCRIT,' )'));
          call symputx('_cstDispProgstmt',cats('%nrstr( ',PROGSTMT,' )'));

          * Does PROGSTMT contain path or file separators?   *;
          if kindexc(PROGSTMT,':\/.')>0 then
          do;
            _cstnewpath=strip(resolve(PROGSTMT));
            rc=filename("_cstcode",_cstnewpath);
            did=fopen("_cstcode");
            if did = 0 then
            do;
              call symputx('_cstError',1);
              call symputx('_cst_MsgID','CST0008');
              call symputx('_cstactual',catx('=','PROGSTMT',kstrip(PROGSTMT)));
              call symputx('_cst_MsgParm1','The code segment parsed from the Analysis Results PROGSTMT column');
              call symputx('_cst_MsgParm2','');
            end;
            else do;
              did=dclose(did);
              call symputx('_cst_MsgParm1','The external code module specified or referenced from the Analysis Results PROGSTMT column has been included');
              call symputx('_cstactual',kstrip(PROGSTMT));
              call symputx('_cstDispCode',kstrip(PROGSTMT));
              call execute("%include _cstcode;");
            end;
          end;
          else
          do;
            call symputx('_cst_MsgParm1','The full Analysis Results PROGSTMT column contents were submitted');
            call symputx('_cstDispCode','<See Analysis Results PROGSTMT column contents>');
            call execute(PROGSTMT);
          end;

      run;

      %if &_cstError=1 %then
      %do;
        %let _cstSrcData=&sysmacroname;
        %let _cstExitError=1;
        %goto exit_error;
      %end;

    %end;
    %else %if &_cstUseTLFddt=Y %then
    %do;

      %* Get the fileref of the tlf xml file ;
      %cstutil_getsasreference(_cstSASRefType=externalxml,_cstSASRefSubtype=tlfxml,_cstSASRefsasref=_cstTLFxmlRef);
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0202;
        %let _cst_MsgParm1=The TLF xml file reference could not be found in SASReferences;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstExitError=2;
        %goto exit_error;
      %end;
      %let _cstTLFxmlLib=&_cstTLFxmlRef;

      %* Get the fileref of the tlf map file ;
      %cstutil_getsasreference(_cstSASRefType=referencexml,_cstSASRefSubtype=tlfmap,_cstSASRefsasref=_cstTLFmapRef);
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0202;
        %let _cst_MsgParm1=The TLF map file reference could not be found in SASReferences;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstExitError=2;
        %goto exit_error;
      %end;

      libname &_cstTLFxmlLib xml XMLMAP=&_cstTLFmapRef;

      %* Get all tlf metadata in work files (default parameters) *;
      %adamutil_gettlfmetadata(_cstOutLib=&_cstTLFLibrary);

      %* Set tlf metadata into macro variables *;
      %adamutil_settlfparmvalues(_cstTLFDS=tlf_master);

      %* Include the specific tlf code segment;
      %let _cstDispCode=&_CSTTLF_MASTERCODEPATH;
      options source2;
      %include "&_CSTTLF_MASTERCODEPATH";

      %let _cstSrcData=&sysmacroname;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0200,
          _cstResultParm1=Display location - &_cstDispPath,_cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);

    %end;

  %end;

%cstutil_saveresults();

%exit_error:

    %if &_cstExitError=1 %then
    %do;
      %put ********************************************************;
      %put ERROR: Fatal error encountered, process cannot continue.;
      %put ********************************************************;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
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
    %end;
    %else %if &_cstExitError=2 %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

  %if &_cstDebug=0 %then
  %do;
  %end;
  %else
  %do;
    %put <<< adam_createdisplay;
    %put _all_;
  %end;

%mend adam_createdisplay;
