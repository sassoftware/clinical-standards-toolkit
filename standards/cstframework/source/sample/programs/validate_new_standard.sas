**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* validate_new_standard.sas                                                      *;
*                                                                                *;
* Sample driver program to perform a primary Toolkit action, in this case,       *;
* to validate the metadata defined for a newly-registered standard.              *;
* Checks that can be run with the minimal set of metadata required for           *;
* registration of a new standard (i.e. standards, standardsasreferences, and     *;
* standardlookuo) are included.  Also included are checks that run against       *;
* reference metadata (e.g. reference_tables and reference_columns) that will run *;
* *if* this metadata is also included for the newly-registered standard.         *;
*                                                                                *;
* NOTE:  This sample program will NOT run successfully unless the lines          *;
*        commented with <--------------  Example only, user must set below are   *;
*        set with a valid, registered standard and standardversion.              *;
*                                                                                *;
* CSTversion  1.7                                                                *;
**********************************************************************************;

%let _cstStandard=CST-FRAMEWORK;
%let _cstStandardVersion=1.2;

%let _cstNewStandard=CDISC-ADAM;          * <--------------  Example only, user must set ;
%let _cstNewStandardVersion=CUSTOM;       * <--------------  Example only, user must set ;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%let _cstTableMetadata=work._csttablemetadata;
%let _cstColumnMetadata=work._cstcolumnmetadata;

*********************************************************************;
* New standard of interest is referenced in the following data step *;
*********************************************************************;
%cst_getRegisteredStandards(_cstOutputDS=work._cstAllStandards);

data work._cstStandardsforIV;
  set work._cstAllStandards (where=(upcase(standard) = "&_cstNewStandard" and standardversion="&_cstNewStandardVersion"));
run;

*************************************************************************;
* The following data step sets the studyrootpath and studyoutputpath.   *;
*************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstGRoot","/cst-framework-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstGRoot","/cst-framework-&_cstVersion"));
run;

%let workPath=%sysfunc(pathname(work));


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

*******************************************************************************************;
* Build sample SASReferences data set to point to the run-time validation_control_newstd  *;
* data set identifying the validation checks relevant to new standards.                   *;
* Note the last 2 records (type=referencemetadata) for the new standard would not be      *;
* included if that metdata is not available when this driver is run.                      *;
*******************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.stdvalidation_sasrefs);

*************************************************************************************************;
* column order:  standard, standardversion, type, subtype, sasref, reftype, iotype, filetype,   *;
*                allowoverwrite, path, order, memname, comment                                  *;
* note that &_cstGRoot points to the Global Library root directory                              *;
*************************************************************************************************;
proc sql;
  insert into work.stdvalidation_sasrefs
  values ("CST-FRAMEWORK"     "1.2"                      "control"           "validation"           "cstcntl"  "libref"  "input"  "view"     "N"  "" '&workpath'                                                               1 "validation_control_newstd.sas7bdat" "") 
  values ("CST-FRAMEWORK"     "1.2"                      "globalmetadata"    "standard"             "glmeta"   "libref"  "input"  "dataset"  "N"  "" '&_cstGRoot/metadata'                                                     . "standards.sas7bdat"              "") 
  values ("CST-FRAMEWORK"     "1.2"                      "globalmetadata"    "sasreferences"        "glmeta"   "libref"  "input"  "dataset"  "N"  "" '&_cstGRoot/metadata'                                                     . "standardsasreferences.sas7bdat"  "") 
  values ("CST-FRAMEWORK"     "1.2"                      "messages"          ""                     "cstmsg"   "libref"  "input"  "dataset"  "N"  "" '&_cstGRoot/standards/cst-framework-&_cstVersion/messages'                1 "messages.sas7bdat"               "") 
  values ("CST-FRAMEWORK"     "1.2"                      "template"          ""                     "csttmplt" "libref"  "input"  "folder"   "N"  "" '&_cstGRoot/standards/cst-framework-&_cstVersion/templates'               2 ""                                "") 
  values ("CST-FRAMEWORK"     "1.2"                      "referencemetadata" "column"               "fwrmeta"  "libref"  "input"  "dataset"  "N"  "" '&workpath'                                                               . "reference_columns.sas7bdat"      "") 
  values ("CST-FRAMEWORK"     "1.2"                      "referencemetadata" "table"                "fwrmeta"  "libref"  "input"  "dataset"  "N"  "" '&workpath'                                                               . "reference_tables.sas7bdat"       "") 
  values ("CST-FRAMEWORK"     "1.2"                      "sourcemetadata"    "column"               "fwsmeta"  "libref"  "input"  "dataset"  "N"  "" '&workpath'                                                               . "source_columns.sas7bdat"         "") 
  values ("CST-FRAMEWORK"     "1.2"                      "sourcemetadata"    "table"                "fwsmeta"  "libref"  "input"  "dataset"  "N"  "" '&workpath'                                                               . "source_tables.sas7bdat"          "") 
  values ("CST-FRAMEWORK"     "1.2"                      "properties"        "validation"           "valprop"  "fileref" "input"  "file"     "N"  "" '&_cstGRoot/standards/cst-framework-&_cstVersion/programs'                1 "validation.properties"           "") 
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "cstmetadata"       "lookup"               "stdmeta"  "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/control"   . "standardlookup.sas7bdat"         "") 
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "cstmetadata"       "standard"             "stdmeta"  "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/control"   . "standards.sas7bdat"              "")  
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "cstmetadata"       "sasreferences"        "stdmeta"  "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/control"   . "standardsasreferences.sas7bdat"  "")  
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "lookup"            ""                     "lookup"   "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/control"   . "standardlookup.sas7bdat"         "") 
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "referencemetadata" "column"               "refmeta"  "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/metadata"  . "reference_columns.sas7bdat"      "")  
  values ("&_cstNewStandard"  "&_cstNewStandardVersion"  "referencemetadata" "table"                "refmeta"  "libref"  "input"  "dataset"  "N"  "" "&_cstGRoot/standards/&_cstNewStandard-&_cstNewStandardVersion/metadata"  . "reference_tables.sas7bdat"       "") 
  ;
quit;

proc sort data=work.stdvalidation_sasrefs (label="SASReferences: Validation of new standard");
  by standard standardversion type subtype;
run;


***************************************************************************;
*  Build the run-time validation control data set of checks to be run.    *;
*  This list can be modified to match the metadata available for the new  *;
*  standard (look at the tablescope column in validation_master).         *;
***************************************************************************;

libname _cstTemp "&_cstGRoot./standards/cst-framework-1.7/validation/control";
data work.validation_control_newstd;
  set _cstTemp.validation_master;
    * The following checks would normally be run for every newly-registered standard  *;
    if substr(uniqueid,1,9) in (
       'CSTV25101'
       'CSTV25201'
       'CSTV25202'
       'CSTV25401'
       'CSTV26003'
       'CSTV26004'
       'CSTV26005'
       'CSTV26901'
       'CSTV27001'
       'CSTV27201'
       'CSTV27301'
       'CSTV27401'
       'CSTV27402'
       'CSTV27503'
       'CSTV28001'
    ) then output;
    * The following checks would normally be run only if reference metadata   *;
    * (e.g. reference_tables) is avalaible for the newly-registered standard  *;
    if substr(uniqueid,1,9) in (
       'CSTV26001'
       'CSTV26002'
       'CSTV29501'
    ) then output;
run;
libname _cstTemp;

*************************************************************************************;
* The following macro (cstutil_processsetup) utilizes the following parameters:     *;
*                                                                                   *;
* _cstSASReferencesSource - Setup should be based upon what initial source?         *;
*   Values: SASREFERENCES (default) or RESULTS data set. If RESULTS:                *;
*     (1) no other parameters are required and setup responsibility is passed to    *;
*                 the cstutil_reportsetup macro                                     *;
*     (2) the results data set name must be passed to cstutil_reportsetup as        *;
*                 libref.memname                                                    *;
*                                                                                   *;
* _cstSASReferencesLocation - The path (folder location) of the sasreferences data  *;
*                              set (default is the path to the WORK library)        *;
*                                                                                   *;
* _cstSASReferencesName - The name of the sasreferences data set                    *;
*                              (default is sasreferences)                           *;
*************************************************************************************;
%let _cstSetupSrc=SASREFERENCES;
%cstutil_processsetup(_cstSASReferencesName=stdvalidation_sasrefs);

filename initCode CATALOG "work._cstIV.init.source" &_cstLRECL;
data _null_;
  file initCode;
  attrib rc format=8.;
  rc=input(symget('_cst_rc'),8.);
  if rc=1 then
  do;
    put '%cstutil_writeresult(_cstResultID=CST0200,
          _cstResultParm1=PROCESS WORKFLOW: Aborting standard-level validation,
          _cstSeqNoParm=0,
          _cstSrcDataParm=VALIDATE_NEW_STANDARD);';  
  end;
  else
  do;

    put '**********************************************************************************;';
    put '* Call code-generator macro to build and submit job stream                       *;';
    put '* This includes a call to the cstvalidate macro for each standard specified in   *;';
    put '*  the work._cstStandardsforIV data set.                                         *;';
    put '**********************************************************************************;';
    put 'filename incCode CATALOG "work._cstIV.stds.source" &_cstLRECL;';
    put '%cstutilbuildstdvalidationcode(_cstStdDS=work._cstStandardsforIV,_cstSampleRootPath=%str(&workpath),
      _cstSampleSASRefDSPath=%str(&workpath),
      _cstSampleSASRefDSName=stdvalidation_sasrefs,
      _cstCallingDriver=validate_new_standard.sas);';
    put '%include incCode;';

  end;
run;
%include initCode;

proc datasets nolist lib=work;
  delete _cstIV / memtype=catalog;
quit;

filename initCode clear;

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