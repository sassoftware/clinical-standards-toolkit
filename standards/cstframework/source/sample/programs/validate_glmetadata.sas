**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* validate_glmetadata.sas                                                        *;
*                                                                                *;
* Sample driver program to perform a primary Toolkit action, in this case,       *;
* to validate the metadata in the Global Library metadata folder.                *;
*                                                                                *;
* Assumptions:                                                                   *;
*   (1) This driver excludes those validation checks that are specific to any    *;
*        given standard, focusing primarily on the cstGlobalLibrary              *;
*        metadata folder typically referenced using the glmeta libref.           *;
*                                                                                *;
* CSTversion  1.5                                                                *;
**********************************************************************************;

%let _cstStandard=CST-FRAMEWORK;
%let _cstStandardVersion=1.2;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);

**********************************************************************;
* User defines standard(s) of interest in the following data step    *;
* Only the CST-FRAMEWORK standard addresses Global Library metadata. *;
**********************************************************************;

%cst_getRegisteredStandards(_cstOutputDS=work._cstAllStandards);

data work._cstStandardsforIV;
  set work._cstAllStandards (where=(
       (upcase(standard) = 'CST-FRAMEWORK' and standardversion='1.2')
  ));
run;

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cst-framework-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cst-framework-&_cstVersion"));
run;
%let workPath=%sysfunc(pathname(work));

%let _cstSetupSrc=SASREFERENCES;

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
* Modify the sample SASReferences data set to point to the run-time validation_control  *;
* data set identifying the validation checks of interest.                               *;
*                                                                                       *;
* The validation_control_glmeta view of the validation_master data set includes those   *;
* checks specific to the <cstGlobalLibrary>/metadata folder.                            *;
*****************************************************************************************;
libname _cstTemp "&studyrootpath/control";

data work.stdvalidation_sasrefs;
  set _cstTemp.stdvalidation_sasrefs;
  if type='control' and subtype='validation' then
  do;
    filetype='view';
    memname='validation_control_glmeta.sas7bvew';
  end;
run;

libname _cstTemp;

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

%cstutil_processsetup(_cstSASReferencesLocation=&workpath,_cstSASReferencesName=stdvalidation_sasrefs);

**********************************************************************************;
* work.stdvalidation_sasrefs will accumulate SASReferences records from all      *;
*  sources for later use by cstvalidate().                                       *;
**********************************************************************************;

data work.stdvalidation_sasrefs;
  set &_cstSASRefs;
    attrib _srcfile format=$8. label='File source for record';
    **********************************************************************;
    * Framework validation sasreferences:  cstcntl.stdvalidation_sasrefs *;
    **********************************************************************;
    _srcfile='GLVAL';
run;

************************************************************************************;
*  SAS Clinical Standards Toolkit optional code to change the SAS view definition  *;
*  Can be used to add additional qualifiers, for example where checkid="CSTV070"   *;
*  Note the view requires that the cstrcntl libref be allocated prior to use.      *;
************************************************************************************;
/*
proc sql;
  create view cstcntl.validation_control_glmeta (label="Global Library metadata checks")
    as select * 
    from cstrcntl.validation_master as a 
    where upcase(a.checktype)="GLMETA"
    order by checkid, standard, standardversion, checksource, uniqueid; 
quit; 
*/


filename initCode CATALOG "work._cstIV.init.source" &_cstLRECL;
data _null_;
  file initCode;
  attrib rc format=8.;
  rc=input(symget('_cst_rc'),8.);
  if rc=1 then
  do;
    put '%cstutil_writeresult(_cstResultID=CST0200,
          _cstResultParm1=PROCESS WORKFLOW: Aborting Global Library metadata validation,
          _cstSeqNoParm=0,
          _cstSrcDataParm=VALIDATE_GLMETADATA);';  
  end;
  else
  do;

    put '**********************************************************************************;';
    put '* Call code-generator macro to build and submit job stream                       *;';
    put '* This includes a call to the cstvalidate macro for each standard specified in   *;';
    put '*  the work._cstStandardsforIV data set.                                         *;';
    put '**********************************************************************************;';
    put 'filename incCode CATALOG "work._cstCode.stds.source" &_cstLRECL;';
    put '%cstutilbuildstdvalidationcode(_cstStdDS=work._cstStandardsforIV,_cstSampleRootPath=_DEFAULT_,
      _cstSampleSASRefDSPath=_DEFAULT_,_cstSampleSASRefDSName=_DEFAULT_,_cstCallingDriver=validate_glmetadata.sas);';
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