**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* find_unsupported_tags.sas                                                      *;
*                                                                                *;
* Sample utility module to demonstrate parsing of an ODM XML file to find all    *;
* elements and attributes that SAS Clinical Standards Toolkit does not recognize *;
* by default.  These may be, for example, vendor or customer extensions or new   *;
* tags implemented in a later version of ODM.                                    *;
*                                                                                *;
* This information may then be used to customize Toolkit XSLTs and ODM metadata  *;
* to incorporate the new data into the SAS representation of ODM.                *;
*                                                                                *;
* The general workflow:                                                          *;
*   (1) call the cstutil_readxmltags macro, which creates a data set of          *;
*        element names (e.g. _cstxmlelementds=work.cstodmelements) and a data    *;
*        set of attribute names (e.g. _cstxmlattrds=work.cstodmattributes)       *;
*   (2) compare elements and attributes to a set of known (i.e. supported)       *;
*        elements and attributes                                                 *;
*   (3) report discrepancies                                                     *;
*                                                                                *;
* Assumptions and Limitations:                                                   *;
*   See the cstutil_readxmltags macro header                                     *;
*                                                                                *;
* TODO:  Consider doing something similar to assess inconsistencies with the     *;
*        current odm.map file.                                                   *;
*                                                                                *;
* CSTversion  1.5                                                                *;
**********************************************************************************;

%let _cstStandard=CDISC-ODM;
%let _cstStandardVersion=1.3.1;   * <----- User sets to ODM version of interest  *;

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
*        %cstutil_processsetup()                                                        *;
*****************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values("CST-FRAMEWORK"  "1.2"                   "messages"          ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                              1  ""                             "")
  values("&_cstStandard"  "&_cstStandardVersion"  "messages"          ""           "odmmsg"   "libref"  "input"  "dataset"  "N"  "" ""                              2  ""                             "")
  values("&_cstStandard"  "&_cstStandardVersion"  "autocall"          ""           "odmcode"  "fileref" "input"  "folder"   "N"  "" ""                              1  ""                             "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencemetadata" "table"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                              . ""                              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencemetadata" "column"     "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                              . ""                              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "results"           "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"      . "readxmltags_results.sas7bdat"  "")
  values("&_cstStandard"  "&_cstStandardVersion"  "externalxml"       "xml"        "odmxml"   "fileref" "input"  "file"     "N"  "" "&studyRootPath/sourcexml"      . "odm_extended.xml"              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "referencexml"      "map"        "odmmap"   "fileref" "input"  "file"     "N"  "" "&studyRootPath/referencexml"   . "odm.map"                       "")
  values("&_cstStandard"  "&_cstStandardVersion"  "properties"        "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                              1 ""                              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "standardmetadata"  "element"    "odmmeta"  "libref"  "input"  "dataset"  "N"  "" ""                              . ""                              "")
  values("&_cstStandard"  "&_cstStandardVersion"  "standardmetadata"  "attribute"  "odmmeta"  "libref"  "input"  "dataset"  "N"  "" ""                              . ""                              "")
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
*     ERROR - At least one file associated with fileref ODMCODE is still in use.        *;
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

***************(*************************;
* Extract tags and compare to ODM model *;
*****************************************;

%cstutil_readxmltags(
     _cstxmlfilename=odmxml
    ,_cstxmlreporting=Results
    ,_cstxmlelementds=work.elements
    ,_cstxmlattrds=work.attributes );