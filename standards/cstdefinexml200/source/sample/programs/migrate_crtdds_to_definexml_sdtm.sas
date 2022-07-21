**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* migrate_crtdds_to_definexml_sdtm.sas                                           *;
*                                                                                *;
* Sample driver program to migrate CRT-DDS v1 SDTM metadata source data sets to  *;
* Define-XML v2 metadata source data sets.                                       *;
*                                                                                *;
* Caveat: As with many automated conversion tools, this should be used with      *;
* caution. The source metadata files resulting from this conversion provide a    *;
* starting point for Define-XML 2.0 metadata and a decent way to get a jump      *;
* start on  exploring 2.0 features but they should not be considered ideal       *;
* Define 2.0 implementations suitable for production use.                        *;
* In particular, the set of ValueList definitions and where clauses is converted *;
* from a Value Level Metadata definitions in CRT-DDS 1.0 that has gaps in a      *;
* number of ways.                                                                *;
*                                                                                *;
* CSTversion  1.7                                                                *;
*                                                                                *;
* The following statements may require information from the user                 *;
**********************************************************************************;

%let _cstStandard=CDISC-DEFINE-XML;
%let _cstStandardVersion=2.0.0;

%let _cstTrgStandard=CDISC-SDTM;     * <----- User sets to standard of the source study          *;
%let _cstTrgStandardVersion=3.1.2;   * <----- User sets to standard version of the source study  *;

%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
%cstutil_setcstsroot;
%cstutil_setcstgroot;

%* Make macros available *;
options insert=(sasautos=("&_cstGRoot/standards/cdisc-definexml-2.0.0-&_cstVersion/macros")); 

*****************************************************************************************************;
* The following data step sets (at a minimum) the studyrootpath and studyoutputpath.  These are     *;
* used to make the driver programs portable across platforms and allow the code to be run with      *;
* minimal modification. These macro variables by default point to locations within the              *;
* cstSampleLibrary, set during install but modifiable thereafter.  The cstSampleLibrary is assumed  *;
* to allow write operations by this driver module.                                                  *;
*****************************************************************************************************;

%let studyRootPath=&_cstSRoot/%lowcase(&_cstTrgStandard)-&_cstTrgStandardVersion-&_cstVersion;
%let studyOutputPath=&_cstSRoot/%lowcase(&_cstStandard)-&_cstStandardVersion-&_cstVersion;

data _null_;
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-sdtm-3.1.2-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-definexml-2.0.0-&_cstVersion"));
run;
%let workPath=%sysfunc(pathname(work));

%**********************************************************************************;
%* Define libnames for input                                                      *;
%**********************************************************************************;
%* Original CRT-DDS v1 source metadata for SDTM 3.1.2 in CST 1.7;
libname crtdds "&studyRootPath/sascstdemodata/metadata";

%**********************************************************************************;
%* Define libnames for output                                                     *;
%**********************************************************************************;
%* Migrated Define-XML v2 source metadata;
libname defv2 "&studyOutputPath/derivedstudymetadata_crtdds/%lowcase(&_cstTrgStandard)-&_cstTrgStandardVersion";

%**********************************************************************************;
%* Define formats                                                                 *;
%**********************************************************************************;

*********************************************************************;
* Set CDISC NCI Controlled Terminology version for this process.    *;
*********************************************************************;
%cst_getstandardsubtypes(_cstStandard=CDISC-TERMINOLOGY,_cstOutputDS=work._cstStdSubTypes);
data _null_;
  set work._cstStdSubTypes (where=(standardversion="&_cstTrgStandard" and isstandarddefault='Y'));
  * User can override CT version of interest by specifying a different where clause:            *;
  * Example: (where=(standardversion="&_cstTrgStandard" and standardsubtypeversion='201104'))   *;
  call symputx('_cstCTPath',path);
  call symputx('_cstCTMemname',memname);
run;

proc datasets lib=work nolist;
  delete _cstStdSubTypes;
quit;
run;

%* SDTM Study formats in CST 1.7;
libname studyfmt "&studyRootPath/sascstdemodata/terminology/formats";

%* CDISC-NCI Terminology to be used in CST 1.7;
libname ncisdtm "&_cstCTPath";

%* Formats to be used for SDTM;
options fmtsearch = (studyfmt.formats ncisdtm.&_cstCTMemname);

%***********************************************************************************;
%* Create some formats for mapping (used in the cstutilmigratecrtdds2define macro) *;
%***********************************************************************************;
proc format;
  value $_cststd
   /* Maps from CRT-DDS values to required Define-XML v2 values */
   "CDISC SDTM"="SDTM-IG"
   "CDISC SEND"="SEND-IG"
   "CDISC ADAM"="ADAM-IG"
  ;
  value $_cstdom
   /* Map to ItemGroup/@Domain attribute */
   "QSCG" = "QS"
   "QSCS" = "QS"
   "QSMM" = "QS"
   "RELREC"=' '
   "SUPPAE" = "AE"
  ;
  value $_cstdomd
   /* Map to ItemGroup/Alias[@Context='DomainDescription']/@Name attribute */
   "QSCG" = "Questionnaires"
   "QSCS" = "Questionnaires"
   "QSMM" = "Questionnaires"
   "SUPPAE" = "Adverse Events"
  ;
  value $_cstcls
   /* Maps from CRT-DDS values to required Define-XML v2 values */
   "SPECIAL PURPOSE DOMAINS" = "SPECIAL PURPOSE"
   "SPECIAL PURPOSE DATASETS" = "SPECIAL PURPOSE"
   "FINDINGS ABOUT" = "FINDINGS"
   "ADSL" = "SUBJECT LEVEL ANALYSIS DATASET"
   "ADAE" = "ADAM OTHER"
   "BDS" = "BASIC DATA STRUCTURE"
  ;
  value $_cstvlm
   /* For SDTM maps to variables that are being described by Value Level Metadata */
   "EG.EGTESTCD" = "EGORRES"
   "IE.IETESTCD" = "IEORRES"
   "TI.IETESTCD" = "IECAT"
   "LB.LBTESTCD" = "LBORRES"
   "PE.PETESTCD" = "PEORRES"
   "SC.SCTESTCD" = "SCORRES"
   "VS.VSTESTCD" = "VSORRES"
   "SUPPAE.QNAM" = "QVAL"
  ;
run;  

%**********************************************************************************;
%* Define the studyversion macro variable.                                        *;
%* This will become the MetaDataVersion/@OID attribute                            *;
%* In CRT-DDS this was the source_study.definedocumentname column                 *;
%* Also define the SASRef macro variable to use for the SASRef column in the      *;
%* source_xxx data sets.                                                          *;
%**********************************************************************************;
proc sql noprint;
 select definedocumentname, SASRef into :studyversion, :SASRef
 from crtdds.source_study;
quit;

************************************************************;
* Debugging aid:  set _cstDebug=1                          *;
************************************************************;
%let _cstDebug=0;
data _null_;
  _cstDebug = input(symget('_cstDebug'),8.);
  if _cstDebug then
    call execute("options &_cstDebugOptions;");
  else
    call execute(("%sysfunc(tranwrd(options %cmpres(&_cstDebugOptions), %str( ), %str( no)));"));
run;

%**********************************************************************************;
%* Migrate source tables                                                          *;
%**********************************************************************************;
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_study, _cstSrcType=study,
  _cstTrgDS=defv2.source_study, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_tables,  _cstSrcType=table,
  _cstTrgDS=defv2.source_tables, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_columns,  _cstSrcType=column,
  _cstTrgDS=defv2.source_columns, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_values,  _cstSrcType=value,
  _cstTrgDS=defv2.source_values, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_documents,  _cstSrcType=document,
  _cstTrgDS=defv2.source_documents, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);


%* Clean-up;
proc catalog cat=work.formats et=formatc;
  delete _cststd _cstdom _cstdomd _cstcls _cstvlm;
quit;


%**********************************************************************************;
%* Create source_codelists                                                        *;
%**********************************************************************************;

%* Get formats ;
 %cstutilgetncimetadata(
  _cstFormatCatalogs=,
  _cstNCICTerms=ncisdtm.cterms,
  _cstLang=en,
  _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard,
  _cstStandardVersion=&_cstTrgStandardVersion,
  _cstFmtDS=work._cstformats,
  _cstSASRef=&SASRef,
  _cstReturn=_cst_rc,
  _cstReturnMsg=_cst_rcmsg
  );

%* Create a data set with all applicable formats. ;
data work.cl_column_value(keep=xmlcodelist);
  set defv2.source_columns defv2.source_values;
    xmlcodelist=upcase(xmlcodelist);
    if xmlcodelist ne '';
run;

proc sort data=work.cl_column_value nodupkey;
  by xmlcodelist;
run;
  
%* Only keep applicable formats. ;
proc sql;
  create table defv2.source_codelists
  as select
    nci.*
  from
    work._cstformats nci, work.cl_column_value cv
  where (upcase(compress(nci.codelist, '$')) = 
         upcase(compress(cv.xmlcodelist, '$')))
  ;
quit;  

%put NOTE: [CSTLOG%str(MESSAGE)] Data set defv2.source_codelists has been created with %str
     ()%cstutilnobs(_cstDataSetName=defv2.source_codelists) observation(s).;

%* Clean-up;
%cstutil_deleteDataSet(_cstDataSetName=work._cstformats);
%cstutil_deleteDataSet(_cstDataSetName=work.cl_column_value);


%**********************************************************************************;
%* Updates for External Controlled Terminology                                    *;
%**********************************************************************************;

proc sql;
 insert into defv2.source_codelists
   (sasref, codelist, codelistname, codelistdatatype, dictionary, version, 
    studyversion, standard, standardversion)
    values ("&SASRef", "CL.AEDICT", "Adverse Event Dictionary", "text", "MEDDRA", "8.0", 
            "&studyversion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values ("&SASRef", "CL.DRUGDCT", "Drug Dictionary", "text", "WHODRUG", "200204", 
            "&studyversion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
            ;
quit;  

data defv2.source_columns;
  set defv2.source_columns;
  if table="AE" and column in ("AEDECOD" "AEBODSYS") then xmlcodelist="CL.AEDICT";
  if table="CM" and column in ("CMDECOD" "CMCLAS" "CMCLASCD")
    then xmlcodelist="CL.DRUGDCT";
run;    
