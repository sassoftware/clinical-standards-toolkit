**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_sas_from_datasetxml.sas                                                 *;
*                                                                                *;
* Sample driver program to create SAS data sets from Dataset-XML V1.0.0 files    *;
*                                                                                *;
* Assumptions:                                                                   *;
*         The SASReferences file must exist, and must be identified in the       *;
*         call to cstutil_processsetup if it is not work.sasreferences.          *;
*                                                                                *;
* CST version  1.7                                                               *;
*                                                                                *;
* The following statements may require information from the user                 *;
**********************************************************************************;

%let _cstStandard=CDISC-DATASET-XML;
%let _cstStandardVersion=1.0.0;

%let _cstDataFolder0=data;              * <----- User sets to original data subfolder  *;
%let _cstDataFolder=data_derived;       * <----- User sets to data subfolder           *;
%let _cstDefineXMLFile=define.xml;      * <----- User sets name of define file         *;
%let _cstDatasetXMLFolder=sourcexml;    * <----- User sets to Dataset-XML subfolder    *;
%let _cstResultsName=read_results;      * <----- User sets to name of results data set *;

%*let _cstDataFolder0=data_adam;             * <----- User sets to original data subfolder  *;
%*let _cstDataFolder=data_adam_derived;      * <----- User sets to data subfolder           *;
%*let _cstDefineXMLFile=define_adam.xml;     * <----- User sets name of define file         *;
%*let _cstDatasetXMLFolder=sourcexml_adam;   * <----- User sets to Dataset-XML subfolder    *;
%*let _cstResultsName=read_results_adam;     * <----- User sets to name of results data set *;

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;
%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-datasetxml-1.0.0-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-datasetxml-1.0.0-&_cstVersion"));
run;

*****************************************************************************************;
* One strategy to defining the required library and file metadata for a CST process     *;
*  is to optionally build SASReferences in the WORK library.  An example of how to do   *;
*  this follows.                                                                        *;
*                                                                                       *;
* The call to cstutil_processsetup below tells CST how SASReferences will be provided   *;
*  and referenced.  If SASReferences is built in work, the call to cstutil_processsetup *;
*  may, assuming all defaults, be as simple as:                                         *;
*        %cstutil_processsetup(_cstStandard=CDISC-SDTM)                                 *;
*****************************************************************************************;

%let _cstSetupSrc=SASREFERENCES;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values("CST-FRAMEWORK"  "1.2"                   "messages"       ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                         1  ""               "")
  values("&_cstStandard"  "&_cstStandardVersion"  "messages"       ""           "datamsg"  "libref"  "input"  "dataset"  "N"  "" ""                         2  ""               "")
  values("&_cstStandard"  "&_cstStandardVersion"  "autocall"       ""           "datacode" "fileref" "input"  "folder"   "N"  "" ""                         1 ""                "")
  values("&_cstStandard"  "&_cstStandardVersion"  "properties"     "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                         1 ""                "")
  values("&_cstStandard"  "&_cstStandardVersion"  "externalxml"    "xml"        "dataxml"  "libref"  "input"  "folder"   "N"  "" "&studyRootPath/&_cstDatasetXMLFolder" 1 ""    "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcemetadata" ""           "defxml"   "fileref" "input"  "file"     "N"  "" "&studyRootPath/&_cstDatasetXMLFolder" 1 "&_cstDefineXMLFile"  "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcedata"     ""           "srcdata"  "libref"  "output" "folder"   "Y"  "" "&studyRootPath/&_cstDataFolder0"       . ""                   "")
  values("&_cstStandard"  "&_cstStandardVersion"  "targetdata"     ""           "trgdata"  "libref"  "output" "folder"   "Y"  "" "&studyRootPath/&_cstDataFolder"       . ""                    "")
  values("&_cstStandard"  "&_cstStandardVersion"  "results"        "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results" . "&_cstResultsName"  "")
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

******************************************************;
* Run the standard-specific Dataset-XML macros.      *;
******************************************************;
%datasetxml_read(
  _cstdatetimeLength=64,
  _cstAttachFormats=Y
  );

******************************************************;
* Compare original data sets with created data sets. *;
******************************************************;

%let _cstResultsDS=results.&_cstResultsName;

%cstutilcomparedatasets(
  _cstLibBase=srcdata, 
  _cstLibComp=trgdata, 
  _cstCompareLevel=0, 
  _cstCompOptions=%str(criterion=0.00000000000001),
  _cstCompDetail=Y
); 

***************************************************************;
* Clean-up the CST process files, macro variables and macros. *;
***************************************************************;
* Delete sasreferences if created above  *;
proc datasets lib=work nolist;
  delete sasreferences / memtype=data;
quit;

%*cstutil_cleanupcstsession(
     _cstClearCompiledMacros=0
    ,_cstClearLibRefs=1
    ,_cstResetSASAutos=1
    ,_cstResetFmtSearch=0
    ,_cstResetSASOptions=0
    ,_cstDeleteFiles=1
    ,_cstDeleteGlobalMacroVars=0);
