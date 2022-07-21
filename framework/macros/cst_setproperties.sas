%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_setProperties                                                              *;
%*                                                                                *;
%* Reads a properties file or data set and sets global macros, accordingly.       *;
%*                                                                                *;
%* A properties file must have the format name=value. A data set must have a      *;
%* character field for name and value. A line in which the first non-blank        *;
%* character is # or ! is ignored. A data set can have a comment field, but this  *;
%* field is ignored.                                                              *;
%*                                                                                *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstPropertiesLocation - required - The location of the properties      *;
%*            file. The format depends upon the value of _cstLocationType.        *;
%* @param _cstLocationType - required - The format for the value of               *;
%*            _cstPropertiesLocation. Valid values are:                           *;
%*            PATH: The path to a properties file.                                *;
%*            FILENAME: A valid, assigned SAS filename to the properties file.    *;
%*            DATA: A (libname.)membername of a SAS data set that contains the    *;
%*            properties.                                                         *;
%*            Values: PATH | FILENAME | DATA                                      *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_setProperties(
  _cstPropertiesLocation=,
  _cstLocationType=,
  _cstResultsOverrideDS=
  ) / des='CST: Reads a properties file/data set and sets global macros accordingly';

  %cstutil_setcstgroot;

  %local
    _cstError
    _cstLocnData
    _cstLocnFilename
    _cstLocnPath
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstParamInError
    _cstParm1
    _cstParm2
    _cstRandom
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstSeqCount
    _cstSourceData
    _cstTempDS1
    _cstTempFN1
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
  ;

  %let _cstThisMacroRC=0;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempFN1=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %let _cstLocnPath=PATH;
  %let _cstLocnFilename=FILENAME;
  %let _cstLocnData=DATA;

  %let _cstSourceData=&sysmacroname;
  %let _cstSeqCount=0;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);

  %* Pre-condition: location must be specified;
  %if (%length(&_cstPropertiesLocation)=0) %then %do;
    %let _cstParamInError=_cstPropertiesLocation;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-condition: locationType must be specified;
  %if (%length(&_cstLocationType)=0) %then %do;
    %let _cstParamInError=_cstLocationType;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-condition: locationType must be valid;
  %if (not ((%sysfunc(upcase(&_cstLocationType))=&_cstLocnPath) OR
       (%sysfunc(upcase(&_cstLocationType))=&_cstLocnFilename) OR
       (%sysfunc(upcase(&_cstLocationType))=&_cstLocnData))
      ) %then %do;
    %let _cstParm1=&_cstLocationType;
    %goto INVALID_LOCNTYPE;
  %end;


  %if ((%sysfunc(upcase(&_cstLocationType))=&_cstLocnPath) OR
       (%sysfunc(upcase(&_cstLocationType))=&_cstLocnFilename)
      ) %then %do;
    %if (%sysfunc(upcase(&_cstLocationType))=&_cstLocnPath) %then %do;
      *assign a filename to the path provided;
      filename &_cstTempFN1 "&_cstPropertiesLocation";
    %end;
    %else %do;
      %let _cstTempFN1=&_cstPropertiesLocation;
    %end;
    %if ^%sysfunc(fexist(&_cstTempFN1)) %then
    %do;
      %let _cstPropertiesLocation=%sysfunc(pathname(&_cstTempFN1,'F'));
      %let _cstParm1=The properties file;
      %goto FILE_NOTFOUND;
    %end;

    %cstutilreadproperties(
      _cstPropertiesFile=&_cstTempFN1,
      _cstLocationType=FILENAME, 
      _cstOutputDSName=&_cstTempDS1
    );

  %end;
  %else %do;
    * Load the provided data set into a temporary file;
    data &_cstTempDS1;
      set &_cstPropertiesLocation;
    run;
  %end;

  * Read the temporary file and assign the macro variables;
  data _null_;
    set &_cstTempDS1;
    length firstLetter $1;

    * must begin with a letter or underscore;
    firstLetter = substr(name,1,1);
    if (firstLetter = '_') OR
       ('a' LE firstLetter LE 'z') OR
       ('A' LE firstLetter LE 'Z');

    * set the global macro variable;
    call symputx(kstrip(name),kstrip(value),'G');
  run;

  proc datasets nolist lib=work;
    delete &_cstTempDS1 / mt=data;
    quit;
  run;

  %let _cstThisMacroRC=0;
  %* handle the case where the properties reset the _cstResultSeq to 0;
  %if (&_cstResultSeq=0) %then %do;
      %let _cstResultSeq=1;
  %end;
  %let _cstSeqCount=%eval(&_cstSeqCount+1);
  %cstutil_writeresult(
                _cstResultId=CST0108
                ,_cstResultParm1=&_cstLocationType
                ,_cstResultParm2=&_cstPropertiesLocation
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCount
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstSrcDataParm=&_cstSourceData
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NULL_PARAMETER:
  %let _cstThisMacroRC=1;
  %let _cstSeqCount=%eval(&_cstSeqCount+1);
  %cstutil_writeresult(
                _cstResultId=CST0081
                ,_cstResultParm1=&_cstParamInError
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCount
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstSrcDataParm=&_cstSourceData
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_LOCNTYPE:
  %let _cstThisMacroRC=1;
  %let _cstSeqCount=%eval(&_cstSeqCount+1);
  %cstutil_writeresult(
                _cstResultId=CST0107
                ,_cstResultParm1=&_cstParm1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCount
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstSrcDataParm=&_cstSourceData
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%FILE_NOTFOUND:
  %let _cstThisMacroRC=1;
  %let _cstSeqCount=%eval(&_cstSeqCount+1);
  %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=&_cstParm1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCount
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstSrcDataParm=&_cstSourceData
                ,_cstActualParm=%str(&_cstPropertiesLocation)
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %if (%sysfunc(upcase(&_cstLocationType))=&_cstLocnPath) %then %do;
    *deassign the filename to the path provided;
    filename &_cstTempFN1 ;
  %end;

  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  %* Delete the temporary messages data set if it was created here;
  %* TODO: Future. Make this a callable component as it is used a lot;
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

%mend cst_setProperties;