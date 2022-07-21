**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* extract_domaindata_all.sas                                                     *;
*                                                                                *;
* Sample driver program to perform a utility action specific to CDISC-ODM:       *;
* extract all data sets from the ClinicalData or ReferenceData sections          *;
* of the ODM XML file.  However, this code assumes that the XML file has been    *;
* converted into a SAS representation of the ODM standard, such that this code   *;
* runs against a set of SAS data sets, NOT directly against the XML file.        *;
*                                                                                *;
* Assumptions:                                                                   *;
*         The SASReferences file must exist, and must be identified in the       *;
*         call to cstutil_processsetup if it is not work.sasreferences.          *;
* CSTversion  1.5                                                                *;
*                                                                                *;
*  The following statements may require information from the user                *;
**********************************************************************************;

%let _cstStandard=CDISC-ODM;
%let _cstStandardVersion=1.3.1;      * <----- User sets to ODM version of interest *;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);

%let _cstTrgStandard=CDISC-SDTM;     * <----- User sets to type of data being extracted  *;
%let _cstTrgStandardVersion=3.1.2;   * <----- User sets to type of data being extracted  *;

*****************************************************************************************************;
* The following %let statements set the studyrootpath and studyoutputpath.  These are used to make  *;
* the driver programs portable across platforms and allow the code to be run with minimal           *;
* modification. Studyrootpath points to read-only locations in the sasroot hierarchy.               *;
* Studyoutputpath points to writable locations for process output.  Users may find it necessary to  *;
* reset studyoutputpath to some write-enabled location since the !sasroot directories may be write- *;
* protected. The call to cstutil_createsubdir creates any studyoutputpath subdirectories expected   *;
* by sasreferences records and sets studyOutputPath to workpath if a value is not set here.         *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-odm-&_cstStandardVersion.-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-odm-&_cstStandardVersion.-&_cstVersion"));
run;
%let workPath=%sysfunc(pathname(work));

%let _cstSetupSrc=SASREFERENCES;

*****************************************************************************************;
* One strategy to defining the required library and file metadata for a CST process     *;
*  is to optionally build SASReferences in the WORK library.  An example of how to do   *;
*  this follows.                                                                        *;
*                                                                                       *;
* The call to cstutil_processsetup below tells CST how SASReferences will be provided   *;
*  and referenced.  If SASReferences is built in work, the call to cstutil_processsetup *;
*  may, assuming all defaults, be as simple as:                                         *;
*        %cstutil_processsetup(_cstStandard=CDISC-ODM)                                 *;
*****************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values("CST-FRAMEWORK"    "1.2"                     "messages"         ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                                 1 ""                             "")
  values("&_cstStandard"    "&_cstStandardVersion"    "messages"         ""           "odmmsg"   "libref"  "input"  "dataset"  "N"  "" ""                                 2 ""                             "")
  values("&_cstStandard"    "&_cstStandardVersion"    "autocall"         ""           "auto1"    "fileref" "input"  "folder"   "N"  "" ""                                 1 ""                             "")
  values("&_cstStandard"    "&_cstStandardVersion"    "control"          "reference"  "cntl_s"   "libref"  "both"   "dataset"  "Y"  "" "&workpath"                        . "sasreferences"                "")
  values("&_cstStandard"    "&_cstStandardVersion"    "fmtsearch"        ""           "odmfmt"   "libref"  "input"  "catalog"  "N"  "" "&studyRootPath/derived/formats"   1 "odmfmtcat_en"                 "")
  values("&_cstStandard"    "&_cstStandardVersion"    "sourcedata"       ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studyRootPath/derived/data"      . ""                             "")
  values("&_cstTrgStandard" "&_cstTrgStandardVersion" "targetdata"       ""           "trgdata"  "libref"  "output" "folder"   "Y"  "" "&studyOutputPath/derived/domains" . ""                             "")
  values("&_cstStandard"    "&_cstStandardVersion"    "results"          "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"         . "extract_results_all.sas7bdat" "")
  values("&_cstStandard"    "&_cstStandardVersion"    "properties"       "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                                 1 ""                             "")
  ;
quit;

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

*****************************************************************************************;
* Clinical Standards Toolkit utilizes autocall macro libraries to contain and           *;
*  reference standard-specific code libraries.  Once the autocall path is set and one   *;
*  or more macros have been used within any given autocall library, deallocation or     *;
*  reallocation of the autocall fileref cannot occur unless the autocall path is first  *;
*  reset to exclude the specific fileref.                                               *;
*                                                                                       *;
* This becomes a problem only with repeated calls to %cstutil_processsetup() or         *;
*  %cstutil_allocatesasreferences within the same sas session.  Doing so, without       *;
*  submitting code similar to the code below may produce SAS errors such as:            *;
*     ERROR - At least one file associated with fileref AUTO1 is still in use.          *;
*     ERROR - Error in the FILENAME statement.                                          *;
*                                                                                       *;
* If you call %cstutil_processsetup() or %cstutil_allocatesasreferences more than once  *;
*  within the same sas session, typically using %let _cstReallocateSASRefs=1 to tell    *;
*  CST to attempt reallocation, use of the following code is recommended between each   *;
*  code submission.                                                                     *;
*                                                                                       *;
* Use of the following code is NOT needed to run this driver module initially.          *;
*****************************************************************************************;

%*let _cstReallocateSASRefs=1;
%*include "&_cstGRoot/standards/cst-framework-&_cstVersion/programs/resetautocallpath.sas";

*****************************************************************************************;
* The following macro (cstutil_processsetup) utilizes the following parameters:         *;
*                                                                                       *;
* _cstSASReferencesSource - Setup should be based upon what initial source?             *;
*   Values: SASREFERENCES (default) or RESULTS data set. If RESULTS:                    *;
*     (1) no other parameters are required and setup responsibility is passed to the    *;
*                 cstutil_reportsetup macro                                             *;
*     (2) the results data set name must be passed to cstutil_reportsetup as            *;
*                 libref.memname                                                        *;
*                                                                                       *;
* _cstSASReferencesLocation - The path (folder location) of the sasreferences data set  *;
*                              (default is the path to the WORK library)                *;
*                                                                                       *;
* _cstSASReferencesName - The name of the sasreferences data set                        *;
*                              (default is sasreferences)                               *;
*****************************************************************************************;

%cstutil_processsetup();

**********************************************************************************;
* Run the standard-specific extract macro.                                       *;
**********************************************************************************;

filename incCode CATALOG "work._cstCode.domains.source" &_cstLRECL;

data _null_;
 set srcdata.itemgroupdefs(keep=OID Name IsReferenceData SASDatasetName Domain);
  file incCode;
  length macrocall $400 _cstOutputName $100;

  _cstOutputName=SASDatasetName;
  * If we have to use the Name, Only use letters and digits;
  if missing(_cstOutputName) then _cstOutputName=cats(compress(Name,,'adk'));
  * If first character a digit, prepend an underscore;
  if anydigit(_cstOutputName)=1 then _cstOutputName=cats('_', _cstOutputName);
  * Cut long names;
  if length(_cstOutputName) > 32 then _cstOutputName=substr(_cstOutputName, 1, 32);

  macrocall=cats('%odm_extractdomaindata(_cstSelectAttribute=OID',
                                      ', _cstSelectAttributeValue=', OID,
                                      ', _cstIsReferenceData=', IsReferenceData,
                                      ', _cstMaxLabelLength=256',
                                      ', _cstAttachFormats=Yes',
                                      ', _cstODMMinimumKeyset=No',
                                      ', _cstLang=en',
                                      ', _cstOutputDS=', _cstOutputName, ');');
  put macrocall;
run;

%include incCode;
filename incCode clear;

proc datasets lib=work nolist;
  delete _cstCode / memtype=catalog;
quit;