**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_datasetxml_standalone.sas                                               *;
*                                                                                *;
* Sample driver program to create Dataset-XML V1.0.0 files from a library of SAS *;
* data sets.                                                                     *;
*                                                                                *;
* Assumptions:                                                                   *;
* The code, as written, is designed to be run as stand-alone code, with the user *;
* responsible for all library assignments. All information will be in the LOG.   *;
* No results data set will be created.                                           *;
*                                                                                *;
* CST version  1.7                                                               *;
*                                                                                *;
* The following filename and libname statements may need to be changed by the    *;
* user to ensure the correct paths.                                              *;
**********************************************************************************;
%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cstutil_setcstgroot;
%cstutil_setcstsroot;

**********************************************************************************;
* Set Root paths for input and output                                            *;
**********************************************************************************;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-datasetxml-1.0.0-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-datasetxml-1.0.0-&_cstVersion"));
run;

**********************************************************************************;
* Location of the Dataset-XML root                                               *;
**********************************************************************************;
%let DatasetXMLGlobalRoot=&_cstGRoot/standards/cdisc-datasetxml-1.0.0-&_cstVersion;

**********************************************************************************;
* Make the macros available                                                      *;
**********************************************************************************;
options  insert=(sasautos=("&DatasetXMLGlobalRoot/macros")) mautosource;

************************************************************;
* Debugging aid:  set _cstDebug=1                          *;
************************************************************;
%let _cstDebug=0;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options mprint mlogic symbolgen mautolocdisplay;");
  else
    call execute("options nomprint nomlogic nosymbolgen nomautolocdisplay;");
run;

**********************************************************************************;
* Create SDTM Dataset-XML files                                                  *;
**********************************************************************************;
libname srcdata  "&studyRootPath/data";
libname xmldata  "&studyOutputPath/sourcexml";
filename srcmeta "&studyOutputPath/sourcexml/define.xml";

%datasetxml_write(
  _cstSourceLibrary=srcdata,
  _cstOutputLibrary=xmldata,
  _cstSourceMetadataDefineFileRef=srcmeta,
  _cstCheckLengths=Y,
  _cstIndent=N,
  _cstZip=Y,
  _cstDeleteAfterZip=N
  );  
  
libname srcdata clear;
libname xmldata clear;
filename srcmeta clear;

**********************************************************************************;
* Create ADaM Dataset-XML files                                                  *;
**********************************************************************************;
libname srcdata  "&studyRootPath/data_adam";
libname xmldata  "&studyOutputPath/sourcexml_adam";
filename srcmeta "&studyOutputPath/sourcexml_adam/define_adam.xml";

%datasetxml_write(
  _cstSourceLibrary=srcdata,
  _cstOutputLibrary=xmldata,
  _cstSourceMetadataDefineFileRef=srcmeta,
  _cstCheckLengths=Y,
  _cstIndent=N,
  _cstZip=Y,
  _cstDeleteAfterZip=N
  );
  
libname srcdata clear;
libname xmldata clear;
filename srcmeta clear;
