**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* compare_metadata_sasdefine_xpt.sas                                             *;
*                                                                                *;
* Sample driver program to compare the metadata in the SAS representation of a   *;
* CDISC-DEFINE-XML V2.0.0 (define.xml) file with the metadata in the SAS Version *;
* 5 (XPT) transport files described by the Define-XML V2.0.0 file.               *;
*                                                                                *;
* Assumptions:                                                                   *;
*         The SASReferences file must exist, and must be identified in the       *;
*         call to cstutil_processsetup if it is not work.sasreferences.          *;
*                                                                                *;
* CSTversion  1.7                                                                *;
*                                                                                *;
* The following statements may require information from the user                 *;
**********************************************************************************;

%let _cstStandard=CDISC-DEFINE-XML;
%let _cstStandardVersion=2.0.0;

%let _cstSrcStandard=CDISC-SDTM;     * <----- User sets to standard of the source study          *;
%let _cstSrcStandardVersion=3.1.2;   * <----- User sets to standard version of the source study  *;

%*let _cstSrcStandard=CDISC-ADAM;   * <----- User sets to standard of the source study          *;
%*let _cstSrcStandardVersion=2.1;   * <----- User sets to standard version of the source study  *;

%* Standard Subfolder with the SAS Version 5 transport files or the derived SAS Define-XML data sets; 
%let _cstStandardSubFolder=%lowcase(&_cstSrcStandard)-&_cstSrcStandardVersion;

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cstutil_setcstsroot;

%let studyRootPath=&_cstSRoot/cdisc-definexml-2.0.0-&_cstVersion;
%let studyOutputPath=&_cstSRoot/cdisc-definexml-2.0.0-&_cstVersion;
%let workPath=%sysfunc(pathname(work));

*****************************************************************************************;
* Setup the libraries.                                                                  *;
*****************************************************************************************;

filename srcdata "&studyRootPath/transport/&_cstStandardSubFolder";
libname srcmeta "&studyRootPath/data/&_cstStandardSubFolder";
libname results "&studyOutputPath/results";

************************************************************;
* Debugging aid:  set _cstDebug=1                          *;
* Note value may be reset in call to cstutil_processsetup  *;
*  based on property settings.  It can be reset at any     *;
*  point in the process.                                   *;
************************************************************;
%let _cstDebug=0;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options &_cstDebugOptions;");
  else
    call execute(("%sysfunc(tranwrd(options %cmpres(&_cstDebugOptions), %str( ), %str( no)));"));
run;

*******************************************************************************;
* Run the Framework macro.                                                    *;
*******************************************************************************;

%cstutilcomparemetadatasasdefine(
  _cstSourceXPTFolder=%sysfunc(pathname(srcdata)),
  _cstSourceMetadataLibrary=srcmeta,
  _cstRptDS=results.compare_metadata_results
  );
