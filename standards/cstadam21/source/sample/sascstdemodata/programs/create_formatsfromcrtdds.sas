**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_formatsfromcrtdds.sas                                                   *;
*                                                                                *;
* This sample driver module performs the setup steps to derive the formats       *;
* for a CDISC-ADAM study as defined in the CRTDDS data (define.xml).             *;
*                                                                                *;
* Code lists are stored in a SAS Format catalog with the study                   *;
*                                                                                *;
* The code, as written, is designed to be run one of two ways:                   *;
*    (1) as stand-alone code, with the user responsible for all library          *;
*         allocations.                                                           *;
*    (2) with inputs and outputs defined within a SASReferences data set         *;
*                                                                                *;
*       ==> Note the sourcedata libref pointing to the library of SAS data sets  *;
*       capturing define.xml metadata in this driver points to a *shared* folder *;
*       that may contain define metadata extracted from *any* study, including   *;
*       any SDTM version, ADaM or SEND study.  Before running this driver, be    *;
*       sure to rerun the xml read macro (crtdds_read, define_read) to extract   *;
*       metadata from the intended define.xml file.                              *;
*                                                                                *;
* CSTversion  1.3                                                                *;
**********************************************************************************;

%let _cstCTCat=;
%let _cstCTLibrary=;
%let _cstSASrefLib=;
%let _cstTrgStandard=CDISC-CRTDDS;     * <----- User sets to type of data being extracted  *;
%let _cstTrgStandardVersion=1.0;       * <----- User sets to type of data being extracted  *;
%let _cstStandard=CDISC-ADAM;
%let _cstStandardVersion=2.1;

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
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
run;
%let workPath=%sysfunc(pathname(work));

/*
**************************************************************************************************************;
* OPTION 1:  Run code standalone                                                                             *;
*  Assign CSTFMT the output libref where the Controlled Terminology format catalog will reside               *;
*  Assign SRCDATA the input libref where the CRTDDS SAS representation data sets currently reside            *;
*  Assign SASAUTOS the cstGlobalLibrary (&_cstGRoot) where the standard specific (ie ADAM21) macros reside   *;
*  Assign _cstCTCat the value for the name of the format catalog                                             *;
**************************************************************************************************************;

************************************************************;
* Debugging aid:  set _cstDebug=1                          *;
* Note value may be reset in call to cstutil_processsetup  *;
*  based on property settings.  It can be reset at any     *;
*  point in the process.                                   *;
************************************************************;
%let _cstDebug=0;

**********************************************
*  Check debug option and set cleanup macro  *
*  No cleanup macro for manual run.          *
**********************************************;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options &_cstDebugOptions;");
  else
    call execute(("%sysfunc(tranwrd(options %cmpres(&_cstDebugOptions), %str( ), %str( no)));"));
  _cstTemp2='';
  call symputx('_cstCleanup',_cstTemp2);data _null_;
run;

%cstutil_setcstgroot;

**********************************************************************************************;
*  The following 4 lines of code may need to be modified by the user, see Option 1 comments  *;
**********************************************************************************************;
libname cstfmt  "&studyOutputPath/terminology/formats";
libname srcdata "&studyRootPath/deriveddata";
options  mautosource sasautos=("&_cstGRoot/standards/cdisc-adam-2.1-&_cstVersion/macros", sasautos);

%let _cstCTCat=cterms;
%let _cstSASrefLib=srcdata;
%let _cstCTLibrary=cstfmt;

%cstutil_createTempMessages();

********************************************;
* End of OPTION 1 setup                    *;
********************************************;
*/

********************************************;
* OPTION 2:  Run code using SASReferences  *;
********************************************;

%let _cstSetupSrc=SASREFERENCES;
%let workPath=%sysfunc(pathname(work));

***********************************************************************************************************;
* Build the SASReferences data set                                                                        *;
* column order:  standard, standardversion, type, subtype, sasref, reftype, iotype, filetype,             *;
*                allowoverwrite, relpathprefix, path, order, memname, comment                             *;
* note that &_cstGRoot points to the Global Library root directory                                        *;
* path and memname are not required for Global Library references - defaults will be used                 *;
***********************************************************************************************************;
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values ("CST-FRAMEWORK"     "1.2"                      "messages"       ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                                 1 ""                          "")
  values ("&_cstTrgStandard"  "&_cstTrgStandardVersion"  "sourcedata"     ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studyRootPath/deriveddata"       . ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"     "autocall"       ""           "adamauto" "fileref" "input"  "folder"   "N"  "" ""                                 1 ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"     "messages"       ""           "adammsg"  "libref"  "input"  "dataset"  "N"  "" ""                                 2 ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"     "properties"     "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                                 1 "initialize.properties"     "")
  values ("&_cstStandard"     "&_cstStandardVersion"     "results"        "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"         . "codelist_results.sas7bdat" "")
  values ("&_cstStandard"     "&_cstStandardVersion"     "fmtsearch"      ""           "cstfmt"   "libref"  "output" "catalog"  "Y"  "" "&studyOutputPath/terminology/formats" 1 "cterms.sas7bcat"       "")
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
*     ERROR - At least one file associated with fileref ADAMAUTO is still in use.       *;
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

%cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSASrefLib);
%cstutil_getsasreference(_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,_cstSASRefmember=_cstCTCat);

********************************************;
* End of OPTION 2 setup                    *;
********************************************;


%adamutil_createformatsfromcrtdds;


* Delete sasreferences if created above  *;
proc datasets lib=work nolist;
  delete sasreferences / memtype=data;
quit;

**********************************************************************************;
* Clean-up the CST process files, macro variables and macros.                    *;
**********************************************************************************;

&_cstCleanup.;
