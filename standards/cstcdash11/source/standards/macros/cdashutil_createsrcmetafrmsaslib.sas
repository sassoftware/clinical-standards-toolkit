%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cdashutil_createsrcmetafrmsaslib                                               *;
%*                                                                                *;
%* Derives source metadata files from a SAS data library.                         *;
%*                                                                                *;
%* This macro derives source metadata files from a SAS data library for a CDISC   *;
%* CDASH study.                                                                   *;
%*                                                                                *;
%* These source metadata files are used by the SAS Clinical Standards Toolkit to  *;
%* support CDISC CDASH data conversion to SDTM:                                   *;
%*          source_study                                                          *;
%*          source_tables                                                         *;
%*          source_columns                                                        *;
%*          source_itemgroups                                                     *;
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
%*       metadata source. These values are used only to build an ODM XML file.    *;
%*       These values are marked as  <--- HARDCODE  below.                        *;
%*                                                                                *;
%* Limitations:                                                                   *;
%*   1. source_itemgroups and source_values have no SAS library source metadata   *;
%*      and must be created in the calling macro or another macro.                *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity to evaluate                         *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in              *;
%*             _cstStandard                                                       *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived during process     *;
%*             setup                                                              *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstScenarioDS - optional - A SAS data set <libref.dataset> that        *;
%*            contains specific scenarios (for example, LOCAL PROCESSING) used    *;
%*            in the current study for each domain.                               *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cdashutil_createsrcmetafrmsaslib(_cstScenarioDS=
    ) / des='CST: Create CDASH metadata from SAS library';

%local
  _cstCDASHDataLib
  _cstClassColumnDS
  _cstClassLib
  _cstClassTableDS
  _cstCleanup
  _cstDataRecords
  _cstDetails
  _cstRefColumnDS
  _cstRefLib
  _cstRefTableDS
  _cstrundt
  _cstScenarioExists
  _cstTrgColumnDS
  _cstTrgMetaLibrary
  _cstTrgStudyDS
  _cstTrgTableDS
  _cstXMLFlag
;

%let _cstCleanup=1;
%let _cstSeqCnt=0;
%let _cstSrcData=&sysmacroname;
%let _cstXMLFlag=;
%let _cstScenarioExists=0;

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
%cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstCDASHDataLib);
proc contents data=&_cstCDASHDataLib.._all_ out=work.contents
    (keep=memname memlabel name type length label varnum formatl formatd sorted sortedby)  noprint;
run;

***************************************;
* Begin derivation of source_study    *;
***************************************;

%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=study,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgStudyDS);
%cst_createdsfromtemplate(_cstStandard=&_cstStandard,
                          _cstStandardVersion=&_cstStandardVersion,
                          _cstType=sourcemetadata,_cstSubType=study,
                          _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgStudyDS);

data work.source_study;
  length formalstandardname $20 studydescription $2000;
  sasref=upcase("&_cstCDASHDataLib");
  definedocumentname='';                                                                        * <--- HARDCODE  *;
  studyname='Derived Study built by SAS Clinical Standards Toolkit';                            * <--- HARDCODE  *;
  studydescription=catx(' ','Derived Study built from data in',pathname("&_cstCDASHDataLib"));  * <--- HARDCODE  *;
  protocolname='SAS_CST_CDASH Sample Protocol';                                                 * <--- HARDCODE  *;
  standard = "&_cstStandard";
  standardversion = "&_cstStandardVersion";
  formalstandardname = tranwrd(standard,'-',' ');
  formalstandardversion = standardversion;
  output;
run;

data &_cstTrgMetaLibrary..&_cstTrgStudyDS;
 set &_cstTrgMetaLibrary..&_cstTrgStudyDS work.source_study;
run;

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

***************************************;
* Begin derivation of source_tables   *;
***************************************;

%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefTableDS);

*  This section attempts to guess information about unrecognized domains     *;
*  based on available SAS metadata and columns contained within each domain. *;

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
    * Interventions topic variable:  **TRT  *;
    if substr(name,3)='TRT' then
    do;
      tempclass='Interventions';
      tempkeys=catx(' ','STUDYID USUBJID',name,cats(memname,'STDAT'));
      tempdomain = catx('.',upcase("&_cstCDASHDataLib"),memname);
      dsid=open(tempdomain);
      if dsid ne 0 then
        if varnum(dsid,cats(memname,'STDAT'))=0 then tempkeys=TRANWRD(tempkeys,cats(memname,'STDAT'),'');
      tempkeys = compbl(tempkeys);
      rc=close(dsid);
    end;
    * Findings topic variable:  **TEST  *;
    else if substr(name,3)='TEST' then
    do;
      tempclass='Findings';
      tempkeys=catx(' ','STUDYID USUBJID',cats(memname,'STDAT'),name);
      tempdomain = catx('.',upcase("&_cstCDASHDataLib"),memname);
      dsid=open(tempdomain);
      if dsid ne 0 then
        do tempvar = cats(memname,'STDAT'),name;
          if varnum(dsid,tempvar)=0 then tempkeys=TRANWRD(tempkeys,tempvar,'');
        end;
        tempkeys = compbl(tempkeys);
        rc=close(dsid);
      end;
    * Events topic variable:  **TERM  *;
    else if substr(name,3)='TERM' then
    do;
      tempclass='Events';
      tempkeys=catx(' ','STUDYID USUBJID',cats(memname,'TERM'),cats(memname,'STDAT'));
      tempdomain = catx('.',upcase("&_cstCDASHDataLib"),memname);
      dsid=open(tempdomain);
      if dsid ne 0 then
        do tempvar = cats(memname,'TERM'),cats(memname,'STDAT');
          if varnum(dsid,tempvar)=0 then tempkeys=TRANWRD(tempkeys,tempvar,'');
        end;
        tempkeys = compbl(tempkeys);
        rc=close(dsid);
    end;
  end;
  if last.memname then output;
run;

*  Split processing for domains found in the reference standard (work.ref_tables)    *;
*  and those unrecognized domains (work.new_tables).                                 *;
proc sql noprint;
  create table work.ref_tables as
  select upcase("&_cstCDASHDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         ref.class,
         ref.scenario,
         case when tempkeys ne '' then tempkeys
              else ref.keys
         end as keys length=200 format=$200. label="Table Keys",
         ref.state,
         ref.date,
         ref.standard,
         ref.standardversion,
         ref.comment,
         ref.view,
         ref.xmlrepeating from
    &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where tables.memname ne '' and ref.table ne ''
    order by table;
  create table work.new_tables as
  select upcase("&_cstCDASHDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         case when memname ne '' then memname
              else table
         end as table length=32 format=$32. label="Table Name",
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         case when tempclass ne '' then tempclass
              else class
         end as class length=40 format=$40. label="Observation Class within Standard",
         ref.scenario,
         case when tempkeys ne '' then tempkeys
              else keys
         end as keys length=200 format=$200. label="Table Keys",
         ref.state,
         ref.date,
         ref.standard,
         ref.standardversion,
         ref.comment,
         ref.view,
         ref.xmlrepeating from
    &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where (tables.memname ne '' and ref.table eq '')
    order by table;
quit;

%*********************************************;
%*  Put all the tables back together again.  *;
%*********************************************;
data work.source_tables;
  retain sasref table label class scenario view keys state date standard standardversion xmlrepeating comment;
  set work.ref_tables
      work.new_tables;
run;

%*******************************;
%*  Handle the table scenario  *;
%*******************************;

%if %length(&_cstScenarioDS)>0 %then
%do;
  %if %sysfunc(exist(&_cstScenarioDS)) %then 
  %do;
    %let _cstScenarioExists=1;
    proc sort data=work.source_tables;
      by table; 
    run;

    proc sort data=&_cstScenarioDS out=work.source_scenario;
      by table;
    run;

    data work.source_tables (drop=keepscenario);
      retain sasref table label class scenario view keys state date standard standardversion xmlrepeating comment;
      merge work.source_tables (in=intable) 
            work.source_scenario (in=inscenario);
        by table;
      if upcase(scenario)=upcase(keepscenario);
    run;
  %end;
%end;

%*************************************************;
%*  Write out final table-level source metadata  *;
%*************************************************;
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgTableDS);

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

proc sort data=work.source_tables out=work.source_tables_sorted dupout=work.source_tables_dups nodupkey;
  by sasref table;
run;

%let _cstDataRecords=0;
data _null_;
  if 0 then set work.source_tables_dups nobs=_numobs;
  call symputx('_cstDataRecords',_numobs);
  stop;
run;

%if &_cstDataRecords %then
%do;
  %if &_cstScenarioExists=0 %then
  %do;
    %let _cstDetails=It may be necessary to subset reference metadata using a study-specific domain list specified in the _cstScenarioDS data set parameter;
  %end;

  %cstutil_writeresult(
      _cstResultID=CST0201,
      _cstResultParm1=Derived source metadata data set contains duplicate records,
      _cstSeqNoParm=1,
      _cstResultFlagParm=1,
      _cstSrcDataParm=%upcase(&_cstTrgMetaLibrary..&_cstTrgTableDS),
      _cstActualParm=&_cstTrgMetaLibrary..&_cstTrgTableDS,
      _cstResultDetails=&_cstDetails);
%end;

***************************************;
* Begin derivation of source_columns  *;
***************************************;

%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefColumnDS);

data work.columns;
  set work.contents (drop=memlabel sorted sortedby rename=(memname=table type=ctype label=clabel length=clength));
run;

%*******************************;
%*  Handle the table scenario  *;
%*******************************;

%if &_cstScenarioExists=1 %then
%do;
  proc sort data=work.columns;
    by table name; 
  run;

  proc sort data=&_cstScenarioDS out=work.source_scenario;
    by table;
  run;

  * Adds keepscenario (only) from work.source_scenario  *;
  data work.columns;
    merge work.columns (in=intable) 
          work.source_scenario;
      by table;
    if intable;
  run;
  proc sort data=&_cstRefLib..&_cstRefColumnDS  out=work.&_cstRefColumnDS;
    by table column;
  run;
  
  * Subset reference_columns to just those scenarios of interest defined in the calling driver *;
  data work.&_cstRefColumnDS;
    merge work.&_cstRefColumnDS (in=intable) 
          work.source_scenario;
      by table;
    if intable and scenario=keepscenario;
  run;
%end;
%else
%do;
  proc copy in=&_cstRefLib out=work; 
    select &_cstRefColumnDS; 
  run;
%end;

* Split processing for columns found in the reference standard (work.ref_columns)   *;
*  and those unrecognized (custom) columns (work.new_columns).   *;
proc sql noprint;
  create table work.ref_columns as
  select upcase("&_cstCDASHDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         ref.scenario,
         ref.view,
         ref.column,
         ref.lang,
         columns.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         columns.clength as length length=8 format=8. label="Column Length",
         ref.xmldatatype,
         ref.xmlcodelist,
         ref.core,
         ref.varsource,
         ref.algorithm,
         ref.standard,
         ref.standardversion,
         ref.standardref,
         ref.prompt,
         ref.xmlmulist,
         ref.xmlitemgroup,
         ref.question,
         ref.bridg,
         ref.definition,
         ref.crfinstruct,
         ref.sponsorinfo,
         1 as _cstfound from
    work.&_cstRefColumnDS ref
      full join
    work.columns
    on ref.table=columns.table and ref.column=columns.name
    where columns.name ne '' and ref.column ne ''
    order by table, column;
  create table work.new_columns as
  select upcase("&_cstCDASHDataLib")as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         columns.table,
         columns.name as column length=32 format=$32. label="Column Name",
         case when clabel ne '' then clabel
              else ''
         end as prompt length=200 format=$200. label="Prompt",
         columns.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         columns.clength as length length=8 format=8. label="Column Length",
         ref.scenario,
         ref.view,
         ref.lang,
         ref.xmldatatype,
         ref.xmlcodelist,
         ref.core,
         ref.varsource,
         ref.algorithm,
         ref.standard,
         ref.standardversion,
         ref.standardref, 
         ref.xmlmulist,
         ref.xmlitemgroup,
         ref.question,
         ref.bridg,
         ref.definition,
         ref.crfinstruct,
         ref.sponsorinfo
         from
    work.&_cstRefColumnDS ref
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

%cstutil_getsasreference(_cstSASRefType=classmetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstClassLib,
        _cstSASRefmember=_cstClassTableDS);
%cstutil_getsasreference(_cstSASRefType=classmetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstClassLib,
        _cstSASRefmember=_cstClassColumnDS);

* Step 1:  Now go to refmeta.class_columns to get some generic metadata on any of the new columns    *;
*  This step will only find metadata for columns in the Findings, Events and Interventions classes.  *;
proc sql noprint;
  create table work.new_columns_step1 as
  select new.sasref,
         new.table,
         new.scenario,
         new.view,
         new.column,
         new.prompt,
         new.lang,
         new.order,
         new.type,
         new.length,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.varsource,
         class.algorithm,
         class.standard,
         class.standardversion,
         class.standardref,
         class.xmlmulist,
         class.xmlitemgroup,
         class.question,
         class.bridg,
         class.definition,
         class.crfinstruct,
         class.sponsorinfo,
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
         new.scenario,
         new.view,
         new.column,
         new.prompt,
         new.lang,
         new.order,
         new.type,
         new.length,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.varsource,
         class.algorithm,
         class.standard,
         class.standardversion,
         class.standardref,
         class.xmlmulist,
         class.xmlitemgroup,
         class.question,
         class.bridg,
         class.definition,
         class.crfinstruct,
         class.sponsorinfo,
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
         new.scenario,
         new.view,
         new.column,
         new.prompt,
         new.lang,
         new.order,
         new.type,
         new.length,
         class.xmldatatype,
         class.xmlcodelist,
         class.core,
         class.varsource,
         class.algorithm,
         class.standard,
         class.standardversion,
         class.standardref,
         class.xmlmulist,
         class.xmlitemgroup,
         class.question,
         class.bridg,
         class.definition,
         class.crfinstruct,
         class.sponsorinfo,
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


* Put all the columns back together again.  *;
data work.source_columns;
  set work.ref_columns
      work.new_columns_step1 (where=(_cstfound=1))
      work.new_columns_step2 (where=(_cstfound=1))
      work.new_columns_step3 (where=(_cstfound=1 or substr(table,1,4) ne 'SUPP'))
  ;
  lang="&_cstCDISCLang";
  if standard='' then standard="&_cstStandard";
  if standardversion='' then standardversion="&_cstStandardVersion";
run;

proc sort data=work.source_columns;
  by table column;
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
    if _n_=1 then _cstSeqNo=0;

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
                          ,_cstOrderby=%str(resultid, checkid, resultseq, seqno);
                          );
%end;

%****************************************************************;
%*  Retrieve source_column scenario values from table metadata  *;
%*  Retrieve source_column view values from table metadata      *;
%*  This will handle any missing values for new columns         *;
%****************************************************************;

%if &_cstScenarioExists=1 %then
%do;
  proc sort data=work.source_columns;
    by table;
  run;

  data work.source_columns (drop=keepscenario);
    merge work.source_columns(in=intable) 
          work.source_scenario(in=inscenario);
      by table;
    if (upcase(scenario)=upcase(keepscenario)) or view='';
  run;
  
%end;

proc sql noprint;
  create table work.source_columns2 as
  select tab.scenario, tab.view, col.* from
  work.source_columns(drop=scenario view) col
   left join
  work.source_tables tab
  on col.table = tab.table;
quit;

data work.source_columns2;
  retain sasref table scenario view column prompt lang order type length core varsource xmldatatype 
         xmlcodelist xmlmulist xmlitemgroup algorithm standard standardversion standardref question 
         bridg definition crfinstruct sponsorinfo;
  set work.source_columns2;
run;


%**************************************************;
%*  Write out final column-level source metadata  *;
%**************************************************;
%cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstTrgMetaLibrary,
        _cstSASRefmember=_cstTrgColumnDS);

proc sort data=work.source_columns2 (drop=_cstfound) out=&_cstTrgMetaLibrary..&_cstTrgColumnDS  (label="Source Column Metadata");
  by sasref table order;
run;

proc sort data=work.source_columns2 dupout=work.source_columns2_dups nodupkey;
  by sasref table order;
run;

%let _cstDataRecords=0;
data _null_;
  if 0 then set work.source_columns2_dups nobs=_numobs;
  call symputx('_cstDataRecords',_numobs);
  stop;
run;

%if &_cstDataRecords %then
%do;
  %if &_cstScenarioExists=0 %then
  %do;
    %let _cstDetails=It may be necessary to subset reference metadata using a study-specific domain list specified in the _cstScenarioDS data set parameter;
  %end;

  %cstutil_writeresult(
      _cstResultID=CST0201,
      _cstResultParm1=Derived source metadata data set contains duplicate records,
      _cstSeqNoParm=1,
      _cstResultFlagParm=1,
      _cstSrcDataParm=%upcase(&_cstTrgMetaLibrary..&_cstTrgColumnDS),
      _cstActualParm=&_cstTrgMetaLibrary..&_cstTrgColumnDS,
      _cstResultDetails=&_cstDetails);
%end;

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

%if %symexist(_cstDebug) %then 
%do;
  %if &_cstDebug=1 %then
  %do;
    %let _cstCleanup=0;
  %end;
%end;
%if &_cstCleanup=1 %then
%do;
    proc datasets lib=work nolist;
      delete columns tables contents &_cstRefColumnDS new_: ref_: source_: /memtype=data;
    quit;
%end;
 
%mend cdashutil_createsrcmetafrmsaslib;