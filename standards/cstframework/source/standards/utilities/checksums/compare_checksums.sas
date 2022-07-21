**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* compare_checksums.sas                                                          *;
*                                                                                *;
* Sample driver program to perform a comparison of file checksums for a          *;
* specified folder hierarchy (for example, the Global Library).  Two macros are  *;
* called:                                                                        *;
*    cstutilgeneratechecksums - create an xml file of checksums for the folder   *;
*                                hierarchy you specify                           *;
*    cstutilcomparechecksums - compares the checksums in 2 XML files created     *;
*                                by cstutilgeneratechecksums                     *;
*                                                                                *;
* This module assumes that checksum files have been created previously using     *;
* cstutilgeneratechecksums.  Sample calls to cstutilgeneratechecksums have been  *;
* commented out.  Checksum XML files can be created for customized Toolkit       *;
* components (e.g. Global Library) and subsequently used for comparisons.        *;
*                                                                                *;
* This module reports differences in checksums between the 1.5, 1.5.1 and 1.6    *;
* production releases of Toolkit to illustrate the functionality of the          *;
* cstutilcomparechecksums macro.                                                 *;
*                                                                                *;
* CSTversion  1.7                                                                *;
**********************************************************************************;


***********************************************************************;
* Specify the folder path to the checksums code repository. User must *;
* set this value if running outside of the Clinical Standards Toolkit *;
* environment to access the checksums information. Default value for  *;
* the _cstChecksumsPath macro variable is:                            *;
* C:\cstGlobalLibrary\standards\cst-framework-1.7\utilities\checksums *;
***********************************************************************;
%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cstutil_setcstgroot;
data _null_;
  call symput('_cstChecksumsPath',cats("&_cstGRoot","/standards/cst-framework-&_cstVersion/utilities/checksums"));
run;

***********************************************************************;
* OPTION 2:  Run code standalone                                      *;
***********************************************************************;
%*let _cstChecksumsPath=C:/cstGlobalLibrary/standards/cst-framework-1.7/utilities/checksums;
%*let _cstDebugOptions=mprint mlogic symbolgen mautolocdisplay;


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

*************************;
* Make macros available *;
*************************;

options sasautos=(sasautos "&_cstChecksumsPath/lib");

proc groovy;
  execute parseonly "&_cstChecksumsPath/lib/checksum.groovy";
quit;

libname chksums "&_cstChecksumsPath/productionchecksums";

************************************;
* Framework macros                 *;
************************************;
****cstutilgeneratechecksums(
  _cstFolder=c:/Program Files/SASHome/SASFoundation/9.3/cstframework/sasmacro, 
  _cstXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstframework.xml, 
  _cstProdCode=cstframework,
  _cstLabel=CST 1.5 Production
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstframework.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstframework.xml, 
  _cstCompResults=work.cstframework,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstframework_15_151.html
  );
  
%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstframework.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstframework.xml, 
  _cstCompResults=work.cstframework,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstframework_151_16.html
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstframework.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstframework.xml, 
  _cstCompResults=work.cstframework,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstframework_15_16.html
  );
  
************************************;
* Global Library                   *;
************************************;
****cstutilgeneratechecksums(
  _cstFolder=c:/cstGlobalLibrary, 
  _cstXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstgblstdlib.xml, 
  _cstProdCode=cstgblstdlib,
  _cstLabel=CST 1.5 Production
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstgblstdlib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstgblstdlib.xml, 
  _cstCompResults=work.cstgblstdlib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstgblstdlib_15_151.html
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstgblstdlib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstgblstdlib.xml, 
  _cstCompResults=work.cstgblstdlib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstgblstdlib_151_16.html
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstgblstdlib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstgblstdlib.xml, 
  _cstCompResults=work.cstgblstdlib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstgblstdlib_15_16.html
  );

************************************;
* Sample Library                   *;
************************************;
****cstutilgeneratechecksums(
  _cstFolder=c:/cstSampleLibrary, 
  _cstXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstsamplelib.xml, 
  _cstProdCode=cstsamplelib,
  _cstLabel=CST 1.5 Production
  );
  
%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstsamplelib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstsamplelib.xml, 
  _cstCompResults=work.cstsamplelib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstsamplelib_15_151.html
  );
  
%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst151_cstsamplelib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstsamplelib.xml, 
  _cstCompResults=work.cstsamplelib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstsamplelib_151_16.html
  );

%cstutilcomparechecksums(
  _cstBaseXMLFile=%sysfunc(pathname(chksums))/checksums_cst15_cstsamplelib.xml,
  _cstCompXMLFile=%sysfunc(pathname(chksums))/checksums_cst16_cstsamplelib.xml, 
  _cstCompResults=work.cstsamplelib,
  _cstOutReportPath=&_cstChecksumsPath/results,
  _cstOutReportFile=cstsamplelib_15_16.html
  );