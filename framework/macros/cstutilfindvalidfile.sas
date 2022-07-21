%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilfindvalidfile                                                           *;
%*                                                                                *;
%* Checks whether a folder, file, data set, catalog, or catalog member exists.    *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param _cstFileType - required - The type of object to check within the SAS    *;
%*            Clinical Standards Toolkit:                                         *;
%*            CATALOG: Checks for the existence of a SAS fomat catalog or catalog *;
%*                     member that is specified in _cstFileRef. This macro        *;
%*                     requires that the libname be assigned before invoking this *;
%*                     macro. A two-part file name is required for a catalog (for *;
%*                     example, mysas.formats). A four-part name is required for  *;
%*                     a catalog member (for example, mysas.formats.race.formatc).*;
%*            DATASET: Checks for the existence of a SAS dataset that is specified*;
%*                     in _cstFileRef. The libname must be assigned before        *;
%*                     invoking this macro.                                       *;
%*            VIEW:    Checks for the existence of a SAS view that is specified in*;
%*                     _cstFileRef. The libname must be assigned before invoking  *;
%*                     this macro.                                                *;
%*            FILE:    Checks for the existence of a file that is specified in    *;
%*                     _cstFilePath and _cstFileRef.                              *;
%*            FOLDER:  Checks for the existence of a folder that is specified in  *;
%*                     _cstFilePath.                                              *;
%*            Values: CATALOG | DATASET | VIEW | FILE | FOLDER                    *;
%* @param _cstFilePath - conditional - The physical path of the file or folder to *;
%*            check. Required when _cstFileType is FILE or FOLDER (for example,   *;
%*            _cstFilePath=C:\cstSampleLibrary\cdisc-sdtm-3.1.2).                 *;
%* @param _cstFileRef - required - The name of the object to check.               *;
%*            _cstFileType=CATALOG for catalog _cstFileRef=cat1.format            *;
%*            _cstFileType=CATALOG for member _cstFileRef=cat1.formats.sex.formatc*;
%*            _cstFileType=DATASET _cstFileRef=mysas.dm                           *;
%*            _cstFileType=VIEW _cstFileRef=mysas.dmview                          *;
%*            _cstFileType=FILE  _cstFileRef=dm.sas7bdat                          *;
%*            _cstFileType=FOLDER _cstFileRef=                                    *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilfindvalidfile(
    _cstFileType=,
    _cstFilePath=,
    _cstFileRef=
    ) / des="CST: Checks for existence of a filesystem object";

  %if %symexist(_cstDebug) %then 
  %do;
    %if &_cstDebug=1 %then
    %do;
      %put *********************************************************************;
      %put * STARTING macro &sysmacroname;
      %put *  Parameter _cstFileType = &_cstFileType;
      %put *  Parameter _cstFilePath = &_cstFilePath;
      %put *  Parameter _cstFileRef  = &_cstFileRef;
      %put *  _cst_rc                = &_cst_rc;
      %put *  _cst_rcmsg             = &_cst_rcmsg;
      %put *********************************************************************;
    %end;
  %end;

  %local _cstDir
         _cstRandom
         _cstType;

  %*****************************************;
  %*  Set error code and message variable  *;
  %*****************************************;
  %let _cst_rc=0;
  %let _cst_rcmsg=;

  %***********************************;
  %*  Check _cstFileType parameters  *;
  %***********************************;
  %if %upcase(&_cstFileType) ne FILE and
      %upcase(&_cstFileType) ne CATALOG and
      %upcase(&_cstFileType) ne DATASET and
      %upcase(&_cstFileType) ne VIEW and
      %upcase(&_cstFileType) ne FOLDER %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Macro parameter _cstFileType=&_cstFileType is invalid;
    %goto exit_macro;
  %end;

  %if %upcase(&_cstFileType)=FILE or %upcase(&_cstFileType)=FOLDER %then
  %do;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstDir=_cst&_cstRandom;

    %*************************************************;
    %* Does the macro have the parameters it needs?  *;
    %*************************************************;
    %if %upcase(&_cstFileType)=FOLDER and %quote(&_cstFilePath)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstFilePath parameter is required when checking _cstFileType=FOLDER;
      %goto exit_macro;
    %end;
    %if %upcase(&_cstFileType)=FILE and (%quote(&_cstFilePath)=%str() or %quote(&_cstFileRef)=%str()) %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstFilePath and _cstFileRef parameters are required when checking _cstFileType=FILE;
      %goto exit_macro;
    %end;
    %***********************************************;
    %*  Check to see if directory for file exists  *;
    %***********************************************;
    %let rc=%sysfunc(filename(_cstDir,&_cstFilePath));
    %if %sysfunc(fexist(&_cstDir)) ne 1 %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = Specified directory (&_cstFilePath) does not exist;
      %goto exit_macro;
    %end;

    %*************************************************;
    %*  Check has finished for _cstFileType = FOLDER *;
    %*************************************************;
    %if %upcase(&_cstFileType)=FOLDER %then %goto exit_macro;

    %***************************************************************;
    %*  Make sure directory has trailing / slash for concatenation *;
    %***************************************************************;
    %if %sysfunc(kindexc(%sysfunc(kreverse(%ktrim(%kleft(&_cstFilePath)))),\/)) ne 1 %then %let _cstFilePath=%ktrim(%kleft(&_cstFilePath))/;

    %**************************;
    %*  Check if file exists  *;
    %**************************;
    %if %sysfunc(fileexist(%ktrim(%kleft(&_cstFilePath))%ktrim(%kleft(&_cstFileRef)))) ne 1 %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = File &_cstFileRef does not exist in specified directory - &_cstFilePath;
    %end;
  %end;
  %*******************************************;
  %*  Check if catalog/catalog member exists *;
  %*******************************************;
  %else %if %upcase(&_cstFileType)=CATALOG %then
  %do;
    %**************************************************;
    %*  Does the macro have the parameters it needs?  *;
    %**************************************************;
    %if %quote(&_cstFileRef)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg =The _cstFileRef parameter is required when checking _cstFileType=CATALOG;
      %goto exit_macro;
    %end;
    %***************************************************;
    %*  Check for existence of catalog/catalog member  *;
    %***************************************************;
    %if %sysfunc(cexist(&_cstFileRef)) = 0 %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = Catalog or Catalog Member (&_cstFileRef) does not exist in specified directory;
    %end;
  %end;

  %**************************************************;
  %*  Check for existence of SAS data set/SAS View  *;
  %**************************************************;
  %else %if %upcase(&_cstFileType)=DATASET or %upcase(&_cstFileType)=VIEW %then
  %do;
    %**************************************************;
    %*  Does the macro have the parameters it needs?  *;
    %**************************************************;
    %if %quote(&_cstFileRef)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstFileRef parameter is required when checking _cstFileType=DATASET;
      %goto exit_macro;
    %end;
    %**************************************************;
    %*  Check for existence of SAS data set/SAS view  *;
    %**************************************************;
    %let _cstType=%substr(%left(&_cstFileType),1,4);
    %if %sysfunc(exist(&_cstFileRef,&_cstType)) = 0 %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = SAS &_cstFileType (&_cstFileRef) does not exist;
    %end;
  %end;

  %exit_macro:

  %if &_cst_rc=1 %then %put [CSTLOG%str(MESSAGE)] &_cst_rcmsg;

  %if %symexist(_cstDebug) %then 
  %do;
    %if &_cstDebug=1 %then
    %do;
      %put *********************************************************************;
      %put * LEAVING macro &sysmacroname;
      %put *  Parameter _cstFileType = &_cstFileType;
      %put *  Parameter _cstFilePath = &_cstFilePath;
      %put *  Parameter _cstFileRef  = &_cstFileRef;
      %put *  _cst_rc                = &_cst_rc;
      %put *  _cst_rcmsg             = &_cst_rcmsg;
      %put *********************************************************************;
    %end;
  %end;
%mend cstutilfindvalidfile;
