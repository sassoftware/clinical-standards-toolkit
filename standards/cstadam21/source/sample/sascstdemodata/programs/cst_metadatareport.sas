**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* cst_metadatareport.sas                                                         *;
*                                                                                *;
* Sample driver program to perform reporting of validation check metadata.       *;
* This code performs any needed set-up and data management tasks, followed by    *;
* one or more calls to the %cstutil_createmetadatareport() macro to generate     *;
* report output.                                                                 *;
*                                                                                *;
* Two scenarios for invoking this routine are addressed in this driver module:   *;
*   (1) This code is run as a natural continuation of a CST process, within      *;
*        the same SAS session, with all required files available.  The working   *;
*        assumption is that the SASReferences data set (&_cstSASRefs) exists and *;
*        contains information on all files required for reporting.               *;
*   (2) This code is being run in another SAS session with no CST setup          *;
*        established.  In this case, the user assumes responsibility for         *;
*        defining all librefs and macro variables needed to run the reports,     *;
*        although defaults are set.                                              *;
*                                                                                *;
* Assumptions:                                                                   *;
* (1) SASReferences is not required for this task.  If found, it will be used.   *;
*      If not found, default libraries and macro variables are set and may be    *;
*      overridden by the user.                                                   *;
* (2) The user of this code may override any cstutil_createmetadatareport        *;
*      parameter values.                                                         *;
* (3) Only the cstutil_createmetadatareport &_cstRptControl and &_cstMessages    *;
*      parameters are REQUIRED.                                                  *;
* (4) If the _cststdrefds parameter is not set, the associated panel cannot be   *;
*      generated.                                                                *;
* (5) By default, a PDF report format is assumed. This may be overridden.        *;
* (6) Report output will be written to cstcheckmetadatareport.pdf in the SAS     *;
*      WORK library unless another location is specified in SASReferences or     *;
*      in the set-up code below.                                                 *;
* (7) The report macro cstutil_createmetadatareport will only produce panel 1    *;
*      (Check Overview) unless any of the last 3 parameters are set to Y.        *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%let _cstStandard=CDISC-ADAM;
%let _cstStandardVersion=2.1;   * <----- User sets to ADaM version of interest  *;
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
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
  call symput('trgStudyRootPath',cats("&_cstSRoot","/cdisc-sdtm-3.1.2-&_cstVersion/sascstdemodata"));
run;
%let workPath=%sysfunc(pathname(work));

* Initialize macro variables used for this task  *;

%let _cstRptControl=;
%let _cstRptLib=;
%let _cstRptOutputFile=&studyOutputPath/results/cstcheckmetadatareport.pdf;
%let _cstSetupSrc=SASREFERENCES;
%let _cstStandardPath=;
%let _cstStdRef=;
%let _cstStdTitle=;

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
* One strategy to defining the required library and file metadata for a CST process     *;
*  is to optionally build SASReferences in the WORK library.  An example of how to do   *;
*  this follows.                                                                        *;
*                                                                                       *;
* The call to cstutil_processsetup below tells CST how SASReferences will be provided   *;
*  and referenced.  If SASReferences is built in work, the call to cstutil_processsetup *;
*  may, assuming all defaults, be as simple as  %cstutil_processsetup()                 *;
*****************************************************************************************;
/*
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

*************************************************************************************************;
* column order:  standard, standardversion, type, subtype, sasref, reftype, iotype, filetype,   *;
*                allowoverwrite, relpathprefix, path, order, memname, comment                   *;
* note that &_cstGRoot points to the Global Library root directory                              *;
* path and memname are not required for Global Library references - defaults will be used       *;
*************************************************************************************************;
proc sql;
  insert into work.sasreferences
  values ("CST-FRAMEWORK"     "1.2"                   "messages"          ""                  "messages" "libref"  "input"  "dataset"  "N"  "" ""                                               1 ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "autocall"          ""                  "adamauto" "fileref" "input"  "folder"   "N"  "" ""                                               1 ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "control"           "reference"         "cntl_s"   "libref"  "input"  "dataset"  "N"  "" "&studyRootPath/control"                         . "sasreferences.sas7bdat"      "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "control"           "validation"        "cntl_v"   "libref"  "input"  "dataset"  "N"  "" "&studyRootPath/control"                         . "validation_control.sas7bdat" "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "messages"          ""                  "adammsg"  "libref"  "input"  "dataset"  "N"  "" ""                                               2 ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "properties"        "initialize"        "inprop"   "fileref" "input"  "file"     "N"  "" ""                                               1 "initialize.properties"       "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "properties"        "validation"        "valprop"  "fileref" "input"  "file"     "N"  "" "&studyRootPath/programs"                        2 "validation.properties"       "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencecontrol"  "validation"        "refcntl"  "libref"  "input"  "dataset"  "N"  "" ""                                               . ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencecontrol"  "standardref"       "refcntl"  "libref"  "input"  "dataset"  "N"  "" ""                                               . ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "column"            "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                               . ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "table"             "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                                               . ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "sourcedata"        ""                  "srcdata"  "libref"  "input"  "dataset"  "N"  "" "&studyRootPath/data"                            . ""                            "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "sourcemetadata"    "column"            "srcmeta"  "libref"  "input"  "dataset"  "N"  "" "&studyRootPath/metadata"                        . "source_columns.sas7bdat"     "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "sourcemetadata"    "table"             "srcmeta"  "libref"  "input"  "dataset"  "N"  "" "&studyRootPath/metadata"                        . "source_tables.sas7bdat"      "")
  values ("CDISC-TERMINOLOGY" "NCI_THESAURUS"         "fmtsearch"         ""                  "cstfmt"   "libref"  "input"  "catalog"  "N"  "" "&_cstCTPath"                                    1  "&_cstCTMemname"             "")
  ;
quit;
*/

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

%cstutil_processsetup(_cstSASReferencesLocation=&studyrootpath/control,_cstSASReferencesName=validation_sasrefs);

********************************************************************************;
* Run reports                                                                  *;
* Note multiple invocations require unique &_cstreportoutput parameter values  *;
********************************************************************************;

%cstutil_reportsetup(_cstRptType=Metadata);

%cstutil_createmetadatareport(
    _cststandardtitle=&_cstStdTitle,
    _cstvalidationds=&_cstRptControl,
    _cstvalidationdswhclause=,
    _cstmessagesds=&_cstMessages,
    _cststdrefds=&_cstStdRef,
    _cstreportoutput=%nrbquote(&_cstRptOutputFile),
    _cstcheckmdreport=Y,
    _cstmessagereport=Y,
    _cststdrefreport=N,
    _cstrecordview=N);