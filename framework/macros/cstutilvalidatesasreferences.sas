%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilvalidatesasreferences                                                   *;
%*                                                                                *;
%* Validates the structure and content of a SASReferences data set.               *;
%*                                                                                *;
%* This macro is typically used is these ways:                                    *;
%*   1. As a part of the normal process setup, called either prior to or as a     *;
%*      part of cstutil_allocatesasreferences()                                   *;
%*   2. As a standalone call outside the context of use within the SAS Clinical   *;
%*      Toolkit process setup                                                     *;
%*                                                                                *;
%* The macro sets the _cst_rc and _cst_rcmsg global macro variables to indicate   *;
%* that the SASReferences data set is valid (_cst_rc=0) or not valid              *;
%* (_cst_rc ne 0).                                                                *;
%*                                                                                *;
%* These are the conditions that are checked by this macro:                       *;
%*   1. The data set is structurally correct. (CHK01)                             *;
%*   2. An unknown standard or standardversion exists. (CHK02)                    *;
%*   3. The referenced input and output files and folders can be accessed. (CHK03)*;
%*   4. All required look-throughs to Global Library defaults work. (CHK04)       *;
%*   5. All discrete character field values are found in the standard lookup.     *;
%*      (CHK05)                                                                   *;
%*   6. For the given context, path and memname macro variables are resolved.     *;
%*      (CHK06)                                                                   *;
%*   7. Multiple fmtsearch records exist but valid ordering is not provided.      *;
%*      (CHK07)                                                                   *;
%*   8. Multiple autocall records exists but valid ordering is not provided.      *;
%*      (CHK08)                                                                   *;
%*                                                                                *;
%* @macvar _cstDeBug       Turns debugging on or off for the session              *;
%* @macvar _cstMessages    Cross-standard work messages data set                  *;
%* @macvar _cst_MsgID      Results: Result or validation check ID                 *;
%* @macvar _cst_MsgParm1   Messages: Parameter 1                                  *;
%* @macvar _cst_MsgParm2   Messages: Parameter 2                                  *;
%* @macvar _cstSASRefs     Run-time SASReferences data set derived in process     *;
%*                         setup                                                  *;
%* @macvar _cstSASRefsLoc  SASReferences file location                            *;
%* @macvar _cstSASRefsName SASReferences file name                                *;
%* @macvar _cstSeqCnt      Results: Sequence number within _cstResultSeq          *;
%* @macvar _cstResultSeq   Results: Unique invocation of check                    *;
%* @macvar _cst_rc         Task error status                                      *;
%* @macvar _cst_rcmsg      Message associated with _cst_rc                        *;
%* @macvar _cstLRECL       Logical record length setting for filename statement   *;
%*                                                                                *;
%* @param _cstDSName  -required - The SASReferences data set in the format        *;
%*            (libname.)member. If a value is not provided, this macro attempts to*;
%*            derive a value by using the following sequence:                     *;
%*                1. Use the global macro variables _cstSASRefsLoc and            *;
%*                   _cstSASRefsName.                                             *;
%*                2. Use the global macro variable _cstSASRefs.                   *;
%*                3. Abort.                                                       *;
%* @param _cstStandard - required - The name of a registered standard.            *;
%*            Default: CST-FRAMEWORK                                              *;
%* @param _cstStandardVersion - required - The version of a registered standard.  *;
%*            Default: 1.2                                                        *;
%* @param _cstSASRefsGoldStd - required - The comparative gold standard against   *;
%*            which this SASReferences file is compared. By default, the Global   *;
%*            Library metadata standardsasreferences is assumed. If provided, use *;
%*            the format (libname.)member.                                        *;
%* @param _cstallowoverride - optional - Ignore one or more of the conditions     *;
%*            defined above. Specify the check code in a blank-delimited string   *;
%*            (for example, CHK01 CHK07). If null, all conditions are tested.     *;
%* @param _cstResultsType - required - Report findings in the SAS log or in the   *;
%*            Results data set.                                                   *;
%*            Values: LOG | RESULTS                                               *;
%*            Default: LOG                                                        *;
%* @param _cstPreAllocated - required - Allocate librefs and filerefs when this   *;
%*            macro is called. If not, validation of data sets and catalogs is    *;
%*            performed based on paths and memnames, not libref.memnames.         *;
%*            Values: N|Y                                                         *;
%*            Default: N                                                          *;
%* @param _cstVerbose - required - Report specific problems and the absence of    *;
%*            problems. Otherwise, report only success or failure in _cst_rc.     *;
%*            Values: N|Y                                                         *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @history 2013-12-04 Now temporarily allocate _cstCWA in CHK03 when             *; 
%*            _cstPreAllocated=N for verification of SAS files.                   *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilvalidatesasreferences (
    _cstDSName=&_cstSASRefs,
    _cstStandard=CST-FRAMEWORK,
    _cstStandardversion=1.2,
    _cstSASRefsGoldStd=,
    _cstallowoverride=,
    _cstResultsType=LOG,
    _cstPreAllocated=N,
    _cstVerbose=N
    ) / des='CST: Validate sasreferences';


  %* Declare local variables used in the macro      *;
  %* This list excludes (internal) macro parameters *;
  %local
    _cstContext
    _cstCurrentStyle
    _cstDataRecords
    _cstDeallocateTemplateLib
    _cstDeallocateTempLib0
    _cstDeallocateLookupLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstIncludeCode
    _cstNeedToDeleteMsgs
    _cstNumErrorRecs
    _cstOverrideCheck
    _cstRandom
    _cstSrcMacro
    _cstStdLookupDS
    _cstStdLookupLib
    _cstStdLookupPath
    _cstTemplateLib
    _cstTempDS
    _cstTempLib0
    _cstTempPath
    _cstThisDeBug
    _cstThisMacroRC
    _cstThisMacroRCmsg
    ;

  %* We will use the absence of the _cstSASRefsLoc, _cstSASRefsName, and _cstGRoot global       *;
  %*  macro variables as an indication that this macro is being called independent of a typical *;
  %*  CST process.                                                                              *;
  %if (%eval(not %symexist(_cstSASRefsLoc)) or %eval(not %symexist(_cstSASRefsName)) or
       %eval(not %symexist(_cstGRoot))) %then
  %do;
    %if %symexist(_cstDeBug) %then
      %let _cstThisDeBug=&_cstDeBug;
    %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
    %if &_cstThisDeBug>0 %then
      %let _cstDeBug=&_cstThisDeBug;
    %let _cstContext=STANDALONE;
  %end;
  %* If there is any problem entering this method, abort and do not run  *;
  %else %if (&_cst_rc) %then %do;
    %goto EXIT_ABORT;
  %end;

  %* Check for the presence of the messages data set, required when writing to a results data set *;
  %if (^%sysfunc(exist(&_cstMessages))) %then %do;
    %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);
  %end;

  %* Initialize local macro variables as needed *;
  %let _cstThisMacroRC=0;
  %let _cstNumErrorRecs=0;
  %let _cstCurrentStyle=0;
  %let _cstDataRecords=0;
  %let _cstSrcMacro=&SYSMACRONAME;

  %* Retrieve static variables  *;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib0=_cst&_cstRandom;

  %* SASReferences must be provided in a STANDALONE context *;
  %if %upcase(&_cstContext)=STANDALONE %then
  %do;
    %if (%length(&_cstDSName)=0) %then %do;
      %* SAS References not specified in the _cstDSName parameter;
      %goto NO_SASREFS;
    %end;
  %end;

  * Assign the libname to the global metadata library;
  libname cstMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  %* Pre-requisite: _cstDSName must be passed in (or provided as global macro variables);
  %if (%length(&_cstDSName)=0) %then %do;
    %* try to use global macro variables;
    %if ((%symexist(_cstSASRefsLoc)=1) AND (%symexist(_cstSASRefsName)=1)) %then %do;
      %* check that the macro vars specifying path/data set have values;
      %if ((%length(&_cstSASRefsLoc)>0) and (%length(&_cstSASRefsName)>0)) %then %do;
        libname &_cstTempLib0 "%unquote(&_cstSASRefsLoc)";
        %let _cstDeallocateTempLib0=Y;
        %* check that the data set exists;
        %if (%sysfunc(exist(&_cstTempLib0..&_cstSASRefsName))) %then %do;
           %let _cstDSName=&_cstTempLib0..&_cstSASRefsName;
        %end;
        %else %do;
          * Clear the libname;
          libname &_cstTempLib0 ;
          %let _cstDeallocateTempLib0=N;

          %* SAS References does not exist using the global macro variables;
          %goto NO_SASREFS;
        %end;

      %end;
      %* check that the macro vars specifying path/data set have values;
      %else %do;
        %if (%symexist(_cstSASRefs)=1) %then %do;
          %if (%length(&_cstSASRefs)>0) %then %do;
            %let _cstDSName=&_cstSASRefs;
          %end;
        %end;
      %end;

    %end;
    %* macro vars specifying path/data set do not exist so use the cstSASRefs;
    %else %do;
      %if (%symexist(_cstSASRefs)=1) %then %do;
        %if (%length(&_cstSASRefs)>0) %then %do;
          %let _cstDSName=&_cstSASRefs;
        %end;
      %end;
    %end;

    %if (%length(&_cstDSName)=0) %then %do;
      %* SAS References not passed in and no global macro variables supplied;
      %goto NO_SASREFS;
    %end;
  %end;

  %if (^%sysfunc(exist(&_cstDSName))) %then %do;
    %* SASReferences data set does not exist;
    %goto SASREFS_NOTFOUND;
  %end;

  %let dsid=%sysfunc(open(&_cstDSName,i));
  %if (&dsid = 0) %then %do;
    %* SASReferences data set cannot be opened;
    %goto NO_SASREFSOPEN;
  %end;
  %let anyobs=%sysfunc(attrn(&dsid,ANY));
  %if &anyobs le 0 %then %do;
    %let dsid=%sysfunc(close(&dsid));
    %* SASReferences data set does not have any obs;
    %goto NO_SASREFSOBS;
  %end;
  %let dsid=%sysfunc(close(&dsid));

  %* Defaults are set to CST-FRAMEWORK  *;
  %if (%length(&_cstStandard)=0) %then %do;
    %let _cstStandard=CST-FRAMEWORK;
  %end;
  %if (%length(&_cstStandardVersion)=0) %then %do;
    %let _cstStandardVersion=1.2;
  %end;

  proc sql noprint;
    select standard,standardversion
      from cstMDLib.&_cstGlobalStdDS
        where (upcase(standard)="&_cstStandard" and upcase(standardversion)="&_cstStandardVersion");
  quit;
  %if &sqlobs=0 %then %do;
    %goto NO_STD;
  %end;

  %if (%length(&_cstSASRefsGoldStd)>0) %then %do;
    %* User is overriding the default Gold Standard  *;
    %if ^%sysfunc(exist(&_cstSASRefsGoldStd)) %then
    %do;
      %* Gold standard passed in does not exist *;
      %goto NO_GOLDSTD;
    %end;
  %end;
  %else %do;
    %if (%symexist(_cstStdSASRefs)=1) %then %do;
      %if (%length(&_cstStdSASRefs)>0) %then %do;
        %let _cstSASRefsGoldStd=&_cstStdSASRefs;
      %end;
      %else
      %do;
        %* Set the Gold standards to the Global Library standardsasreferences data set  *;
        %let _cstSASRefsGoldStd=cstMDLib.&_cstGlobalStdSASRefsDS;
      %end;
    %end;
    %else
    %do;
      %* Set the Gold standards to the Global Library standardsasreferences data set  *;
      %let _cstSASRefsGoldStd=cstMDLib.&_cstGlobalStdSASRefsDS;
    %end;
  %end;
  %if (%length(&_cstResultsType)=0) %then %do;
    %let _cstResultsType=LOG;
  %end;

%* End of parameter qualification  *;


%* Determine whether SASReferences contains new (CST 1.5 ->) columns  *;
%* Set the _cstCurrentStyle macro accordingly                         *;
data _null_;
  dsid=open("&_cstDSName");
  if dsid ne 0 then
  do;
    if varnum(dsid,'IOTYPE')>0 or varnum(dsid,'FILETYPE')>0 or
       varnum(dsid,'ALLOWOVERWRITE')>0 or varnum(dsid,'RELPATHPREFIX')>0 or
       varnum(dsid,'ENGINE')>0 or varnum(dsid,'REFTYPEOPTIONS')>0 then
         call symputx('_cstCurrentStyle',1);
    rc=close(dsid);
  end;
run;


%**********************************************************************;
%* Internal helper macros                                             *;
%* (convenience macros supporting repetitive calls throughout module) *;
%**********************************************************************;

%macro _cstOverride(_cstChkID=);
  %*********************************************************************************************;
  %* _cstOverride                                                                              *;
  %*   _cstChkID is check number (e.g. CHK01) -- see header                                    *;
  %*********************************************************************************************;

  %if (%length(&_cstallowoverride)>0) %then %do;
    %do _chk=1 %to %SYSFUNC(countw(&_cstallowoverride,' '));
      %if %SYSFUNC(scan(&_cstallowoverride,&_chk,' '))=&_cstChkID %then
      %do;
        %let _cstOverrideCheck=1;
        %return;
      %end;
    %end;
  %end;
%mend;

%macro _cstReportProblem(_cstLogMsg=,_cstRsltID=,_cstChkID=,_cstMsg1=,_cstMsg2=,_cstActVar=,_cstKeyVar=,
                         _cstParmVar1=,_cstParmVar2=);
  %*********************************************************************************************;
  %* _cstReportProblem                                                                         *;
  %*   _cstLogMsg is message text to report in the LOG                                         *;
  %*   _cstRsltID is the error number (e.g. CST0008) to report in the results data set         *;
  %*   _cstChkID is check number (e.g. CHK01, see header) to report in the results data set    *;
  %*   _cstMsg1 is message parameter 1 if needed by _cstChkID                                  *;
  %*   _cstMsg2 is message parameter 2 if needed by _cstChkID                                  *;
  %*   _cstActVar is the column in _cstProblems to report error values in the results data set *;
  %*   _cstKeyVar is the column in _cstProblems to report key values in the results data set   *;
  %*   _cstParmVar1 is the column in _cstProblems to use as message parameter 1                *;
  %*   _cstParmVar2 is the column in _cstProblems to use as message parameter 2                *;
  %*********************************************************************************************;

  %* Reset counter each call *;
  %let _cstDataRecords=0;

  %if %sysfunc(exist(work._cstproblems)) %then
  %do;
    data _null_;
      if 0 then set work._cstproblems nobs=_numobs;
      call symputx('_cstDataRecords',_numobs);
      stop;
    run;
  %end;

  * One or more problems were found *;
  %if &_cstDataRecords %then
  %do;
    %if &_cstDeBug %then
    %do;
      %* Keep problems data set around *;
      data work._cstProblems_&_cstChkID;
        set work._cstProblems;
      run;
    %end;

    %let _cstDataRecords=0;
    %let _cstNumErrorRecs=%eval(&_cstNumErrorRecs+1);

    %if %upcase(&_cstResultsType)=RESULTS %then
    %do;

      data work._cstproblems (label='Work error data set');
        %cstutil_resultsdskeep;
          set work._cstproblems end=last;

            attrib
              _cstSeqNo format=8. label="Sequence counter for result column"
              _cstMsgParm1 format=$char100. label="Message parameter value 1 (temp)"
              _cstMsgParm2 format=$char100. label="Message parameter value 2 (temp)"
            ;

            retain _cstSeqNo 0;
            if _n_=1 then _cstSeqNo=&_cstSeqCnt;

            keep _cstMsgParm1 _cstMsgParm2;

            * Set results data set attributes *;
            %cstutil_resultsdsattr;
            retain message resultseverity resultdetails '';

            resultid="&_cstRsltID";
            checkid="&_cstChkID";
  %if (%length(&_cstParmVar1)>0) %then %do;
            _cstMsgParm1=&_cstParmVar1;
  %end;
  %else %do;
            _cstMsgParm1="&_cstMsg1";
  %end;
  %if (%length(&_cstParmVar2)>0) %then %do;
            _cstMsgParm2=&_cstParmVar2;
  %end;
  %else %do;
            _cstMsgParm2="&_cstMsg2";
  %end;
            resultseq=1;
            resultflag=1;
            srcdata = upcase("&_cstDSName");
  %if (%length(&_cstActVar)>0) %then %do;
            actual=&_cstActVar;
  %end;
  %if (%length(&_cstKeyVar)>0) %then %do;
            keyvalues=&_cstKeyVar;
  %end;
            _cst_rc=&_cst_rc;

            _cstSeqNo+1;
            seqno=_cstSeqNo;

        if last then
        do;
          call symputx('_cstSeqCnt',_cstSeqNo);
          call symputx('_cstDataRecords',_n_);
        end;
      run;

      %* Parameters passed are check-level -- not record-level -- values *;
      %cstutil_appendresultds(
                           _cstErrorDS=work._cstproblems
                          ,_cstVersion=&_cstStandardVersion
                          ,_cstSource=CST
                          ,_cstStdRef=
                          ,_cstOrderBy=%str(checkid,resultseq,seqno));

    %end;
    %else %do;
      %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cstLogMsg;
    %end;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstproblems);
  %end;

%mend;

%macro _cstProblemIgnored(_cstLogMsg=,_cstRsltID=,_cstChkID=);
  %*********************************************************************************************;
  %* _cstProblemIgnored                                                                        *;
  %*   _cstLogMsg is message text to report in the LOG                                         *;
  %*   _cstRsltID is the error number (e.g. CST0008) to report in the results data set         *;
  %*   _cstChkID is check number (e.g. CHK01, see header) to report in the results data set    *;
  %*********************************************************************************************;

    %if &_cstResultsType=RESULTS %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cstRsltID
                  ,_cstValCheckID=&_cstChkID
                  ,_cstResultParm1=%str(&_cstLogMsg)
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=%upcase(&_cstDSName)
                  ,_cstResultFlagParm=0
                  );
    %end;
    %else %do;
      %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] WARN%STR(ING): &_cstLogMsg;
    %end;

%mend;

%macro _cstCheckForProblem(_cstRsltID=,_cstChkID=);
  %*********************************************************************************************;
  %* _cstCheckForProblem                                                                       *;
  %*   _cstRsltID is the error number (e.g. CST0008) to report in the results data set         *;
  %*   _cstChkID is check number (e.g. CHK01, see header) to report in the results data set    *;
  %*********************************************************************************************;

  %* _cst_rc will have been set by a prior call if a problem was detected in another macro *;
  %if &_cst_rc %then
  %do;
    %let _cst_rc=0;
    %let _cstNumErrorRecs=%eval(&_cstNumErrorRecs+1);
    %if &_cstResultsType=RESULTS %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cstRsltID
                  ,_cstValCheckID=&_cstChkID
                  ,_cstResultParm1=%str(&_cst_rcmsg)
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=%upcase(&_cstDSName)
                  ,_cstResultFlagParm=1
                  ,_cstRCParm=&_cst_rc
                  );
    %end;
    %else %do;
      %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cst_rcmsg;
    %end;
    %let _cst_rcmsg=;
  %end;

%mend;

%* End of internal macro specification  *;


%*****************************************;
%* CHK01                                 *;
%* Is the data set structurally correct? *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK01);
%if &_cstOverrideCheck=0 %then
%do;

  * Point to the standard-specific lookup data set *;
  data _null_;
     set &_cstSASRefsGoldStd (where=(upcase(standard)=upcase(kstrip("&_cstStandard")) and upcase(standardversion)=upcase(kstrip("&_cstStandardVersion")) and
            upcase(type)='CSTMETADATA' and upcase(subtype)='LOOKUP'));
       call symputx('_cstStdLookupPath',path);
       call symputx('_cstStdLookupLib',sasref);
       call symputx('_cstStdLookupDS',kstrip(scan(memname,1,'.')));
  run;

  %if (%length(&_cstStdLookupLib)>0) %then %do;

    %if %length(%sysfunc(pathname(&_cstStdLookupLib,'L')))<1 %then
    %do;
       libname &_cstStdLookupLib "&_cstStdLookupPath";
       %let _cstDeallocateLookupLib=Y;
    %end;

    data _null_;
      set &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(value)='SASREFERENCES'));
        call symputx('_cstTempDS',kstrip(template));
        call symputx('_cstTemplateLib',kstrip(scan(template,1,'.')));
    run;

    %if (%length(&_cstTemplateLib)>0) %then %do;

      %if %length(%sysfunc(pathname(&_cstTemplateLib,'L')))<1 %then
      %do;
        data _null_;
           set &_cstSASRefsGoldStd (where=(upcase(standard)=upcase(kstrip("&_cstStandard")) and upcase(standardversion)=upcase(kstrip("&_cstStandardVersion")) and
                  upcase(sasref)=upcase(kstrip("&_cstTemplateLib"))));
             call symputx('_cstTempPath',path);
        run;

        libname &_cstTemplateLib "&_cstTempPath";
        %let _cstDeallocateTemplateLib=Y;
      %end;


      %cstutilcomparestructure(_cstBaseDSName=&_cstTempDS,
                               _cstCompDSName=&_cstDSName,
                               _cstReturn=_cst_rc,
                               _cstReturnMsg=_cst_rcmsg,
                               _cstResultsDS= work._cstproblems);

      %if %sysfunc(exist(work._cstProblems)) %then
      %do;
        data _null_;
          %if %symexist(_cstStrictValidation) %then
          %do;
            %if &_cstStrictValidation=1 %then
            %do;
              * ANY difference is to be reported *;
              if 0 then set work._cstProblems nobs=_numobs;
            %end;
            %else %do;
              %if &_cst_rc>15 %then %do;
                * At least one serious difference was detected *;
                * All differences are to be reported *;
                if 0 then set work._cstProblems nobs=_numobs;
              %end;
              %else %do;
                _numobs=0;
              %end;
            %end;
          %end;
          %else %do;
            %if &_cst_rc>15 %then %do;
              * At least one serious difference was detected *;
              * All differences are to be reported *;
              if 0 then set work._cstProblems nobs=_numobs;
            %end;
            %else %do;
              _numobs=0;
            %end;
          %end;
          call symputx('_cstDataRecords',_numobs);
          stop;
        run;
      %end;

      * One or more errors were found*;
      %if &_cstDataRecords %then
      %do;
        %*******differences found in the dataset structure*********;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %let _cst_rc=0;
        %***let _cst_rcmsg=&_cstDataRecords differences found between template and SASReferences data sets;

        %if %upcase(&_cstResultsType)=LOG %then
        %do;
          %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cst_rcmsg;
        %end;
        %else %do;
          %cstutil_writeresult(
                   _cstResultID=CST0202
                   ,_cstValCheckID=CHK01
                   ,_cstResultParm1=&_cst_rcmsg
                   ,_cstResultParm2=
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=%upcase(&_cstDSName)
                   ,_cstResultFlagParm=1
                   ,_cstRCParm=&_cst_rc
                   );
        %end;

        data work._cstProblems;
          set work._cstProblems;
            attrib _cstactual format=$200.;
          select;
            when(upcase(issue) in ('BASEVAR' 'COMPVAR' 'DSLABEL'))
              _cstactual=catx(',',cats('expected=',baseValue),cats("&_cstDSName=",compValue));
            otherwise
              _cstactual=catx(',',cats('Variable=',name),cats('expected=',baseValue),cats("&_cstDSName=",compValue));
          end;

        run;

        %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0202,_cstChkID=CHK01,
                           _cstActVar=_cstactual,_cstParmVar1=description);

      %end;
    %end;
    %else %do;
      %* Unable to perform check  *;
      %_cstProblemIgnored(_cstLogMsg=%str(Check not run: Template information from the standardlookup data set could not be found),
           _cstRsltID=CST0200,_cstChkID=CHK01);
    %end;
  %end;
  %else %do;
    %* Unable to perform check  *;
    %_cstProblemIgnored(_cstLogMsg=%str(Check not run: Template information from the standardlookup data set could not be found),
         _cstRsltID=CST0200,_cstChkID=CHK01);
  %end;

  %if &_cstDeBug>0 %then
  %do;
     data work._cstProblemsCHK01;
       set work._cstProblems;
     run;
  %end;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%*****************************************;
%* CHK02                                 *;
%* Unknown standard/standardversion      *;
%* Type=referencecterm are excepted      *;
%* Type=cmplib are excepted              *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK02);
%if &_cstOverrideCheck=0 %then
%do;

  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);
  proc sql noprint;
    create table work._cstProblems as
    select sasref.standard,sasref.standardversion from &_cstDSName sasref
      left join   
    work._cstStandards (keep=standard standardversion) std
    on sasref.standard=std.standard and sasref.standardversion=std.standardversion  
    where missing(std.standard) and 
          ((missing(sasref.standard) and upcase(type) not in ("REFERENCECTERM" "CMPLIB")) or
          (not missing(sasref.standard)));
  quit;  
  data work._cstProblems;
    set work._cstProblems;
      attrib _cstactual format=$200.;
    _cstactual=cats('standard=',kstrip(standard),',standardversion=',kstrip(standardversion));
  run;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstStandards);

  %let _cst_rc=0;
  %let _cst_rcmsg=%upcase(&_cstDSName) contains unknown standard/standardversion;
  %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0202,_cstChkID=CHK02,
                     _cstMsg1=%str(Unknown standard/standardversion),_cstActVar=_cstactual);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;

%*****************************************;
%* CHK03                                 *;
%* Can the referenced input and output   *;
%*  files and folders be reached?        *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK03);
%if &_cstOverrideCheck=0 %then
%do;

  * Handle backward-compatibility:  SASRefs that do not include the columns iotype and filetype  *;
  * In this case (_cstCurrentStyle=0), we are simply not going to perform this check.                *;
  %if &_cstCurrentStyle %then
  %do;

    data _null_;
      attrib _csttemp label="Text string field for file names"  format=$char12.;

      * catalog name for generated info *;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstIncludeCode',_csttemp);
    run;

    filename cstCode CATALOG "work.&_cstIncludeCode..findvalidfile.source" &_cstLRECL;

    data _null_;
      set &_cstDSName (where=(upcase(path) ne upcase(kstrip('&WORKPATH'))));
      file cstCode;
        attrib tempref format=$200.
               tempvar format=$500.
               tempmsg format=$200.;

        select(upcase(filetype));
          when('FOLDER') do;
            *Examples:  sasautos and sourcedata *;
            if path ne '' then
            do;
              if upcase(iotype) in ('INPUT','BOTH') then
              do;
                tempvar=cats('%cstutilfindvalidfile(_cstfiletype=FOLDER,_cstfilepath=',kstrip(path),');');
                put tempvar;
                tempvar='%_cstCheckForProblem(_cstRsltID=CST0202,_cstChkID=CHK03);';
                put tempvar;
              end;
              else if upcase(iotype) in ('OUTPUT') then
              do;
                tempvar=cats('%cstutilcheckwriteaccess(_cstfiletype=FOLDER,_cstfilepath=',kstrip(path),');');
                put tempvar;
                tempvar='%_cstCheckForProblem(_cstRsltID=CST0201,_cstChkID=CHK03);';
                put tempvar;
              end;
            end;
            else
            do;
              * Report missing information, record ignored.  *;
              tempmsg=cats('PATH missing for type=',kstrip(type),',subtype=',kstrip(subtype));
              tempvar=cats('%_cstProblemIgnored(_cstLogMsg=%str(',kstrip(tempmsg),'),_cstRsltID=CST0201,_cstChkID=CHK03);');
              put tempvar;
            end;
          end;
          when('DATASET','CATALOG','VIEW') do;
            *DATASET Examples:  messages and validation_control *;
            *VIEW Examples:  validation_control *;
            *CATALOG Examples:  fmtsearch *;

            %if %upcase(&_cstPreAllocated)=N %then %do;
              if path ne '' and memname ne '' then
              do;
                * Do temporary library allocation so calls to cstutilfindvalidfile and cstutilcheckwriteaccess  *;
                * can pass correct filetype.                                                                    *;
                tempvar=catx(' ','libname _cstCWA',cats('"',kstrip(path),'";'));
                put tempvar;
                tempref=catx('.','_cstCWA',scan(memname,1,'.'));
                if upcase(iotype) in ('INPUT','BOTH') then
                do;
                  tempvar=cats('%cstutilfindvalidfile(_cstfiletype=',upcase(filetype),',_cstfileref=',kstrip(tempref),');');
                  put tempvar;
                  tempvar='%_cstCheckForProblem(_cstRsltID=CST0202,_cstChkID=CHK03);';
                  put tempvar;
                end;
                if upcase(iotype) in ('OUTPUT','BOTH') then
                do;
                  tempvar=cats('%cstutilcheckwriteaccess(_cstfiletype=',upcase(filetype),',_cstfileref=',kstrip(tempref),');');
                  put tempvar;
                  tempvar='%_cstCheckForProblem(_cstRsltID=CST0201,_cstChkID=CHK03);';
                  put tempvar;
                end;
                tempvar='libname _cstCWA;';
                put tempvar;
              end;
              else
              do;
                * Report missing information, record ignored.  *;
                tempmsg=cats('PATH or MEMNAME missing for type=',kstrip(type),',subtype=',kstrip(subtype),',path=',kstrip(path),',memname=',kstrip(memname));
                tempvar=cats('%_cstProblemIgnored(_cstLogMsg=%str(',kstrip(tempmsg),'),_cstRsltID=CST0201,_cstChkID=CHK03);');
                put tempvar;
              end;
            %end;
            %else %do;
              if sasref ne '' and memname ne '' then
              do;
                tempref=catx('.',sasref,kstrip(scan(memname,1,'.')));
                if upcase(iotype) in ('INPUT','BOTH') then
                do;
                  tempvar=cats('%cstutilfindvalidfile(_cstfiletype=',upcase(filetype),',_cstfileref=',kstrip(tempref),');');
                  put tempvar;
                  tempvar='%_cstCheckForProblem(_cstRsltID=CST0202,_cstChkID=CHK03);';
                  put tempvar;
                end;
                if upcase(iotype) in ('OUTPUT','BOTH') then
                do;
                  tempvar=cats('%cstutilcheckwriteaccess(_cstfiletype=',upcase(filetype),',_cstfileref=',kstrip(tempref),');');
                  put tempvar;
                  tempvar='%_cstCheckForProblem(_cstRsltID=CST0201,_cstChkID=CHK03);';
                  put tempvar;
                end;
              end;
              else
              do;
                * Report missing information, record ignored.  *;
                tempmsg=cats('SASREF or MEMNAME missing for type=',kstrip(type),',subtype=',kstrip(subtype),',sasref=',kstrip(sasref),',memname=',kstrip(memname));
                tempvar=cats('%_cstProblemIgnored(_cstLogMsg=%str(',kstrip(tempmsg),'),_cstRsltID=CST0201,_cstChkID=CHK03);');
                put tempvar;
              end;
            %end;
          end;
          when('FILE') do;
            *Examples:  properties and xml *;
            if path ne '' and memname ne '' then
            do;
              * Following statement combines path+memname - not currently a planned parameter value *;
              ***tempref=tranwrd(catx('/',kstrip(tranwrd(path,'\','/')),kstrip(memname)),'//','/');
              if upcase(iotype) in ('INPUT','BOTH') then
              do;
                tempvar=cats('%cstutilfindvalidfile(_cstfiletype=',upcase(filetype),',_cstfilepath=',kstrip(path),',_cstfileref=',kstrip(memname),');');
                put tempvar;
                tempvar='%_cstCheckForProblem(_cstRsltID=CST0202,_cstChkID=CHK03);';
                put tempvar;
              end;
              if upcase(iotype) in ('OUTPUT','BOTH') then
              do;
                tempvar=cats('%cstutilcheckwriteaccess(_cstfiletype=',upcase(filetype),',_cstfilepath=',kstrip(path),',_cstfileref=',kstrip(memname),');');
                put tempvar;
                tempvar='%_cstCheckForProblem(_cstRsltID=CST0201,_cstChkID=CHK03);';
                put tempvar;
              end;
            end;
            else
            do;
              * Report missing information, record ignored.  *;
              tempmsg=cats('PATH or MEMNAME missing for type=',kstrip(type),',subtype=',kstrip(subtype),',path=',kstrip(path),',memname=',kstrip(memname));
              tempvar=cats('%_cstProblemIgnored(_cstLogMsg=%str(',kstrip(tempmsg),'),_cstRsltID=CST0201,_cstChkID=CHK03);');
              put tempvar;
            end;
          end;
          otherwise
          do;
            * Report unknown filetype, record ignored.  *;
            tempmsg=cats('Unknown FILETYPE for type=',kstrip(type),',subtype=',kstrip(subtype),',_cstfiletype=',kstrip(filetype));
            tempvar=cats('%_cstProblemIgnored(_cstLogMsg=%str(',kstrip(tempmsg),'),_cstRsltID=CST0201,_cstChkID=CHK03);');
            put tempvar;
          end;
        end;
    run;

    %if &_cstDeBug %then
    %do;
      options source2;
    %end;

    %include cstCode;

    %if &_cstDeBug %then
    %do;
      options nosource2;
    %end;

    %* clear the filename;
    filename cstCode;

    proc datasets nolist lib=work;
      delete &_cstIncludeCode / mt=catalog;
      quit;
    run;

  %end;
  %else %do;
    %* Unable to perform check  *;
    %_cstProblemIgnored(_cstLogMsg=%str(Check not run: This SASReferences data set does not include new columns introduced in release 1.5),
         _cstRsltID=CST0200,_cstChkID=CHK03);
  %end;

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%*****************************************;
%* CHK04                                 *;
%* Do all required look-thrus to Global  *;
%*  Global Library defaults work?        *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK04);
%if &_cstOverrideCheck=0 %then
%do;

  %* Ignoring *types, are there ANY records where path is null?               *;
  %* Should be run AFTER call to cst_insertStandardSASRefs to be meaningful.  *;
  %* Applicable to within-process use, not STANDALONE                         *;

  data work._cstproblems;
    set &_cstDSName;
      attrib _cstkeys   format=$200.;
    if missing(path) then
    do
      _cstkeys=catx(',',cats('standard=',standard),cats('standardversion=',standardversion),
                      cats('type=',type),cats('subtype=',subtype));
      output;
    end;
  run;

  %if %upcase(&_cstContext) ne STANDALONE %then
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=%str(%ERROR: %upcase(&_cstDSName) contains null PATH value);
    %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0088,_cstChkID=CHK04,
                       _cstMsg1=%upcase(&_cstDSName),_cstMsg2=PATH,_cstKeyVar=_cstkeys);
  %end;
  %else %do;
    %if %upcase(&_cstVerbose)=Y %then
    %do;
      %_cstProblemIgnored(_cstLogMsg=%str(%upcase(&_cstDSName) null PATH values ignored),
           _cstRsltID=CST0200,_cstChkID=CHK04);
    %end;
  %end;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%*****************************************;
%* CHK05                                 *;
%* Are all discrete character field      *;
%*  values found in standardlookup?      *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK05);
%if &_cstOverrideCheck=0 %then
%do;
  %* Checking here for: reftype, type+subtype combinations, and the new columns iotype, filetype and allowoverwrite *;

  * Point to the standard-specific lookup data set *;
  data _null_;
     set cstMDLib.&_cstGlobalStdSASRefsDS (where=(upcase(standard)=upcase(kstrip("&_cstStandard")) and upcase(standardversion)=upcase(kstrip("&_cstStandardVersion")) and
            upcase(type)='CSTMETADATA' and upcase(subtype)='LOOKUP'));
       call symputx('_cstStdLookupPath',path);
       call symputx('_cstStdLookupLib',sasref);
       call symputx('_cstStdLookupDS',kstrip(scan(memname,1,'.')));
  run;

  %if (%length(&_cstStdLookupLib)>0) %then %do;

    %if %length(%sysfunc(pathname(&_cstStdLookupLib,'L')))<1 %then
    %do;
       libname &_cstStdLookupLib "&_cstStdLookupPath";
       %let _cstDeallocateLookupLib=Y;
    %end;

    proc sql noprint;
      create table work._cstproblems as
      select test,'Invalid REFTYPE value' as problem format=$40.,sr1.* from
      (select 'reftype' as test format=$40., * from
        (select upcase(reftype) as reftype from &_cstDSName
             except
         select upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(column)='REFTYPE')))) prob1
       left join
      &_cstDSName sr1 on upcase(sr1.reftype) = upcase(prob1.reftype)


          outer union corr

      select test,'Invalid TYPE value' as problem format=$40.,sr2.* from
       (select 'type' as test format=$40., * from
        (select upcase(type) as type from &_cstDSName (where=(subtype=''))
           except
         select upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(column)='TYPE')))) prob2
       left join
      &_cstDSName sr2 on upcase(sr2.type) = upcase(prob2.type)

          outer union corr

      select test,'Invalid TYPE+SUBTYPE combination' as problem format=$40.,sr3.* from
       (select 'type+subtype' as test format=$40., * from
        (select upcase(type) as type,upcase(subtype) as subtype from &_cstDSName (where=(subtype ne ''))
           except
         select upcase(refvalue),upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and
            upcase(column)='SUBTYPE' and upcase(refcolumn)='TYPE')))) prob3
       left join
      &_cstDSName sr3 on upcase(sr3.type) = upcase(prob3.type) and upcase(sr3.subtype) = upcase(prob3.subtype)

  %if &_cstCurrentStyle %then
  %do;

          outer union corr

      select test,'Invalid IOTYPE value' as problem format=$40.,sr2.* from
       (select 'iotype' as test format=$40., * from
        (select upcase(iotype) as iotype from &_cstDSName
           except
         select upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(column)='IOTYPE')))) prob2
       left join
      &_cstDSName sr2 on upcase(sr2.iotype) = upcase(prob2.iotype)

          outer union corr

      select test,'Invalid FILETYPE value' as problem format=$40.,sr2.* from
       (select 'filetype' as test format=$40., * from
        (select upcase(filetype) as filetype from &_cstDSName
           except
         select upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(column)='FILETYPE')))) prob2
       left join
      &_cstDSName sr2 on upcase(sr2.filetype) = upcase(prob2.filetype)

          outer union corr

      select test,'Invalid ALLOWOVERWRITE value' as problem format=$40.,sr2.* from
       (select 'allowoverwrite' as test format=$40., * from
        (select upcase(allowoverwrite) as allowoverwrite from &_cstDSName
           except
         select upcase(value) from &_cstStdLookupLib..&_cstStdLookupDS (where=(upcase(table)='STANDARDSASREFERENCES' and upcase(column)='ALLOWOVERWRITE')))) prob2
       left join
      &_cstDSName sr2 on upcase(sr2.allowoverwrite) = upcase(prob2.allowoverwrite)

  %end;

      ;
    quit;

    data work._cstproblems;
      set work._cstproblems;
        attrib _cstactual format=$200.
               _cstkeys   format=$200.;
        select(upcase(test));
          when('REFTYPE') do;
          _cstactual=cats('reftype=',reftype);
        end;
          when('TYPE') do;
          _cstactual=cats('type=',type);
        end;
          when('TYPE+SUBTYPE') do;
          _cstactual=cats('type=',type,',subtype=',subtype);
        end;
          when('IOTYPE') do;
          _cstactual=cats('iotype=',iotype);
        end;
          when('FILETYPE') do;
          _cstactual=cats('filetype=',filetype);
        end;
          when('ALLOWOVERWRITE') do;
          _cstactual=cats('allowoverwrite=',allowoverwrite);
        end;
        otherwise;
        end;
        _cstkeys=catx(',',cats('standard=',standard),cats('standardversion=',standardversion),
                      cats('type=',type),cats('subtype=',subtype));
    run;


    %let _cst_rc=0;
    %let _cst_rcmsg=%str(%upcase(&_cstDSName) contains one or more invalid values);
    %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0116,_cstChkID=CHK05,
                       _cstMsg1=,_cstMsg2=&_cstDSName,_cstActVar=_cstactual,_cstKeyVar=_cstkeys);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

    %let _cst_rc=0;
    %let _cst_rcmsg=;

    ***libname &_cstStdLookupLib;

  %end;
  %else %do;
    %* Unable to perform check  *;
    %_cstProblemIgnored(_cstLogMsg=%str(Check not run: Standard-specific lookup data set unavailable),
         _cstRsltID=CST0200,_cstChkID=CHK05);
  %end;

%end;


%*****************************************;
%* CHK06                                 *;
%* Given context, are all macro          *;
%*  variables resolved?                  *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK06);
%if &_cstOverrideCheck=0 %then
%do;

  data work._cstproblems (drop=i newpath newmemname aproblem);
    set &_cstDSName;
      attrib macrovar format=$32.
             newpath format=$500.
             newmemname format=$40.
             aproblem format=8.
             _cstactual format=$200.
             _cstkeys   format=$200.;
      retain aproblem 0;

      aproblem=0;

      * path contains one or more macro references  *;
      if kindexc(path,'&') then do;
        _cstactual=cats('path=',kstrip(path));
        newpath=path;
        * compress extra '&' characters out *;
        do until (kindex(newpath,'&&')=0);
          newpath=tranwrd(newpath,'&&','&');
        end;
        do i=1 to countc(newpath,'&');
          newpath=ksubstr(newpath,kindexc(newpath,'&'));
          if kindexc(newpath,'./\& ') then
            macrovar=ksubstr(newpath,1,kindexc(newpath,'./\ ')-1);
          else
            macrovar=newpath;
          if countc(macrovar,'&') > 1 then
            macrovar=ksubstr(macrovar,1,kindexc(ksubstr(macrovar,2),'&'));
          if symexist(kcompress(macrovar,'&')) then
          do;
            if resolve(macrovar)='' then aproblem=1;  * macro variable is blank *;
          end;
          else
            aproblem=1;   * macro variable does not exist *;
          newpath=ksubstr(newpath,kindexc(newpath,'&')+1);
        end;
      end;
      macrovar='';
      if indexc(memname,'&') then do;
        _cstactual=cats('memname=',kstrip(memname));
        newmemname=memname;
        * compress extra '&' characters out *;
        do until (index(newmemname,'&&')=0);
          newmemname=tranwrd(newmemname,'&&','&');
        end;
        do i=1 to countc(newmemname,'&');
          newmemname=substr(newmemname,indexc(newmemname,'&'));
          if indexc(newmemname,'./\& ') then
            macrovar=substr(newmemname,1,indexc(newmemname,'./\ ')-1);
          else
            macrovar=newmemname;
          if countc(macrovar,'&') > 1 then
            macrovar=substr(macrovar,1,indexc(substr(macrovar,2),'&'));
          if symexist(compress(macrovar,'&')) then
          do;
            if resolve(macrovar)='' then aproblem=1;  * macro variable is blank *;
          end;
          else
            aproblem=1;   * macro variable does not exist *;
          newmemname=substr(newmemname,indexc(newmemname,'&')+1);
        end;
      end;
      if aproblem=1 then
      do;
        _cstkeys=catx(',',cats('standard=',standard),cats('standardversion=',standardversion),
                          cats('type=',type),cats('subtype=',subtype));
        output;
      end;
  run;

  %if %upcase(&_cstContext) ne STANDALONE %then
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=%upcase(&_cstDSName) contains unresolved macros in PATH or MEMNAME;
    %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0013,_cstChkID=CHK06,
                       _cstActVar=_cstactual,_cstKeyVar=_cstkeys);
  %end;
  %else %do;
    %if %upcase(&_cstVerbose)=Y %then
    %do;
      %_cstProblemIgnored(_cstLogMsg=%str(%upcase(&_cstDSName) unresolved macro variables ignored),
           _cstRsltID=CST0200,_cstChkID=CHK06);
    %end;
  %end;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%*****************************************;
%* CHK07                                 *;
%* Multiple fmtsearch records but valid  *;
%*  ordering is not provided             *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK07);
%if &_cstOverrideCheck=0 %then
%do;
  proc sort data=&_cstDSName (where=(upcase(type)='FMTSEARCH')) out=work._cstSorted;
    by order;
  run;
  data _null_;
    if 0 then set work._cstSorted nobs=_numobs;
    call symputx('_cstDataRecords',_numobs);
    stop;
  run;
  data work._cstproblems (drop=recCnt);
    set work._cstSorted;
      by order;
    attrib _cstactual format=$40.
           _cstkeys   format=$200.;
    retain recCnt;
    if _n_=1 then
      recCnt=symgetn('_cstDataRecords');

    if (missing(order) and recCnt>0) or (not first.order and last.order) then
    do;
      _cstactual=cats('order=',kstrip(put(order,8.)));
      _cstkeys=catx(',',cats('standard=',standard),cats('standardversion=',standardversion),
                          cats('type=',type),cats('subtype=',subtype));
      output;
    end;
  run;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstSorted);

  %let _cst_rc=0;
  %let _cst_rcmsg=%upcase(&_cstDSName) contains multiple FMTSEARCH records with non-unique or missing ORDER;
  %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0011,_cstChkID=CHK07,
                     _cstMsg1=FMTSEARCH,_cstMsg2=ORDER,_cstActVar=_cstactual,_cstKeyVar=_cstkeys);

  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%*****************************************;
%* CHK08                                 *;
%* Multiple autocall records but valid   *;
%*  ordering is not provided             *;
%*****************************************;
%let _cstOverrideCheck=0;
%_cstOverride(_cstChkID=CHK08);
%if &_cstOverrideCheck=0 %then
%do;
  proc sort data=&_cstDSName (where=(upcase(type)='AUTOCALL')) out=work._cstSorted;
    by order;
  run;
  data _null_;
    if 0 then set work._cstSorted nobs=_numobs;
    call symputx('_cstDataRecords',_numobs);
    stop;
  run;
  data work._cstproblems (drop=recCnt);
    set work._cstSorted;
      by order;
    attrib _cstactual format=$40.
           _cstkeys   format=$200.;
    retain recCnt;
    if _n_=1 then
      recCnt=symgetn('_cstDataRecords');

    if (missing(order) and recCnt>0) or (not first.order and last.order) then
    do;
      _cstactual=cats('order=',kstrip(put(order,8.)));
      _cstkeys=catx(',',cats('standard=',standard),cats('standardversion=',standardversion),
                          cats('type=',type),cats('subtype=',subtype));
      output;
    end;
  run;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstSorted);

  %let _cst_rc=0;
  %let _cst_rcmsg=%upcase(&_cstDSName) contains multiple AUTOCALL records with non-unique or missing ORDER;
  %_cstReportProblem(_cstLogMsg=&_cst_rcmsg,_cstRsltID=CST0011,_cstChkID=CHK08,
                     _cstMsg1=AUTOCALL,_cstMsg2=ORDER,_cstActVar=_cstactual,_cstKeyVar=_cstkeys);

  %cstutil_deleteDataSet(_cstDataSetName=work._cstProblems);

  %let _cst_rc=0;
  %let _cst_rcmsg=;

%end;


%goto CLEANUP;

%**********************************************************************;
%* Error conditions resulting in _cstResultFlagParm=-1, signalling    *;
%*  macro did not complete successfully.                              *;
%**********************************************************************;


%SASREFS_NOTFOUND:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=ERROR: The SASReferences data set does not exist;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=The SASReferences data set &_cstDSName
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%NO_SASREFS:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=ERROR: A SASReferences file was not passed as a parameter and one is not specified using global environment variables;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0103
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%NO_SASREFSOBS:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=The SASReferences data set has no observations;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0112
                ,_cstResultParm1=&_cstDSName
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%NO_SASREFSOPEN:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=The SASReferences data set cannot be opened;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstDSName
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;

%NO_GOLDSTD:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=ERROR: The Gold standard file does not exist;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=&_cstSASRefsGoldStd
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%NO_STD:
  %let _cstThisMacroRC=1;
  %let _cstThisMacroRCmsg=ERROR: Standard + standardversion do not exist;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cststandardversion
                ,_cstResultParm2=&_cststandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=-1
                ,_cstRCParm=&_cstThisMacroRC
                );
  %goto CLEANUP;


%CLEANUP:

  %if &_cstNumErrorRecs>0 %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0090
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                );
  %end;

  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * Clear the global metadata library;
  libname cstMDLib;

  %if (&_cstDeallocateTempLib0=Y) %then %do;
    * de-allocate the temporary libname to SASRefs;
    libname &_cstTempLib0;
  %end;

  %if (&_cstDeallocateLookupLib=Y) %then %do;
    * de-allocate the temporary libname to cstmetadata.lookup;
    libname &_cstStdLookupLib;
  %end;

  %if (&_cstDeallocateTemplateLib=Y) %then %do;
    * de-allocate the temporary libname to the templates folder;
    libname &_cstTemplateLib;
  %end;


  %* Delete the temporary messages data set if it was created here;
  %if (&_cstNeedToDeleteMsgs=1) %then %do;
    %cstutil_deleteDataSet(_cstDataSetName=&_cstMessages);
  %end;

  %* Set the global return code;
  %if &_cstNumErrorRecs>0 %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=ERROR: One or more problems were detected with the SASReferences data set.;
  %end;
  %else %if &_cstThisMacroRC=1 %then
  %do;
    %let _cst_rc=&_cstThisMacroRC;
    %let _cst_rcmsg=&_cstThisMacroRCmsg;
  %end;
  %else
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=;
  %end;

%EXIT_ABORT:

%mend cstutilvalidatesasreferences;
