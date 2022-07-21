**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* Register the framework to the global library                                   *;
**********************************************************************************;

* ---- CAUTION -- CAUTION -- CAUTION -- CAUTION -- CAUTION ---- ; 
* You should never revert framework.  That is, once you have    ;
* installed a newer version of framework, you should not run    ;
* this program from an earlier version.  The macros in SASAUTOS ;
* and the information registered by this program work together. ;
* Reverting this information will mean that the versions are    ;
* incompatible.                                                 ;
* ------------------------------------------------------------- ;

%cstutil_setcstgroot;

%global
  _cstGlobalMDPath
  _cstGlobalMDLib
  _cstGlobalStdDSName
  _cstGlobalStdSASRefsDSName
  _cstGlobalStdLookupDSName
  ;

%cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);    
%cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDSName);                                                                                                
%cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDSName);                                                                                                
%cst_getStatic(_cstName=CST_GLOBALMD_LOOKUP, _cstVar=_cstGlobalStdLookupDSName);
%cst_getStatic(_cstName=CST_GLOBALMD_TRANSFORMSXML,_cstVar=_cstGlobalTransformsXML);   

libname cstMeta "%unquote(&_cstGlobalMDPath)";

proc sql;
  delete from cstMeta.&_cstGlobalStdDSName
    where standard="CST-FRAMEWORK";
  delete from cstMeta.&_cstGlobalStdSASRefsDSName
    where standard="CST-FRAMEWORK";
  delete from cstMeta.&_cstGlobalStdLookupDSName
    where standard="CST-FRAMEWORK";
quit;

%cst_registerStandard(
  _cstRootPath=%nrstr(&_cstGRoot./standards/cst-framework-1.7),
  _cstControlSubPath=control,
  _cstStdDSName=standards,
  _cstStdSASRefsDSName=standardsasreferences,
  _cstStdLookupDSName=standardlookup);

%symdel
  _cstGlobalMDPath
  _cstGlobalMDLib
  _cstGlobalStdDSName
  _cstGlobalStdSASRefsDSName
  _cstGlobalStdLookupDSName
  / nowarn;
   