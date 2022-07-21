%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_writepdf                                                                *;
%*                                                                                *;
%* Creates a PDF representation of the define.xml (CRT-DDSv1.0).                  *;
%*                                                                                *;
%* This macro uses as source the SAS representation of the CRT-DDS standard. The  *;
%* PDF report has an optional table of contents and the following sections:       *;
%*  - Dataset level metadata                                                      *;
%*  - Variable level metadata                                                     *;
%*  - Value level metadata                                                        *;
%*  - Algorithms (Computational Methods)                                          *;
%*  - Controlled Terminology                                                      *;
%*                                                                                *;
%*  This macro uses data from the following CRT-DDS datasets:                     *;
%*                                                                                *;
%*       annotatedcrfs                                                            *;
%*    +  clitemdecodetranslatedtext                                               *;
%*    +  codelistitems                                                            *;
%*    +  codelists                                                                *;
%*       computationmethods                                                       *;
%*    +  definedocument                                                           *;
%*    +  externalcodelists                                                        *;
%*    +  itemdefs                                                                 *;
%*    +  itemgroupdefitemrefs                                                     *;
%*    +  itemgroupdefs                                                            *;
%*    +  itemgroupleaf                                                            *;
%*    +  itemgroupleaftitles                                                      *;
%*       itemvaluelistrefs                                                        *;
%*       mdvleaf                                                                  *;
%*       mdvleaftitles                                                            *;
%*    +  metadataversion                                                          *;
%*    +  study                                                                    *;
%*       supplementaldocs                                                         *;
%*       valuelistitemrefs                                                        *;
%*       valuelists                                                               *;
%*                                                                                *;
%*  The data sets that have a + in front of them must exist. However, not all of  *;
%*  them need to have records in them.                                            *;
%*                                                                                *;
%*  The contents of the sections (which attributes are printed) is based on the   *;
%*  Study Data Tabulation Model Metadata Submission Guidelines (SDTM-MSG)         *;
%*  (http://www.cdisc.org/sdtm, 2011-12-31)                                       *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%*                                                                                *;
%*                                                                                *;
%* @param _cstCDISCStandard - required - The CDISC standard for which the PDF     *;
%*            file will be created.                                               *;
%*            Values:  SDTM | SEND | ADAM                                         *;
%*            Default: SDTM                                                       *;
%* @param _cstSourceLib - required - The library that contains CRT-DDS SAS data   *;
%*            sets. If not provided, the code looks in SASReferences for          *;
%*             type=sourcedata.                                                   *;
%* @param _cstReportOutput - required - The PDF file to create.                   *;
%*             If not provided, the code looks in SASReferences for type=report.  *;
%* @param _cstReportStyle - optional - The ODS style to use.                      *;
%*            Default: Styles.Printer                                             *;
%* @param _cstFontSize - required - The report cell font size in points.          *;
%*            Default: 10pt                                                       *;
%* @param _cstReportTitle - optional - The PDF document properties title.         *;
%* @param _cstReportAuthor - optional - The PDF document properties author.       *;
%* @param _cstReportKeywords - optional - The PDF document properties keywords.   *;
%* @param _cstODSoptions - optional - Additional ODS PDF options.                 *;
%*            Default: %str(compress=5 uniform)                                   *;
%* @param _cstPage1ofN  - required - Display the page number as 'Page n of N' (Y) *;
%*            or as 'Page n' (N).                                                 *;
%*            Values:  N | Y                                                      *;
%*            Default: Y                                                          *;
%* @param _cstLinks - required - Create internal PDF hyperlinks.                  *;
%*            Values:  N | Y                                                      *;
%*            Default: N                                                          *;
%* @param _cstTOC - required - Create the table of contents.                      *;
%*            Values:  N | Y                                                      *;
%*            Default: N                                                          *;
%* @param _cstReturn - required - The macro variable whose return value is set by *;
%*            this macro.                                                         *;
%*            Default: _cst_rc                                                    *;
%* @param _cstReturnMsg - required - The macro variable whose return message is   *;
%*            set by this macro.                                                  *;
%*            Default: _cst_rcmsg                                                 *;
%*                                                                                *;
%* @since  1.5                                                                    *;
%* @exposure external                                                             *;

%macro crtdds_writepdf(
    _cstCDISCStandard=SDTM,
    _cstSourceLib=,
    _cstReportOutput=,
    _cstReportStyle=Styles.Printer,
    _cstFontSize=10pt,
    _cstReportTitle=,
    _cstReportAuthor=,
    _cstReportKeywords=,
    _cstODSoptions=%str(compress=5 uniform),
    _cstPage1ofN=Y,
    _cstLinks=N,
    _cstTOC=N,
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg,
    _cstCallingPgm=
    ) / des='Creates a PDF report of the CRT-DDS metadata';

%local _cstActual _cstThisMacroRC _cstThisDeBug _cstSaveOptions _cstRandom LinkStyle _cstMissing _cstStudy
       ds0 ds1 ds2 ds3 ds4 ds5 ds6 ds7 ds8 ds9 ds10 ds11 ds12 ds13
       _cstVL_label0 _cstVL_label1 _cstVL_label2 _cstVL_label3 _cstVL_label4 _cstVL_label5
       _cstCM_Label _cstNoprintSDS _cstNoprintADaM _cstValueLists _cstComputationalMethods _cstNextCode
       _cstSrcDataLib _cstReportLib _cstReportFile _cstPage1ofNstring
      ;

%let _cstActual=;
%let _cstSrcDataLib=;
%let _cstReportLib=;
%let _cstReportFile=;
%let _cstSrcData=&sysmacroname;

%let _cstThisDeBug=0;
%if %symexist(_cstDeBug) %then %let _cstThisDeBug=&_cstDeBug;

%* Save options;
%let _cstSaveOptions=
 %sysfunc(getoption(varlenchk, keyword))
 %sysfunc(getoption(orientation, keyword))
 %sysfunc(getoption(papersize, keyword))
 %sysfunc(getoption(leftmargin, in, keyword))
 %sysfunc(getoption(rightmargin, in, keyword))
 %sysfunc(getoption(bottommargin, in, keyword))
 %sysfunc(getoption(orientation, keyword))
 %sysfunc(getoption(byline))
 %sysfunc(getoption(center))
 %sysfunc(getoption(number))
 %sysfunc(getoption(date));

%* Write information about this process to the results data set  *;
%if %symexist(_cstResultsDS) %then
%do;
   %cstutilwriteresultsintro(_cstPgm=&_cstCallingPgm);
%end;

%* Set options ;
options varlenchk=nowarn;
options orientation=landscape papersize=letter;
options leftmargin="1in" rightmargin="1in" topmargin="0.5in" bottommargin="0.5in";
options nobyline nocenter nonumber nodate;

%***************************************************;
%*  Check _cstReturn and _cstReturnMsg parameters  *;
%***************************************************;
%if (%length(&_cstReturn)=0) or (%length(&_cstReturnMsg)=0) %then %do;
  %* We are not able to communicate other than to the LOG;
  %put %str(ERR)OR:(&_cstSrcData) %str
    ()macro parameters _CSTRETURN and _CSTRETURNMSG can not be missing.;
  %goto exit_macro_nomsg;
%end;

%if (%eval(not %symexist(&_cstReturn))) %then %global &_cstReturn;
%if (%eval(not %symexist(&_cstReturnMsg))) %then %global &_cstReturnMsg;

%*************************************************;
%*  Set _cstReturn and _cstReturnMsg parameters  *;
%*************************************************;
%let _cstThisMacroRC=0;
%let &_cstReturnMsg=;

%**************************************;
%*  Check _cstCDISCStandard parameter *;
%**************************************;
%if %length(&_cstCDISCStandard)=0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstCDISCStandard is missing.;
    %goto exit_macro;
  %end;

%if (%upcase(&_cstCDISCStandard) ne ADAM) and
    (%upcase(&_cstCDISCStandard) ne SDTM) and
    (%upcase(&_cstCDISCStandard) ne SEND) %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=%str(Required macro parameter _cstCDISCStandard has to be ADAM, SDTM or SEND.);
    %let _cstActual=%str(&_cstCDISCStandard);
    %goto exit_macro;
  %end;

%**************************************;
%*  Check _cstSourceLib parameter  *;
%**************************************;
%if %length(&_cstSourceLib)=0 %then
  %do;
    %cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSrcDataLib,_cstAllowZeroObs=1);
    %let _cstSourceLib = &_cstSrcDataLib;
    %if %length(&_cstSourceLib)=0 %then
      %do;
        %let _cstThisMacroRC=1;
        %let &_cstReturnMsg=Required macro parameter _cstSourceLib is missing.;
        %goto exit_macro;
    %end;
  %end;

%if %sysfunc(libref(&_cstSourceLib)) ne 0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Library &_cstSourceLib not assigned.;
    %let _cstActual=%str(&_cstSourceLib);
    %goto exit_macro;
  %end;

%**************************************;
%*  Check _cstReportOutput parameter  *;
%**************************************;
%if %length(&_cstReportOutput)=0 %then
  %do;
    %cstutil_getsasreference(_cstSASRefType=report,_cstSASRefSubtype=outputfile,_cstSASRefsasref=_cstReportLib,
        _cstSASRefmember=_cstReportFile,_cstAllowZeroObs=1);

  %if %length(&_cstReportLib)=0 or %length(&_cstReportFile)=0 %then
    %do;
      %let _cstThisMacroRC=1;
      %let &_cstReturnMsg=Required macro parameter _cstReportOutput is missing.;
      %goto exit_macro;
    %end;
    %else %let _cstReportOutput=%sysfunc(pathname(&_cstReportLib));
  %end;

%**************************************;
%*  Check _cstReportStyle parameter  *;
%**************************************;
%if %length(&_cstReportStyle)=0 %then
  %do;
    %put WAR%STR(NING)(&_cstSrcData): No _cstReportStyle specified, default style will be used;
  %end;

%**************************************;
%*  Check _cstFontSize parameter         *;
%**************************************;
%if %length(&_cstFontSize)=0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstFontSize is missing.;
    %goto exit_macro;
  %end;

%**************************************;
%*  Check _cstPage1ofN parameter      *;
%**************************************;
%if %length(&_cstPage1ofN)=0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstPage1ofN is missing.;
    %goto exit_macro;
  %end;

%if (%upcase(&_cstPage1ofN) ne N) and (%upcase(&_cstPage1ofN) ne Y) %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstPage1ofN has to be Y or N.;
    %let _cstActual=%str(&_cstPage1ofN);
    %goto exit_macro;
  %end;

%**************************************;
%*  Check _cstLinks parameter         *;
%**************************************;
%if %length(&_cstLinks)=0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstLinks is missing.;
    %goto exit_macro;
  %end;

%if (%upcase(&_cstLinks) ne N) and (%upcase(&_cstLinks) ne Y) %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstLinks has to be Y or N.;
    %let _cstActual=%str(&_cstLinks);
    %goto exit_macro;
  %end;

%**************************************;
%*  Check _cstTOC parameter           *;
%**************************************;
%if %length(&_cstTOC)=0 %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstTOC is missing.;
    %goto exit_macro;
  %end;

%if (%upcase(&_cstTOC) ne N) and (%upcase(&_cstTOC) ne Y) %then
  %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Required macro parameter _cstTOC has to be Y or N.;
    %let _cstActual=%str(&_cstTOC);
    %goto exit_macro;
  %end;


%*****************************************************;
%* Parameters have been checked, set macro variables *;
%*****************************************************;

%let LinkStyle=foreground=blue linkcolor=_undef_;

%let _cstRandom=%sysfunc(putn(%sysevalf(%sysfunc(ranuni(0))*10000,floor),z4.));
%let ds0=_defstudymdv_&_cstRandom;
%let ds1=_defstudymdv_trans_&_cstRandom;
%let ds2=_igd_&_cstRandom;
%let ds3=_igd_leaf_&_cstRandom;
%let ds4=_igdirid_&_cstRandom;
%let ds5=_vl_&_cstRandom;
%let ds6=_vlirid_&_cstRandom;
%let ds7=_vliridid_&_cstRandom;
%let ds8=_cl_&_cstRandom;
%let ds9=_clitex_&_cstRandom;
%let ds10=_methods_&_cstRandom;
%let ds11=_anncrf_&_cstRandom;
%let ds12=_suppdoc_&_cstRandom;
%let ds13=_procdoc_&_cstRandom;
%let _cstNextCode=_cod&_cstRandom;

%* Set standard specific title elements;
%if %upcase(&_cstCDISCStandard) eq ADAM %then %do;
  %let _cstIG_label1=Analysis Datasets;
  %let _cstID_width1=4in;
  %let _cstVL_label1=ParameterLists;
  %let _cstVL_label2=Parameter Value Level Metadata;
  %let _cstVL_label3=Parameter Value List;
  %let _cstVL_label4=%str(Where PARAMCD=);
  %let _cstVL_label5=%str(Where PARAM=);
  %let _cstCM_Label=Analysis Derivation;
  %let _cstNoprintSDS=;
  %let _cstNoprintADaM=noprint;
%end;
%if %upcase(&_cstCDISCStandard) eq SDTM %then %do;
  %let _cstIG_label1=SDTM Datasets;
  %let _cstID_width1=3in;
  %let _cstVL_label1=ValueLists;
  %let _cstVL_label2=Value Level Metadata;
  %let _cstVL_label3=Value List;
  %let _cstVL_label4=Value;
  %let _cstVL_label5=Label;
  %let _cstCM_Label=Computational Algorithm;
  %let _cstNoprintSDS=noprint;
  %let _cstNoprintADaM=;
%end;
%if %upcase(&_cstCDISCStandard) eq SEND %then %do;
  %let _cstIG_label1=SEND Datasets;
  %let _cstID_width1=3in;
  %let _cstVL_label1=ValueLists;
  %let _cstVL_label2=Value Level Metadata;
  %let _cstVL_label3=Value List;
  %let _cstVL_label4=Value;
  %let _cstVL_label5=Label;
  %let _cstCM_Label=Computational Algorithm;
  %let _cstNoprintSDS=noprint;
  %let _cstNoprintADaM=;
%end;

%if %upcase(&_cstPage1ofN) eq Y %then
    %let _cstPage1ofNstring = page ^{thispage} of ^{lastpage};
  %else
    %let _cstPage1ofNstring = page ^{thispage};

%**************************************;
%* Minimal expected CRT-DDS data sets *;
%**************************************;
%let _cstMissing=;
%if ^%sysfunc(exist(&_cstSourceLib..definedocument)) %then %let _cstMissing = &_cstMissing definedocument;
%if ^%sysfunc(exist(&_cstSourceLib..study)) %then %let _cstMissing = &_cstMissing study;
%if ^%sysfunc(exist(&_cstSourceLib..metadataversion)) %then %let _cstMissing = &_cstMissing metadataversion;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Missing expected CRT-DDS data set(s) in &_cstSourceLib: &_cstMissing;
    %goto exit_macro_cleanup;
  %end;

%******************************************************************************;
%* End of parameter checks                                                    *;
%******************************************************************************;

%******************************************************************************;
%* Data Management                                                            *;
%******************************************************************************;
proc sql noprint;
  select StudyName into :_cstStudy trimmed
  from &_cstSourceLib..study
    ;
  create table &ds0 as
  select *
  from &_cstSourceLib..definedocument(rename=(description=definedoc_description)) dd,
    &_cstSourceLib..study(rename=(oid=study_oid)) s,
    &_cstSourceLib..metadataversion mdv
  where (s.fk_definedocument = dd.fileoid) and (mdv.fk_study = s.study_oid)
  ;
quit;
%put NOTE: PROC SQL selected &sqlobs rows;

%* There should only be one ODM/StudyMetaDataVersion element *;
%If &sqlobs ne 1
  %then %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=One and only one ODM/StudyMetaDataVersion element expected;
    %goto exit_macro_cleanup;
  %end;

data &ds1(keep=Vartype VarName VarLabel VarValue href);
length VarType $32 VarName $32 VarLabel $100 VarValue $2000 href $512;
  set &ds0;
array odm1 {5} FileType FileOID ODMVersion CreationDateTime AsOfDateTime;
array odm2 {3} StudyName StudyDescription ProtocolName ;
array odm3 {5} Name Description DefineVersion StandardName StandardVersion;
  href="";
  do i=1 to hbound(odm1); VarName=VNAME(ODM1(i)); VarLabel=VLABEL(ODM1(i)); varType="1ODM";             VarValue=ODM1(i); output; end;
  do i=1 to hbound(odm2); VarName=VNAME(ODM2(i)); VarLabel=VLABEL(ODM2(i)); VarType="2GlobalVariables"; VarValue=ODM2(i); output; end;
  do i=1 to hbound(odm3); VarName=VNAME(ODM3(i)); VarLabel=VLABEL(ODM3(i)); varType="3MetaDataVersion"; VarValue=ODM3(i); output; end;
run;


%******************************************************************************;
%* Add Annotated CRFs                                                         *;
%******************************************************************************;
%if (%sysfunc(exist(&_cstSourceLib..AnnotatedCRFs)) and
     %sysfunc(exist(&_cstSourceLib..mdvleaf)) and
     %sysfunc(exist(&_cstSourceLib..mdvleaftitles)))
%then %do;
  proc sql;
  create table &ds11 as
    select m1.leafID, "ACRF" as VarName,
           "Annotated CRF" as VarLabel, "4CRF" as varType,
           DocumentRef, href, title as VarValue from
    &_cstSourceLib..AnnotatedCRFs m1
    left join
    (select * from
       &_cstSourceLib..mdvleaf mdvleaf
     left join
       &_cstSourceLib..mdvleaftitles mdvleaftitles
        on (mdvleaf.id = mdvleaftitles.fk_mdvleaf)) mdvlt
    on ((m1.leafID = mdvlt.ID) and
        (m1.FK_MetaDataVersion = mdvlt.FK_MetaDataVersion));
  quit;

  %if %eval(&sqlobs) > 0 %then %do;
    data &ds1;
      set &ds1 &ds11;
    run;
  %end;
%end;

%******************************************************************************;
%* Add SupplementalDocs                                                       *;
%******************************************************************************;
%if (%sysfunc(exist(&_cstSourceLib..SupplementalDocs)) and
     %sysfunc(exist(&_cstSourceLib..mdvleaf)) and
     %sysfunc(exist(&_cstSourceLib..mdvleaftitles)))
%then %do;
  proc sql;
  create table &ds12 as
    select m1.leafID, "SUPPD" as VarName,
           "Supplemental Data Definitions" as VarLabel, "5SUPDOC" as varType,
           DocumentRef, href, title as VarValue from
    &_cstSourceLib..SupplementalDocs m1
    left join
    (select * from
       &_cstSourceLib..mdvleaf mdvleaf
     left join
       &_cstSourceLib..mdvleaftitles mdvleaftitles
        on (mdvleaf.id = mdvleaftitles.fk_mdvleaf)) mdvlt
    on ((m1.leafID = mdvlt.ID) and
        (m1.FK_MetaDataVersion = mdvlt.FK_MetaDataVersion));
  quit;

  %if %eval(&sqlobs) > 0 %then %do;
    data &ds1;
      set &ds1 &ds12;
    run;
  %end;
%end;

  data &ds1;
    set &ds1;
    %* introduce count variable to get rid of 'Table 1' bookmarks *;
    %* see: http://support.sas.com/kb/31/278.html                 *;
    count=1;
    if not missing(href) then VarValue = catt(VarValue, ' [', href, ']');
  run;

%******************************************************************************;
%* ItemGroups                                                                 *;
%******************************************************************************;

%**************************************;
%* Minimal expected CRT-DDS data sets *;
%**************************************;
%let _cstMissing=;
%if ^%sysfunc(exist(&_cstSourceLib..itemgroupdefs)) %then %let _cstMissing = &_cstMissing itemgroupdefs;
%if ^%sysfunc(exist(&_cstSourceLib..itemgroupleaf)) %then %let _cstMissing = &_cstMissing itemgroupleaf;
%if ^%sysfunc(exist(&_cstSourceLib..itemgroupleaftitles)) %then %let _cstMissing = &_cstMissing itemgroupleaftitles;
%if ^%sysfunc(exist(&_cstSourceLib..itemgroupdefitemrefs)) %then %let _cstMissing = &_cstMissing itemgroupdefitemrefs;
%if ^%sysfunc(exist(&_cstSourceLib..itemdefs)) %then %let _cstMissing = &_cstMissing itemdefs;
%if ^%sysfunc(exist(&_cstSourceLib..codelists)) %then %let _cstMissing = &_cstMissing codelists;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Missing expected CRT-DDS data set(s) in &_cstSourceLib: &_cstMissing;
    %goto exit_macro_cleanup;
  %end;


%* Maintain order of ItemGroups;
data &ds2;
 %* Set formatss to fix 9.3M1 defect issue, will be solved in 9.3M2 ;
 format class $200. structure $300. purpose $200.;
 length igd_order 8;
 set &_cstSourceLib..itemgroupdefs;
 igd_order=_n_;
run;

proc sql;
  create table &ds3 as
  select * from
   &ds2 igd
   left join
     (select * from
       &_cstSourceLib..itemgroupleaf igl,
       &_cstSourceLib..itemgroupleaftitles iglt
      where (iglt.fk_itemgroupleaf = igl.id)
     ) igllt
     on (igd.oid = igllt.fk_itemgroupdefs)
     order by igd_order;
  ;
quit;
%put NOTE: PROC SQL selected &sqlobs rows;
data &ds3;
 set &ds3;
  %* introduce count variable to get rid of 'Table 1' bookmarks *;
  %* see: http://support.sas.com/kb/31/278.html                 *;
  count=1;
run;


proc sql;
  create table &ds4 as
  select * from
    (select * from
      (select * from
        (select * from
           &ds3(keep=oid igd_order Name SASDatasetName Label ArchiveLocationID href title) igd
         left join
           &_cstSourceLib..itemgroupdefitemrefs ir
         on (igd.oid = ir.fk_itemgroupdefs)
        ) igdir
       left join
         &_cstSourceLib..itemdefs(rename=(oid=id_oid name=id_name datatype=id_datatype label=id_label)) id
       on (igdir.itemoid = id.id_oid)
      ) igdirid
  %if %sysfunc(exist(&_cstSourceLib..itemvaluelistrefs)) %then %do;
    left join
           &_cstSourceLib..itemvaluelistrefs ivlr
         on (ivlr.fk_itemdefs = igdirid.id_oid)
  %end;
    ) igdiridvl
left join
    &_cstSourceLib..codelists(drop=fk_metadataversion rename=(oid=cl_oid name=cl_name datatype=cl_datatype)) cl
  on (cl.cl_oid = igdiridvl.codelistref)
left join
    &_cstSourceLib..computationmethods(drop=fk_metadataversion rename=(oid=cm_oid)) cm
  on (cm.cm_oid = igdiridvl.computationmethodoid)
  order by igd_order, ordernumber
  ;
quit;
%put NOTE: PROC SQL selected &sqlobs rows;

DATA &ds4;
 length tmplink textvar $400;
 length comment_method $4000;
%* Set format to fix 9.3M1 defect issue, will be solved in 9.3M2 ;
format id_label $400.;
  SET &ds4;
  tmplink="";
  if not missing(title) or not missing(href)then do;
    %if %upcase(&_cstLinks) eq Y %then %do;
      if not missing(href) then do;
        if missing(title) then textvar=href;
                          else textvar=trim(title)||', '||trim(href);
        tmplink = "^S={cellheight=20pt font_size=10pt just=left"||" url='"||trim(href) ||"'}"||
                  trim(label)||" Dataset ("||
                  trim(Name)||", ^S={&LinkStyle} "||trim(textvar)||"^S={foreground=black })";
      end;
      else
        tmplink = "^S={cellheight=20pt font_size=10pt just=left}"||
                  trim(label)||" Dataset ("||
                  trim(Name)||", "||trim(title)||")";
    %end;
    %else %do;
      if not missing(href) then do;
        if missing(title) then textvar=href;
                          else textvar=trim(title)||', '||trim(href);
        tmplink = "^S={cellheight=20pt font_size=10pt just=left}"||
                  trim(label)||" Dataset ("||
                  trim(Name)||", "||trim(textvar)||")";
      end;
      else
         tmplink = "^S={cellheight=20pt font_size=10pt}"||
                  trim(label)||" Dataset ("||
                  trim(Name)||", "||trim(title)||")";
    %end;
  end;
  %* introduce count variable to get rid of 'Table 1' bookmarks *;
  %* see: http://support.sas.com/kb/31/278.html                 *;
  count=1;
  if not missing(comment) and not missing(method)
    then comment_method=cats(comment, "^{newline 2}", "Derivation: ", method);
    else
      if not missing(method) then comment_method=cats("Derivation: ", method);
                             else comment_method=comment;
  %if %upcase(&_cstCDISCStandard) eq ADAM %then %do;
    if not missing(origin) then comment_method=cats("Origin:", origin, "^{newline 2}", comment_method);
  %end;
run;

%******************************************************************************;
%* ValueLists                                                                 *;
%******************************************************************************;

%let _cstValueLists=1;
%if ^%sysfunc(exist(&_cstSourceLib..valuelists)) or
    ^%sysfunc(exist(&_cstSourceLib..itemvaluelistrefs)) or
    ^%sysfunc(exist(&_cstSourceLib..valuelistitemrefs))
  %then %do;
    %let _cstValueLists=0;
    %put Note: No Value Lists;
    %goto no_valuelists;
  %end;

%* Maintain order of ValueLists;
data &ds5;
 length vl_order 8;
 set &_cstSourceLib..valuelists;
 vl_order=_n_;
run;

%* Value lists;
proc sql;
  create table &ds6 as
  select vl_order, vlirids.* from
   (select * from
      (select * from
        (select * from
           (select valuelistoid, fk_itemdefs, name from
              &_cstSourceLib..itemvaluelistrefs ivlr
            left join
              &_cstSourceLib..itemdefs(rename=(oid=id_oid)) id
            on (ivlr.fk_itemdefs = id.id_oid)
            ) vl
         left join
            &_cstSourceLib..valuelistitemrefs ir
         on (vl.valuelistoid = ir.fk_valuelists)
        ) vlir
       left join
       &_cstSourceLib..itemdefs(rename=(oid=id_oid name=id_name datatype=id_datatype label=id_label)) id
       on (vlir.itemoid = id.id_oid)
      ) vlirid
    left join
      &_cstSourceLib..codelists(drop=fk_metadataversion rename=(oid=cl_oid name=cl_name datatype=cl_datatype)) cl
    on (cl.cl_oid = vlirid.codelistref)
   ) vlirids
  left join
    &ds5 vl
  on (vl.oid = vlirids.valuelistoid)
  ;
  create table &ds7 as
select * from
  (select ds6.*, ivlr.valuelistoid as valuelistoid2 from
   &ds6 ds6 left join &_cstSourceLib..itemvaluelistrefs ivlr
   on (ds6.id_oid = ivlr.fk_itemdefs)
   ) ds7
left join
    &_cstSourceLib..computationmethods(drop=fk_metadataversion rename=(oid=cm_oid)) cm
  on (cm.cm_oid = ds7.computationmethodoid)
  order by vl_order, valuelistoid, fk_itemdefs, ordernumber
  ;
quit;
%put NOTE: PROC SQL selected &sqlobs rows;

data &ds7;
 length comment_method $4000;
 set &ds7;
 %* introduce count variable to get rid of 'Table 1' bookmarks *;
 %* see: http://support.sas.com/kb/31/278.html                 *;
 count=1;
  if not missing(comment) and not missing(method)
    then comment_method=cats(comment, "^{newline 2}", "Derivation: ", method);
    else
      if not missing(method) then comment_method=cats("Derivation: ", method);
                             else comment_method=comment;

  %if %upcase(&_cstCDISCStandard) eq ADAM %then %do;
    if not missing(origin) then comment_method=cats("Origin:", origin, "^{newline 2}", comment_method);
  %end;
run;

%no_valuelists:

%******************************************************************************;
%* CodeLists                                                                  *;
%******************************************************************************;

%let _cstMissing=;
%if ^%sysfunc(exist(&_cstSourceLib..codelists)) %then %let _cstMissing = &_cstMissing codelists;
%if ^%sysfunc(exist(&_cstSourceLib..codelistitems)) %then %let _cstMissing = &_cstMissing codelistitems;
%if ^%sysfunc(exist(&_cstSourceLib..clitemdecodetranslatedtext)) %then %let _cstMissing = &_cstMissing clitemdecodetranslatedtext;
%if ^%sysfunc(exist(&_cstSourceLib..externalcodelists)) %then %let _cstMissing = &_cstMissing externalcodelists;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let _cstThisMacroRC=1;
    %let &_cstReturnMsg=Missing expected CRT-DDS data set(s) in &_cstSourceLib: &_cstMissing;
    %goto exit_macro_cleanup;
  %end;

%* Maintain order of CodeLists;
data &ds8;
 length cl_order 8;
 set &_cstSourceLib..codelists;
 cl_order=_n_;
run;

%* CodeLists;
proc sql;
  create table &ds9 as
  select * from
    ((select 'EXT' as Source, cl.*, dictionary, version from
        &ds8 cl, &_cstSourceLib..externalcodelists cle
      where (cl.oid = cle.fk_codelists))
     outer union corr
     (select 'CLI' as Source, cl.*, codedvalue, rank, oid_cli from
        &ds8 cl, &_cstSourceLib..codelistitems(rename=(oid=oid_cli)) cli
      where (cl.oid = cli.fk_codelists))
    ) clecli
    left join
      &_cstSourceLib..clitemdecodetranslatedtext clid
    on (clecli.oid_cli = clid.fk_codelistitems)
    order by cl_order, rank, codedvalue
    ;
quit;
%put NOTE: PROC SQL selected &sqlobs rows;

data &ds9;
length tmptext $400;
format tmptext $400.;
 set &ds9;
  tmptext = trim(name)|| ', reference name (' || trim(oid)|| ')';
  %* introduce count variable to get rid of 'Table 1' bookmarks *;
  %* see: http://support.sas.com/kb/31/278.html                 *;
  count=1;
run;

/* Create format _cstmethod for external codelists */

proc format lib=work.formats;
  value $_cstextcodelist;
run;
data &ds9._fmt;
  retain type 'C';
  set &ds9(rename=(oid=start) where=(source='EXT'));
  fmtname = '_cstextcodelist';
  label = "ExternalDictionaries";
run;
proc format cntlin=&ds9._fmt;
run;
%if &_cstThisDeBug eq 0 %then %do;
  %cstutil_deleteDataSet(_cstDataSetName=&ds9._fmt);
%end;

%******************************************************************************;
%* Computational Methods                                                      *;
%******************************************************************************;

%let _cstComputationalMethods=1;
%if ^%sysfunc(exist(&_cstSourceLib..valuelists)) or
    ^%sysfunc(exist(&_cstSourceLib..itemvaluelistrefs)) or
    ^%sysfunc(exist(&_cstSourceLib..valuelistitemrefs))
  %then %do;
    %let _cstComputationalMethods=0;
    %put Note: No Computational Methods;
    %goto no_computationalmethods;
  %end;

data &ds10;
  set &_cstSourceLib..computationmethods;
  %* introduce count variable to get rid of 'Table 1' bookmarks *;
  %* see: http://support.sas.com/kb/31/278.html                 *;
  count=1;
run;

%no_computationalmethods:


%******************************************************************************;
%* Generate Report                                                            *;
%******************************************************************************;

ods listing close;
ods escapechar = '^';

%* Changed to using proc document;
/*
%if &_cstLinks eq Y %then %do;
ods pdf file="&_cstReportOutput" &_cstODSoptions
        title="&_cstReportTitle"
        author="&_cstReportAuthor"
        keywords="&_cstReportKeywords"
        %if %length(&_cstReportStyle) %then style=&_cstReportStyle;
        ;
%end;
*/
ods document name=work.prddoc(write);

%******************************************************************************;
%* Create output object with report.                                          *;
%* We are using ods document to be able to manipulate the bookmarks.          *;
%******************************************************************************;

%******************************************************************************;
%* Print first page                                                           *;
%******************************************************************************;
%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="TOP";
   %end; */

ods proclabel = "[\][-][TOP]Metadata for &_cstStudy" ;
proc report data=&ds1 split='@' nowd headline contents=""
  style(report)={font_size=10pt rules=none frame=void}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "Metadata for &_cstStudy";
  column count Vartype VarName VarLabel href VarValue;
  define count / order noprint;
  define VarType  / order order=data "" style=[cellwidth=2in] noprint;
  define VarName  / display          "" style=[cellwidth=1.2in] noprint;
  define VarLabel / display          "" style=[cellwidth=3.2in font_weight=bold] ;
  define href     / display          "" noprint;
  define VarValue / display          "" style=[cellwidth=4in]   ;
  break before count / contents="" page;
  compute after VarType;
   line " ";
  endcomp;

  %if %upcase(&_cstLinks) eq Y %then %do;
    compute VarValue;
      length urlstring $400;
      if not missing(href) then do;
         urlstring=left(href);
         call define('_c6_','url', urlstring);
         call define(_col_,'style',"style=[&linkstyle]");
      end;
    endcomp;
  %end;
run;


%******************************************************************************;
%* Print data set list                                                        *;
%******************************************************************************;
%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="DSLIST";
   %end; */
ods proclabel = "[\][-][DSLIST]&_cstIG_label1 for &_cstStudy" ;
proc report data=&ds3 SPLIT='@' nowd headline contents=''
  style(report)={font_size=10pt cellpadding=4pt cellspacing=.3pt /* rules=none frame=void */}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "&_cstIG_label1 for &_cstStudy";
  column count oid name label class structure purpose DomainKeys href title;
  define count / order ""  noprint;
  define oid        / display  noprint;
  define name       / display  "Dataset"     style=[cellwidth=1.0in];
  define label      / display  "Description" style=[cellwidth=1.6in];
  define class      / display  "Class"       style=[cellwidth=1.0in];
  define structure  / display  "Structure"   style=[cellwidth=1.5in];
  define purpose    / display  "Purpose"     style=[cellwidth=0.8in];
  define domainkeys / display  "Keys"        style=[cellwidth=1.4in];
  define href       / noprint;
  define title      / display  "Location"    style=[cellwidth=1.5in];

  break before count / contents="" page;

%if %upcase(&_cstLinks) eq Y %then %do;
  compute label;
    length urlstring $400;
    if not missing(label) then do;
       urlstring="#IG."||left(oid);
       urlstring=kcompress(urlstring, ' ()<>[]{}/%&\');
       call define('_c4_','url', urlstring);
       call define(_col_,'style',"style=[&LinkStyle]");
    end;
  endcomp;

  compute title;
    length urlstring textvar $400;
    if not missing(href) then do;
        if missing(title) then textvar=href;
                          else textvar=trim(title)||', '||trim(href);
      urlstring=left(href);
      call define('_c10_','url', urlstring);
      call define(_col_,'style',"style=[&linkstyle]");
    end;
    else textvar=title;
    title=textvar;
  endcomp;
%end;
%else %do;
  compute title;
    length textvar $400;
    if not missing(href) then do;
      if missing(title) then textvar=href;
                        else textvar=trim(title)||', '||trim(href);
    end;
    else textvar=title;
    title=textvar;
  endcomp;
%end;

run;

%******************************************************************************;
%* Print separate Domains                                                     *;
%******************************************************************************;
%macro ReportDomain(GroupDef_OID, GroupDef_Name, GroupDef_Label);

%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="IG.&GroupDef_OID";
   %end; */
ods proclabel = "[IG][&GroupDef_Name][IG.&GroupDef_OID]&GroupDef_Label" ;
proc report data=&ds4 split='@' nowd headline  contents=''
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "&GroupDef_Label (&GroupDef_Name)";
  column count Name tmplink Ordernumber ValueListOID id_name id_label
         KeySequence id_DataType length
         DisplayFormat CodeListRef cl_name Origin
         Role Comment Method comment_method;
  define count / order noprint;
  define Name           / order noprint;
  define tmplink        / order format=$400. noprint;
  define Ordernumber    / order noprint;
  define ValueListOID   / noprint;
  define id_name        / order order=data "Variable" STYLE=[CELLWIDTH=1.1in];
  define id_label       / display "Label"    STYLE=[CELLWIDTH=1.1in];
  define KeySequence    / display "Key"     STYLE=[CELLWIDTH=0.5in] noprint;
  define id_datatype    / display "Type"     STYLE=[CELLWIDTH=0.6in];
  define length         / display "length"   STYLE=[CELLWIDTH=0.7in] noprint;
  define DisplayFormat  / display "Display Format"  STYLE=[CELLWIDTH=1.0in] &_cstNoprintSDS;
  define CodeListRef    / display "" style=[CELLWIDTH=1in] noprint;
  define cl_name        / display "Controlled Terms or Format" style=[CELLWIDTH=0.9in];
  define Origin         / display "Origin"  FLOW STYLE=[CELLWIDTH=1.0in] &_cstNoprintADaM;
  define Role           / display "Role"    FLOW STYLE=[CELLWIDTH=0.9in] &_cstNoprintADaM;
  define comment        / display "Comment" noprint;
  define method         / display "Derivation" noprint;
  define comment_method / display "Comments / Derivations" STYLE=[CELLWIDTH=&_cstID_width1];

  break before count / contents="" page;

  compute before _page_ / style={just=left};
    line tmplink $400.;
  endcomp;

  %if %upcase(&_cstLinks) eq Y %then %do;
    compute id_name;
      length urlstring $200;
      if not missing(ValueListOID) then do;
         urlstring="#VL."||left(ValueListOID);
         urlstring=kcompress(urlstring, ' ()<>[]{}/%&\');
         call define('_c6_','url', urlstring);
         call define(_col_,'style',"style=[&LinkStyle]");
      end;
    endcomp;
  %end;

  compute cl_name / character;
    length urlstring $200;
    urlstring="#CL."||left(put(CodeListRef, $_cstextcodelist.));
    urlstring=kcompress(urlstring, ' ()<>[]{}/%&\');
    if not missing (CodeListRef) then do;
    %if %upcase(&_cstLinks) eq Y %then %do;
      call define('_c13_','url', urlstring);
      call define(_col_,'style',"style=[&LinkStyle]");
    %end;
    end;
    else do;
      if reverse(strip(id_name))=: 'RUD' or
         id_datatype = 'date' or
         id_datatype = 'time' or
         id_datatype = 'datetime' then do;
          cl_name = 'ISO8601';
      end;
    end;
  endcomp;

/*
%if %upcase(&_cstLinks) eq Y %then %do;
  compute method;
    length urlstring $200;
    if not missing (Method) then do;
      urlstring="#CM.ComputationalAlgorithms";
      call define('_c17_','url', urlstring);
      call define(_col_,'style',"style=[&LinkStyle]");
    end;
  endcomp;
%end;
*/

where OID="&GroupDef_OID";

run;

%mend ReportDomain;

data _null_;
 set  &ds2;
 call execute ('%bquote(%ReportDomain(' || strip(OID)   || "," ||
                                           strip(Name)  || "," ||
                                           strip(label) ||
                                         "));" );
RUN;

%******************************************************************************;
%* Print value lists                                                          *;
%******************************************************************************;

%macro ReportValueList(VL_Order, ValueList_OID);

%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="VL.&ValueList_OID";
   %end; */
ods proclabel = "[VL][:][VL.&ValueList_OID]&ValueList_OID" ;

proc report data=&ds7 split='@' nowd headline  contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "&_cstVL_label2 - &_cstVL_label3 &ValueList_OID";
  column count valuelistoid name ValueListoid2 id_name id_label id_datatype
         DisplayFormat codelistref cl_name origin comment method comment_method;

  define count / order noprint;
  define valuelistoid /  noprint;
  define name / "Source Variable" STYLE=[CELLWIDTH=1.1in];
  define valuelistoid2 / noprint;
  define id_name / "&_cstVL_label4" STYLE=[CELLWIDTH=1.1in];
  define id_label / "&_cstVL_label5" STYLE=[CELLWIDTH=1.1in];
  define id_datatype / "Type" STYLE=[CELLWIDTH=0.6in];
  define DisplayFormat  / display "Display Format"  STYLE=[CELLWIDTH=1.0in] &_cstNoprintSDS;
  define codelistref    / display "" style=[cellwidth=1in] noprint;
  define cl_name / "Controlled Terms or Format" style=[CELLWIDTH=0.9in];
  define origin / "Origin" STYLE=[CELLWIDTH=0.9in] &_cstNoprintADaM;
  define comment / "Comment" STYLE=[CELLWIDTH=1.9in] noprint;
  define method / "Derivation" STYLE=[CELLWIDTH=1.0in] noprint;
  define comment_method / "Comments / Derivations" STYLE=[CELLWIDTH=3in];

  break before count / contents="" page;

  compute before _page_ / style={just=left};
    line valuelistoid $400.;
  endcomp;

  %if %upcase(&_cstLinks) eq Y %then %do;
    compute id_name;
      length urlstring $200;
      if not missing(valuelistoid2) then do;
         urlstring="#VL."||left(valuelistoid2);
         urlstring=kcompress(urlstring, ' ()<>[]{}/%&\');
         call define('_c5_','url', urlstring);
         call define(_col_,'style',"style=[&LinkStyle]");
      end;
    endcomp;
  %end;

  compute cl_name / character;
    length urlstring $200;
    urlstring="#CL."||left(put(CodeListRef, $_cstextcodelist.));
    urlstring=kcompress(urlstring, ' ()<>[]{}/%&\');
    if not missing (CodeListRef) then do;
    %if %upcase(&_cstLinks) eq Y %then %do;
      call define('_c10_','url', urlstring);
      call define(_col_,'style',"style=[&LinkStyle]");
    %end;
    end;
    else do;
      if reverse(strip(id_name))=: 'RUD' or
         id_datatype = 'date' or
         id_datatype = 'time' or
         id_datatype = 'datetime' then do;
          cl_name = 'ISO8601';
      end;
    end;
  endcomp;

/*
%if %upcase(&_cstLinks) eq Y %then %do;
  compute method;
    length urlstring $200;
    if not missing (method) then do;
      urlstring="#CM.ComputationalAlgorithms";
      call define('_c12_','url', urlstring);
      call define(_col_,'style',"style=[&LinkStyle]");
    END;
  ENDCOMP;
%end;
*/

where vl_order=&VL_Order;

run;
%mend ReportValueList;

%if &_cstValueLists=1 %then %do;
  data _null_;
   set &ds7;
   by vl_order valuelistoid fk_itemdefs ordernumber;
   if first.vl_order then do;
     call execute ('%bquote(%ReportValueList(' || strip(put(vl_order, best.))   || "," ||
                                                  strip(valuelistoid) ||
                                             "));" );
   end;
  run;
%end;

%******************************************************************************;
%* Print Controlled Terminology (Code Lists)                                  *;
%******************************************************************************;

%MACRO ReportCodeList(CL_Order, CodeList_OID, CodeList_Name);

%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="CL.&CodeList_OID";
   %end; */
ods proclabel = "[CL][&CodeList_Name][CL.&CodeList_OID]&CodeList_OID" ;

proc report data=&ds9 split='@' nowd headline  contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "Controlled Terminology (Code Lists) - &CodeList_OID";
  column count tmptext name oid codedvalue translatedtext;
  define count / order noprint;
  define tmptext / format=$400. noprint;
  define name / noprint;
  define oid / noprint;
  define codedvalue / "Coded Value" style=[cellwidth=4in];
  define translatedtext / "Decode" style=[cellwidth=4in];

  compute before _page_ / style={just=left};
    line tmptext $400.;
  endcomp;

  break before count / contents="" page;

  where cl_order=&CL_Order;

run;
%mend ReportCodeList;

data _null_;
  set &ds9(where=(source='CLI'));
  by cl_order rank codedvalue;
  if first.cl_order then do;
    call execute
         ('%bquote(%ReportCodeList('||strip(put(cl_order, best.))||","||strip(oid)||","||strip(name)||"));" );
  end;
run;


%******************************************************************************;
%* Print Controlled Terminology (External Dictionaries)                       *;
%******************************************************************************;
%MACRO ReportCodeListExt(CL_Order, CodeList_OID, CodeList_Name);

%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="DT.&CodeList_OID";
   %end; */
ods proclabel = "[DT][&CodeList_Name][DT.&CodeList_OID]&CodeList_OID" ;

proc report data=&ds9 split='@' nowd headline contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "Controlled Terminology (External Dictionaries) - &CodeList_OID";
  column count tmptext name oid dictionary version;
  define count / order noprint;
  define tmptext / format=$400. noprint;
  define name / noprint;
  define oid / noprint;
  define dictionary    / "Dictionary" style=[cellwidth=3in];
  define version       / "Version" style=[cellwidth=5in];

  compute before _page_ / style={just=left};
    line tmptext $400.;
  endcomp;

  break before count / contents="" page;

  where cl_order=&CL_Order;

run;
%mend ReportCodeListExt;

ods proclabel = "[DT][ ][CL.ExternalDictionaries]External Dictionaries" ;
proc report data=&ds9(where=(source='EXT')) split='@' nowd headline contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "Controlled Terminology (External Dictionaries)";
  column count tmptext name oid dictionary version;
  define count / order noprint;
  define tmptext / format=$400. noprint;
  define name / "Name" style=[cellwidth=4in];
  define oid / "Reference Name" style=[cellwidth=1in];
  define dictionary    / "Dictionary" style=[cellwidth=2in];
  define version       / "Version" style=[cellwidth=1in];

  break before count / contents="" page;
run;


/*
data _null_;
  set &ds9(where=(source='EXT'));
  by cl_order rank codedvalue;
  if first.cl_order then do;
    call execute
         ('%bquote(%ReportCodeListExt('||strip(put(cl_order, best.))||","||strip(oid)||","||strip(name)||"));" );
  end;
run;
*/

%******************************************************************************;
%* Print Computational Methods                                                *;
%******************************************************************************;

%MACRO ReportMethods(Method_OID);

%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ODS pdf ANCHOR="CM.&Method_OID";
   %end; */
ods proclabel = "[CM][&Method_OID][CM.&Method_OID]&Method_OID" ;

proc report data=&ds10 split='@' nowd headline  contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "&_cstCM_Label.s";
  column count oid method;
  define count / order noprint;
  define oid    / "Reference Name" style=[cellwidth=2in];
  define method / "Computation Algorithm" style=[cellwidth=6in];

  break before count / contents="" page;

  where oid="&Method_OID";

run;
%mend ReportMethods;


ods proclabel = "[CM][ ][CM.ComputationalAlgorithms]&_cstCM_Label.s" ;

proc report data=&ds10 split='@' nowd headline  contents=""
  style(report)={font_size=10pt}
  style(header)={font_size=10pt}
  style(column)={font_size=&_cstFontSize}
  ;
  title01 j=r "&_cstPage1ofNstring";
  title02 j=l "&_cstCM_Label.s";
  column count oid method;
  define count / order noprint;
  define oid    / "Reference Name" style=[cellwidth=2in];
  define method / "&_cstCM_Label" style=[cellwidth=6in];

  break before count / contents="" page;
run;

/*
%if &_cstComputationalMethods=1 %then %do;
  data _null_;
    set &ds10;
      call execute ('%bquote(%ReportMethods('||strip(oid)||"));" );
  run;
%end;
*/

%******************************************************************************;
%* Proc document processing                                                   *;
%******************************************************************************;

ods document close;
%* Changed to using proc document;
/* %if %upcase(&_cstLinks) eq Y %then %do;
     ods pdf close;
   %end; */

ods output properties=&ds13;
proc document name=work.prddoc;
  list / levels=all details;
run;
quit;
ods output close;

proc format lib=work.formats;
  value $_fldr
    "IG"    = "Datasets"
    "VL"    = "&_cstVL_label1"
    "CM"    = "Algorithms"
    "CL"    = "CodeLists"
    "DT"    = "CodeListsExternal"
  ;
  value $_fldrn  %* bookmark label in case of no links ;
    "IG"    = "&_cstIG_label1"
    "VL"    = "&_cstVL_label2"
    "CM"    = "&_cstCM_Label.s"
    "CL"    = "Controlled Terms"
    "DT"    = "External Dictionaries"
  ;
  value $_fldrnl  %* bookmark label in case of links ;
    "IG"    = "&_cstIG_label1"
    "VL"    = "&_cstVL_label3"
    "CM"    = "&_cstCM_Label"
    "CL"    = "Controlled Term"
    "DT"    = "External Dictionaries"
  ;
run;

data &ds13;
length folder foldername anchor newlabel $200;
  set &ds13(where=(type='Dir')) end=end;
  if index(label , ']') then do;
    folder     = put(scan (label, 1, '[]'),$_fldr.);
    %if %upcase(&_cstLinks) eq Y %then %do;
       foldername = catx(" ", put(scan (label, 1, '[]'),$_fldrnl.), scan (label, 2, '[]'));
    %end;
    %else %do;
       foldername = put(scan (label, 1, '[]'),$_fldrn.);
    %end;
    anchor = scan (label, 3, '[]');
    anchor = kcompress(anchor, ' ()<>[]{}/%&\');
    if scan (label, 1, '[]')='IG'
      then newlabel   = catx(" ", scan (label, 4, '[]'), cats('(', scan (label, 2, '[]'), ')'));
      else newlabel   = scan (label, 4, '[]');
  end;
run;

filename &_cstNextCode CATALOG "work.&_cstNextCode..SAScode.source";
data &ds13;
  retain count 0;
set &ds13 end=enddoc;
  by folder notsorted;
  file &_cstNextCode;
  if _n_=1 then put "proc document name=prddoc2(write);";
  if first.folder then count=0;
  count+1;
  if folder='\' then do;
    put 'setlabel \work.prddoc' path +(-1) '\Report#1 "' newlabel +(-1) '";';
    put 'move     \work.prddoc' path +(-1) '\Report#1 to \;';
    put 'ods pdf anchor="' anchor +(-1) '";';
    put 'replay ' path ';';
    put 'run;' /;
  end;

  if first.folder and folder ne "\" then do;
    put 'dir ^^;' / 'make ' folder ';' / 'dir ^^;';
    put 'setlabel \' folder '"' folder +(-1) '";' / 'run;';
    put "dir \ " +(-1) folder ';' /;
  end;

  if folder ne '\' then do;
    put 'setlabel \' folder '"' foldername +(-1) '";';
    put 'setlabel \work.prddoc' path +(-1) '\Report#1 "' newlabel +(-1) '";';
    put 'copy     \work.prddoc' path +(-1) '\Report#1 to ^;';
    put 'ods pdf anchor="' anchor +(-1) '";';
%if %upcase(&_cstLinks) eq Y %then %do;
    put 'replay \' folder +(-1) '#1\Report#' count  +(-1) ';';
    put 'run;' /;
%end;
  end;

%if %upcase(&_cstLinks) ne Y %then %do;
  if last.folder and folder ne "\" then do;
    put 'replay \' folder +(-1) '#1;';
    put 'run;' /;
  end;
%end;

  if enddoc then put "quit;";
run;


%******************************************************************************;
%* Replay to PDF                                                              *;
%******************************************************************************;

ods pdf file="&_cstReportOutput" &_cstODSoptions
        title="&_cstReportTitle"
        author="&_cstReportAuthor"
        keywords="&_cstReportKeywords"
        %if &_cstTOC=Y %then contents=yes;
        %if %length(&_cstReportStyle) %then style=&_cstReportStyle;
        ;

%include &_cstNextCode;

ods pdf close;

ods listing;
title01;

  %* Everything was OK so  report it;
  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CRT0010
                ,_cstResultParm1=&_cstReportOutput
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcData
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );


%******************************************************************************;
%* End of macro                                                               *;
%******************************************************************************;
%exit_macro_cleanup:

%if &_cstThisDeBug eq 0 %then %do;

  %* Cleanup ;
  %do i=0 %to 13;
    %if (%sysfunc(exist(&&ds&i))) %then %do;
      proc datasets nolist lib=work;
        delete &&ds&i / memtype=data;
      quit;
      run;
    %end;
  %end;

  %if %sysfunc(cexist(work.formats._cstextcodelist.formatc)) %then %do;
    proc catalog cat=work.formats;
      delete _cstextcodelist.formatc;
    quit;
  %end;

  %if %sysfunc(cexist(work.formats._fldr.formatc)) %then %do;
    proc catalog cat=work.formats;
      delete _fldr.formatc;
    quit;
  %end;

  %if %sysfunc(cexist(work.formats._fldn.formatc)) %then %do;
    proc catalog cat=work.formats;
      delete _fldn.formatc;
    quit;
  %end;

  %if %sysfunc(cexist(work.formats._fldnl.formatc)) %then %do;
    proc catalog cat=work.formats;
      delete _fldnl.formatc;
    quit;
  %end;

  %if %sysfunc(cexist(work.&_cstNextCode)) %then %do;
    proc datasets nolist lib=work;
      delete &_cstNextCode / memtype=catalog;
    quit;
  %end;

%end;

%exit_macro:

%if %length(&&&_cstReturnMsg) ne 0 %then %do;
  %put ERR%str(OR)(&_cstSrcData): &&&_cstReturnMsg;


      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0202
                  ,_cstResultParm1=&&&_cstReturnMsg
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=&_cstActual
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );



%end;

  %cstutil_saveresults();
  %let &_cstReturn=&_cstThisMacroRC;

%exit_macro_nomsg:

%* Restore options;
%if %length(&_cstSaveOptions) ne 0 %then options &_cstSaveOptions;

%mend crtdds_writepdf;
