%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_createTempMessages                                                     *;
%*                                                                                *;
%* Creates a temporary Messages data set using the CST-FRAMEWORK messages.        *;
%*                                                                                *;
%* If the Messages data set specified by the macro variable &_cstMessages does    *;
%* not exist, this macro creates a temporary version. It looks for the default    *;
%* version of the SAS Clinical Standards Toolkit framework. It copies the Messages*;
%* data set specified in the default SASReferences file to the name specified in  *;
%* the &_cstMessages macro variable. If the caller supplies the name of a macro   *;
%* variable in _cstCreationFlag, this is set if the data set was created in this  *;
%* macro.                                                                         *;
%*                                                                                *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstCreationFlag - optional - The name of the macro variable to set in  *;
%*            the macro. If the macro does not create the Messages data set       *;
%*            (because it existed), the macro variable is set to 0. If the macro  *;
%*            creates the data set, the macro variable is set to 1. It is strongly*;
%*            suggested that the caller use this macro variable to ensure that the*;
%*            temporary data set is cleaned up afterward.                         *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_createTempMessages(
    _cstCreationFlag=
    ) / des='CST: Create a temporary messages data set';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstDefaultVersion
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstNextCode
    _cstRandom
    _cstTempDS1
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

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %* Pre-requisite: The data set specified by &_cstMessages does not exist;
  %if %symexist(_cstMessages) %then %do;
    %if %sysfunc(exist(&_cstMessages)) %then %do;
      %if (%length(_cstFlagCreatedIt) > 0) %then %do;
        %* Set the flag to mean that this method did not create the data set;
        %if (%length(&_cstCreationFlag) > 0) %then %do;
            %let &_cstCreationFlag=0;
        %end;
        %return;
      %end;
    %end;
  %end;
  %else %do;
    %global _cstMessages;
    %let _cstmessages=work._cstmessages;
  %end;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  * Find the default version of the framework;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDS
      (where=(
        (upcase(standard)="CST-FRAMEWORK") AND
        (upcase(isStandardDefault)="Y")
      ));
    call symputx('_cstDefaultVersion',standardVersion,'L');
  run;

  * Assign a filename for the code that will be generated;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source";

  * Find the messages data set and create code to copy it;
  data _null_;
    file &_cstNextCode;
    set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDS(where=(
      (upcase(standard)="CST-FRAMEWORK") AND
      (upcase(standardversion)="&_cstDefaultVersion") AND
      (upcase(type)="MESSAGES")
      ));

    * handle the case where membername has been given an extension;
    memname=scan(memname,1,'.');
    path=%unquote(path);

    put 'libname &_cstNextCode "' path +(-1)'" access=readonly;';

    put 'proc sql;';
    put @2 "create table &_cstMessages as select * from &_cstNextCode.." memname';';
    put @2 'quit;';

    put "libname &_cstNextCode;";
  run;

  * Include the generated code;
  %include &_cstNextCode;

  %* set the variable flag to say that the data set was created from within this macro;
  %if (%length(&_cstCreationFlag) > 0) %then %do;
    %let &_cstCreationFlag=1;
  %end;

  * Clear the filename;
  filename &_cstNextCode;

  * Clear the libname;
  libname &_cstGlobalMDLib;

  * Clean up temporary data sets if they exist;
  proc datasets nolist lib=work;
    delete &_cstTempDS1  / mt=data;
    delete &_cstNextCode / mt=catalog;
  quit;

%mend cstutil_createTempMessages;