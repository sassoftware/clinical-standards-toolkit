%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_registerStandard                                                           *;
%*                                                                                *;
%* Registers a new standard within the global standards library.                  *;
%*                                                                                *;
%* This macro registers a new standard and standardversion to the SAS Clinical    *;
%* Standards Toolkit. The minimum information that is required to register a new  *;
%* standard is defined in the macro parameters.rdversion from the                 *;
%* StandardSASReferences data set. The data sets defined by _cstStdDSName and     *;
%* _cstStdSASRefsDSName have the same structure as the data sets in the global    *;
%* standards library metadata directory.                                          *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstRootPath - required - The root path for the directory structure of  *;
%*            the standard.                                                       *;
%* @param _cstControlSubPath - required - The path, relative to _cstRootPath, of  *;
%*            the directory that contains the metadata files for a standard       *;
%*            (normally called standard and standardSASReferences).               *;
%* @param _cstStdDSName - required - The member name of the data set that         *;
%*            contains metadata about the standard to install.                    *;
%* @param _cstStdSASRefsDSName - required - The member name of the data set       *;
%*            that contains the metadata about the standardSASReferences data set *;
%*            to install.                                                         *;
%* @param _cstStdLookupDSName - optional - The member name of the data set        *;
%*            that contains the metadata about the standardlookup data set        *;
%*            to install.                                                         *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cst_registerStandard(
     _cstRootPath=,
     _cstControlSubPath=,
     _cstStdDSName=,
     _cstStdSASRefsDSName=,
     _cstStdLookupDSName=
     ) /des='CST: Register a new standard';

  %local
    _cstControlLib
    _cstDuplicate
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDSName
    _cstGlobalStdSASRefsDSName
    _cstGlobalStdLookupDSName
    _cstGlobalTransformsXML
    _cstIsANewStandard
    _cstParm1
    _cstRandom
    _cstStandard
    _cstStandardVersion
    _cstTempFilename01
    _cstTempNewStdMD
    _cstTempNewStdRefsMD
    _cstTempNewLookupMD
    _cstTempOrigStdMD
    _cstTempXslMD
    _cstTempStdXslMD
    _cstThisMacroMsg
    _cstThisMacroRC
    _cstThisResultsDS
    ;

  %* create the global macro variable if it does not exist, then set it;
  %if (%eval(not %symexist(_cst_rc))) %then %do;
    %global _cst_rc;
  %end;

  %let _cstThisMacroRC=0;
  %let _cstThisMacroMsg=;


  %if %klength(&_cstRootPath)=0 or %klength(&_cstControlSubPath)=0 %then
  %do;
    * Parameter specification to macro incomplete.  *;
    %let _cstThisMacroMsg=Both _cstRootPath and _cstControlSubPath must have non-missing values;
    %goto BADPARM;
  %end;

  %* assign the library to the control area that contains the registration data sets;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstControlLib=_cst&_cstRandom;

  libname &_cstControlLib "%unquote(&_cstRootPath./&_cstControlSubPath)";

  %if %length(&_cstStdDSName)=0 %then %do;
    * Parameter specification to macro incomplete.  *;
    %let _cstThisMacroMsg=You must specify the name of the file containing standard metadata in _cstStdDSName;
    %goto BADPARM;
  %end;
  %if (^%sysfunc(exist(&_cstControlLib..&_cstStdDSName))) %then %do;
    * Parameter specification to macro invalid.  *;
    %let _cstThisMacroMsg=&_cstControlLib..&_cstStdDSName could not be found;
    %goto BADPARM;
  %end;

  %if %length(&_cstStdSASRefsDSName)=0 %then %do;
    * Parameter specification to macro incomplete.  *;
    %let _cstThisMacroMsg=You must specify the name of the file containing standard metadata in _cstStdSASRefsDSName;
    %goto BADPARM;
  %end;
  %if (^%sysfunc(exist(&_cstControlLib..&_cstStdSASRefsDSName))) %then %do;
    * Parameter specification to macro invalid.  *;
    %let _cstThisMacroMsg=&_cstControlLib..&_cstStdSASRefsDSName could not be found;
    %goto BADPARM;
  %end;

/* standardlookup is NOT required -- e.g. CDISC-TERMINOLOGY 

  %if %length(&_cstStdLookupDSName)=0 %then %do;
    * Parameter specification to macro incomplete.  *;
    %let _cstThisMacroMsg=You must specify the name of the file containing standard lookup metadata in _cstStdLookupDSName;
    %goto BADPARM;
  %end;
  %if (^%sysfunc(exist(&_cstControlLib..&_cstStdLookupDSName))) %then %do;
    * Parameter specification to macro invalid.  *;
    %let _cstThisMacroMsg=&_cstControlLib..&_cstStdLookupDSName could not be found;
    %goto BADPARM;
  %end;
*/

  %* get the path of the global metadata directory and the names of the global data sets;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_LOOKUP,_cstVar=_cstGlobalStdLookupDSName);
  %cst_getStatic(_cstName=CST_GLOBALMD_TRANSFORMSXML,_cstVar=_cstGlobalTransformsXML);

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempFilename01=_cst&_cstRandom;

  %if (%symexist(_cstMessages)) %then %do;
    %* Create a temporary messages data set if required;
    %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);
  %end;

  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)";

  %* create a temporary data set and set root path for the standard;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempNewStdMD=_cst&_cstRandom;

  * Create a temporary data set with the standard root path in it;
  data &_cstTempNewStdMD;
    set &_cstControlLib..&_cstStdDSName;
      rootpath="&_cstRootPath";
      call symputx('_cstStandard',standard,'L');
      call symputx('_cstStandardVersion',standardVersion,'L');
  run;

  * Check the standard-version is not already installed;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempOrigStdMD=_cst&_cstRandom;
  proc sort data=&_cstGlobalMDLib..&_cstGlobalStdDSName out=&_cstTempOrigStdMD;
    by standard standardversion;
  run;

  %let _cstDuplicate=N;
  data _null_;
    merge &_cstTempNewStdMD(in=x keep=standard standardversion) &_cstTempOrigStdMD(in=y keep=standard standardversion);
      by standard standardversion;
        if (x and y) then do;
          call symputx('_cstDuplicate','Y','L');
        end;
  run;

  %if (&_cstDuplicate=Y) %then %do;
    %let _cstThisMacroRC=0;
    %let _cstParm1=&_cstStandard &_cstStandardVersion;
    %goto STD_EXISTS;
  %end;

  %* Check to see if the standard is already installed and update the isStandardDefault accordingly;
  %let _cstIsANewStandard=1;
  data _null_;
     set &_cstTempOrigStdMD;
     if (standard="&_cstStandard") then do;
       call symputx('_cstIsANewStandard','0');
     end;
  run;
  %if (&_cstIsANewStandard) %then %do;
    data &_cstTempNewStdMD;
       set &_cstTempNewStdMD;
         if ((standard="&_cstStandard") AND
            (standardVersion="&_cstStandardVersion")) then do;
               isStandardDefault="Y";
         end;
    run;
  %end;


  * try to get exclusive access to the data sets;
  lock &_cstGlobalMDLib..&_cstGlobalStdDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdDSName data set.;
    %goto LOCKERROR;
  %end;

  lock &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdSASRefsDSName data set.;
    %goto LOCKERROR;
  %end;

  lock &_cstGlobalMDLib..&_cstGlobalStdLookupDSName;
  %if (&syslckrc=0) %then;
  %else %do;
    %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Unable to acquire exclusive locks on the global &_cstGlobalStdLookupDSName data set.;
    %goto LOCKERROR;
  %end;


  * Create a temporary version of the new SASRefs file and calculate the full path;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempNewStdRefsMD=_cst&_cstRandom;
  data &_cstTempNewStdRefsMD;
    set &_cstControlLib..&_cstStdSASRefsDSName;
      if ktrim(relpathprefix) ne '' then
      do;
        path = ktrim(kleft("&_cstRootPath")) || '/' || ktrim(kleft(path));
        relpathprefix='';
      end;
  run;
 
  %if (%sysfunc(exist(&_cstControlLib..&_cstStdLookupDSName))) %then %do;
    * Create a temporary version of the new Lookup file and calculate the full path;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempNewLookupMD=_cst&_cstRandom;
    data &_cstTempNewLookupMD;
      set &_cstControlLib..&_cstStdLookupDSName;
    run;
  %end;
  %else
  %do;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempNewLookupMD=_cst&_cstRandom;
    %cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=cstmetadata,_cstSubType=lookup,
          _cstOutputDS=&_cstTempNewLookupMD);
  %end;


  * Append the data to the standard;
  proc append base=&_cstGlobalMDLib..&_cstGlobalStdDSName
    data=&_cstTempNewStdMD;
  run;

  proc sort data=&_cstGlobalMDLib..&_cstGlobalStdDSName;
    by standard standardVersion;
  run;

  * Append the data to the standard sasreferences;
  proc append base=&_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName
    data=&_cstTempNewStdRefsMD;
  run;

  proc sort data=&_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName;
    by standard standardVersion type subType sasref;
  run;

  * Append the data to the standard lookup;
  proc append base=&_cstGlobalMDLib..&_cstGlobalStdLookupDSName
    data=&_cstTempNewLookupMD;
  run;

  proc sort data=&_cstGlobalMDLib..&_cstGlobalStdLookupDSName;
    by standard standardVersion sasref table column refcolumn refvalue value templatetype template;
  run;


  * Get the default XSL stylesheet;
  %let _cstTempXslMD=_cst_xsl_&_cstRandom;
  data &_cstTempXslMD(keep=standard standardversion memname rename=(memname=DefaultStylesheet));
    set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName;
      where type="referencexml" and subtype="stylesheet" and not missing(memname);
  run;

  %let _cstTempStdXslMD=_cst_std_xsl_&_cstRandom;
  proc sql;
    create table &_cstTempStdXslMD as
    select std.*, xsl.DefaultStylesheet
      from 
      &_cstGlobalMDLib..&_cstGlobalStdDSName std
    left join
      &_cstTempXslMD xsl
    on (std.standard=xsl.standard) and (std.standardVersion=xsl.standardVersion)
    order by standard, standardVersion
    ;
  quit;  
  
  * Recreate the available transforms XML file;
  filename &_cstTempFilename01 "%unquote(&_cstGlobalMDPath./&_cstGlobalTransformsXML)";

  data _null_;
    file &_cstTempFilename01;
        put '<?xml version="1.0" encoding="UTF-8" ?>';
        put '<AvailableTransforms>';
  run;

  data _null_;
    set &_cstTempStdXslMD(where=(isXMLStandard='Y'));
      file &_cstTempFilename01 mod;
        put @3 '<Transform>';
        put @6 '<StandardName>' standard +(-1) '</StandardName>';
        put @6 '<StandardVersion>' standardVersion +(-1) '</StandardVersion>';
        if not missing(importXSL)
          then put @6 '<ImportXSL>' importXSL +(-1) '</ImportXSL>';
        if not missing(exportXSL)
          then put @6 '<ExportXSL>' exportXSL +(-1) '</ExportXSL>';
        put @6 '<Schema>' schema +(-1) '</Schema>';
        if not missing(DefaultStylesheet) then
          put @6 '<DefaultStylesheet>' DefaultStylesheet +(-1) '</DefaultStylesheet>'; 
        put @3 '</Transform>';
  run;

  data _null_;
    file &_cstTempFilename01 mod;
        put '</AvailableTransforms>';
  run;

  filename &_cstTempFilename01 "%unquote(&_cstGlobalMDPath./&_cstGlobalTransformsXML)";

  %let _cstThisMacroRC=0;
  %if (%symexist(_cstResultsDS)) %then %do;
    %put [CSTLOG%str(MESSAGE).&sysmacroname]: Info: &_cstStandard &_cstStandardVersion has been registered as a standard.;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                  _cstResultId=CST0105
                  ,_cstResultParm1=&_cstStandard &_cstStandardVersion
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=CST_REGISTERSTANDARD
                  ,_cstResultFlagParm=&_cstThisMacroRC
                  ,_cstRCParm=&_cstThisMacroRC
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %goto CLEANUP;

%BADPARM:
  %let _cstThisMacroRC=1;
  %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] Parameter specifications to cst_registerstandard are incomplete or invalid.;
  %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] &_cstThisMacroMsg..;
  %goto CLEANUP;

%STD_EXISTS:
  %let _cstThisMacroRC=1;
  %put %str(ERR)OR: [CSTLOG%str(MESSAGE).&sysmacroname] The standard &_cstParm1 already exists.;
  %goto CLEANUP;

%LOCKERROR:
  %let _cstThisMacroRC=1;
  %goto CLEANUP;

%CLEANUP:
  %if &_cstThisMacroRC=0 %then
  %do;
    * unlock the data sets;
    lock &_cstGlobalMDLib..&_cstGlobalStdDSName clear;
    lock &_cstGlobalMDLib..&_cstGlobalStdSASRefsDSName clear;
    lock &_cstGlobalMDLib..&_cstGlobalStdLookupDSName clear;

    %* delete the work data sets;
    proc datasets nolist lib=work;
      delete &_cstTempNewStdMD &_cstTempOrigStdMD &_cstTempNewStdRefsMD 
             &_cstTempNewLookupMD &_cstTempXslMD &_cstTempStdXslMD/ mt=data;
    quit;

    %* clear the libnames;
    libname &_cstGlobalMDLib;
    libname &_cstControlLib;

  %end;

  %let _cst_rc=&_cstThisMacroRC;

%mend cst_registerStandard;
