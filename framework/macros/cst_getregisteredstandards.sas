%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_getRegisteredStandards                                                     *;
%*                                                                                *;
%* Generates a data set that contains the installed models and versions.          *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstOutputDS - required - The libname.memname of the data set to create.*;
%* @param _cstResultsDS - optional - The results that were created.               *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_getRegisteredStandards(
    _cstOutputDS=,
    _cstResultsDS=
    ) / des='CST: Generates a data set containing the installed models and versions';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstParamInError
    _cstRandom
  ;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %* Pre-requisite: _cstOutputDS is not blank;
  %if (%length(&_cstOutputDS)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstOutputDS;
    %goto NULL_PARAMETER;
  %end;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  * Copy the installed models data set to the specified one;
  data &_cstOutputDS;
    set &_cstGlobalMDLib..&_cstGlobalStdDS;
  run;

  * Clear the library;
  libname &_cstGlobalMDLib;

  %goto cleanup;

%NULL_PARAMETER:
  %put ERROR: A required parameter was not supplied - &_cstParamInError..;
  %let _cst_rc=1;
  %return;

%CLEANUP:

%mend cst_getRegisteredStandards;