**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_sas_from_datasetxml_standalone.sas                                      *;
*                                                                                *;
* Sample driver program to create SAS data sets from Dataset-XML V1.0.0 files    *;
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
%cstutil_setcstsroot;
%cstutil_setcstgroot;

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
%let DatasetXMLRoot=&_cstGRoot/standards/cdisc-datasetxml-1.0.0-&_cstVersion;

**********************************************************************************;
* Make the macros available                                                      *;
**********************************************************************************;
options  insert=(sasautos=("&DatasetXMLRoot/macros")) mautosource;

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
* Create SDTM SAS Data sets                                                      *;
**********************************************************************************;
libname dataxml  "&studyRootPath/sourcexml";
libname sdtmdat0  "&studyRootPath/data";
libname sdtmdata  "&studyRootPath/data_derived";
filename defxml  "&studyOutputPath/sourcexml/define.xml";

%datasetxml_read(
  _cstSourceDatasetXMLLibrary=dataxml,
  _cstOutputLibrary=sdtmdata,
  _cstSourceMetadataDefineFileRef=defxml,
  _cstdatetimeLength=64,
  _cstAttachFormats=Y
  );

******************************************************;
* Compare original data sets with created data sets. *;
******************************************************;
%cstutilcomparedatasets(
  _cstLibBase=sdtmdat0, 
  _cstLibComp=sdtmdata, 
  _cstCompareLevel=0, 
  _cstCompOptions=%str(criterion=0.00000000000001),
  _cstCompDetail=Y
); 

libname dataxml clear;
* libname sdtmdat0 clear;
* libname sdtmdata clear;
filename defxml clear;

**********************************************************************************;
* Create ADaM SAS Data sets                                                      *;
**********************************************************************************;
libname dataxml "&studyRootPath/sourcexml_adam";
libname adamdat0 "&studyRootPath/data_adam";
libname adamdata "&studyRootPath/data_adam_derived";
filename defxml "&studyOutputPath/sourcexml_adam/define_adam.xml";

%datasetxml_read(
  _cstSourceDatasetXMLLibrary=dataxml,
  _cstOutputLibrary=adamdata,
  _cstSourceMetadataDefineFileRef=defxml,
  _cstdatetimeLength=64,
  _cstAttachFormats=Y
  );

******************************************************;
* Compare original data sets with created data sets. *;
******************************************************;
%cstutilcomparedatasets(
  _cstLibBase=adamdat0, 
  _cstLibComp=adamdata, 
  _cstCompareLevel=0, 
  _cstCompOptions=%str(criterion=0.00000000000001),
  _cstCompDetail=Y
); 

libname dataxml clear;
* libname adamdat0 clear;
* libname adamdata clear;
filename defxml clear;
