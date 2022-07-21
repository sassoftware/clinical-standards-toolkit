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

  * Create the global data sets;
  proc sql;
    create table &_cstGlobalMetadata..&_cstTableNameGlobalStdsReg
      like &_cstFrameworkTemplates..standards;
    create table &_cstGlobalMetadata..&_cstTableNameGlobalSASRefs
      like &_cstFrameworkTemplates..sasreferences;
    create table &_cstGlobalMetadata..&_cstTableNameGlobalLookup
      like &_cstFrameworkTemplates..standardlookup;
    create table &_cstGlobalLogs..&_cstGlobalLoggingDS
      like &_cstFrameworkTemplates..transactionlog;
    quit;
  run;

  * Clear the libnames ;
  libname &_cstGlobalMetadata;
  libname &_cstGlobalLogs;
  libname &_cstFrameworkTemplates;  