**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_sourcemetadata.sas                                                      *;
*                                                                                *;
* This sample driver module performs the setup steps to derive source metadata   *;
* files for a CDISC-ADAM study.                                                  *;
*                                                                                *;
* The following source metadata files are used by Clinical Standards Toolkit to  *;
* support CDISC-ADAM validation and derivation of define.xml files:              *;
*          source_tables                                                         *;
*          source_columns                                                        *;
*          source_study                                                          *;
*          source_documents                                                      *;
*          source_values                                                         *;
*                                                                                *;
* The code, as written, is designed to be run one of two ways:                   *;
*    (1) as stand-alone code, with the user responsible for all library          *;
*         allocations.                                                           *;
*    (2) with inputs and outputs defined within a SASReferences data set         *;
*                                                                                *;
* This driver currently calls one of two macros that utilize different input     *;
*  data:                                                                         *;
*    _cstSrcType=ADAMLIBRARY uses a single library of (presumably ADAM) SAS      *;
*       data sets.  The ADAM macro adamutil_createsrcmetafromsaslib is called.   *;
*    _cstSrcType=CRTDDS uses a library of SAS data sets capturing define.xml     *;
*       metadata (typically derived using the CRTDDS macro crtdds_read).  The    *;
*       ADAM macro adamutil_createsrcmetafromcrtdds is called.                   *;
*                                                                                *;
*       ==> Note the sourcedata libref pointing to the library of SAS data sets  *;
*       capturing define.xml metadata in this driver points to a *shared* folder *;
*       that may contain define metadata extracted from *any* study, including   *;
*       any SDTM version, ADaM or SEND study.  Before running this driver, be    *;
*       sure to rerun the xml read macro (crtdds_read, define_read) to extract   *;
*       metadata from the intended define.xml file.                              *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%let _cstMacroName=%str(ERROR - Process aborted, unknown value for _cstSrcType macro variable);
%let _cstRefLib=;
%let _cstRefColumnDS=;
%let _cstRefTableDS=;
%let _cstCRTDataLib=;
%let _cstCRTMetaLibrary=;
%let _cstCRTStudyDS=;
%let _cstADAMDataLib=;
%let _cstTLFxmlfile=;
%let _cstTLFmapfile=;
%let _cstTrgAnalysesDS=;
%let _cstTrgColumnDS=;
%let _cstTrgDocumentDS=;
%let _cstTrgMetaLibrary=;
%let _cstTrgStudyDS=;
%let _cstTrgTableDS=;
%let _cstTrgValueDS=;
%let _cstStandard=CDISC-ADAM;
%let _cstStandardVersion=2.1  ;    * <------- ADAM version             *;
%let _cstSrcType=ADAMLIBRARY;      * <------- ADAMLIBRARY or CRTDDS    *;
%let _cstCTPath=;
%let _cstCTMemname=;
%let _cstCTDescription=;
%let studySrcDataPath=;

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
  attrib _cstSource format=$12.
         _cstTemp _cstTemp2 format=$200.;
  _cstSource=upcase(symget('_cstSrcType'));
  select (_cstSource);
    when('ADAMLIBRARY')
    do;
      _cstTemp=cats('%adamutil_','createsrcmetafromsaslib');
      call symput('studyRootPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
      call symput('studySrcDataPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata/data"));
      call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
    end;
    when('CRTDDS')
    do;
      _cstTemp=cats('%adamutil_','createsrcmetafromcrtdds');
      call symput('studyRootPath',cats("&_cstSRoot","/cdisc-crtdds-1.0-&_cstVersion"));
      call symput('studySrcDataPath',cats("&_cstSRoot","/cdisc-crtdds-1.0-&_cstVersion/adamdata"));
      call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion/sascstdemodata"));
    end;
    otherwise;
  end;
  if _cstTemp ne '' then
    call symputx('_cstMacroName',_cstTemp);
  call symputx('_cstCleanup',_cstTemp2);
run;
%let workPath=%sysfunc(pathname(work));

/*
***************************************************************************************************************************;
* OPTION 1:  Run code standalone                                                                                          *;
*  Assign REFMETA the input libref where the Reference Metadata currently reside (Reference_columns, Reference_tables)    *;
*  Assign SRCDATA the input libref where the CRTDDS data reside describing the source data derived from define.xml        *;
*  Assign TRGMETA the output libref where the source metadata files like source_columns and Analysis_results reside       *;
*  Assign SASAUTOS the cstGlobalLibrary (&_cstGRoot) where the standard specific (ie ADAM) macros reside                  *;
*  Assign filenames to point to any Tables, Figures and Listing metadata that may be available                            *;
***************************************************************************************************************************;

**********************************************;
* Debugging aid:  set _cstDebug=1            *;
*  Check debug option and set cleanup macro  *
*  No cleanup macro for manual run.          *
**********************************************;
%let _cstDebug=0;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options &_cstDebugOptions;");
  else
    call execute(("%sysfunc(tranwrd(options %cmpres(&_cstDebugOptions), %str( ), %str( no)));"));
  _cstTemp2='';
  call symputx('_cstCleanup',_cstTemp2);
run;

%cstutil_setcstgroot;

************************************************************************************************;
*  The following libname, filename and option statements may need to be modified by the user.  *; 
*  See Option 1 comments above.                                                                *;
************************************************************************************************;
libname refmeta "&_cstGRoot/standards/cdisc-adam-2.1-&_cstVersion/metadata";
libname trgmeta "&studyOutputPath/metadata";
libname srcdata "&studySrcDataPath";
filename tlfxml "&_cstSRoot./cdisc-adam-2.1-&_cstVersion/sascstdemodata/metadata/tlfddt.xml";
filename tlfmap "&_cstSRoot./cdisc-adam-2.1-&_cstVersion/sascstdemodata/metadata/tlfddt.map";
options  mautosource sasautos=("&_cstGRoot/standards/cdisc-adam-2.1-&_cstVersion/macros", sasautos);

%let _cstRefLib=refmeta;
%let _cstRefColumnDS=reference_columns;
%let _cstRefTableDS=reference_tables;
%let _cstCRTDataLib=srcdata;
%let _cstCRTMetaLibrary=srcmeta;
%let _cstCRTStudyDS=source_study;
%let _cstADAMDataLib=srcdata;
%let _cstTLFxmlfile=tlfxml;
%let _cstTLFmapfile=tlfmap;
%let _cstTrgAnalysesDS=analysis_results;
%let _cstTrgColumnDS=source_columns;
%let _cstTrgMetaLibrary=trgmeta;
%let _cstTrgStudyDS=source_study;
%let _cstTrgTableDS=source_tables;
%let _cstTrgDocumentDS=source_documents;
%let _cstTrgValueDS=source_values;

%cstutil_createTempMessages();

********************************************;
* End of OPTION 1 setup                    *;
********************************************;
*/

********************************************;
* OPTION 2:  Run code using SASReferences  *;
********************************************;

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
  values ("CST-FRAMEWORK"     "1.2"                   "messages"          ""           "messages" "libref"  "input"  "dataset"  "N"  "" ""                            1 ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "autocall"          ""           "adamauto" "fileref" "input"  "folder"   "N"  "" ""                            1 ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "messages"          ""           "adammsg"  "libref"  "input"  "dataset"  "N"  "" ""                            2 ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "properties"        "initialize" "inprop"   "fileref" "input"  "file"     "N"  "" ""                            1 "initialize.properties"     "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "column"     "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                            . ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencemetadata" "table"      "refmeta"  "libref"  "input"  "dataset"  "N"  "" ""                            . ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "results"           "results"    "results"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/results"    . "srcmeta_results.sas7bdat"  "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "sourcedata"        ""           "srcdata"  "libref"  "input"  "folder"   "N"  "" "&studySrcDataPath"           . ""                          "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "column"     "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_columns.sas7bdat"   "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "table"      "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_tables.sas7bdat"    "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "study"      "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_study.sas7bdat"     "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "value"      "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_values.sas7bdat"    "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "document"   "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "source_documents.sas7bdat" "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "targetmetadata"    "analyses"   "trgmeta"  "libref"  "output" "dataset"  "Y"  "" "&studyOutputPath/metadata"   . "analysis_results.sas7bdat" "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "externalxml"       "tlfxml"     "tlfxml"   "fileref" "input"  "file"     "N"  "" "&_cstSRoot./cdisc-adam-2.1-&_cstVersion/sascstdemodata/metadata"     . "tlfddt.xml"                "")
  values ("&_cstStandard"     "&_cstStandardVersion"  "referencexml"      "tlfmap"     "tlfmap"   "fileref" "input"  "file"     "N"  "" "&_cstSRoot./cdisc-adam-2.1-&_cstVersion/sascstdemodata/metadata"     . "tlfddt.map"                "")
  values ("CDISC-TERMINOLOGY" "NCI_THESAURUS"         "fmtsearch"         ""           "cstfmt"   "libref"  "input"  "catalog"  "N"  "" "&_cstCTPath"                 1  "&_cstCTMemname"           "")
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
* The default setting for _cstReallocateSASRef is 1.                                    *;
*****************************************************************************************;

%let _cstReallocateSASRefs=1;
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

%cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstCRTDataLib);
%cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstADAMDataLib);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgTableDS);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgColumnDS);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=study,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgStudyDS);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=value,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgValueDS);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=document,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgDocumentDS);
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=analyses,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgAnalysesDS);
%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefTableDS);
%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefColumnDS);
%cstutil_getsasreference(_cstSASRefType=externalxml,_cstSASRefSubtype=tlfxml,_cstSASRefsasref=_cstTLFxmlfile,
        _cstAllowZeroObs=1);
%cstutil_getsasreference(_cstSASRefType=referencexml,_cstSASRefSubtype=tlfmap,_cstSASRefsasref=_cstTLFmapfile,
        _cstAllowZeroObs=1);

********************************************;
* End of OPTION 2 setup                    *;
********************************************;

&_cstMacroName.;

* Delete sasreferences if created above  *;
proc datasets lib=work nolist;
  delete sasreferences / memtype=data;
quit;

**********************************************************************************;
* Clean-up the CST process files, macro variables and macros.                    *;
**********************************************************************************;
/*
&_cstCleanup.;
*/