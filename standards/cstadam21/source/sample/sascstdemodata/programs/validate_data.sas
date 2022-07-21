**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* validate_data.sas                                                              *;
*                                                                                *;
* Sample driver program to perform a primary Toolkit action, in this case,       *;
* validation, to assess compliance of some source data and metadata with a       *;
* registered standard.  A call to a standard-specific validation macro is        *;
* required later in this code.                                                   *;
*                                                                                *;
* Assumptions:                                                                   *;
*   The SASReferences file must exist, and must be identified in the call to     *;
*    cstutil_processsetup if it is not work.sasreferences.                       *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

*****************************************;
* Populate key process macro variables  *;
*****************************************;

%let _cstStandard=CDISC-ADAM;
%let _cstStandardVersion=2.1;        * <----- User sets to ADaM version of interest  *;
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

%let _cstTrgStandard=CDISC-SDTM;     * <----- User sets to comparison standard (if any)  *;
%let _cstTrgStandardVersion=3.1.3;   * <----- User sets to comparison standard (if any)  *;

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These nacro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%cstutil_setcstsroot;
data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
  call symput('trgStudyRootPath',cats("&_cstSRoot","/cdisc-sdtm-&_cstTrgStandardVersion-&_cstVersion/sascstdemodata"));
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

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.validation_sasrefs);

*************************************************************************************************;
* note that &_cstGRoot points to the Global Library root directory                              *;
* path and memname are not required for Global Library references - defaults will be used       *;
*************************************************************************************************;
proc sql;
  insert into work.validation_sasrefs
    set standard="CST-FRAMEWORK",standardVersion="1.2",type="messages",subtype="",sasref="messages",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=1,memname="",comment=""
    set standard="CST-FRAMEWORK",standardVersion="1.2",type="template",subtype="",sasref="csttmplt",
        reftype="libref",iotype="input",filetype="folder",allowoverwrite="N",relpathprefix="",
        path="",order=2,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="autocall",subtype="",sasref="adamauto",
        reftype="fileref",iotype="input",filetype="folder",allowoverwrite="N",relpathprefix="",
        path="",order=1,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="control",subtype="reference",sasref="cntl_s",
        reftype="libref",iotype="both",filetype="dataset",allowoverwrite="Y",relpathprefix="",
        path="&workpath",order=.,memname="validation_sasrefs.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="control",subtype="validation",sasref="cntl_v",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/control",order=.,memname="validation_control.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="lookup",subtype="",sasref="lookup",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="messages",subtype="",sasref="adammsg",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=2,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="template",subtype="",sasref="adamtmpl",
        reftype="libref",iotype="input",filetype="folder",allowoverwrite="N",relpathprefix="",
        path="",order=1,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="properties",subtype="initialize",sasref="inprop",
        reftype="fileref",iotype="input",filetype="file",allowoverwrite="N",relpathprefix="",
        path="",order=1,memname="initialize.properties",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="properties",subtype="validation",sasref="valprop",
        reftype="fileref",iotype="input",filetype="file",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/programs",order=2,memname="validation.properties",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="referencecontrol",subtype="validation",sasref="refcntl",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="referencecontrol",subtype="checktable",sasref="refcntl",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="referencecterm",subtype="",sasref="ctref",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/terminology/coding-dictionaries",order=1,memname="meddra.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="referencemetadata",subtype="column",sasref="refmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="referencemetadata",subtype="table",sasref="refmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="results",subtype="validationmetrics",sasref="results",
        reftype="libref",iotype="output",filetype="dataset",allowoverwrite="Y",relpathprefix="",
        path="&studyOutputPath/results",order=.,memname="validation_metrics.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="results",subtype="validationresults",sasref="results",
        reftype="libref",iotype="output",filetype="dataset",allowoverwrite="Y",relpathprefix="",
        path="&studyOutputPath/results",order=.,memname="validation_results.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="sourcedata",subtype="",sasref="srcdata",
        reftype="libref",iotype="input",filetype="folder",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/baddata",order=.,memname="",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="sourcemetadata",subtype="column",sasref="srcmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/badmetadata",order=.,memname="source_columns.sas7bdat",comment=""
    set standard="&_cstStandard",standardVersion="&_cstStandardVersion",type="sourcemetadata",subtype="table",sasref="srcmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&studyRootPath/badmetadata",order=.,memname="source_tables.sas7bdat",comment=""
    set standard="&_cstTrgStandard",standardVersion="&_cstTrgStandardVersion",type="sourcedata",subtype="",sasref="sdtmdata",
        reftype="libref",iotype="input",filetype="folder",allowoverwrite="N",relpathprefix="",
        path="&trgStudyRootPath/data",order=.,memname="",comment=""
    set standard="&_cstTrgStandard",standardVersion="&_cstTrgStandardVersion",type="sourcemetadata",subtype="column",sasref="sdtmmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&trgStudyRootPath/metadata",order=.,memname="source_columns.sas7bdat",comment=""
    set standard="&_cstTrgStandard",standardVersion="&_cstTrgStandardVersion",type="sourcemetadata",subtype="table",sasref="sdtmmeta",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="&trgStudyRootPath/metadata",order=.,memname="source_tables.sas7bdat",comment=""
    set standard="&_cstTrgStandard",standardVersion="&_cstTrgStandardVersion",type="referencemetadata",subtype="column",sasref="sdtmref",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="&_cstTrgStandard",standardVersion="&_cstTrgStandardVersion",type="referencemetadata",subtype="table",sasref="sdtmref",
        reftype="libref",iotype="input",filetype="dataset",allowoverwrite="N",relpathprefix="",
        path="",order=.,memname="",comment=""
    set standard="CDISC-TERMINOLOGY",standardVersion="NCI_THESAURUS",type="fmtsearch",subtype="",sasref="cstfmt",
        reftype="libref",iotype="input",filetype="catalog",allowoverwrite="N",relpathprefix="",
        path="&_cstCTPath",order=1,memname="&_cstCTMemname",comment=""
    set standard="CDISC-TERMINOLOGY",standardVersion="NCI_THESAURUS",type="fmtsearch",subtype="",sasref="sdtmfmt",
        reftype="libref",iotype="input",filetype="catalog",allowoverwrite="N",relpathprefix="",
        path="&_cstGRoot/standards/cdisc-terminology-&_cstVersion/cdisc-sdtm/current/formats",order=2,memname="cterms.sas7bcat",comment=""
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

%*cstutil_processsetup(_cstSASReferencesLocation=&studyrootpath/control,_cstSASReferencesName=validation_sasrefs);
%cstutil_processsetup(_cstSASReferencesName=validation_sasrefs);

**********************************************************************************;
* Run the standard-specific validation macro.                                    *;
**********************************************************************************;

%adam_validate;

* Delete sasreferences if created above and not needed for additional processing  *;
proc datasets lib=work nolist;
  delete validation_sasrefs / memtype=data;
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