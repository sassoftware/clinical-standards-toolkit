%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_setStandardVersionDefault                                                  *;
%*                                                                                *;
%* Sets the default version for a registered standard.                            *;
%*                                                                                *;
%* This macro also resets any previous default version for the standard.          *;
%*                                                                                *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the registered standard.          *;
%* @param _cstStandardVersion - required - The version of the standard from which *;
%*            the data set is created. If this parameter is omitted, the default  *;
%*            version for the given standard is used. If a default version is not *;
%*            defined, an error is generated.                                     *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_setStandardVersionDefault(
    _cstStandard=,
    _cstStandardVersion=,
    _cstResultsOverrideDS=
    ) / des='CST: Sets the default version for a registered standard';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstParamInError
    _cstRandom
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstTempDS1
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
    ;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);
  %let _cstResultSeq=1;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)";

  %* Pre-requisite: _cstStandard is not blank;
  %if (%length(&_cstStandard)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstStandard;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstStandardVersion is not blank;
  %if (%length(&_cstStandardVersion)=0) %then %do;
    %let _cstParamInError=_cstStandardVersion;
    %goto NULL_PARAMETER;
  %end;

  * Pre-requisite: Check that the standard-version is valid;
  %let _cstError=Y;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDS
      (where=(
        upcase(standard)=%sysfunc(upcase("&_cstStandard"))
      ));
    if (_n_=1) then call symputx('_cstError','N','L');
  run;

  %if (&_cstError=Y) %then %do;
    %goto INVALID_STD;
  %end;

  * Pre-requisite: Check that the version is valid (if provided) or a default exists if not;
  %let _cstError=Y;
  * Check that the version is valid;
  data &_cstTempDS1;
    set &_cstTempDS1
      (where=(upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion"))));
    if (_n_=1) then call symputx('_cstError','N','L');
  run;

  %* process an error;
  %if (&_cstError=Y) %then %do;
    %goto INVALID_VERSION;
  %end;

  * Attempt to get exclusive access to the data sets;
  lock &_cstGlobalMDLib..&_cstGlobalStdDS;
  %if (&syslckrc=0) %then;
  %else %do;
    %goto LOCKERROR;
  %end;

  * Set the records accordingly;
  proc sql;
    * clear any previous standard;
    update &_cstGlobalMDLib..&_cstGlobalStdDS
      set isstandarddefault='N'
      where upcase(standard)=upcase("&_cstStandard");
    * define the new standard;
    update &_cstGlobalMDLib..&_cstGlobalStdDS
      set isstandarddefault='Y'
      where (upcase(standard)=upcase("&_cstStandard") AND
        upcase(standardVersion)=upcase("&_cstStandardVersion"));
    quit;

  * release the lock on the data set;
  lock &_cstGlobalMDLib..&_cstGlobalStdDS clear;

  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0109
                ,_cstResultParm1=&_cstStandard
                ,_cstResultParm2=&_cstStandardVersion
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDVERSIONDEFAULT
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NULL_PARAMETER:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0081
                ,_cstResultParm1=&_cstParamInError
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDVERSIONDEFAULT
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
                ,_cstSrcDataParm=CST_SETSTANDARDVERSIONDEFAULT
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_STD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0082
                ,_cstResultParm1=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDVERSIONDEFAULT
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_VERSION:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstStandardVersion
                ,_cstResultParm2=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDVERSIONDEFAULT
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CLEANUP:
  * clear the libname to the global metadata;
  libname &_cstGlobalMDLib;

  * delete the work data files;
  proc datasets nolist lib=work;
    delete &_cstTempDS1 / mt=cat;
  quit;

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

%mend cst_setStandardVersionDefault;