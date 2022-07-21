**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_tumordataset.sas                                                        *;
*                                                                                *;
* This sample driver module builds the tumor data set (and optionally            *;
* tumor.xpt file) from a variety of SEND source data sets.                       *;
*                                                                                *;
*                                                                                *;
* CSTversion  1.5                                                                *;
**********************************************************************************;

%let _cstMacroName=%str(ERROR - Process aborted);
%let _cstStandard=CDISC-SEND;
%let _cstStandardVersion=3.0  ;    * <------- SEND version             *;
%let _cstCTPath=;
%let _cstCTMemname=;
%let _cstCTDescription=;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);

* Set Controlled Terminology version for this process  *;
%cst_getstandardsubtypes(_cstStandard=CDISC-TERMINOLOGY,_cstOutputDS=work._cstStdSubTypes);
data _null_;
  set work._cstStdSubTypes (where=(standardversion="&_cstStandard" and isstandarddefault='Y'));
  * User can override CT version of interest by specifying a different where clause:            *;
  * Example: (where=(standardversion="&_cstStandard" and standardsubtypeversion='201101'))   *;
  call symputx('_cstCTPath',path);
  call symputx('_cstCTMemname',memname);
  call symputx('_cstCTDescription',description);
run;

proc datasets lib=work nolist;
  delete _cstStdSubTypes;
quit;

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-send-3.0-&_cstVersion/sascstdemodata"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-send-3.0-&_cstVersion/sascstdemodata"));
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
*  may, assuming all defaults, be as simple as  %cstutil_processsetup()                 *;
*****************************************************************************************;

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
  values ("CST-FRAMEWORK"     "1.2"                   "messages"          ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                            1 ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "autocall"          ""           "sendauto" "fileref" "input"  "folder"   "N"  "" ""                            1 ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "control"           "reference"  "control"  "libref"  "both"   "dataset"  "Y"  "" "&workpath"                   . "sasreferences.sas7bdat"        "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "fmtsearch"         ""           "srcfmt"   "libref"  "input"  "catalog"  "N"  "" "&studyRootPath/terminology/formats" 1 "formats.sas7bcat"       "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "messages"          ""           "sendmsg"  "libref"  "input"  "dataset"  "N"  "" ""                            2 ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "properties"        "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                            1 "initialize.properties"         "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "column"     "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                            . ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "table"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                            . ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "classmetadata"     "column"     "clmeta"   "libref"  "input"  "dataset"  "N"  "" ""                            . ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "classmetadata"     "table"      "clmeta"   "libref"  "input"  "dataset"  "N"  "" ""                            . ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "results"           "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"    . "createtumor_results.sas7bdat"  "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "sourcedata"        ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studyRootPath/data"         . ""                              "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "column"     "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_columns.sas7bdat"       "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "table"      "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_tables.sas7bdat"        "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "study"      "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_study.sas7bdat"         "")
  values ("CDISC-TERMINOLOGY" "NCI_THESAURUS"         "fmtsearch"         ""           "cstfmt"   "libref"  "input"  "catalog"  "N"  "" "&_cstCTPath"                 2  "&_cstCTMemname"               "")
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
*     ERROR - At least one file associated with fileref SENDAUTO is still in use.       *;
*     ERROR - Error in the FILENAME statement.                                          *;
*                                                                                       *;
* If you call %cstutil_processsetup() or %cstutil_allocatesasreferences more than once  *;
*  within the same sas session, typically using %let _cstReallocateSASRefs=1 to tell    *;
*  CST to attempt reallocation, use of the following code is recommended between each   *;
*  code submission.                                                                     *;
*                                                                                       *;
* Use of the following code is NOT needed to run this driver module initially.          *;
* The default setting for _cstReallocateSASRef is 1.                                    *;
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

**********************************************************;
* Run the standard-specific create tumor data set macro. *;
**********************************************************;

%sendutil_createtumordataset(
    _cstSENDinputlibrary=srcdata,
    _cstSENDoutputDSfile=results.tumor,
    _cstSENDcreateXPT=1,
    _cstSENDoutputXPTfile=&studyOutputPath/results/tumor.xpt,
    _cstSENDExtendedVars=,
  _cstAbortIfDataIssue=N
    );

* Delete sasreferences if created above  *;
proc datasets lib=work nolist;
  delete sasreferences / memtype=data;
quit;

**********************************************************************************;
* Clean-up the CST process files, macro variables and macros.                    *;
**********************************************************************************;
%*cstutil_cleanupcstsession(
     _cstClearCompiledMacros=0
    ,_cstClearLibRefs=0
    ,_cstResetSASAutos=0
    ,_cstResetFmtSearch=0
    ,_cstResetSASOptions=1
    ,_cstDeleteFiles=1
    ,_cstDeleteGlobalMacroVars=0);