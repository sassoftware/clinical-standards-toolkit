**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_sourcemetadata.sas                                                      *;
*                                                                                *;
* This sample driver module performs the setup steps to derive source metadata   *;
* files for a CDISC-CDASH study.                                                 *;
*                                                                                *;
* The following source metadata files are used by Clinical Standards Toolkit to  *;
* support a CDISC-CDASH implementation:                                          *;
*          source_tables                                                         *;
*          source_columns                                                        *;
*          source_study                                                          *;
*          source_itemgroups                                                     *;
*          source_values                                                         *;
*                                                                                *;
* The code, as written, is designed to be with inputs and outputs defined within *;
* a SASReferences data set.                                                      *;
*                                                                                *;
* CSTversion  1.7                                                                *;
**********************************************************************************;

%let _cstClassColumnDS=;
%let _cstClassTableDS=;
%let _cstMacroName=%str(ERROR - Process aborted, unknown value for _cstSrcType macro variable);
%let _cstRefLib=;
%let _cstRefColumnDS=;
%let _cstRefTableDS=;
%let _cstCDASHDataLib=;
%let _cstTrgMetaLibrary=;
%let _cstTrgStudyDS=;
%let _cstTrgDocumentDS=;
%let _cstTrgTableDS=;
%let _cstTrgColumnDS=;
%let _cstTrgValueDS=;
%let _cstStandard=CDISC-CDASH;
%let _cstStandardVersion=1.1;      * <------- 1.1;
%let studySrcDataPath=;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These macro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  attrib _cstTemp2 format=$200.;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-cdash-1.1-&_cstVersion/sascstdemodata"));
  call symput('studySrcDataPath',cats("&_cstSRoot","/cdisc-cdash-1.1-&_cstVersion/sascstdemodata/data"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-cdash-1.1-&_cstVersion/sascstdemodata"));
  call symputx('_cstCleanup',_cstTemp2);
run;
%let workPath=%sysfunc(pathname(work));

%let _cstSetupSrc=SASREFERENCES;

*************************************************************************************************;
* Build the SASReferences data set                                                              *;
* column order:  standard, standardversion, type, subtype, sasref, reftype, iotype, filetype,   *;
*                allowoverwrite, relpathprefix, path, order, memname, comment                   *;
* note that &_cstGRoot points to the Global Library root directory                              *;
* path and memname are not required for Global Library references - defaults will be used       *;
*************************************************************************************************;
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);
proc sql;
  insert into work.sasreferences
  values ("CST-FRAMEWORK" "1.2"                   "messages"          ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                                   1 ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "autocall"          ""           "cdasauto" "fileref" "input"  "folder"   "N"  "" ""                                   1 ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "classmetadata"     "column"     "clmeta"   "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "classmetadata"     "table"      "clmeta"   "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "messages"          ""           "cdasmsg"  "libref"  "input"  "dataset"  "N"  "" ""                                   2 ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "properties"        "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                                   1 ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "referencemetadata" "table"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "referencemetadata" "column"     "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "referencemetadata" "itemgroup"  "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "referencemetadata" "value"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                   . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "results"           "results"    "results"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/results"           . "srcmeta_results.sas7bdat"   "")
  values ("&_cstStandard" "&_cstStandardVersion"  "sourcedata"        ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studySrcDataPath"                  . ""                           "")
  values ("&_cstStandard" "&_cstStandardVersion"  "targetmetadata"    "study"      "trgmeta"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/derived/metadata"  . "source_study.sas7bdat"      "")
  values ("&_cstStandard" "&_cstStandardVersion"  "targetmetadata"    "itemgroup"  "trgmeta"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/derived/metadata"  . "source_itemgroups.sas7bdat" "")
  values ("&_cstStandard" "&_cstStandardVersion"  "targetmetadata"    "table"      "trgmeta"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/derived/metadata"  . "source_tables.sas7bdat"     "")
  values ("&_cstStandard" "&_cstStandardVersion"  "targetmetadata"    "column"     "trgmeta"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/derived/metadata"  . "source_columns.sas7bdat"    "")
  values ("&_cstStandard" "&_cstStandardVersion"  "targetmetadata"    "value"      "trgmeta"  "libref"  "output" "dataset"  "N"  "" "&studyOutputPath/derived/metadata"  . "source_values.sas7bdat"     "")
  ;
quit;

************************************************************;
* Debugging aid:  set _cstDebug=1                          *;
* Note value may be reset in call to cstutil_processsetup  *;
*  based on property settings.  It can be reset at any     *;
*  point in the process.                                   *;
************************************************************;
%let _cstDebug=0;

**********************************************
*  Check debug option and set cleanup macro  *
*  cleanup macro for SASReferences run.      *
**********************************************;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options &_cstDebugOptions;");
  else
    call execute(("%sysfunc(tranwrd(options %cmpres(&_cstDebugOptions), %str( ), %str( no)));"));
  _cstTemp2='%cstutil_cleanupcstsession(_cstClearLibRefs=1,_cstResetSASAutos=1,_cstResetSASOptions=0)';
  call symputx('_cstCleanup',_cstTemp2);
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
*     ERROR - At least one file associated with fileref SDTMAUTO is still in use.       *;
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

************************************************;
*  User must provide proper scenario values    *;
*  for each of the following tables: EG, LB    *;
*  and PE. User also must set the LANG value   *;
*  for the _cstCDISCLang macro variable below  *;
************************************************;

%let _cstCDISCLang=en;

data work.source_scenario;
  attrib table        format=$32.
         keepscenario format=$45.;
  table="EG";
  keepscenario="CENTRAL PROCESSING";
  *keepscenario="CENTRAL READING";
  *keepscenario="LOCAL READING";
  output;
  table="LB";
  *keepscenario="CENTRAL PROCESSING";
  keepscenario="CENTRAL PROCESSING WITH CLINICAL SIGNIFICANCE";
  *keepscenario="LOCAL PROCESSING";
  output;
  table="PE";
  *keepscenario="BEST PRACTICE";
  keepscenario="TRADITIONAL";
  output;
run;

%cdashutil_createsrcmetafrmsaslib(_cstScenarioDS=work.source_scenario);

* Delete sasreferences and source_scenario if created above  *;
%cstutil_deleteDataSet(_cstDataSetName=work.sasreferences);
%cstutil_deleteDataSet(_cstDataSetName=work.source_scenario);

**********************************************************************************;
* Clean-up the CST process files, macro variables and macros.                    *;
**********************************************************************************;
/*
&_cstCleanup.;
*/