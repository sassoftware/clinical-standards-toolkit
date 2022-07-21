%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilregisterctsubtype                                                       *;
%*                                                                                *;
%* Enables registration of a new set of controlled terminology.                   *;
%*                                                                                *;
%* Notes:                                                                         *;
%*   1. Any librefs referenced in macro parameters must be pre-allocated.         *;
%*   2. Each successful registration of new controlled terminology is written to  *;
%*      a transaction file as specified by the SAS Clinical Standards Toolkit.    *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. Parameter value lengths must conform to standardsubtypes column           *;
%*      attributes.                                                               *;
%*   2. Management of new controlled terminology data sets and catalogs occurs    *;
%*      outside the macro. Examples include whether both data sets and catalogs   *;
%*      are included in _cstPath, and whether these are copied  to a <current>    *;
%*      folder.                                                                   *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session. Set _cstDebug=1   *;
%*             before this macro call to retain work files created in this macro. *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of macro                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstTransactionDS Identifies logging data set (may be set before       *;
%*             calling this macro to override the default)                        *;
%*                                                                                *;
%* @param _cstStd - required - The name of the data standard. For example,        *;
%*           CDISC-TERMINOLOGY. ($20)                                             *;
%* @param _cstStdVer - required - The version of the data standard. For example,  *;
%*           CDISC-SDTM. ($20)                                                    *;
%* @param _cstStandardSubtype - required - The name of the standard subtype. For  *;
%*           example,  NCI_THESAURUS. ($20)                                       *;
%* @param _cstStandardSubtypeVersion - required - The version of the standard     *;
%*           subtype.  For example, 201412. ($20)                                 *;
%* @param _cstPath - required - The path to the Controlled Terminology folder     *;
%*           location of the _cstMemName file(s). ($2048)                         *;
%* @param _cstMemName - required - The Name of Controlled Terminology data set or *;
%*           catalog. For example, CTERMS.  ($32)                                 *;
%* @param _cstIsStandardDefault - optional - Specifies that this is the default   *;
%*           version for the subtype?  ($1)                                       *;
%*           Values: Y | N                                                        *;
%*           Default: N                                                           *;
%*           If Y, previous default version is set to N.                          *;
%* @param _cstDescription - optional - The description of the subtype. ($200)     *;
%*                                                                                *;
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;

%macro cstutilregisterctsubtype(
    _cstStd=,
    _cstStdVer=,
    _cstStandardSubtype=,
    _cstStandardSubtypeVersion=,
    _cstPath=,
    _cstMemName=,
    _cstIsStandardDefault=N,
    _cstDescription=
    ) / des="CST: Register CT subtype";


  %local _cstDSRecCnt
         _cstFound
         _cstGlobalMDLib
         _cstGlobalMDPath
         _cstGlobalStdDS
         _cstMsgID
         _cstNeedToDeleteMsgs
         _cstNewDS
         _cstRandom
         _cstReturnCode
         _cstSrcLib
         _cstSrcMacro
         _cstSubTypeDS
         _cstSubTypeLib
         _cstSubTypeRoot
         _cstTempDS
         _cstUseResultsDS
         _cstVersion
         _cstWhereClause
  ;

  %let _cstDSRecCnt=0;
  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstUseResultsDS=0;
  
  %***************************************************;
  %*  Check for existence of global macro variables  *;
  %***************************************************;
  %if ^%symexist(_cst_rc) %then 
  %do;
    %global _cst_rc _cst_rcmsg;
    %let _cst_rc=0;
  %end;
  %if ^%symexist(_cstDeBug) %then 
  %do;
    %global _cstDeBug;
    %let _cstDebug=0;
  %end;

  %if (%symexist(_cstResultsDS)=1) %then 
  %do;
    %if (%klength(&_cstResultsDS)>0) and %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      %let _cstUseResultsDS=1;
      %******************************************************;
      %*  Create a temporary messages data set if required  *;
      %******************************************************;
      %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);
    %end;
  %end;


  %******************************;
  %* Set/check parameter values *;
  %******************************;

  %let _cstStd=%upcase(&_cstStd);  
  %let _cstStdVer=%upcase(&_cstStdVer);  

  %if %klength(&_cstStd)<1 or %klength(&_cstStdVer)<1 or %klength(&_cstStandardSubtype)<1 or %klength(&_cstStandardSubtypeVersion)<1 %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Each of the _cstStd, _cstStdVer, _cstStandardSubtype and _cstStandardSubtypeVersion parameters must be specified.;
    %goto exit_error;
  %end;

  %let _cstFound=0;  
  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);
  data _null_;
    set work._cstStandards (where=(upcase(standard)="&_cstStd"));
    call symputx('_cstFound','1');
  run;
  %if &_cstFound=0 %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Standard specified in the _cstStd parameter (&_cstStd) is not a registered standard.;
    %goto exit_error;
  %end;

  %* Can we find and get to the target data set?  *;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %* cst_getStatic can be overwritten as needed for CST_CT_SUBTYPES_DATA *;
  %cst_getStatic(_cstName=CST_CT_SUBTYPES_DATA,_cstVar=_cstSubTypeDS);

  %* Assign the libname to the global metadata library;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  data _null_;
    set &_cstGlobalMDLib..&_cstGlobalStdDS (where=(upcase(standard)="&_cstStd"));
      call symputx('_cstSubTypeRoot',catx('/',rootpath,controlsubfolder));
  run;
  libname &_cstGlobalMDLib;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstSubTypeLib=_cst&_cstRandom;
  %let _cstReturnCode=%sysfunc( libname( &_cstSubTypeLib, &_cstSubTypeRoot));
  %if %sysfunc(libref(&_cstSubTypeLib)) %then
  %do;
    %put %sysfunc(sysmsg());
    %let _cstReturnCode=%sysfunc(libname(&_cstSubTypeLib, ""));
    %let _cst_rc=1;
    %let _cst_rcmsg=Unable to allocate a libref to the rootpath specified for &_cstStd.;
    %goto exit_error;
  %end;
  %else %do;
    %* check that _cstSubTypeDS exists  *;
    %if %sysfunc(exist(&_cstSubTypeLib..&_cstSubTypeDS))=0 %then 
    %do;
      %let _cst_rc=1;
      %let _cst_rcmsg=&_cstSubTypeDS does not exist in &_cstSubTypeRoot.;
      %goto exit_error;
     %end;
  %end;

  %let _cstFound=0;  
  data _null_;
    set &_cstSubTypeLib..&_cstSubTypeDS (where=(upcase(standardversion)="&_cstStdVer" and 
                upcase(standardsubtype)=upcase("&_cstStandardSubtype") and 
                upcase(standardsubtypeversion)=upcase("&_cstStandardSubtypeVersion")));
    call symputx('_cstFound','1');
  run;
  %if &_cstFound=1 %then
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=Attempt to register a set of controlled terminology that already exists. Process aborted.;
    %put WAR%STR(NING): [CSTLOG%str(MESSAGE).&_cstSrcMacro]: &_cst_rcmsg;
    %goto exit_error;
  %end;

  %if %klength(&_cstPath)>0 %then
  %do;
    %* Assign libname;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstSrcLib=_cst&_cstRandom;
    %let _cstReturnCode=%sysfunc( libname( &_cstSrcLib, &_cstPath));
    %if %sysfunc(libref(&_cstSrcLib)) %then
    %do;
      %put %sysfunc(sysmsg());
      %let _cstReturnCode=%sysfunc(libname(&_cstSrcLib, ""));
      %let _cst_rc=1;
      %let _cst_rcmsg=Unable to allocate a libref to the location specified in the _cstPath parameter.;
      %goto exit_error;
    %end;
    %else %do;
      %if %klength(&_cstMemName)<1 %then
      %do;
        %let _cst_rc=1;
        %let _cst_rcmsg=The name of the controlled terminology data set or catalog must be specified in the _cstMemName parameter.;
        %goto exit_error;
      %end;
      %* check that _cstMemName exists - look for both a catalog and a data set  *;
      %else %if %sysfunc(exist(&_cstSrcLib..&_cstMemName))=0 and %sysfunc(cexist(&_cstSrcLib..&_cstMemName))=0 %then 
      %do;
        %let _cstReturnCode=%sysfunc(libname(&_cstSrcLib, ""));
        %let _cst_rc=1;
        %let _cst_rcmsg=&_cstMemName does not exist in &_cstPath.;
        %goto exit_error;
      %end;
    %end;
    %let _cstReturnCode=%sysfunc(libname(&_cstSrcLib, ""));
  %end;
  %else %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The location of the controlled terminology must be specified in the _cstPath parameter.;
    %goto exit_error;
  %end;

  %if %klength(&_cstIsStandardDefault) < 1 %then
    %let _cstIsStandardDefault=N;
  %else %let _cstIsStandardDefault=%upcase(&_cstIsStandardDefault);  
  %if &_cstIsStandardDefault ^= N and &_cstIsStandardDefault ^= Y %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The _cstIsStandardDefault parameter (&_cstIsStandardDefault) must be Y or N.;
    %goto exit_error;
  %end;

     %**************************************************;
     %* Check parameter value lengths                  *;
     %* These must not exceed data set column lengths  *;
     %**************************************************;

     %if %length(&_cststd)>20 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstStd parameter (&_cstStd) is limited to 20 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cststdver)>20 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstStdVer parameter (&_cstStdVer) is limited to 20 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cststandardsubtype)>20 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstStandardSubtype parameter (&_cstStandardSubtype) is limited to 20 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cstStandardSubtypeVersion)>20 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstStandardSubtypeVersion parameter (&_cstStandardSubtypeVersion) is limited to 20 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cstPath)>2048 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstPath parameter is limited to 2048 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cstMemName)>32 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstMemName parameter (&_cstMemName) is limited to 32 characters.;
       %goto exit_error;
     %end;
     %if %length(&_cstDescription)>200 %then
     %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The length of the _cstDescription parameter is limited to 200 characters.;
       %goto exit_error;
     %end;


  %************************;
  %* Begin macro logic    *;
  %************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNewDS=_cst&_cstRandom;
  proc sql noprint;
    create table work.&_cstNewDS
      like &_cstSubTypeLib..&_cstSubTypeDS;
  quit;

  data _null_;
    set work._cstStandards (where=(standard="CST-FRAMEWORK"));
    call symputx('_cstVersion',strip(productrevision));
  run;

  %* If this is to become the default, we must reset any other version that is currently     *;
  %* the deafult to N.  This will be documented in the transaction log and results data set. *;
  %if &_cstIsStandardDefault = Y %then
  %do;
  
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS=_cst&_cstRandom;
    data work.&_cstTempDS;
      set &_cstSubTypeLib..&_cstSubTypeDS (where=(upcase(standard)="&_cstStd" and 
                                                  upcase(standardversion)="&_cstStdVer" and
                                                  upcase(standardsubtype)=upcase("&_cstStandardSubtype") and 
                                                  upcase(isstandarddefault)="Y"));
    run;

    data _null_;
      set work.&_cstTempDS nobs=_numobs;
        attrib tempvar format=$5000.;
        tempvar=catx(" and ",cats("upcase(standard)='",symget('_cstStd'),"'"),
                             cats("upcase(standardversion)='",symget('_cstStdVer'),"'"),
                             cats("upcase(standardsubtype)='",symget('_cstStandardSubtype'),"'"),
                             "upcase(isstandarddefault)='Y'");
        call symputx('_cstDSRecCnt',_numobs);
        call symputx('_cstWhereClause',tempvar);
    run;
    %cstutil_deleteDataSet(_cstDataSetName=work.&_cstTempDS);
 
    %* Only do this if necessary.  *;
    %if &_cstDSRecCnt>0 %then
    %do;
      %cstutilupdatemetadatarecords(_cstStd=&_cstStd,
                                    _cstStdVer=&_cststandardsubtype,
                                    _cstDS=&_cstSubTypeLib..&_cstSubTypeDS,
                                    _cstDSIfClause=%str(&_cstWhereClause),
                                    _cstColumn=isstandarddefault,
                                    _cstValue=N,
                                    _cstTestMode=N);
    %end;
  %end;

  * Create the to-be-added record from parameter values *;
  proc sql;
    insert into work.&_cstNewDS
      set standard="&_cstStd",
          standardversion="&_cstStdVer",
          standardsubtype="&_cstStandardSubtype",
          standardsubtypeversion="&_cstStandardSubtypeVersion",
          path="&_cstPath",
          memname="&_cstMemName",
          isstandarddefault="&_cstIsStandardDefault",
          productrevision="&_cstVersion",
          description="&_cstDescription"
    ;
  quit;
    
  %* Add the record *;
  %cstutilappendmetadatarecords(_cstStd=&_cstStd,_cstStdVer=&_cstStandardSubtype,_cstDS=&_cstSubTypeLib..&_cstSubTypeDS,
    _cstNewDS=work.&_cstNewDS,_cstUpdateDSType=APPEND,_cstOverwriteDup=N,_cstTestMode=N);

  %let _cst_rc=0;
  %put NOTE: [CSTLOG%str(MESSAGE).&_cstSrcMacro]: &_cst_rcmsg;
  %let _cst_rcmsg=Operation successful.;
  
  %goto exit_macro;

  %****************************;
  %*  Handle any errors here  *;
  %****************************;
%exit_error:
  
  %let _cstMsgID=CST0202;
  %if &_cst_rc=0 %then
    %let _cstMsgID=CST0201;
    
  %if &_cstUseResultsDS=1 %then 
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=&_cstMsgID
                ,_cstResultParm1=%bquote(&_cst_rcmsg)
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cst_rc
                ,_cstRCParm=&_cst_rc
                );
  %end;
  %else %if %length(&_cst_rcmsg)>0 and &_cst_rc ^=0 %then
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&_cstSrcMacro] &_cst_rcmsg;
  %goto exit_macro;

%exit_macro:

  %if &_cstDeBug<1 %then
  %do;
    * Clean up temporary data sets if they exist;
    %cstutil_deleteDataSet(_cstDataSetName=work._cstStandards);
    %if %length(&_cstNewDS)>0 %then
      %cstutil_deleteDataSet(_cstDataSetName=&_cstNewDS);
    
    %* Delete the temporary messages data set if it was created here;
    %if (&_cstNeedToDeleteMsgs=1) %then
    %do;
      %local _cstMsgDir _cstMsgMem;
      %if %eval(%index(&_cstMessages,.)>0) %then
      %do;
        %let _cstMsgDir=%scan(&_cstMessages,1,.);
        %let _cstMsgMem=%scan(&_cstMessages,2,.);
      %end;
      %else
      %do;
        %let _cstMsgDir=work;
        %let _cstMsgMem=&_cstMessages;
      %end;
      %cstutil_deleteDataSet(_cstDataSetName=&_cstMsgDir..&_cstMsgMem);
    %end;
    
    %if %length(&_cstSubTypeLib)>0 %then
    %do;
      libname &_cstSubTypeLib;
    %end;
  %end;    

%mend cstutilregisterctsubtype;
