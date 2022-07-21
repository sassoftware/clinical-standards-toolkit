%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmutil_createsrcmetafromsaslib                                               *;
%*                                                                                *;
%* Derives source metadata files from a SAS data library.                         *;
%*                                                                                *;
%* This sample utility macro derives source metadata files from a SAS data        *;
%* library for a CDISC-SDTM study.                                                *;
%*                                                                                *;
%* These source metadata files are used by the SAS Clinical Standards Toolkit to  *;
%* support CDISC SDTM  validation and to derive CDISC CRT-DDS (define.xml) files: *;
%*          source_study                                                          *;
%*          source_tables                                                         *;
%*          source_columns                                                        *;
%*          source_values                                                         *;
%*          source_documents                                                      *;
%*                                                                                *;
%* This is the general strategy:                                                  *;
%*    1. Use PROC CONTENTS output as the primary source of the information.       *;
%*    2. Use reference_tables and reference_columns for matching the columns.     *;
%*    3. Use class_columns as a generic source for the metadata.                  *;
%*                                                                                *;
%* NOTE:  This is ONLY an attempted approximation of source metadata. No          *;
%*        assumptions should be made that the result accurately represents the    *;
%*        study data.                                                             *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. The source data is read from a single SAS library. You can modify the    *;
%*       code to reference multiple libraries by using library concatenation.     *;
%*    2. The data set keys are estimated by the sort order of the source data     *;
%*       (if specified). If it is not specified, the data set keys are estimated  *;
%*       based on columns that SAS uses to define keys in the reference standard. *;
%*    3. For any unknown domain, the domain class (Events, Interventions, or      *;
%*       Findings) is estimated based on the class-specific topic variable (that  *;
%*       is, _TERM (events), _TRT (interventions), and _TESTCD (findings)).       *;
%*    4. Most column values in source_study are hardcoded because there is no     *;
%*       metadata source. These values are used only to build the define.xml file.*;
%*       These values are marked as  <--- HARDCODE  below.                        *;
%*                                                                                *;
%* Limitations:                                                                   *;
%*   1. source_documents and source_values have no SAS library source metadata    *;
%*       and are initialized as 0-observation data sets                           *;
%*   2. Here are two scenarios that have not been addressed:                      *;
%*         - Split domains, such as QS**                                          *;
%*         - SDTM 3.1.2 FA multiple domains (for example, FACM, etc.)             *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstSASRefs  Run-time SASReferences data set derived in process setup  *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstCRTDataLib CRT-DDS Source data library                             *;
%* @macvar _cstSDTMDataLib SDTM Source data library                               *;
%* @macvar _cstTrgMetaLibrary Target Source metadata library                      *;
%* @macvar _cstTrgStudyDS Target Source study metadata data set                   *;
%* @macvar _cstRefLib Reference metadata library                                  *;
%* @macvar _cstRefColumnDS Reference column metadata data set                     *;
%* @macvar _cstClassColumnDS Reference class column metadata data set             *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @history 2013-11-11 Removed comment content because this is not the            *;
%*            intended source information for derivation of the define file.      *;
%*            Standardized lengths, labels, and formats.                          *;
%*            Added initialization of source_values and source_documents.         *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro sdtmutil_createsrcmetafromsaslib(
    ) / des='CST: Create SDTM metadata from SAS library';

%local
  _cstDataRecords
  _cstrundt
  _cstXMLFlag
;

%let _cstSeqCnt=0;
%let _cstSrcData=&sysmacroname;
%let _cstXMLFlag=;

%* Write information about this process to the results data set  *;
%if %symexist(_cstResultsDS) %then
%do;
  data _null_;
    call symputx('_cstrundt',put(datetime(),is8601dt.));
  run;

  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstStandard,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStandardVersion,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: CREATE_SOURCEMETADATA,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: METADATA DERIVATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstsasrefs,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
  %if %symexist(studyRootPath) %then
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
  %else
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
  %let _cstSeqCnt=9;
%end;

* A single source data library serves as the input to this process.  *;
proc contents data=&_cstCRTDataLib.._all_ out=work.contents
    (keep=memname memlabel name type length label varnum formatl formatd sorted sortedby)  noprint;
run;

***************************************;
* Begin derivation of source_study    *;
***************************************;

%cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                          _cstType=sourcemetadata,_cstSubType=study,
                          _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgStudyDS);

* Create a sample source_study data set that serves (currently) only as input to  *;
*  crtdds_sdtm311todefine10 to build a define file from SDTM source metadata.     *;
data work.source_study;
  length formalstandardname $20 studydescription $2000;
  definedocumentname='SAS_CST_Define';                                                        * <--- HARDCODE  *;
  sasref=upcase("&_cstSDTMDataLib");
  studyname='Derived Study built by SAS Clinical Standards Toolkit';                          * <--- HARDCODE  *;
  protocolname='SAS_CST_Define Sample Protocol';                                              * <--- HARDCODE  *;
  studydescription=catx(' ','Derived Study built from data in',pathname("&_cstCRTDataLib"));  * <--- HARDCODE  *;
  Standard = "&_cstStandard";
  StandardVersion = "&_cstStandardVersion";
  formalstandardname = tranwrd(standard,'-',' ');
  formalstandardversion = standardversion;
  output;
run;

data &_cstTrgMetaLibrary..&_cstTrgStudyDS;
 set &_cstTrgMetaLibrary..&_cstTrgStudyDS work.source_study;

* Write out final study-level source metadata  *;
proc sort data=&_cstTrgMetaLibrary..&_cstTrgStudyDS (label="Source Study Metadata");
  by sasref studyname;
run;

%if %symexist(_cstResultsDS) %then
%do;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgStudyDS
);
%end;

**************************************************;
* Initialize source_values                       *;
* (empty, no sourcedata information available)   *;
**************************************************;

%cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                          _cstType=sourcemetadata,_cstSubType=value,
                          _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgValueDS);

proc sort data=&_cstTrgMetaLibrary..&_cstTrgValueDS (label="Source Value Metadata");
  by sasref table column order;
run;

%if %symexist(_cstResultsDS) %then
%do;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgValueDS
);
%end;


**************************************************;
* Initialize source_documents                    *;
* (empty, no sourcedata information available)   *;
**************************************************;

%cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                          _cstType=sourcemetadata,_cstSubType=document,
                          _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgDocumentDS);

proc sort data=&_cstTrgMetaLibrary..&_cstTrgDocumentDS (label="Source Document Metadata");
  by sasref doctype title;
run;

%if %symexist(_cstResultsDS) %then
%do;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgDocumentDS
);
%end;

***************************************;
* Begin derivation of source_tables   *;
***************************************;

* This section attempts to guess information about unrecognized domains (custom or SUPP*)  *;
*  based on available SAS metadata and columns contained within each domain.               *;

proc sort data=work.contents;
  by memname sortedby;
run;

data work.tables (drop=name sorted sortedby tempdomain tempvar dsid rc);
  set work.contents (keep=memname memlabel name sorted sortedby);
    by memname;
  attrib tempkeys format=$200.
         tempclass format=$40.
         tempdomain format=$20.
         tempvar format=$8.;
  retain tempkeys tempclass;
  if first.memname then
  do;
    tempkeys='';
    tempclass='';
  end;

  * First look to see if the data set is sorted, and if so assume the sort columns as keys *;
  if sorted=1 then
  do;
    if sortedby ne . then
      tempkeys = catx(' ',tempkeys,name);
  end;
  * Otherwise, estimate the class and keys based on the data set columns  *;
  else
  do;
    if (substr(memname,1,4))='SUPP' then
    do;
       if tempclass = '' then do;
         tempclass='Relates';
         tempkeys='STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM';
       end;
    end;
    else do;
      * Interventions topic variable:  **TRT  *;
      if substr(name,3)='TRT' then
      do;
        tempclass='Interventions';
        tempkeys=catx(' ','STUDYID USUBJID',name,cats(memname,'STDTC'));
        tempdomain = catx('.',upcase("&_cstCRTDataLib"),memname);
        dsid=open(tempdomain);
        if dsid ne 0 then
          if varnum(dsid,cats(memname,'STDTC'))=0 then tempkeys=TRANWRD(tempkeys,cats(memname,'STDTC'),'');
        tempkeys = compbl(tempkeys);
        rc=close(dsid);
      end;
      * Findings topic variable:  **TESTCD  *;
      else if substr(name,3)='TESTCD' then
      do;
        tempclass='Findings';
        tempkeys=catx(' ','STUDYID USUBJID',name,'VISITNUM',cats(memname,'TPTREF'),cats(memname,'TPTNUM'));
        tempdomain = catx('.',upcase("&_cstCRTDataLib"),memname);
        dsid=open(tempdomain);
        if dsid ne 0 then
          do tempvar = 'VISITNUM',cats(memname,'TPTREF'),cats(memname,'TPTNUM');
            if varnum(dsid,tempvar)=0 then tempkeys=TRANWRD(tempkeys,tempvar,'');
          end;
          tempkeys = compbl(tempkeys);
          rc=close(dsid);
        end;
      * Events topic variable:  **TERM  *;
      else if substr(name,3)='TERM' then
      do;
        tempclass='Events';
        tempkeys=catx(' ','STUDYID USUBJID',cats(memname,'DECOD'),cats(memname,'STDTC'));
        tempdomain = catx('.',upcase("&_cstCRTDataLib"),memname);
        dsid=open(tempdomain);
        if dsid ne 0 then
          do tempvar = cats(memname,'DECOD'),cats(memname,'STDTC');
            if varnum(dsid,tempvar)=0 then tempkeys=TRANWRD(tempkeys,tempvar,'');
          end;
          tempkeys = compbl(tempkeys);
          rc=close(dsid);
      end;
    end;
  end;
  if last.memname then output;
run;

* Split processing for domains found in the reference standard (work.ref_tables)    *;
*  and those unrecognized (custom and SUPP*) domains (work.new_tables).             *;
proc sql noprint;
  create table work.ref_tables as
  select upcase("&_cstSDTMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         ref.class,
         ref.xmlpath,
         ref.xmltitle,
         ref.structure,
         ref.purpose,
         case when tempkeys ne '' then tempkeys
              else ref.keys
         end as keys length=200 format=$200. label="Table Keys",
         ref.state,
         ref.date,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.comment from
    &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where tables.memname ne '' and ref.table ne ''
    order by table;
  create table work.new_tables as
  select upcase("&_cstSDTMDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         case when memname ne '' then memname
              else table
         end as table length=32 format=$32. label="Table Name",
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         case when tempclass ne '' then tempclass
              else class
         end as class length=40 format=$40. label="Observation Class within Standard",
         cats('<INIT>/',lowcase(calculated table),'.xpt') as xmlpath length=200 format=$200. label="(Relative) path to xpt file",
         catx(' ',calculated table,calculated label,'SAS transport file') as xmltitle length=200 format=$200. label="Title for xpt file",
         ref.structure,
         ref.purpose,
         case when tempkeys ne '' then tempkeys
              else keys
         end as keys length=200 format=$200. label="Table Keys",
         ref.state,
         ref.date,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.comment from
    &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where (tables.memname ne '' and ref.table eq '')
    order by table;
quit;

%**********************************************************;
%*  Check for new domains and supply most common xmlpath  *;
%**********************************************************;
proc sql noprint;
   select xmlpath into :_cstXMLFlag from work.new_tables;
quit;

%if "&_cstXMLFlag" ne "" %then
%do;
  data work.buildpath(keep=xmldir);
    set &_cstRefLib..&_cstRefTableDS(keep=xmlpath);
    length dir1 xmldir $2000;
    dir1=tranwrd(kreverse(xmlpath),'\','/');
    xmldir=kreverse(ksubstr(dir1,kindexc(dir1,'/')));
  run;

  proc freq data=work.buildpath;
    tables xmldir/out=work.xmlpath noprint;
  run;

  proc sort data=work.xmlpath;
    by descending count;
  run;

  data _null_;
    set work.xmlpath;
    by descending count;
    if _n_=1;
    call symputx('_cstXMLPath',xmldir);
  run;

  data work.new_tables;
   set work.new_tables;
   xmlpath=tranwrd(xmlpath,'<INIT>/',"&_cstXMLPath");
  run;

  %cstutil_deleteDataSet(_cstDataSetName=work.buildpath); 
  %cstutil_deleteDataSet(_cstDataSetName=work.xmlpath); 
%end;

%*********************************************;
%*  Put all the tables back together again.  *;
%*********************************************;
data work.source_tables;
  set work.ref_tables
      work.new_tables;
    * DE3138 reset comment column to null to avoid define mapping inconsistency issues *;
    comment='';
    standard="&_cstStandard";
    standardversion="&_cstStandardVersion";
run;

* Write out final table-level source metadata  *;
proc sort data=work.source_tables out=&_cstTrgMetaLibrary..&_cstTrgTableDS  (label="Source Table Metadata");
  by sasref table;
run;

%if %symexist(_cstResultsDS) %then
%do;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgTableDS
);
%end;

***************************************;
* Begin derivation of source_columns  *;
***************************************;

data work.columns;
  set work.contents (drop=memlabel sorted sortedby rename=(memname=table type=ctype label=clabel length=clength));
run;

* Split processing for columns found in the reference standard (work.ref_columns)   *;
*  and those unrecognized (custom and SUPP*) columns (work.new_columns).            *;
proc sql noprint;
  create table work.ref_columns as
  select upcase("&_cstSDTMDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         ref.column,
         case when clabel ne '' then clabel
              else label
         end as label length=200 format=$200. label="Column Description",
         columns.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         columns.clength as length length=8 format=8. label="Column Length",
         case when formatl>0 then cats(formatl,'.',formatd)
              else ref.displayformat
         end as displayformat length=32 format=$32. label="Display Format",
         ref.xmldatatype,
         ref.xmlcodelist,
         ref.core,
         ref.origin,
         ref.role,
         ref.term,
         ref.algorithm,
         ref.qualifiers,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.comment,
         1 as _cstfound from
    &_cstRefLib..&_cstRefColumnDS ref
      full join
    work.columns
    on ref.table=columns.table and ref.column=columns.name
    where columns.name ne '' and ref.column ne ''
    order by table, column;
  create table work.new_columns as
  select upcase("&_cstSDTMDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         columns.table,
         columns.name as column length=32 format=$32. label="Column Name",
         case when clabel ne '' then clabel
              else label
         end as label length=200 format=$200. label="Column Description",
         columns.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         columns.clength as length length=8 format=8. label="Column Length",
         ref.displayformat,
         ref.xmldatatype,
         ref.xmlcodelist,
         ref.core,
         ref.origin,
         ref.role,
         ref.term,
         ref.algorithm,
         ref.qualifiers,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.comment from
    &_cstRefLib..&_cstRefColumnDS ref
      full join
    work.columns
    on ref.table=columns.table and ref.column=columns.name
    where columns.name ne '' and ref.column eq ''
    order by table, column;
quit;

* Add class to each record *;
proc sql noprint;
  create table work.new_classcolumns as
  select tab.class, col.* from
  work.new_columns col
   left join
  work.source_tables tab
  on col.table = tab.table;
quit;

* Step 1:  Now go to refmeta.class_columns to get some generic metadata on any of the new columns    *;
*  This step will only find metadata for columns in the Findings, Events and Interventions classes.  *;
proc sql noprint;
  create table work.new_columns_step1 as
  select new.sasref,
         new.table,
         new.column,
         case when new.label ne '' then new.label
              else class.label
         end as label length=200 format=$200. label="Column Description",
         new.order,
         new.type,
         new.length,
         class.displayformat,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.origin,
         class.role,
         class.term,
         class.algorithm,
         class.qualifiers,
         class.standard,
         class.standardversion,
         class.standardref,
         class.comment,
         case when class.column ne '' then 1
              else 0
         end as _cstfound
 from
  work.new_classcolumns new
   left join
  &_cstRefLib..&_cstClassColumnDS class
  on upcase(new.class) = class.table and substr(new.column,3) = substr(class.column,3)
  order by table, column ;
quit;

* This step does a lookup for all domain identifier and timing columns  *;
*  (those without the 2-character domain prefix).                       *;
proc sql noprint;
  create table work.new_columns_step2 as
  select new.sasref,
         new.table,
         new.column,
         case when new.label ne '' then new.label
              else class.label
         end as label length=200 format=$200. label="Column Description",
         new.order,
         new.type,
         new.length,
         class.displayformat,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.origin,
         class.role,
         class.term,
         class.algorithm,
         class.qualifiers,
         class.standard,
         class.standardversion,
         class.standardref,
         class.comment,
         case when class.column ne '' then 1
              else 0
         end as _cstfound
 from
  work.new_columns_step1 (where=(_cstfound=0)) new
   left join
  &_cstRefLib..&_cstClassColumnDS class
  on new.column = class.column
  order by table, column ;
quit;

* This step corrects for multiple identifier groups with common columns like STUDYID  *;
data work.new_columns_step2;
  set work.new_columns_step2;
    by table column;
  if first.column;
run;

* This step does a lookup for all non-identifier domain specific columns  *;
*  (those with the 2-character domain prefix).                            *;
proc sql noprint;
  create table work.new_columns_step3 as
  select new.sasref,
         new.table,
         new.column,
         case when new.label ne '' then new.label
              else class.label
         end as label length=200 format=$200. label="Column Description",
         new.order,
         new.type,
         new.length,
         class.displayformat,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.origin,
         class.role,
         class.term,
         class.algorithm,
         class.qualifiers,
         class.standard,
         class.standardversion,
         class.standardref,
         class.comment,
         case when class.column ne '' then 1
              else 0
         end as _cstfound
 from
  work.new_columns_step2 (where=(_cstfound=0)) new
   left join
  &_cstRefLib..&_cstClassColumnDS class
  on substr(new.column,3) = substr(class.column,3)
  order by table, column ;
quit;

* This step does a lookup for any remaining Supplemental Qualifier columns  *;
* Note the code assumes a single SUPPQUAL reference data set.  If the       *;
*  reference table data set contains multiple SUPP* domain definitions,     *;
*  this code may duplicate columns, so a data reduction step may be needed. *;
proc sql noprint;
  create table work.new_columns_step4 as
  select new.sasref,
         new.table,
         new.column,
         case when new.label ne '' then new.label
              else ref.label
         end as label length=200 format=$200. label="Column Description",
         new.order,
         new.type,
         new.length,
         ref.displayformat,
         ref.xmldatatype,
         ref.xmlcodelist,
         ref.core,
         ref.origin,
         ref.role,
         ref.term,
         ref.algorithm,
         ref.qualifiers,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.comment,
         1 as _cstfound from
  work.new_columns_step3 (where=(_cstfound=0)) new
   left join
  &_cstRefLib..&_cstRefColumnDS ref
  on substr(new.table,1,4) = 'SUPP' and substr(new.column,3) = substr(ref.column,3)
  where substr(new.table,1,4) = 'SUPP' and substr(ref.table,1,4) = 'SUPP'
  order by table, column ;
quit;

* Put all the columns back together again.  *;
data work.source_columns;
  set work.ref_columns
      work.new_columns_step1 (where=(_cstfound=1))
      work.new_columns_step2 (where=(_cstfound=1))
      work.new_columns_step3 (where=(_cstfound=1 or substr(table,1,4) ne 'SUPP'))
      work.new_columns_step4
  ;
    * DE3138 reset comment column to null to avoid define mapping inconsistency issues *;
    comment='';
run;

* Report unrecognized columns  *;
%let _cstDataRecords=0;
data work._cstProblems;
  set work.source_columns (where=(_cstfound=0)) end=last;

    %cstutil_resultsdskeep;
    attrib _cstSeqNo format=8. label="Sequence counter for result column"
           _cstMsgParm1 format=$char100. label="Message parameter value 1 (temp)"
           _cstMsgParm2 format=$char100. label="Message parameter value 2 (temp)"
           ;

    retain _cstSeqNo 0;
    if _n_=1 then _cstSeqNo=&_cstSeqCnt;

    keep _cstMsgParm1 _cstMsgParm2;

    * Set results data set attributes *;
    %cstutil_resultsdsattr;
    retain message resultseverity resultdetails actual keyvalues '';

    srcdata = catx('.',sasref,table);
    resultid="CST0201";
    checkid="";
    _cstMsgParm1=catx(' ','No metadata found for column =',column);
    _cstMsgParm2='';
    resultseq=1;
    resultflag=1;
    _cst_rc=0;

    _cstSeqNo+1;
    seqno=_cstSeqNo;

    %if ^%symexist(_cstResultsDS) %then
    %do;
      put "[CSTLOG" "MESSAGE] No metadata found for " table= column=;
    %end;

    if last then
    do;
      call symputx('_cstSeqCnt',_cstSeqNo);
      call symputx('_cstDataRecords',_n_);
    end;
run;

%if &_cstDataRecords %then
%do;
  %cstutil_appendresultds( _cstErrorDS=work._cstProblems
                          ,_cstVersion=&_cstStandardVersion
                          ,_cstSource=CST
                          ,_cstStdRef=
                          );
%end;

* Write out final column-level source metadata  *;
proc sort data=work.source_columns (drop=_cstfound) out=&_cstTrgMetaLibrary..&_cstTrgColumnDS  (label="Source Column Metadata");
  by sasref table order;
run;

%if %symexist(_cstResultsDS) %then
%do;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgColumnDS
  );
  %******************************************************;
  %* Persist the results if specified in sasreferences  *;
  %******************************************************;
  %cstutil_saveresults();
%end;

* Clean-up  *;

 proc datasets lib=work nolist;
   delete columns tables contents new_: ref_: source_: /memtype=data;
 quit;
 
%mend sdtmutil_createsrcmetafromsaslib;