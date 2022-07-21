**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_ctformats.sas                                                           *;
*                                                                                *;
* Sample driver program to create a format catalog and a Controlled Terminology  *;
* dataset.                                                                       *;
*                                                                                *;
* Assumptions:                                                                   *;
*         The SASReferences file must exist, and must be identified in the       *;
*         call to cstutil_processsetup if it is not work.sasreferences.          *;
*                                                                                *;
* CSTversion  1.5                                                                *;
*                                                                                *;
*  The following statements may require information from the user                *;
**********************************************************************************;

%let _cstCTCat=;
%let _cstCTLibrary=;
%let _cstSASrefLib=;
%let _cstTrgDataLibrary=;
%let _cstCTData=;

%let _cstStandard=CDISC-CT;
%let _cstStandardVersion=1.0.0;   * <----- User sets to ODM version of interest  *;

%*let _cstCTStandard=adam;              * <------- Terminology standard *;
%*let _cstCTDate=201512;                * <------- Terminology date     *;

%*let _cstCTStandard=cdash;             * <------- Terminology standard *;
%*let _cstCTDate=201403;                * <------- Terminology date     *;

%*let _cstCTStandard=cde;               * <------- Terminology standard *;
%*let _cstCTDate=201208;                * <------- Terminology date     *;

%*let _cstCTStandard=send;              * <------- Terminology standard *;
%*let _cstCTDate=201406;                * <------- Terminology date     *;

%let _cstCTStandard=sdtm;               * <------- Terminology standard *;
%let _cstCTDate=201406;                 * <------- Terminology date     *;

***************************************************************************************;

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
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-ct-1.0.0-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-ct-1.0.0-&_cstVersion"));
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
*        %cstutil_processsetup(_cstStandard=CDISC-SDTM)                                 *;
*****************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values ("CST-FRAMEWORK"  "1.2"                   "messages"    ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                          1 ""                       "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "messages"    ""           "odmmsg"   "libref"  "input"  "dataset"  "N"  "" ""                          2 ""                       "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "autocall"    ""           "auto1"    "fileref" "input"  "folder"   "N"  "" ""                          1 ""                       "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "control"     "reference"  "control"  "libref"  "both"   "dataset"  "N"  "" "&workpath"                 . "sasreferences"          "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "results"     "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"  . "cterms_results_&_cstCTStandard._&_cstCTDate..sas7bdat" "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "sourcedata"  ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studyRootPath/data/&_cstCTStandard/&_cstCTDate"         . ""                        "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "fmtsearch"   ""           "cstfmt"   "libref"  "output" "catalog"  "N"  "" "&studyOutputPath/data/&_cstCTStandard/&_cstCTDate/formats" 1 "cterms.sas7bcat"       "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "targetdata"  ""           "trgdata"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/data/&_cstCTStandard/&_cstCTDate/formats" . "cterms.sas7bdat"       "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "properties"  "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                          1 ""                       "")
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

*******************************************************************************;
* Run the standard-specific CT macros.                                        *;
*******************************************************************************;


%* An F will be appended to CodeList Submission Values that end with a digit;

%ct_createformats(
    _cstLang=en,
    _cstCreateCatalog=1,
    _cstKillCatFirst=1,
    _cstUseExpression=,
    _cstAppendChar=F,
    _cstDeleteEmptyColumns=1,
    _cstTrimCharacterData=1
    );


/*

%* Alternatively a custum format can be used to map CodeList Submission Values to valid SAS format names;

proc format lib=work.formats;
  value $_tox
 "TOXGRV3" = "TOXGRV3F"
 "TOXGRV4" = "TOXGRV4F"
 ;
run;

%ct_createformats(
    _cstLang=en,
    _cstKillCatFirst=1,
    _cstUseExpression=%str(strip(put(cdiscsubmissionvalue, $_tox32.)))
    );

proc catalog cat=work.formats;
delete _tox / et=formatc;
quit;

*/