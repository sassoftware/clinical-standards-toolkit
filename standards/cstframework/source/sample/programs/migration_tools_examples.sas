**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* migration_tools_examples.sas                                                   *;
*                                                                                *;
* This sample code requires interaction from the user. Prior to running this     *;
* for several examples below, it is expected that a previous version of Clinical *;
* Standard Toolkit exists and is accessible by the users. For example, this code *;
* is being shipped with version 1.7 and it assumes access to version 1.6 is      *;
* available.  In the example below the root cstGlobalLibrary for the previous    *;
* version has been renamed (or copied) to cst_GlobalLibrar16. See libname        *;
* statements fro NEWCT and OLDCT below.                                          *;
*                                                                                *;
* Sample driver program to demonstrate various migration tools. The following    *;
* macros are demonstrated. More information about these macros can be found in   *;
* the Clinical Standards Toolkit User Guide.                                     *;
*                                                                                *;
*   cstutilinitdifftools                                                         *;
*   cstutilcompareregisteredct                                                   *;
*   cstutilcomparecodelists                                                      *;
*   cstutilcompareautocallmacros                                                 *;
*   cstutilcompareproperties                                                     *;
*   cstutilcomparefolderhierarchy                                                *;
*   cstutilcopyfolderhierarchy                                                   *;
*                                                                                *;
* CSTversion  1.6                                                                *;
*                                                                                *;
* The following statements may require information from the user                 *;
**********************************************************************************;

***********************************;
* Debugging aid:  set _cstDebug=1 *;
***********************************;
%let _cstDebug=0;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options mprint mlogic symbolgen mautolocdisplay;");
  else
    call execute(("%sysfunc(tranwrd(options mprint mlogic symbolgen mautolocdisplay, %str( ), %str( no)));"));
run;

**************************************;
* Initialize special internal macros *;
**************************************;
%cstutilinitdifftools;

******************************;
* Examples of comparing CT   *;
******************************;
libname newct 'C:\cstGlobalLibrary\standards\cdisc-terminology-1.7\control';                             *********<--------User Input needed;
libname oldct 'C:\cstGlobalLibrary16\standards\cdisc-terminology-1.6\control';                           *********<--------User Input needed;

%*****cstutilcompareregisteredct(
  _cstBaseCT=oldct.standardsubtypes,
  _cstNewCT=newct.standardsubtypes
  );

%*****cstutilcompareregisteredct(
  _cstBaseCT=oldct.standardsubtypes,
  _cstNewCT=newct.standardsubtypes,
  _cstRptType=_CSTRESULTSDS
  );

%*****cstutilcompareregisteredct(
  _cstBaseCT=oldct.standardsubtypes,
  _cstNewCT=newct.standardsubtypes,
  _cstRptType=DATASET,
  _cstRptDS=work.compareregisteredct,
  _cstOverwrite=N
  );

libname oldct 'C:\cstGlobalLibrary\standards\cdisc-terminology-1.7\cdisc-sdtm\201212\formats';           *********<--------User Input needed;
libname newct 'C:\cstGlobalLibrary\standards\cdisc-terminology-1.7\cdisc-sdtm\201312\formats';           *********<--------User Input needed;

%*****cstutilcomparecodelists(
  _cstFileType=CATALOG,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,_cstCompareCLI=Y
  );

%*****cstutilcomparecodelists(
  _cstFileType=CATALOG,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,
  _cstCompareCLI=Y,
  _cstRptType=_CSTRESULTSDS,
  _cstRptDS=%nrstr(&_cstResultsDS),
  _cstOverwrite=N
  );

%*****cstutilcomparecodelists(
  _cstFileType=CATALOG,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,
  _cstCompareCLI=Y,
  _cstRptType=DATASET,
  _cstRptDS=work.codelists_cat,
  _cstOverwrite=N
  );

%*****cstutilcomparecodelists(
  _cstFileType=DATASET,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,
  _cstCLVar=codelist,
  _cstCompareCLI=Y,
  _cstCLValueVar=cdisc_submission_value
  );

%*****cstutilcomparecodelists(
  _cstFileType=DATASET,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,
  _cstCLVar=codelist,
  _cstCompareCLI=Y,
  _cstCLValueVar=cdisc_submission_value,
  _cstRptType=_CSTRESULTSDS
  );

%*****cstutilcomparecodelists(
  _cstFileType=DATASET,
  _cstBaseCT=oldct.cterms,
  _cstNewCT=newct.cterms,
  _cstCompareCL=Y,
  _cstCLVar=codelist,
  _cstCompareCLI=Y,
  _cstCLValueVar=cdisc_submission_value,
  _cstRptType=DATASET,
  _cstRptDS=work.codelists_data,
  _cstOverwrite=N
  );



*********************************************;
* Examples of comparing autocall libraries  *;
*********************************************;

*************************************************************;
* Example of log reporting for autocall library comparison  *;
*************************************************************;

%*****cstutilcompareautocallmacros(
  _cstNewPath=C:\Program Files\SASHome2\SASFoundation\9.4\cstframework\sasmacro,
  _cstBasePath=C:\Program Files\SASHome\SASFoundation\9.3\cstframework\sasmacro
  );                                                                                *********<--------User Input needed for parameters;

**************************************************************************;
* Example of results data set reporting for autocall library comparison  *;
**************************************************************************;

%*****cstutilcompareautocallmacros(
  _cstNewPath=C:\Program Files\SASHome2\SASFoundation\9.4\cstframework\sasmacro,
  _cstBasePath=C:\Program Files\SASHome\SASFoundation\9.3\cstframework\sasmacro,        
  _cstRptType=_CSTRESULTSDS,
  _cstOverwrite=N
  );                                                                                *********<--------User Input needed for parameters;

******************************************************************;
* Example of data set reporting for autocall library comparison  *;
******************************************************************;

%*****cstutilcompareautocallmacros(
  _cstNewPath=C:\Program Files\SASHome2\SASFoundation\9.4\cstframework\sasmacro,
  _cstBasePath=C:\Program Files\SASHome\SASFoundation\9.3\cstframework\sasmacro,
  _cstRptType=DATASET,
  _cstRptDS=work.cstframework_macros,
  _cstOverwrite=N
  );                                                                                *********<--------User Input needed for parameters;



*************************************;
* Examples of comparing properties  *;
*************************************;
 
%*****cstutilcompareproperties(
  _cstBasePath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.1.3-1.7\programs\initialize.properties,
  _cstNewPath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.2-1.7\programs\initialize.properties
  );                                                                                *********<--------User Input needed for parameters;

%*****cstutilcompareproperties(
  _cstBasePath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.1.3-1.7\programs\initialize.properties,
  _cstNewPath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.2-1.7\programs\initialize.properties,
  _cstRptType=_CSTRESULTSDS,
  _cstOverwrite=N
  );                                                                                *********<--------User Input needed for parameters;

%*****cstutilcompareproperties(
  _cstBasePath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.1.3-1.7\programs\initialize.properties,
  _cstNewPath=C:\cstGlobalLibrary\standards\cdisc-sdtm-3.2-1.7\programs\initialize.properties,
  _cstRptType=DATASET,
  _cstRptDS=work.initializeproperties,
  _cstOverwrite=N
  );                                                                                *********<--------User Input needed for parameters;
 
 
  
******************************************;
* Examples of comparing hierarchies      *;
*                                        *;
* comp folder root C:\cstGlobalLibrary16 *;
* base folder root C:\cstGlobalLibrary   *;
******************************************;

%*****cstutilcomparefolderhierarchy(
  _cstBaseFolder=C:\cstGlobalLibrary, 
  _cstBaseVersion=1.7,
  _cstCompFolder=C:\cstGlobalLibrary16,
  _cstCompVersion=1.6,
  _cstRptDiff=work.xx,
  _cstRptDiffType=folder,
  _cstOverwrite=y,
  _cstOutReportPath=%sysfunc(pathname(work)),
  _cstOutReportFile=globallibrarydiff16_1.htm,
  _cstODSReportType=html,
  _cstODSStyle=SASWeb,
  _cstODSOptions=
  );                                           *********<--------User Input needed for parameters;

%*****cstutilcomparefolderhierarchy(
  _cstBaseFolder=C:\cstGlobalLibrary, 
  _cstBaseVersion=1.7,
  _cstCompFolder=C:\cstGlobalLibrary16,
  _cstCompVersion=1.6,
  _cstRptDiff=work.comp_file,
  _cstRptDiffType=file,
  _cstOverwrite=y,
  _cstOutReportPath=%sysfunc(pathname(work)),
  _cstOutReportFile=globallibrarydiff16_2.htm
  );                                           *********<--------User Input needed for parameters;
   
%*****cstutilcomparefolderhierarchy(
  _cstBaseFolder=C:\cstGlobalLibrary, 
  _cstBaseVersion=1.7,
  _cstCompFolder=C:\cstGlobalLibrary16,
  _cstCompVersion=1.6,
  _cstRptDiff=work.comp_dataset,
  _cstRptDiffType=dataset,
  _cstOverwrite=y,
  _cstOutReportPath=%sysfunc(pathname(work)),
  _cstOutReportFile=globallibrarydiff16_3.htm
  );                                           *********<--------User Input needed for parameters;

%*****cstutilcomparefolderhierarchy(
  _cstBaseFolder=C:\cstGlobalLibrary, 
  _cstBaseVersion=1.7,
  _cstCompFolder=C:\cstGlobalLibrary16,
  _cstCompVersion=1.6,
  _cstRptDiff=work.comp_all,
  _cstRptDiffType=all,
  _cstOverwrite=y,
  _cstOutReportPath=%sysfunc(pathname(work)),
  _cstOutReportFile=globallibrarydiff16_4.htm
  );                                           *********<--------User Input needed for parameters;



*********************************************;
* Examples of copying folder hierarchies    *;
*********************************************;

*************************************;
* Example of typical Windows clone  *;
*************************************;

%*****cstutilcopyfolderhierarchy(
  _cstSourceFolder=c:\cstGlobalLibrary,
  _cstNewFolder=c:\temp\NewcstGlobalLibrary,
  _cstFolderDS=work.folders,
  _cstFileDS=work.files, 
  _cstBuildFoldersOnly=Y
  );                                           *********<--------User Input needed for parameters;

*****************************************;
* Example of Windows server (UNC) clone *;
*****************************************;

%*****cstutilcopyfolderhierarchy(
  _cstSourceFolder=c:\cstGlobalLibrary,
  _cstNewFolder=c:\temp\NewcstGlobalLibrary,
  _cstFolderDS=work.folders,
  _cstFileDS=work.files, 
  _cstOverWrite=Y
  );                                           *********<--------User Input needed for parameters;
                                                                                                     
***********************************;
* Example of typical Linux clone  *;
***********************************;

%*****cstutilcopyfolderhierarchy(
  _cstSourceFolder=/data/sfw/cstGlobalLibrary,
  _cstNewFolder=/usr/home/sasowner/steve/cstGlobalLibrary,
  _cstFolderDS=work.folders,
  _cstFileDS=work.files
  );                                           *********<--------User Input needed for parameters;

***************************************************;
* Example of typical Linux clone (hierarchy only) *;
***************************************************;

%*****cstutilcopyfolderhierarchy(
  _cstSourceFolder=/data/sfw/cstGlobalLibrary,
  _cstNewFolder=/usr/home/sasowner/steve/cstGlobalLibrary,
  _cstFolderDS=work.folders,
  _cstFileDS=work.files,
  _cstBuildFoldersOnly=Y
  );                                           *********<--------User Input needed for parameters;