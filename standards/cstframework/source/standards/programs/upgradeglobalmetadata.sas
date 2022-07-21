**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* define the variables/temporary names used                                      *;
**********************************************************************************;

  %global
    _cstTableNameGlobalStdsReg
    _cstTableNameGlobalSASRefs
    _cstTableNameGlobalLookup
    _cstPathGlobalMetadata    
    _cstPathGlobalStandards    
    _cstRandom _cstGlobalMetadata _cstFrameworkTemplates
    _cstGlobalLoggingPath _cstGlobalLoggingDS _cstGlobalLogs;

  %* retrieve the static names to be used;
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD, _cstVar=_cstTableNameGlobalStdsReg);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS, _cstVar=_cstTableNameGlobalSASRefs);
  %cst_getStatic(_cstName=CST_GLOBALMD_LOOKUP, _cstVar=_cstTableNameGlobalLookup);
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH, _cstVar=_cstPathGlobalMetadata);
  %cst_getStatic(_cstName=CST_GLOBALSTD_PATH, _cstVar=_cstPathGlobalStandards);
  %cst_getStatic(_cstName=CST_LOGGING_PATH,_cstVar=_cstGlobalLoggingPath);
  %cst_getStatic(_cstName=CST_LOGGING_DS,_cstVar=_cstGlobalLoggingDS);


  %* Assign a random name for the variables;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMetadata=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalLogs=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstFrameworkTemplates=_cst&_cstRandom;

  * Assign the libname into the global metadata directory;
  libname &_cstGlobalMetadata "%unquote(&_cstPathGlobalMetadata)";

  * Assign the libname into the global logs directory;
  libname &_cstGlobalLogs "%unquote(&_cstGlobalLoggingPath)";

  * Assign the libname into the framework templates directory;
  libname &_cstFrameworkTemplates "%unquote(&_cstPathGlobalStandards/cst-framework-1.7/templates)";


  * Upgrade the global library data sets;
  data &_cstGlobalMetadata..&_cstTableNameGlobalStdsReg;
     if (0) then set &_cstFrameworkTemplates..standards;
     set &_cstGlobalMetadata..&_cstTableNameGlobalStdsReg;
  run;

  data &_cstGlobalMetadata..&_cstTableNameGlobalSASRefs;
     if (0) then set &_cstFrameworkTemplates..sasreferences;
     set &_cstGlobalMetadata..&_cstTableNameGlobalSASRefs;
  run;

  data &_cstGlobalMetadata..&_cstTableNameGlobalLookup;
     if (0) then set &_cstFrameworkTemplates..standardlookup;
     set &_cstGlobalMetadata..&_cstTableNameGlobalLookup;
  run;

  data &_cstGlobalLogs..&_cstGlobalLoggingDS;
     if (0) then set &_cstFrameworkTemplates..transactionlog;
     set &_cstGlobalLogs..&_cstGlobalLoggingDS;
  run;


  * Clear the libnames ;
  libname &_cstGlobalMetadata;
  libname &_cstGlobalLogs;
  libname &_cstFrameworkTemplates;  