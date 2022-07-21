**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* migrate_crtdds_to_definexml_adam.sas                                           *;
*                                                                                *;
* Sample driver program to migrate CRT-DDS v1 ADaM metadata source data sets to  *;
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

%let _cstTrgStandard=CDISC-ADAM;     * <----- User sets to standard of the source study          *;
%let _cstTrgStandardVersion=2.1;     * <----- User sets to standard version of the source study  *;

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
  call symput('studyRootPath',cats("&_cstSRoot","/cdisc-adam-2.1-&_cstVersion"));
  call symput('studyOutputPath',cats("&_cstSRoot","/cdisc-definexml-2.0.0-&_cstVersion"));
run;
%let workPath=%sysfunc(pathname(work));

%**********************************************************************************;
%* Define libnames for input                                                      *;
%**********************************************************************************;
%* Original CRT-DDS v1 source metadata for ADaM 2.1 in CST 1.7;
libname crtdds "&studyRootPath/sascstdemodata/metadata";

* Delete source_documents if present since it's empty anyway *;
proc datasets lib=crtdds nolist;
  delete source_documents / memtype=data;
quit;

%**********************************************************************************;
%* Define libnames for output                                                     *;
%**********************************************************************************;
%* Migrated Define-XML v2 source metadata;
libname defv2 "&studyOutputPath/derivedstudymetadata_crtdds/%lowcase(&_cstTrgStandard)-&_cstTrgStandardVersion";

%**********************************************************************************;
%* Define formats                                                                 *;
%**********************************************************************************;
%* ADaM Study formats in CST 1.7;
libname studyfmt "&studyRootPath/sascstdemodata/terminology/formats";

%* CDISC-NCI Terminology to be used in CST 1.6;
libname ncisdtm "&_cstGRoot/standards/cdisc-terminology-1.7/cdisc-sdtm/201312/formats";

libname ncisdtm "&_cstGRoot/standards/cdisc-terminology-1.7/cdisc-sdtm/201312/formats";
libname nciadam "&_cstGRoot/standards/cdisc-terminology-1.7/cdisc-adam/201107/formats";



%* Formats to be used for ADaM;
options fmtsearch = (studyfmt.cterms nciadam.cterms ncisdtm.cterms);

%***********************************************************************************;
%* Create some formats for mapping (used in the cstutilmigratecrtdds2define macro) *;
%***********************************************************************************;
proc format;
  value $_cststd
   /* Maps from CRT-DDS values to required Define-XML v2 values */
   "CDISC SDTM"="SDTM-IG"
   "CDISC SEND"="SEND-IG"
   "CDISC ADAM"="ADaM-IG"
  ;
  value $_cststv
   /* Maps from CRT-DDS values to required Define-XML v2 values */
   "2.1"="1.0"
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
  value $_cstar
  "PRE-SPECIFIED IN PROTOCOL" = "SPECIFIED IN PROTOCOL"
  "PRE-SPECIFIED IN SAP" = "SPECIFIED IN SAP"
  "DATA DRIVEN" = "DATA DRIVEN"
  "REQUESTED BY REGULATORY AGENCY" = "REQUESTED BY REGULATORY AGENCY"
  other=""
  ;
  value $_cstap
  "PRIMARY EFFICACY" = "PRIMARY OUTCOME MEASURE"
  "KEY SECONDARY EFFICACY" = "SECONDARY OUTCOME MEASURE"
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
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_tables, _cstSrcType=table,
  _cstTrgDS=defv2.source_tables, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_columns, _cstSrcType=column,
  _cstTrgDS=defv2.source_columns, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_values, _cstSrcType=value,
  _cstTrgDS=defv2.source_values, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=source_documents, _cstSrcType=document,
  _cstTrgDS=defv2.source_documents, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);
%cstutilmigratecrtdds2define(_cstSrcLib=crtdds, _cstSrcDS=analysis_results, _cstSrcType=analysisresult,
  _cstTrgDS=defv2.source_analysisresults, _cstStudyVersion=&studyversion, 
  _cstStandard=&_cstTrgStandard, _cstStandardVersion=&_cstTrgStandardVersion, _cstCheckValues=Y);


%**********************************************************************************;
%* Migrate source document references in crtdds.analysis_results                  *;
%**********************************************************************************;
%let _cstDocVars=;
proc sql noprint;
  select upcase(name) into :_cstDocVars separated by ' '
  from dictionary.columns
  where upcase(libname)="DEFV2" and upcase(memname)=upcase("SOURCE_DOCUMENTS")
  ;
quit;

data defv2.source_documents(keep=&_cstDocVars);
  set defv2.source_documents
      crtdds.analysis_results(
        in=in_arm
        rename=(dispid=displayidentifier) 
        where=((not missing(progstmt)) or (not missing(xmlpath)))
      );
  if in_arm then do;

    if missing(SASRef) then SASRef="SRCDATA";
    if missing(StudyVersion) then StudyVersion="&studyversion";
    if missing(Standard) then Standard="&_cstTrgStandard";   
    if missing(StandardVersion) then StandardVersion="&_cstTrgStandard";   
    if not missing(progstmt) then do;
      if kindexc(kscan(progstmt, 1, ' '),':\/.') > 0 then do;
        resultidentifier=cats(displayidentifier, ".", resultid);
        doctype="RESULTCODE";
        href=progstmt;
        title="Programming Statements";
        output;
      end;  
    end;  
    if not missing(xmlpath) then do;
        resultidentifier="";
        doctype="DISPLAY";
        href=xmlpath;
        title=xmltitle;
        output;
    end;  
  end;  
run;      

%put NOTE: [CSTLOG%str(MESSAGE)] Data set defv2.source_documents has been created with %cstutilnobs(_cstDataSetName=defv2.source_documents) observation(s).;
  
%* Clean-up;
proc catalog cat=work.formats et=formatc;
  delete _cststd _cstcls;
quit;

%**********************************************************************************;
%* Create source_codelists                                                        *;
%**********************************************************************************;

%* Get formats ;
 %cstutilgetncimetadata(
  _cstFormatCatalogs=ncisdtm.cterms nciadam.cterms,
  _cstNCICTerms=nciadam.cterms,
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
    values ("&SASRef", "CL.AEDICTFT", "Adverse Event Dictionary", "text", "MEDDRA", "8.0",
            "&studyversion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
    values ("&SASRef", "CL.AEDICTFI", "Adverse Event Dictionary", "integer", "MEDDRA", "8.0",
            "&studyversion", "&_cstTrgStandard", "&_cstTrgStandardVersion")
            ;
quit;

data defv2.source_columns;
  set defv2.source_columns;
  if table="ADAE" and column in ("AELLT" "AEDECOD" "AEHLT" "AEHLGT" "AEBODSYS" "AESOC")
    then xmlcodelist="CL.AEDICTFT";
  if table="ADAE" and column in ("AELLTCD" "AEPTCD" "AEHLTCD")
    then xmlcodelist="CL.AEDICTFI";
run;
