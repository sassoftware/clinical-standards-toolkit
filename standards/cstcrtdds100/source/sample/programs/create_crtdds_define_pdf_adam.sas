**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_crtdds_define_pdf_adam.sas                                              *;
*                                                                                *;
* Sample driver program to create a define.pdf file                              *;
*                                                                                *;
* The code, as written, is designed to be run as stand-alone code, with the user *;
*                                                                                *;
* CSTversion  1.5                                                                *;
*                                                                                *;
*  The following statements may require information from the user                *;
**********************************************************************************;

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
*        %cstutil_processsetup(_cstStandard=CDISC-SDTM)                                 *;
*****************************************************************************************;

%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK, _cstType=control,_cstSubType=reference, _cstOutputDS=work.sasreferences);

proc sql;
  insert into work.sasreferences
  values ("CST-FRAMEWORK"  "1.2"                   "messages"     ""           "messages" "libref"  "input"  "dataset"  "N" ""  ""                           1 ""                                "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "messages"     ""           "crtmsg"   "libref"  "input"  "dataset"  "N" ""  ""                           2 ""                                "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "autocall"     ""           "auto1"    "fileref" "input"  "folder"   "N" ""  ""                           1 ""                                "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "control"      "reference"  "control"  "libref"  "both"   "dataset"  "Y" ""  "&workpath"                  . "sasreferences"                   "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "sourcedata"   ""           "srcdata"  "libref"  "input"  "folder"   "N" ""  "&studyRootPath/adamdata"    . ""                                "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "report"       "outputfile" "pdfrpt"   "fileref" "output" "file"     "Y" ""  "&studyOutputPath/sourcexml" . "define_adam.pdf"                 "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "results"      "results"    "results"  "libref"  "output" "dataset"  "Y" ""  "&studyOutputPath/results"   . "write_results_pdf_adam.sas7bdat" "")
  values ("&_cstStandard"  "&_cstStandardVersion"  "properties"   "initialize" "inprop"   "fileref" "input"  "folder"   "N" ""  ""                           1 "initialize.properties"           "")
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

************************************************************;
*  Define temporary Style to use for the PDF file          *;
************************************************************;

ods path(prepend) work._csttmpl(update);

proc template;
edit Styles.Printer AS Printer_DefineXML;
* Ability to suppress borders on PDF links;

    replace Body from Document
            "Undef margins so we get the margins from the printer or SYS option" /
            PageBreakHtml = html("PageBreakLine")
            LeftMargin = _undef_
            RightMargin = _undef_
            TopMargin = _undef_
            BottomMargin = _undef_
            linkcolor = _undef_
            ;
  end;
run;

*******************************************************************************;
* Run the standard-specific CRTDDS macros.                                    *;
*******************************************************************************;
%let _cst_rcmsg=;

%crtdds_writepdf(
    _cstCDISCStandard=ADAM,
    _cstReportStyle=Printer_DefineXML,
    _cstReportTitle=define_adam.pdf for Study ABC,
    _cstReportAuthor=Sesame Street Pharmaceuticals,
    _cstReportKeywords=%str(CRT-DDS, SDTM, metadata)
    );


*******************************************************************************;
* Other example macro calls                                                   *;
*******************************************************************************;

%*crtdds_writepdf(
    _cstCDISCStandard=ADAM,
    _cstSourceLib=srcdata,
    _cstReportOutput=&studyOutputPath/sourcexml/define_adam_links.pdf,
    _cstReportStyle=Printer_DefineXML,
    _cstFontSize=10pt,
    _cstReportTitle=define.pdf for Study XYZ,
    _cstReportAuthor=Sesame Street Pharmaceuticals,
    _cstReportKeywords=%str(CRT-DDS, SDTM, metadata),
    _cstODSoptions=%str(compress=5 uniform),
    _cstPage1ofN=N,
    _cstLinks=Y,
    _cstTOC=Y
    );

%*crtdds_writepdf(
    _cstCDISCStandard=ADAM,
    _cstSourceLib=srcdata,
    _cstReportOutput=&studyOutputPath/sourcexml/define_links_adam_printer.pdf,
    _cstReportStyle=styles.Printer,
    _cstFontSize=10pt,
    _cstReportTitle=define.xml for Study XYZ,
    _cstReportAuthor=Sesame Street Pharmaceuticals,
    _cstReportKeywords=%str(CRT-DDS, SDTM, metadata),
    _cstODSoptions=%str(compress=5 uniform),
    _cstPage1ofN=N,
    _cstLinks=Y,
    _cstTOC=N
    );

************************************************************;
*  Remove reference to temporary template store            *;
************************************************************;
ods path(remove) work._csttmpl(update);


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
