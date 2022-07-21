%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilreadproperties                                                          *;
%*                                                                                *;
%* Reads a SAS Clinical Standards Toolkit properties file into a data set.        *;
%*                                                                                *;
%* Properties are name-value pairs that are translated into SAS global macro      *;
%* variables. This macro ignores lines that start with # or !.                    *;
%*                                                                                *;
%* @param _cstPropertiesFile - required - The full path to the properties file.   *;
%* @param _cstLocationType - required - The format for the value of               *;
%*            _cstPropertiesFile.                                                 *;
%*            Values:                                                             *;
%*            PATH:     The path to the properties file.                          *;
%*            FILENAME: The valid, assigned SAS filename reference to the         *;
%*                      properties file.                                          *;
%*            Default: PATH                                                       *;
%* @param  _cstOutputDSName - required - The output data set in                   *;
%*            (libname.)member format.                                            *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilreadproperties(
  _cstPropertiesFile=,
  _cstLocationType=PATH, 
  _cstOutputDSName=
  ) / des='CST: Read properties file';

  %local _cstRandom 
         _cstTempFN1;
  
  %**********************************;
  %*  Check Macro parameter values  *;
  %**********************************;
  %if %sysevalf(%superq(_cstPropertiesFile)=, boolean) or 
      %sysevalf(%superq(_cstLocationType)=, boolean) or
      %sysevalf(%superq(_cstOutputDSName)=, boolean) %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): %str()_cstPropertiesFile, _cstLocationType and _cstOutputDSName parameter values are required.;
    %goto exit_error;
  %end;

  %***********************************************;
  %*  Pre-condition: locationType must be valid  *;
  %***********************************************;
  %if (not ((%sysfunc(upcase(&_cstLocationType))=PATH) or (%sysfunc(upcase(&_cstLocationType))=FILENAME))) %then 
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): %str()_cstLocationType must be PATH or FILENAME.;
    %goto exit_error;
  %end;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempFN1=_cst&_cstRandom;

  %if (%sysfunc(upcase(&_cstLocationType))=PATH) %then 
  %do;
    %********************************************;
    %*  Assign a filename to the path provided  *;
    %********************************************;
    filename &_cstTempFN1 "&_cstPropertiesFile";
  %end;
  %else 
  %do;
    %let _cstTempFN1=&_cstPropertiesFile;
  %end;
  
  %if %sysfunc(fexist(&_cstTempFN1))=0 %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): &_cstPropertiesFile does not exist.;
    %goto exit_error;
  %end;

  %*********************************************;
  %*  Read in the file to the output data set  *;
  %*********************************************;
  data &_cstOutputDSName(drop=textline firstEqualsSign);
    length name value textline $250.;
    infile &_cstTempFN1 length=l1;
    input textline $varying. l1;
    textline=kcompress(textline,'0D'x);

    %****************************;
    %*  Line must not be blank  *;
    %****************************;
    if l1 > 0;

    %**************************;
    %*  Ignore comment lines  *;
    %**************************;
    if ksubstr(left(textline), 1, 1) not in ('#' '!');

    %*************************************;
    %*  Must have one equals sign in it  *;
    %*************************************;
    firstEqualsSign=kindex(textline, '=');
    if (firstEqualsSign > 0 or textline=:'=');

    %********************************************;
    %*  Split up the parts into name and value  *;
    %********************************************;
    name=kscan(textline,1, '=');
    if length(textLine) >= firstEqualsSign + 1 then
    do;
      value=ksubstr(textLine, firstEqualsSign + 1);
    end;
    else
    do;
      call missing(value);
    end;
  run;

  %if (%sysfunc(upcase(&_cstLocationType))=PATH) %then 
  %do;
    %************************************************;
    %*  Deassign the filename to the path provided  *;
    %************************************************;
    filename &_cstTempFN1 ;
  %end;

  %exit_error:

%mend cstutilreadproperties;