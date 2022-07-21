%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* adamutil_createsrcmetafromsaslib                                               *;
%*                                                                                *;
%* Derives source metadata files from a SAS library for a CDISC ADaM study.       *;
%*                                                                                *;
%* These source metadata files are used by the SAS Clinical Standards Toolkit to  *;
%* support CDISC ADAM validation and derivation of CDISC CRT-DDS (define.xml):    *;
%*          source_study                                                          *;
%*          source_tables                                                         *;
%*          source_columns                                                        *;
%*          source_documents                                                      *;
%*          source_values                                                         *;
%*                                                                                *;
%* This is the general strategy:                                                  *;
%*    1. Use PROC CONTENTS output as the primary source of the information.       *;
%*    2. Use reference_tables and reference_columns for matching the columns.     *;
%*                                                                                *;
%* NOTE:  This is ONLY an attempted APPROXIMATION of source metadata. No          *;
%*        assumptions should be made that the result completely represents the    *;
%*        study data.                                                             *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. The source data is read from a single SAS library. The code can be       *;
%*       modified to reference multiple libraries using library concatenation.    *;
%*    2. The data set keys are estimated by the sort order of the source data     *;
%*       (if specified). If it is not specified, the data set keys are            *;
%*       estimated based on the columns that SAS uses to define keys in the       *;
%*       reference standard.                                                      *;
%*    3. Most column values in source_study are hardcoded because there is no     *;
%*       metadata source. These values are used only to build the define.xml      *;
%*       file.  These values are marked as <--- HARDCODE in code comments.        *;
%*                                                                                *;
%* Limitations:                                                                   *;
%*   1. source_documents and source_values have no SAS library source metadata    *;
%*       and are initialized as 0-observation data sets                           *;
%*   2. analysis_results is assumed to have no SAS library source metadata        *;
%*       and is initialized as a 0-observation data set                           *;
%*                                                                                *;
%* @macvar studyRootPath Root path to the sample source study                     *;
%* @macvar _cstADAMDataLib Source data library                                    *;
%* @macvar _cstCRTDataLib Source data library                                     *;
%* @macvar _cstCTDescription Description of controlled terminology packet         *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstRefColumnDS Reference column metadata data set                     *;
%* @macvar _cstRefLib Reference metadata library                                  *;
%* @macvar _cstRefTableDS Reference table metadata data set                       *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*            Standards Toolkit                                                   *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstTLFmapfile SAS XML map file that reads the TLF XML file            *;
%* @macvar _cstTLFxmlfile TLF metadata library (XML engine using map file)        *;
%* @macvar _cstTrgAnalysesDS Derived Analysis Results data set                    *;
%* @macvar _cstTrgColumnDS Derived source_columns data set                        *;
%* @macvar _cstTrgMetaLibrary Derived source metadata library                     *;
%* @macvar _cstTrgStudyDS Derived source_study data set                           *;
%* @macvar _cstTrgTableDS Derived source_tables data set                          *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstBuildAnalysisResults - optional - Build the analysis_results        *;
%*            data set in the target metadata folder.                             *;
%*            Values: N | Y                                                       *;
%*            Default: Y                                                          *;
%*                                                                                *;
%* @history 2013-11-11 Removed comment and role content because these are not     *;
%*            the intended source information for derivation of the define file.  *;
%*            Retained reference xmldatatype when known.                          *;
%*            If *DTC, set xmldatatype=datetime.                                  *;
%*            Added initialization of source_values and source_documents.         *;
%* @history 2014-07-22 Reset _cstBuildAnalysisResults=N to be the default         *;
%*            behavior.  If set to Y, a 0-observation data set is created using   *;
%*            the defined data set template.                                      *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure external                                                             *;

%macro adamutil_createsrcmetafromsaslib(
     _cstBuildAnalysisResults=N
    ) / des='CST: Create ADAM metadata from SAS library';

  %local
    _cstCTCnt
    _cstCTLibrary
    _cstCTMember
    _cstCTPath
    _cstDataRecords
    _cstNextCode
    _cstRandom
    _cstrundt
  ;

  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;

  %let _cstCTCnt=0;
  %let _cstCTLibrary=;
  %let _cstCTMember=;
  %let _cstCTPath=;

  %if %klength(&_cstBuildAnalysisResults) < 1 %then
    %let _cstBuildAnalysisResults=N; 
  %else %let _cstBuildAnalysisResults=%upcase(&_cstBuildAnalysisResults);
  
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

    %cstutil_getsasreference(_cstStandard=CDISC-TERMINOLOGY,_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,
                           _cstSASRefmember=_cstCTMember,_cstAllowZeroObs=1,_cstConcatenate=1);
    %let _cstSrcData=&sysmacroname;

    %if %length(&_cstCTLibrary)>0 %then
    %do;
      %let _cstCTCnt=%SYSFUNC(countw(&_cstCTLibrary,' '));
      %do _cstIter=1 %to &_cstCTCnt;
        %let _cstCTPath=&_cstCTPath %sysfunc(ktranslate(%sysfunc(kstrip(%sysfunc(pathname(%scan(&_cstCTLibrary,&_cstIter,' '))))),'/','\'));
        %if %length(&_cstCTMember)>0 %then
          %let _cstCTPath=&_cstCTPath/%scan(&_cstCTMember,&_cstIter,' ');
      %end;
    
      %if %symexist(_cstCTDescription) %then
      %do;
        %if %length(&_cstCTDescription)>0 %then
          %let _cstCTPath=&_cstCTPath (&_cstCTDescription);
      %end;
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CONTROLLED TERMINOLOGY SOURCE: &_cstCTPath,_cstSeqNoParm=10,_cstSrcDataParm=&_cstSrcData);
      %let _cstSeqCnt=10;
    %end;
  %end;


* A single source data library serves as the input to this process.  *;
proc contents data=&_cstCRTDataLib.._all_ out=work.contents
    (keep=memname memlabel name type length label varnum format formatl formatd sorted sortedby)  noprint;
run;

***************************************;
* Begin derivation of source_study    *;
***************************************;

%cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                          _cstType=sourcemetadata,_cstSubType=study,
                          _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgStudyDS);

* Create a sample source_study data set that serves (currently) only as input to  *;
*  crtdds_adamtodefine to build a define file from ADaM source metadata.          *;
data work.source_study;
  sasref=upcase("&_cstADAMDataLib");
  definedocumentname='SAS_CST_Define';                                                      * <--- HARDCODE  *;
  studyname='Derived Study built by SAS Clinical Standards Toolkit';                        * <--- HARDCODE  *;
  studydescription="Derived Study built from data in %sysfunc(pathname(&_cstCRTDataLib))";  * <--- HARDCODE  *;
  protocolname='SAS_CST_Define Sample Protocol';                                            * <--- HARDCODE  *;
  Standard = "&_cstStandard";
  StandardVersion = "&_cstStandardVersion";
  formalstandardname="CDISC ADAM";
  formalstandardversion="2.1";
  output;
run;

data &_cstTrgMetaLibrary..&_cstTrgStudyDS;
 set &_cstTrgMetaLibrary..&_cstTrgStudyDS work.source_study;

* Write out final study-level source metadata  *;
proc sort data=&_cstTrgMetaLibrary..&_cstTrgStudyDS (label="Source Study Metadata");
  by sasref studyname;
run;

%cstutil_deleteDataSet(_cstDataSetName=work.source_study);

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

* For those source data sets not sorted, this section attempts to guess information   *;
*  about keys based on available columns contained within each data set.              *;

proc sort data=work.contents;
  by memname sortedby;
run;

data work.tables (drop=name sorted sortedby tempdomain dsid rc);
  set work.contents (keep=memname memlabel name sorted sortedby);
    by memname;
  attrib tempkeys format=$200.
         tempclass format=$40.
         tempdomain format=$20.;
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
    if memname='ADSL' then
    do;
       if tempclass = '' then do;
         tempclass='ADSL';
         tempkeys='USUBJID';
       end;
    end;
    else if memname='ADAE' then
    do;
      if tempclass = '' then do;
        tempclass='ADAE';
        tempkeys='USUBJID';
        tempdomain = catx('.',upcase("&_cstCRTDataLib"),memname);
        dsid=open(tempdomain);
        if dsid ne 0 then
        do;
          if varnum(dsid,'PARAM')>0 then
            tempkeys=catx(' ',tempkeys,'PARAM');
          else if varnum(dsid,'AETERM')>0 then
            tempkeys=catx(' ',tempkeys,'AETERM');
          else if varnum(dsid,'AEDECOD')>0 then
            tempkeys=catx(' ',tempkeys,'AEDECOD');

          if varnum(dsid,'AVISIT')>0 then
            tempkeys=catx(' ',tempkeys,'AVISIT');
          else if varnum(dsid,'AESTDY')>0 then
            tempkeys=catx(' ',tempkeys,'AESTDY');
          rc=close(dsid);
        end;
      end;
    end;
    else do;
      if tempclass = '' then do;
        tempclass='BDS';
        tempkeys='USUBJID';
        tempdomain = catx('.',upcase("&_cstCRTDataLib"),memname);
        dsid=open(tempdomain);
        if dsid ne 0 then
        do;
          if varnum(dsid,'PARAM')>0 then
            tempkeys=catx(' ',tempkeys,'PARAM');

          if varnum(dsid,'AVISIT')>0 then
            tempkeys=catx(' ',tempkeys,'AVISIT');
          else if varnum(dsid,'ADY')>0 then
            tempkeys=catx(' ',tempkeys,'ADY');
          rc=close(dsid);
        end;
      end;
    end;
  end;
  if last.memname then output;
run;

* Split processing for each class (ADAE, ADSL, BDS)   *;
proc sql noprint;
  create table work.ref_adae as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         ref.class,
         1 as order length=8 format=8. label="Table Order",
         catx('.',lowcase(memname),'xpt') as xmlpath length=200 format=$200. label="(Relative) path to xpt file",
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
         '' as comment length=200 format=$200. label="Comment",
         ref.documentation 
    from &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where tables.memname ne '' and ref.table ne ''  and tables.memname='ADAE'
    order by table;
  create table work.ref_adsl as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         ref.class,
         2 as order length=8 format=8. label="Table Order",
         catx('.',lowcase(memname),'xpt') as xmlpath length=200 format=$200. label="(Relative) path to xpt file",
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
         '' as comment length=200 format=$200. label="Comment",
         ref.documentation 
    from &_cstRefLib..&_cstRefTableDS ref
      full join
    work.tables
    on ref.table=tables.memname
    where tables.memname ne '' and ref.table ne ''  and tables.memname='ADSL'
    order by table;
  create table work.ref_bds as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         tables.memname as table length=32 format=$32.,
         case when memlabel ne '' then memlabel
              else label
         end as label length=200 format=$200. label="Table Label",
         ref.class,
         3 as order length=8 format=8. label="Table Order",
         catx('.',lowcase(memname),'xpt') as xmlpath length=200 format=$200. label="(Relative) path to xpt file",
         case when ref.xmltitle ne '' then ref.xmltitle
              else catx(' ',tables.memname,'SAS transport file')
         end as xmltitle length=200 format=$200. label="Title for xpt file",
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
/*
         case when ref.comment ne '' then ref.comment
              else catx(' ',tables.memlabel,cats('(',tables.memname,')'),'is a Basic Data Structure analysis data set.')
         end as comment length=500 format=$500. label="Comment",
 */
         '' as comment length=200 format=$200. label="Comment",
         ref.documentation
    from &_cstRefLib..&_cstRefTableDS (where=(table='BDS')) ref,
    work.tables
    where tables.memname ne '' and ref.table ne ''  and tables.memname ne 'ADAE' and tables.memname ne 'ADSL'
    order by table;
quit;

* Put all the tables back together again.  *;
data work.source_tables (drop=order);
  set work.ref_adae
      work.ref_adsl
      work.ref_bds;
  if table='ADTTE' then
    date='2012-05-12';
  documentation='';
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

proc datasets lib=work nolist;
  delete ref_adae ref_adsl ref_bds tables source_tables;
quit;

***************************************;
* Begin derivation of source_columns  *;
***************************************;

data work.columns;
  set work.contents (drop=memlabel sorted sortedby rename=(memname=table name=column type=ctype label=clabel length=clength));
  column=upcase(column);
run;

proc sort data=work.columns;
  by table column;
run;

proc sort data=&_cstRefLib..&_cstRefColumnDS out=work.refcolumns (drop=comment);
  by table column;
run;

%cstutil_deleteDataSet(_cstDataSetName=work.contents);

********************************;
* First evaluate ADSL columns  *;
********************************;
data work.match (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                      origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.nomatch (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                        origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.retrymatch  (keep=table column newcolumn1 newcolumn2 ctype clabel clength formatd cdisplayformat varnum _cstfound);

  retain sasref table column label class order type length displayformat xmldatatype xmlcodelist core origin role
         term algorithm qualifiers standard standardversion standardref;

  merge work.refcolumns (in=ref where=(table='ADSL'))
        work.columns (in=src where=(table='ADSL'));
    by table column;
  retain oneDigit twoDigit;
  attrib newcolumn1 format=$8.
         newcolumn2 format=$8.
         cdisplayformat format=$32.;

  if _n_=1 then do;
    oneDigit=prxparse('(\d{1}?)');
    twoDigit=prxparse('(\d{2}?)');
  end;

  if src then
  do;
    sasref=upcase("&_cstADAMDataLib");
    if clabel ne '' then label=clabel;
    order=varnum;
    select(ctype);
      when(1)
      do;
        type='N';
        if formatd>0 then
          xmldatatype='float';
        else
          xmldatatype='integer';
      end;
      otherwise
      do;
        type='C';
        if not ref then
          xmldatatype='text';
      end;
    end;
    if ctype=1 then type='N';
    else type='C';
    if clength>0 then length=clength;

    * Keep source displayformat if non-missing *;
    if formatl>0 then
    do;
      cdisplayformat=put(formatl,8.);
      if formatd>0 then
        cdisplayformat=catx('.',cdisplayformat,formatd);
      else
        cdisplayformat=cats(cdisplayformat,'.');
    end;
    cdisplayformat=cats(format,cdisplayformat);
    if cdisplayformat ne '' then
      displayformat=cdisplayformat;

    standard="&_cstStandard";
    standardversion="&_cstStandardVersion";
    _cstfound=0;

    if ref then
    do;
      _cstfound=1;
      output work.match;
    end;
    else
    do;
      class='ADSL';
      if anydigit(column) then
      do;
        call prxsubstr(twoDigit, column, position, length);
        if position ^= 0 then do;
          newcolumn1=column;
          substr(newcolumn1,position,length)='xx';
          newcolumn2=column;
          substr(newcolumn2,position,length)='zz';
        end;
        else newcolumn1=column;
        call prxsubstr(oneDigit, newcolumn1, position, length);
        if position ^= 0 then do;
          if newcolumn1 = '' then
            newcolumn1=column;
          substr(newcolumn1,position,length)='y';
          if newcolumn2 = '' then
            newcolumn2=column;
          substr(newcolumn2,position,length)='y';
          if newcolumn1=newcolumn2 then
            newcolumn2='';
        end;
        output work.retrymatch;
      end;
      else
        output work.nomatch;
    end;
  end;
run;

proc sql noprint;
  create table work.prxcolumns as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         ref.table,
         src.column,
         case when clabel ne '' then clabel
              else label
         end as label length=200 format=$200. label="Column Description",
         case when ref.class ne '' then ref.class
              else 'ADSL'
         end as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         src.clength as length length=8 format=8. label="Column Length",
         case when cdisplayformat ne '' then cdisplayformat
              else displayformat
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
         '' as comment length=1000 format=$1000. label="Comment",
         1 as _cstfound
  from work.retrymatch src
           left join
       work.refcolumns (where=(table='ADSL')) ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column ne '';
  create table work.unknowncolumns as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         src.table,
         src.column,
         case when clabel ne '' then clabel
              else src.column
         end as label length=200 format=$200. label="Column Description",
         'ADSL' as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         src.clength as length length=8 format=8. label="Column Length",
         case when ctype=1 and formatd<1 then 'integer'
              when ctype=1 and formatd>0 then 'float'
              else 'text'
         end as xmldatatype length=8 format=$8. label="XML Data Type",
         src.cdisplayformat as displayformat length=32 format=$32. label="Display Format",
         "&_cstStandard" as standard length=20 format=$20. label="Name of Standard",
         "&_cstStandardVersion" as standardVersion length=20 format=$20. label="Version of Standard",
         0 as _cstfound
  from work.retrymatch src
           left join
       work.refcolumns (where=(table='ADSL')) ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column eq '';
quit;

data work.source_columns;
  set work.match
      work.nomatch
      work.prxcolumns
      work.unknowncolumns;
run;
proc sort data=work.source_columns;
  by table order;
run;

%if &_cstDebug=0 %then
%do;
  proc datasets library=work nolist;
    delete match nomatch prxcolumns unknowncolumns retrymatch;
  quit;
%end;

********************************;
* Now evaluate ADAE columns    *;
********************************;

proc sort data=work.columns;
  by column table;
run;

proc sort data=&_cstRefLib..&_cstRefColumnDS out=work.refcolumns;
  by column table;
run;

data work.match1 (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                      origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.nomatch1 (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                        origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.retrymatch1  (keep=table column newcolumn1 newcolumn2 ctype clabel clength formatd cdisplayformat varnum _cstfound);

  retain sasref table column label class order type length displayformat xmldatatype xmlcodelist core origin role
         term algorithm qualifiers standard standardversion standardref;

  merge work.refcolumns (in=ref where=(table = 'ADAE'))
        work.columns (in=src where=(table = 'ADAE'));
    by table column;
  retain oneDigit twoDigit;
  attrib newcolumn1 format=$8.
         newcolumn2 format=$8.
         cdisplayformat format=$32.;

  if _n_=1 then do;
    oneDigit=prxparse('(\d{1}?)');
    twoDigit=prxparse('(\d{2}?)');
  end;

  if src then
  do;
    sasref=upcase("&_cstADAMDataLib");
    if clabel ne '' then label=clabel;
    order=varnum;
    select(ctype);
      when(1)
      do;
        type='N';
        if formatd>0 then
          xmldatatype='float';
        else
          xmldatatype='integer';
      end;
      otherwise
      do;
        type='C';
        if not ref then
          xmldatatype='text';
      end;
    end;
    if ctype=1 then type='N';
    else type='C';
    if clength>0 then length=clength;

    * Keep source displayformat if non-missing *;
    if formatl>0 then
    do;
      cdisplayformat=put(formatl,8.);
      if formatd>0 then
        cdisplayformat=catx('.',cdisplayformat,formatd);
      else
        cdisplayformat=cats(cdisplayformat,'.');
    end;
    cdisplayformat=cats(format,cdisplayformat);
    if cdisplayformat ne '' then
      displayformat=cdisplayformat;

    standard="&_cstStandard";
    standardversion="&_cstStandardVersion";
    _cstfound=0;
    if ref then
    do;
      _cstfound=1;
      output work.match1;
    end;
    else
    do;
      class='ADAE';
      if anydigit(column) then
      do;
        call prxsubstr(twoDigit, column, position, length);
        if position ^= 0 then do;
          newcolumn1=column;
          substr(newcolumn1,position,length)='xx';
          newcolumn2=column;
          substr(newcolumn2,position,length)='zz';
        end;
        else newcolumn1=column;
        call prxsubstr(oneDigit, newcolumn1, position, length);
        if position ^= 0 then do;
          if newcolumn1 = '' then
            newcolumn1=column;
          substr(newcolumn1,position,length)='y';
          if newcolumn2 = '' then
            newcolumn2=column;
          substr(newcolumn2,position,length)='y';
          if newcolumn1=newcolumn2 then
            newcolumn2='';
        end;
        output work.retrymatch1;
      end;
      else
        output work.nomatch1;
    end;
  end;
run;

proc sql noprint;
  create table work.prxcolumns1 as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         src.table,
         src.column,
         case when clabel ne '' then clabel
              else label
         end as label length=200 format=$200. label="Column Description",
         case when ref.class ne '' then ref.class
              else 'ADAE'
         end as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         src.clength as length length=8 format=8. label="Column Length",
         case when cdisplayformat ne '' then cdisplayformat
              else displayformat
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
         '' as comment length=1000 format=$1000. label="Comment",
         1 as _cstfound
  from work.retrymatch1 src
           left join
       work.refcolumns (where=(table = 'ADAE')) ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column ne '';
  create table work.unknowncolumns1 as
  select upcase("&_cstADAMDataLib") as sasref,
         src.table,
         src.column,
         case when clabel ne '' then clabel
              else src.column
         end as label length=200 format=$200.,
         'ADAE' as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order,
         case when ctype=1 then 'N'
              else 'C'
         end as type,
         src.clength as length,
         case when ctype=1 and formatd<1 then 'integer'
              when ctype=1 and formatd>0 then 'float'
              else 'text'
         end as xmldatatype,
         src.cdisplayformat as displayformat,
         "&_cstStandard" as standard,
         "&_cstStandardVersion" as standardVersion,
         0 as _cstfound
  from work.retrymatch1 src
           left join
       work.refcolumns (where=(table = 'ADAE')) ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column eq '';
quit;

********************************;
* Now evaluate BDS columns  *;
********************************;

proc sort data=work.columns;
  by column table;
run;

proc sort data=&_cstRefLib..&_cstRefColumnDS(where=(table not in ('ADAE' 'ADSL' 'RESULTS'))) out=work.refcolumns_bds(drop=table);
  by column table;
run;

data work.match2 (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                      origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.nomatch2 (keep=sasref table column label class order type length displayformat xmldatatype xmlcodelist core
                        origin role term algorithm qualifiers standard standardversion standardref _cstfound)
     work.retrymatch2  (keep=table column newcolumn1 newcolumn2 ctype clabel clength formatd cdisplayformat varnum _cstfound);

  retain sasref table column label class order type length displayformat xmldatatype xmlcodelist core origin role
         term algorithm qualifiers standard standardversion standardref;

  merge work.refcolumns_bds (in=ref)
        work.columns (in=src where=(table not in ('ADAE' 'ADSL' 'RESULTS')));
    by column;
  retain oneDigit twoDigit;
  attrib newcolumn1 format=$8.
         newcolumn2 format=$8.
         cdisplayformat format=$32.;

  if _n_=1 then do;
    oneDigit=prxparse('(\d{1}?)');
    twoDigit=prxparse('(\d{2}?)');
  end;

  if src then
  do;
    sasref=upcase("&_cstADAMDataLib");
    if clabel ne '' then label=clabel;
    order=varnum;
    select(ctype);
      when(1)
      do;
        type='N';
        if formatd>0 then
          xmldatatype='float';
        else
          xmldatatype='integer';
      end;
      otherwise
      do;
        type='C';
        if not ref then
          xmldatatype='text';
      end;
    end;
    if ctype=1 then type='N';
    else type='C';
    if clength>0 then length=clength;

    * Keep source displayformat if non-missing *;
    if formatl>0 then
    do;
      cdisplayformat=put(formatl,8.);
      if formatd>0 then
        cdisplayformat=catx('.',cdisplayformat,formatd);
      else
        cdisplayformat=cats(cdisplayformat,'.');
    end;
    cdisplayformat=cats(format,cdisplayformat);
    if cdisplayformat ne '' then
      displayformat=cdisplayformat;

    standard="&_cstStandard";
    standardversion="&_cstStandardVersion";
    _cstfound=0;
    if ref then
    do;
      _cstfound=1;
      output work.match2;
    end;
    else
    do;
      class='BDS';
      if anydigit(column) then
      do;
        call prxsubstr(twoDigit, column, position, length);
        if position ^= 0 then do;
          newcolumn1=column;
          substr(newcolumn1,position,length)='xx';
          newcolumn2=column;
          substr(newcolumn2,position,length)='zz';
        end;
        else newcolumn1=column;
        call prxsubstr(oneDigit, newcolumn1, position, length);
        if position ^= 0 then do;
          if newcolumn1 = '' then
            newcolumn1=column;
          substr(newcolumn1,position,length)='y';
          if newcolumn2 = '' then
            newcolumn2=column;
          substr(newcolumn2,position,length)='y';
          if newcolumn1=newcolumn2 then
            newcolumn2='';
        end;
        output work.retrymatch2;
      end;
      else
        output work.nomatch2;
    end;
  end;
run;

proc sql noprint;
  create table work.prxcolumns2 as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         src.table,
         src.column,
         case when clabel ne '' then clabel
              else label
         end as label length=200 format=$200. label="Column Description",
         case when ref.class ne '' then ref.class
              else 'BDS'
         end as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         src.clength as length length=8 format=8. label="Column Length",
         case when cdisplayformat ne '' then cdisplayformat
              else displayformat
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
         '' as comment length=1000 format=$1000. label="Comment",
         1 as _cstfound
  from work.retrymatch2 src
           left join
       work.refcolumns_bds ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column ne '';
  create table work.unknowncolumns2 as
  select upcase("&_cstADAMDataLib") as sasref length=8 format=$8. label="SASreferences sourcedata libref",
         src.table,
         src.column,
         case when clabel ne '' then clabel
              else src.column
         end as label length=200 format=$200. label="Column Description",
         'BDS' as class length=40 format=$40. label="Observation Class within Standard",
         src.varnum as order length=8 format=8. label="Column Order",
         case when ctype=1 then 'N'
              else 'C'
         end as type length=1 format=$1. label="Column Type",
         src.clength as length length=8 format=8. label="Column Length",
         case when ctype=1 and formatd<1 then 'integer'
              when ctype=1 and formatd>0 then 'float'
              else 'text'
         end as xmldatatype length=8 format=$8. label="XML Data Type",
         src.cdisplayformat as displayformat length=32 format=$32. label="Display Format",
         "&_cstStandard" as standard length=20 format=$20. label="Name of Standard",
         "&_cstStandardVersion" as standardVersion length=20 format=$20. label="Version of Standard",
         0 as _cstfound
  from work.retrymatch2 src
           left join
       work.refcolumns_bds ref
  on src.newcolumn1=ref.column or src.newcolumn2=ref.column
  where ref.column eq '';
quit;


data work.source_columns;
  set work.source_columns
      work.match1
      work.nomatch1
      work.prxcolumns1
      work.unknowncolumns1
      work.match2
      work.nomatch2
      work.prxcolumns2
      work.unknowncolumns2;
  ***********************************************************************************;
  * Programmatically handle display formats for any DATE, DATETIME, or TIME columns *;
  ***********************************************************************************;
  if substr(reverse(strip(column)),1,2)="MT" then
  do;
    if substr(reverse(strip(column)),3,1)="D" then displayformat="DATETIME19.";
    else displayformat="TIME8.";
  end;
  if substr(reverse(strip(column)),1,2)="TD" then displayformat="DATE11.";
  ***********************************************************************************;
  * Programmatically handle xmldatatype for any DATE, DATETIME, or TIME columns     *;
  ***********************************************************************************;
  if substr(reverse(strip(column)),1,3)="CTD" then
    xmldatatype='datetime';
  ***********************************************************************************;
  * Programmatically handle core column values (default=Perm)                       *;
  ***********************************************************************************;
  if missing(core) then core='Perm';
  ***********************************************************************************;
  * Programmatically handle role column values (default=Derived)                    *;
  * Role has no specific use in ADaM so this is for cross-standard consistency only *;
  ***********************************************************************************;
  * if missing(role) then role='Derived';
  * Reset role to missing, as study-specific role may differ from reference role.  *;
  * Users must set any role values feeding into the define file.                   *;
  role='';
run;

proc sort data=work.source_columns;
  by table order;
run;

%if &_cstDebug=0 %then
%do;
  proc datasets library=work nolist;
    delete match1 nomatch1 prxcolumns1 unknowncolumns1 retrymatch1
           match2 nomatch2 prxcolumns2 unknowncolumns2 retrymatch2;
  quit;
%end;


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
    retain message resultseverity resultdetails '';

    srcdata = catx('.',sasref,table);
    resultid="CST0200";
    checkid="";
    _cstMsgParm1=catx(' ','No metadata found for column =',column);
    _cstMsgParm2='';
    resultseq=1;
    resultflag=1;
    _cst_rc=0;

    actual='';
    keyvalues='';
    
    _cstSeqNo+1;
    seqno=_cstSeqNo;

    %if ^%symexist(_cstResultsDS) %then
    %do;
      put "No metadata found for " table= column=;
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
  %let _cstSrcData=&sysmacroname;
  %cstutil_writeresult(
      _cstResultID=CST0074,
      _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
      _cstSeqNoParm=&_cstSeqCnt,
      _cstSrcdataParm=&_cstSrcData,
      _cstActualParm=&_cstTrgColumnDS
  );
%end;

%**********************************;
%*  Clean up temporary data sets  *;
%**********************************;
%if &_cstDebug=0 %then
%do;
  %cstutil_deleteDataSet(_cstDataSetName=work.columns);
  %cstutil_deleteDataSet(_cstDataSetName=work.refcolumns);
  %cstutil_deleteDataSet(_cstDataSetName=work.refcolumns_bds);
  %cstutil_deleteDataSet(_cstDataSetName=work.source_columns);
%end;

*****************************************;
* Begin derivation of analysis_results  *;
* (see @history note)                   *;
*****************************************;

%if &_cstBuildAnalysisResults=Y %then
%do;

  %if ^%sysfunc(exist(&_cstTrgMetaLibrary..&_cstTrgAnalysesDS)) %then 
  %do;
    %cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                              _cstType=sourcemetadata,_cstSubType=analyses,
                              _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgAnalysesDS);

    %if %sysfunc(exist(&_cstTrgMetaLibrary..&_cstTrgAnalysesDS)) %then 
    %do;
    
      proc sort data=&_cstTrgMetaLibrary..&_cstTrgAnalysesDS (label='ADaM Analysis Results');
        by dispid resultid;
      run;
      
      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %let _cstSrcData=&sysmacroname;
        %cstutil_writeresult(
            _cstResultID=CST0074,
            _cstResultParm1=%sysfunc(pathname(&_cstTrgMetaLibrary)),
            _cstSeqNoParm=&_cstSeqCnt,
            _cstSrcdataParm=&_cstSrcData,
            _cstActualParm=&_cstTrgAnalysesDS
        );
      %end;
      %else 
        %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgAnalysesDS created in %sysfunc(pathname(&_cstTrgMetaLibrary));
    %end;
    %else
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %let _cstSrcData=&sysmacroname;
      %cstutil_writeresult(
          _cstResultID=CST0077,
          _cstResultParm1=&_cstTrgMetaLibrary..&_cstTrgAnalysesDS,
          _cstResultParm2=copy from template failed,
          _cstSeqNoParm=&_cstSeqCnt,
          _cstSrcdataParm=&_cstSrcData
      );
    %end;

  %end;
  %else
  %do;
    %let _cstSrcData=&sysmacroname;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
       _cstResultID=CST0200,
       _cstResultParm1=&_cstTrgMetaLibrary..&_cstTrgAnalysesDS already exists and is not being re-created,
       _cstSeqNoParm=&_cstSeqCnt,
       _cstSrcDataParm=&_cstSrcData
    );
  %end;
  
%end;

  %******************************************************;
  %* Persist the results if specified in sasreferences  *;
  %******************************************************;
  %cstutil_saveresults();


%mend adamutil_createsrcmetafromsaslib;
