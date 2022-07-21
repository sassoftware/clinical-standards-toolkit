%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_getStandardSASReferences                                                   *;
%*                                                                                *;
%* Retrieves the global SASReference records for a standard.                      *;
%*                                                                                *;
%* If this macro succeeds, the global variable _cst_rc is set to 0. If it fails,  *;
%* _cst_rc is set to 1. The Results data set contains more information as to the  *;
%* cause of the failure.                                                          *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*             Values: 1 | 0                                                      *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the registered standard.          *;
%* @param _cstStandardVersion - optional - The version of the standard for which  *;
%*            the caller wants to retrieve the global SASReferences. This can be  *;
%*            omitted if the caller is requesting the default version for the     *;
%*            standard.                                                           *;
%* @param _cstOutputDS - required - The (libname.)member name of the output data  *;
%*            set to create.                                                      *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_getStandardSASReferences(
    _cstStandard=,
    _cstStandardVersion=,
    _cstOutputDS=,
    _cstResultsOverrideDS=
    ) / des = 'CST: Retrieves the global SASReference records for the given standard';

  %cstutil_setcstgroot;

  %if (&_cstDebug) %then %do;
    %put >>> cst_getStandardSASReferences;
    %put * _cstStandard=&_cstStandard;
    %put * _cstStandardVersion=&_cstStandardVersion;
    %put * _cstOutputDS=&_cstOutputDS;
    %put * _cstResultsOverrideDS=&_cstResultsOverrideDS;
  %end;

  %* declare local variables used in the macro;
  %local
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstParamInError
    _cstRandom
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstTempDS1
    _cstTempLib2
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
    ;

  %let _cstThisMacroRC=0;

  %* retrieve static variables;
  %if (&_cstDebug) %then %do;
    %put * Retrieving static variables;
  %end;

  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %* Generate the random names used in the macro;
  %if (&_cstDebug) %then %do;
    %put * Generating temporary names;
  %end;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib2=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %if (&_cstDebug) %then %do;
    %put * Setting up the location of the results data sets;
  %end;

  %cstutil_internalManageResults(_cstAction=SAVE);
  %let _cstResultSeq=1;

  %* Pre-requisite: _cstStandard is not blank;
  %if (&_cstDebug) %then %do;
    %put * PRE-REQ: Standard is not blank;
  %end;
  %if (%length(&_cstStandard)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstStandard;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstOutputDS is not blank;
  %if (&_cstDebug) %then %do;
    %put * PRE-REQ: Output data set is not blank;
  %end;
  %if (%length(&_cstOutputDS)=0) %then %do;
    %let _cstParamInError=_cstOutputDS;
    %goto NULL_PARAMETER;
  %end;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  * Pre-requisite: Check that the standard is valid;
  %if (&_cstDebug) %then %do;
    %put * PRE-REQ: Standard is valid;
  %end;
  %let _cstError=Y;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDS
      (where=(upcase(standard)=%sysfunc(upcase("&_cstStandard"))));
    if (_n_=1) then call symputx('_cstError','N','L');
  run;

  %if (&_cstError=Y) %then %do;
    %goto INVALID_STD;
  %end;

  * Pre-requisite: Check that the version is valid (if provided) or a default exists if not;
  %* TODO: Refactor this code to be a callable module - it is used in many places;
  %if (%length(&_cstStandardVersion)>0) %then %do;
    %if (&_cstDebug) %then %do;
      %put * PRE-REQ: StandardVersion provided is valid;
    %end;
    %let _cstError=Y;
    * Check that the version is valid;
    data &_cstTempDS1;
      set &_cstGlobalMDLib..&_cstGlobalStdDS
        (where=(
          (upcase(standard)=%sysfunc(upcase("&_cstStandard"))) AND
          (upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion")))
        ));
      if (_n_=1) then call symputx('_cstError','N','L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %goto INVALID_VERSION;
    %end;
  %end;
  %else %do;
    %if (&_cstDebug) %then %do;
      %put * PRE-REQ: Follow-on.  No standard provided so default must exist;
    %end;

    %let _cstError=Y;
    * Check that there is a default version specified and retrieve it;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(isstandarddefault="Y"));
      if (_n_=1) then call symputx('_cstError','N','L');
      call symputx('_cstStandardVersion',standardVersion,'L');
    run;

    %if (&_cstDebug) %then %do;
       %put Default version for &_cstStandard is &_cstStandardVersion;
    %end;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %goto NO_DEFAULT_VERSION;
    %end;
  %end;

  * Create the output data set for the standard/version;
  data &_cstOutputDS;
    set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDS
      (where=(
        (upcase(standard)=%sysfunc(upcase("&_cstStandard"))) AND
        (upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion")))
      ));

  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0080
                ,_cstResultParm1=&_cstStandard &_cstStandardVersion
                ,_cstResultParm2=&_cstOutputDS
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_GETSTANDARDSASREFERENCES
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
                ,_cstSrcDataParm=CST_GETSTANDARDSASREFERENCES
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
                ,_cstSrcDataParm=CST_GETSTANDARDSASREFERENCES
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
                ,_cstSrcDataParm=CST_GETSTANDARDSASREFERENCES
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%NO_DEFAULT_VERSION:
  %* ERROR: No version was supplied and there is no default for &_cstStandard.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0085
                ,_cstResultParm1=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_GETSTANDARDSASREFERENCES
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * Clear the libname;
  libname &_cstGlobalMDLib;

  * Clean up temporary data sets if they exist;
  proc datasets nolist lib=work;
    delete &_cstTempDS1  / mt=data;
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

  %* set the returc code for this macro;
  %let _cst_rc=&_cstThisMacroRC;

  %if (&_cstDebug) %then %do;
    %put <<< cst_getStandardSASReferences;
  %end;

%mend cst_getStandardSASReferences;