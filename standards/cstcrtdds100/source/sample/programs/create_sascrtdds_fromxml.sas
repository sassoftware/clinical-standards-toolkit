**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_sascrtdds_fromxml.sas                                                   *;
*                                                                                *;
* Sample driver program to read a CDISC-CRTDDS (define.xml) file                 *;
*                                                                                *;
* Assumptions:                                                                   *;
*         The SASReferences file must exist, and must be identified in the       *;
*         call to cstutil_processsetup if it is not work.sasreferences.          *;
*                                                                                *;
* CSTversion  1.3                                                                *;
*                                                                                *;
* The following statements may require information from the user                 *;
**********************************************************************************;

%let _cstSrcStandard=CDISC-SDTM;
%let _cstSrcStandardVersion=3.1.3;   * <----- User sets to SDTM version of the source study  *;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-crtdds-1.0-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-crtdds-1.0-&_cstVersion"));
run;
%let workPath=%sysfunc(pathname(work));

%let _cstSetupSrc=SASREFERENCES;
%let _cstStandard=CDISC-CRTDDS;
%let _cstStandardVersion=1.0;


*****************************************************************************************;
* One strategy to defining the required library and file metadata for a CST process     *;
*  is to optionally build SASReferences in the WORK library.  An example of how to do   *;
*  this follows.                                                                        *;
*                                                                                       *;
* The call to cstutil_processsetup below tells CST how SASReferences will be provided   *;
*  and referenced.  If SASReferences is built in work, the call to cstutil_processsetup *;
*  may, assuming all defaults, be as simple as:                                         *;
*        %cstutil_processsetup()                                                        *;
*****************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values("CST-FRAMEWORK"  "1.2"                   "messages"          ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                                 1 ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "messages"          ""           "crtmsg"   "libref"  "input"  "dataset"  "N"  "" ""                                 2 ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "autocall"          ""           "crtcode"  "fileref" "input"  "folder"   "N"  "" ""                                 1 ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcedata"        ""           "srcdata"  "libref"  "output" "folder"   "Y"  "" "&studyOutputPath/deriveddata"     . ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcemetadata"    "study"      "srcmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/derivedmetadata" . "source_study.sas7bdat"   "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcemetadata"    "table"      "srcmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/derivedmetadata" . "source_tables.sas7bdat"  "")
  values("&_cstStandard"  "&_cstStandardVersion"  "sourcemetadata"    "column"     "srcmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/derivedmetadata" . "source_columns.sas7bdat" "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencemetadata" "table"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                 . ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencemetadata" "column"     "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                 . ""                        "")
  values("&_cstStandard"  "&_cstStandardVersion"  "results"           "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"         . "read_results.sas7bdat"   "")
  values("&_cstStandard"  "&_cstStandardVersion"  "externalxml"       "xml"        "crtxml"   "fileref" "input"  "file"     "N"  "" "&studyRootPath/sourcexml"         . "define.xml"              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencexml"      "map"        "crtmap"   "fileref" "input"  "file"     "N"  "" "&studyRootPath/referencexml"      . "define.map"              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "properties"        "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                                 1 ""                        "")
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
*     ERROR - At least one file associated with fileref CRTCODE is still in use.        *;
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


***************************************************************************;
* Run the cross-standard schema validation macro.                         *;
* Running cstutilxmlvalidate is not required.  The crtdds_read macro will *;
* attempt to import an invalid crtdds xml file. However, importing an     *;
* invalid crtdds xml file may result in an incomplete import.             *;
*                                                                         *;
* cstutilxmlvalidate parameters (all optional):                           *;
*  _cstSASReferences:  The SASReferences data set provides the location   *:
*          of the to-be-validate XML file associated with a registered    *;
*          standard and standardversion (default:  &_cstSASRefs).         *;
*  _cstLogLevel:  Identifies the level of error reporting.                *;
*          Valid values: Info (default) Warning, Error, Fatal Error       *;
*  _cstCallingPgm:  The name of the driver module calling this macro      *;
***************************************************************************;

%cstutilxmlvalidate();

***************************************************************************;
* Run the standard-specific (CRTDDS) macro.                               *;
***************************************************************************;

%crtdds_read();

* Delete sasreferences if created above  *;
proc datasets lib=work nolist;
  delete sasreferences / memtype=data;
quit;

**********************************************************************************;
* Clean-up the CST process files, macro variables and macros.                    *;
**********************************************************************************;
%*cstutil_cleanupcstsession(
     _cstClearCompiledMacros=0
    ,_cstClearLibRefs=1
    ,_cstResetSASAutos=1
    ,_cstResetFmtSearch=0
    ,_cstResetSASOptions=0
    ,_cstDeleteFiles=1
    ,_cstDeleteGlobalMacroVars=0);
