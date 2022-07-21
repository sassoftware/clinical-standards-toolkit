%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_allocGlobalMetadataLib                                                 *;
%*                                                                                *;
%* Allocates the global standards metadata library in Read-only mode.             *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstLibname - required - The libname to assign.                         *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstutil_allocGlobalMetadataLib(
    _cstLibname=
    ) / des='CST: Allocates Global Standards Metadata library';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstGlobalMDPath
    _cstParamInError
  ;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);

  %* Pre-requisite: _cstLibname is not blank;
  %if (%length(&_cstLibname)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstLibname;
    %goto NULL_PARAMETER;
  %end;

  * Assign the libname to the global metadata library;
  libname &_cstLibname "%unquote(&_cstGlobalMDPath)" access=readonly;

  %goto cleanup;

%NULL_PARAMETER:
  %let _cst_rc=1;
  %put ERROR: A required parameter was not supplied - &_cstParamInError..;
  %return;

%CLEANUP:

%mend cstutil_allocGlobalMetadataLib;