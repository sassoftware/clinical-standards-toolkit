%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_setStandardProperties                                                      *;
%*                                                                                *;
%* Sets specific standard global macro variables from properties files.           *;
%*                                                                                *;
%* This macro sets properties (global macro variables) that are supplied as part  *;
%* of a standard. When a standard is registered, it most likely also registers    *;
%* values in a SASReferences file. A number of these values might be for          *;
%* properties files that are used by the standard, or provided by the standard to *;
%* help you. For example, CST_FRAMEWORK provides a property subType of 'required' *;
%* that points to a properties file that has default settings for required        *;
%* properties. You can call this method using this code to set these properties:  *;
%*                                                                                *;
%* %cst_setStandardProperties(                                                    *;
%*    _cstStandard=CST-FRAMEWORK,                                                 *;
%*    _cstStandardVersion=1.2,                                                    *;
%*    _cstSubType=initialize);                                                    *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstMessages  Cross-standard work messages data set                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*             Values: 1 | 0                                                      *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the registered standard.          *;
%* @param _cstStandardVersion - optional - The version of the standard. If the    *;
%*            standard has a default set, this parameter is optional. Otherwise,  *;
%*            it is required.                                                     *;
%* @param _cstSubType - required - The name of the properties subtype from which  *;
%*            to read and set properties.                                         *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_setStandardProperties(
    _cstStandard=,
    _cstStandardVersion=,
    _cstSubType=,
    _cstResultsOverrideDS=
    ) / des='CST: Sets specific standard global macro variables from property files';

  %cstutil_setcstgroot;

  %* the following are needed in case the framework properties are the ones being set;
  %if (not %symexist(_cst_rc)) %then %do;
    %global _cst_rc;
  %end;
  %if (not %symexist(_cstMessages)) %then %do;
    %global _cstMessages;
    %let _cstMessages=work._cstMessages;
  %end;
  %if (not %symexist(_cstResultsDS)) %then %do;
    %global _cstResultsDS;
    %let _cstResultsDS=work._cstResults;
  %end;
  %if (not %symexist(_cstResultSeq)) %then %do;
    %global _cstResultSeq;
    %let _cstResultSeq=0;
  %end;
  %if (not %symexist(_cstSeqCnt)) %then %do;
    %global _cstSeqCnt;
    %let _cstSeqCnt=0;
  %end;
  %if (not %symexist(_cstDebug)) %then %do;
    %global _cstDebug;
    %let _cstDebug=0;
  %end;

  %local
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDSName
    _cstGlobalStdSASRefsDSName
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstParamInError
    _cstParm1
    _cstParm2
    _cstRandom
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstTempDS1
    _cstTempPropMember
    _cstTempPropPath
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
    ;

  %let _cstThisMacroRC=0;

  %* get the path of the global metadata directory and the names of the global data sets;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDSName);


  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);

  %let _cstResultSeq=1;


  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)";

  %* Pre-requisite: _cstStandard must be supplied;
  %if (%length(&_cstStandard)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstStandard;
    %goto NULL_PARAMETER;
  %end;


  %* Pre-requisite: _cstSubType is not blank;
  %if (%length(&_cstSubType)=0) %then %do;
    %let _cstParamInError=_cstSubType;
    %goto NULL_PARAMETER;
  %end;



  * Pre-requisite: Check that the standard is valid;
  %let _cstError=Y;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDSName
      (where=(upcase(standard)=%sysfunc(upcase("&_cstStandard"))));
    if (_n_=1) then call symputx('_cstError','N','L');
  run;

  %if (&_cstError=Y) %then %do;
    %goto INVALID_STD;
  %end;


  * Pre-requisite: Check that the version is valid (if provided) or a default exists if not;
  %if (%length(&_cstStandardVersion)>0) %then %do;
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
  %end;
  %else %do;
    %let _cstError=Y;
    * Check that there is a default version specified and retrieve it;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(isstandarddefault="Y"));
      if (_n_=1) then call symputx('_cstError','N','L');
      call symputx('_cstStandardVersion',standardVersion,'L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %let _cstParm1=&_cstStandard;
      %goto NO_DEFAULT_VERSION;
    %end;
  %end;


  * Retrieve the standard SAS references for the standard and version;
  %let _cstError=Y;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName
      (where=(
        (upcase(standard)=%sysfunc(upcase("&_cstStandard"))) AND
        (upcase(standardVersion)=%sysfunc(upcase("&_cstStandardVersion"))) AND
        (upcase(type)='PROPERTIES') AND
        (upcase(subType)=%sysfunc(upcase("&_cstSubType")))
      ));
    if (_n_=1) then call symputx('_cstError','N','L');

    call symputx('_cstTempPropPath',path,'L');
    call symputx('_cstTempPropMember',memname,'L');
  run;

  %* process there being no SASReferences for the standard/version;
  %if (&_cstError=Y) %then %do;
    %let _cstParm1=&_cstStandard &_cstStandardVersion;
    %let _cstParm2=&_cstSubType;
    %goto NO_SASREFERENCES;
  %end;


  %cst_setProperties(
    _cstPropertiesLocation=&_cstTempPropPath./&_cstTempPropMember
    ,_cstLocationType=PATH
    ,_cstResultsOverrideDS=&_cstThisResultsDS
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
                ,_cstSrcDataParm=CST_SETSTANDARDPROPERTIES
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
                ,_cstSrcDataParm=CST_SETSTANDARDPROPERTIES
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
                ,_cstSrcDataParm=CST_SETSTANDARDPROPERTIES
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NO_DEFAULT_VERSION:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0085
                ,_cstResultParm1=&_cstParm1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDPROPERTIES
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NO_SASREFERENCES:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0106
                ,_cstResultParm1=&_cstParm1
                ,_cstResultParm2=&_cstParm2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_SETSTANDARDPROPERTIES
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

  %let _cst_rc=&_cstThisMacroRC;

%mend cst_setStandardProperties;