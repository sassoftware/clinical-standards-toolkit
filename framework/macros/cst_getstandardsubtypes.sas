%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_getstandardsubtypes                                                        *;
%*                                                                                *;
%* Creates a data set that contains the installed Clinical Terminology subtypes.  *;
%*                                                                                *;
%* Examples of the subtypes are SDTM, CDASH, ADAM, or any user customizations.    *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the registered standard.          *;
%*            Values: CDISC-TERMINOLOGY                                           *;
%*            Default: CDISC-TERMINOLOGY                                          *;
%* @param _cstOutputDS - required - The libname.memname of the data set to create.*;
%* @param _cstResultsDS - optional - The results that were created.               *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cst_getstandardsubtypes(
    _cstStandard=CDISC-TERMINOLOGY,
    _cstOutputDS=,
    _cstResultsDS=
    ) / des='CST: Generates a data set containing installed Clinical Terminology subtypes';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstParamInError
    _cstRandom
    _cstSubTypeDS
    _cstSubTypeLib
    _cstSubTypeRoot
  ;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_CT_SUBTYPES_DATA,_cstVar=_cstSubTypeDS);

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

  * Set the _cstSubTypeRoot macro value;
  data _null_;
    set &_cstGlobalMDLib..&_cstGlobalStdDS (where=(standard="&_cstStandard"));
      call symputx('_cstSubTypeRoot',catx('/',rootpath,'control'));
  run;

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstSubTypeLib=_cst&_cstRandom;

  * Assign the libname to the CT subtypes folder;
  libname &_cstSubTypeLib "%unquote(&_cstSubTypeRoot)" access=readonly;

  * Create the output data set for the standard/version;
  data &_cstOutputDS;
    set &_cstSubTypeLib..&_cstSubTypeDS;
  run;

  * Clear the libraries ;
  libname &_cstGlobalMDLib;
  libname &_cstSubTypeLib;

  %goto cleanup;

%NULL_PARAMETER:
  %put ERROR: A required parameter was not supplied - &_cstParamInError..;
  %let _cst_rc=1;
  %return;

%CLEANUP:

%mend cst_getstandardsubtypes;