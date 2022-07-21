%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_unregisterStandard                                                         *;
%*                                                                                *;
%* Unregisters an existing standard from the global standards library.            *;
%*                                                                                *;
%* This macro unregisters a specific standard and standardversion, removes it     *;
%* from the global standards library metadata Standards data set, and removes all *;
%* records for that standard and standardversion from the StandardSASReferences   *;
%* and StandardLookup data sets.                                                  *;
%*                                                                                *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the standard.                     *;
%* @param _cstStandardVersion - required - The version of the standard.           *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cst_unregisterStandard(
    _cstStandard=,
    _cstStandardVersion=,
    _cstResultsOverrideDS=
    ) / des='CST: Unregister a standard';

  %cstutil_setcstgroot;

  %local
    _cstDoesStdExist
    _cstGlobalMDPath
    _cstGlobalMDLib
    _cstGlobalStdDSName
    _cstGlobalStdSASRefsDSName
    _cstGlobalStdLookupDSName
    _cstGlobalTransformsXML
    _cstIsStandardDefault
    _cstMsgDir
    _cstMsgMem
    _cstNumStandardRecs
    _cstNeedToDeleteMsgs
    _cstRandom
    _cstTempFilename01
    _cstThisMacroRC
    _cstThisResultsDS
    ;

  %let _cstDoesStdExist=0;
  %let _cstThisMacroRC=0;

  %* get the path of the global metadata directory and the names of the global data sets;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_LOOKUP, _cstVar=_cstGlobalStdLookupDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_TRANSFORMSXML,_cstVar=_cstGlobalTransformsXML);

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempFilename01=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);
  %*let _cstResultSeq=%eval(&_cstResultSeq+1);
  %let _cstResultSeq=1;

  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)";

  %* Preconditions;
  %* Cannot unregister the default version if other versions are present;
  proc sql noprint;
     select isStandardDefault into :_cstIsStandardDefault
       from &_cstGlobalMDLib..&_cstGlobalStdDSName
       where ((standard="&_cstStandard") AND
              (standardVersion="&_cstStandardVersion"));
     select count(1) into :_cstDoesStdExist
       from &_cstGlobalMDLib..&_cstGlobalStdDSName
       where ((standard="&_cstStandard") AND
              (standardVersion="&_cstStandardVersion"));
     select count(1) into :_cstNumStandardRecs
       from &_cstGlobalMDLib..&_cstGlobalStdDSName
       where (standard="&_cstStandard");
     quit;
   run;
   %if (("&_cstIsStandardDefault"="Y") AND
        (&_cstNumStandardRecs > 1)) %then %do;
     %goto CANNOTUNREGISTERDEFAULT;
   %end;
   %if (&_cstDoesStdExist=0) %then %do;
     %goto CANNOTUNREGISTERSTD;
   %end;


  * try to get exclusive access to the data sets;
  lock &_cstGlobalMDLib..&_cstGlobalStdDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdDSName data set.;
    %goto LOCKERROR;
  %end;

  lock &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdSASRefsDSName data set.;
    %goto LOCKERROR;
  %end;

  lock &_cstGlobalMDLib..&_cstGlobalStdLookupDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdLookupDSName data set.;
    %goto LOCKERROR;
  %end;


  * delete the standard from the data sets;
  proc sql;
    delete from &_cstGlobalMDLib..&_cstGlobalStdDSName
      where standard="&_cstStandard" and standardVersion="&_cstStandardVersion";
    delete from &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName
      where standard="&_cstStandard" and standardVersion="&_cstStandardVersion";
    delete from &_cstGlobalMDLib..&_cstGlobalStdLookupDSName
      where standard="&_cstStandard" and standardVersion="&_cstStandardVersion";
  quit;

  * Recreate the available transforms XML file;
  filename &_cstTempFilename01 "%unquote(&_cstGlobalMDPath./&_cstGlobalTransformsXML)";

  data _null_;
    file &_cstTempFilename01;
    put '<?xml version="1.0" encoding="UTF-8" ?>';
    put '<AvailableTransforms>';
  run;

  data _null_;
    set &_cstGlobalMDLib..&_cstGlobalStdDSName(where=(isXMLStandard='Y'));
    file &_cstTempFilename01 mod;
    put @3 '<Transform>';
    put @6 '<StandardName>' standard +(-1) '</StandardName>';
    put @6 '<StandardVersion>' standardVersion +(-1) '</StandardVersion>';
    put @6 '<ImportXSL>' importXSL +(-1) '</ImportXSL>';
    put @6 '<ExportXSL>' exportXSL +(-1) '</ExportXSL>';
    put @6 '<Schema>' schema +(-1) '</Schema>';
    put @3 '</Transform>';
  run;

  data _null_;
    file &_cstTempFilename01 mod;
    put '</AvailableTransforms>';
  run;

  filename &_cstTempFilename01 "%unquote(&_cstGlobalMDPath./&_cstGlobalTransformsXML)";

  %put [CSTLOG%str(MESSAGE).&sysmacroname]: Info: &_cstStandard &_cstStandardVersion is no longer registered as a standard.;
  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0110
                ,_cstResultParm1=&_cstStandard &_cstStandardVersion
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_UNREGISTERSTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEARLOCKS;

%CANNOTUNREGISTERDEFAULT:
  %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] The default version &_cstStandardVersion for &_cstStandard cannot be unregistered while other versions exist.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0124
                ,_cstResultParm1=&_cstStandardVersion
                ,_cstResultParm2=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_UNREGISTERSTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CANNOTUNREGISTERSTD:
  %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] The version &_cstStandardVersion for &_cstStandard is unknown and cannot be unregistered.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0082
                ,_cstResultParm1=&_cstStandard/&_cstStandardVersion
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_UNREGISTERSTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;


%LOCKERROR:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0104
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_UNREGISTERSTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CLEARLOCKS:
  * clear any locks on the files;
  lock &_cstGlobalMDLib..&_cstGlobalStdDSName clear;
  lock &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName clear;
  lock &_cstGlobalMDLib..&_cstGlobalStdLookupDSName clear;

%CLEANUP:
  %* clear the libnames;
  libname &_cstGlobalMDLib;
  %* Delete the temporary messages data set if it was created here;
  %if (&_cstNeedToDeleteMsgs=1) %then %do;

    %if %eval(%index(&_cstMessages,.)>0) %then %do;
      %let _cstMsgDir=%scan(&_cstMessages,1,.);
      %let _cstMsgMem=%scan(&_cstMessages,2,.);
    %end;
    %else %do;
      %let _cstMsgDir=work;
      %let _cstMsgMem=&_cstMessages;
    %end;
    proc datasets nolist lib=&_cstMsgDir;
      delete &_cstMsgMem / mt=data;
      quit;
    run;
  %end;

  %let _cst_rc=&_cstThisMacroRC;

%mend cst_unregisterStandard;
