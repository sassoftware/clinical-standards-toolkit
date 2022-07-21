%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmutil_createsrcmetafromcrtdds                                               *;
%*                                                                                *;
%* Derives source metadata files from a CRT-DDS data library.                     *;
%*                                                                                *;
%* This sample utility macro derives source metadata files from a CRT-DDS data    *;
%* library that is derived from the define.xml file for a CDISC SDTM study.       *;
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
%*                                                                                *;
%* NOTE:  This is ONLY an attempted approximation of source metadata. No          *;
%*        assumptions should be made that the result accurately represents the    *;
%*        study data.                                                             *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. The source data is read from a single SAS library. You can modify the    *;
%*       code to reference multiple libraries by using library concatenation.     *;
%*    2. Only one study reference can be specified. Multiple study references     *;
%*       require modification of the code.                                        *;
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
%* @macvar _cstTrgMetaLibrary Target library for CRT-DDS source data              *;
%* @macvar _cstCRTDataLib CRT-DDS source data library                             *;
%* @macvar _cstReflib SDTM reference library                                      *;
%* @macvar _cstRefTableDS SDTM reference table data set                           *;
%* @macvar _cstRefColumnDS SDTM reference column data set                         *;
%* @macvar _cstSDTMDataLib SDTM metadata library                                  *;
%* @macvar _cstTrgStudyDS Target source study metadata data set                   *;
%* @macvar _cstTrgDocumentDS Target source documents metadata data set            *;
%* @macvar _cstTrgTableDS Target source table metadata data set                   *;
%* @macvar _cstTrgColumnDS Target source column metadata data set                 *;
%* @macvar _cstTrgValueDS Target source value metadata data set                   *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro sdtmutil_createsrcmetafromcrtdds(
    ) / des='CST: Create SDTM metadata from CRTDDS Data';

  %local
    _cstErrorFlag
    _cstNextCode
    _cstRandom
    _cstrundt
    _cstTempDS1
    _cstTempDS2
    _cstTempDS3
    _cstTempDS4
    _cstTempDS5
    _cstCounter
    _cstList
    _cstListItem
    _cstCreateValueMetadata
    _cstCreateDocumentMetadata
    ;


  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;

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

  %let _cstErrorFlag=0;

  %*************************************************************;
  %*  Check for existence of required libraries and data sets  *;
  %*************************************************************;

  %if ^%symexist(_cstTrgMetaLibrary) %then
    %cstutil_getsasreference(_cstSASRefType=targetmetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstTrgMetaLibrary,
                             _cstSASRefmember=_cstTrgTableDS);

  %if "&_cstTrgMetaLibrary"="" %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): Location for output data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for output data sets required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %let _cstErrorFlag=1;
  %end;

  %if ^%symexist(_cstCRTDataLib) %then
    %cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstCRTDataLib);

  %if "&_cstCRTDataLib"="" %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): Location for CRTDDS input data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for CRTDDS input data sets required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %let _cstErrorFlag=1;
  %end;

  %if ^%symexist(_cstReflib) %then
    %cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstRefLib,
                             _cstSASRefmember=_cstRefTableDS);

  %if "&_cstReflib" ="" %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): REFERENCE libname not provided.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=REFERENCE libname not provided,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %let _cstErrorFlag=1;
  %end;

  %***************************************************************;
  %*  Set Error Flag to check existence of required CRTDDS Data  *;
  %***************************************************************;

  %if not %sysfunc(exist(&_cstRefLib..&_cstRefTableDS)) %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): The &_cstRefLib..&_cstRefTableDS data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstRefLib..&_cstRefTableDS data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %let _cstErrorFlag=1;
  %end;

  %if not %sysfunc(exist(&_cstRefLib..&_cstRefColumnDS)) %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): The &_cstRefLib..&_cstRefColumnDS data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstRefLib..&_cstRefColumnDS data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %let _cstErrorFlag=1;
  %end;


  %*******************************************************************;
  %*  Set Error Flag to check existence of required CRTDDS Data Sets *;
  %*******************************************************************;
  %let _cstList=&_cstCRTDataLib..computationmethods|%str
              ()&_cstCRTDataLib..codelists|%str
              ()&_cstCRTDataLib..itemgroupdefs|%str
              ()&_cstCRTDataLib..itemgroupleaf|%str
              ()&_cstCRTDataLib..itemgroupleaftitles|%str
              ()&_cstCRTDataLib..itemdefs|%str
              ()&_cstCRTDataLib..itemgroupdefitemrefs|%str
              ()&_cstCRTDataLib..metadataversion|%str
              ()&_cstCRTDataLib..study|%str
              ()&_cstCRTDataLib..definedocument
                ;
  %let _cstCounter=1;
  %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));
  %do %while (%length(&_cstListItem));

    %if not %sysfunc(exist(&_cstListItem)) %then
    %do;
      %put [CSTLOG%str(MESSAGE)] ERR%STR(OR): The &_cstListItem data set does not exist.;
      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstListItem data set does not exist.,
          _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
      %end;
      %let _cstErrorFlag=1;
    %end;

    %let _cstCounter = %eval(&_cstCounter + 1);
    %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));

  %end;

  %********************************;
  %*  Error found exit the macro  *;
  %********************************;

  %if &_cstErrorFlag=1 %then %goto exit_macro;

  %***************************;
  %*  Create TABLE metadata  *;
  %***************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS2=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS3=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS4=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS5=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %************************************************************************;
  %*  Create reference_tables template data set to obtain table metadata  *;
  %*  The CRTDDS data does not contain the original reference metadata.   *;
  %************************************************************************;
  data work.&_cstTempDS1;
    set &_cstRefLib..&_cstRefTableDS;
    if _n_=0;
    stop;
  run;

  %*********************************************;
  %*  Create list of reference_tables domains  *;
  %*********************************************;
  proc contents data=work.&_cstTempDS1 out=work.&_cstTempDS2(keep=name) noprint;
  run;
  %***************************************************************;
  %*  Assign a filename for the code that will be generated      *;
  %*  Generate code to compare incoming lengths of data against  *;
  %*  the defined standard.                                      *;
  %***************************************************************;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source" &_cstLRECL;

  data _null_;
    set work.&_cstTempDS2 end=eof;
    length line1-line5 $128 drop $255;
    retain drop;
    if _n_=1 then drop="drop";
    file &_cstNextCode;
    name=lowcase(name);
    line1="if length("||strip(left(name))||"1) gt lengthm("||strip(left(name))||") then";
    line2="do;";
    line3='put "Length of variable '||strip(left(upcase(name)))||' is too long.";';
    line4="end;";
    line5="else "||strip(left(name))||"="||strip(left(name))||"1;";
    put;
    put line1;
    put line2;
    put @2 line3;
    put line4;
    put line5;
    drop=strip(drop)||" "||strip(left(name))||"1";
    if eof then
    do;
      drop=strip(drop)||";";
      put;
      put drop;
    end;
  run;

  %***************************************************************************;
  %*  Read data from the appropriate CRTDDS tables to create as much of the  *;
  %*  reference_tables data set as possible given the data is incomplete.    *;
  %***************************************************************************;
  proc sql noprint;
    create table work.&_cstTempDS3 (drop=oid fk_itemgroupdefs) as
    select ds14.*, ds23.* from
      (select ds1.oid,
              upcase("&_cstSDTMDataLib") as sasref1,
              case
                when not missing (ds1.Domain) then ds1.Domain
                else ds1.Name
              end as table1 'Table Name',
              label as label1 'Table Label',
              class as class1 'Observation Class within Standard',
              structure as structure1 'Table Structure',
              purpose as purpose1 'Purpose',
              compbl(translate(domainkeys," ",",")) as keys1 'Table Keys',
              %* We are not using ds4.standardname and ds4.standardnameversion since these are the formal names;
              "&_cstStandard" as standard1 'Name of Standard',
              "&_cstStandardVersion" as standardversion1 'Version of Standard',
              comment as comment1 'Comment',
              ds6.creationdatetime as date1
      from &_cstCRTDataLib..itemgroupdefs ds1,
           &_cstCRTDataLib..metadataversion ds4,
           &_cstCRTDataLib..study ds5,
           &_cstCRTDataLib..definedocument ds6

      where ds1.fk_metadataversion=ds4.oid and
            ds4.fk_study=ds5.oid and
            ds5.fk_definedocument=ds6.fileoid) ds14
    left join
      (select ds2.fk_itemgroupdefs,
              href as xmlpath1 '(Relative) path to xpt file',
              title as xmltitle1 'Title for xpt file'
       from &_cstCRTDataLib..itemgroupleaf ds2,
            &_cstCRTDataLib..itemgroupleaftitles ds3
       where ds2.id=ds3.fk_itemgroupleaf) ds23
    on ds14.oid=ds23.fk_itemgroupdefs
    order by table1;
  quit;
  %*********************************************************************;
  %*  Add missing metadata columns with the proper lengths and labels  *;
  %*********************************************************************;
  data work.&_cstTempDS4;
    length table $32 state1 standardref1 $200;
    label table='Table Name'
      state1='Data Set State (Final, Draft)'
      standardref1='Associated reference(s) in Standard';
    set work.&_cstTempDS3;
    table=substr(left(table1),1,32);
    state1='';
    standardref1='';
    %* date is ISO datetime, but we only need the date;
    if index(date1, 'T') then date1=scan(date1, 1, 'T');
    if missing(date1) then date1=put(today(), E8601DA.);
  run;

  proc sort data=work.&_cstTempDS4;
    by table;
  run;

  %*****************************************************;
  %*  Create first pass of the Source_Tables data set  *;
  %*****************************************************;
  data &_cstTrgMetaLibrary..&_cstTrgTableDS;
    merge work.&_cstTempDS1(in=ina) work.&_cstTempDS4(in=inb);
    by table;
    if inb;
    *  Process generated code  *;
    %include &_cstNextCode;
  run;

  proc sort data=&_cstTrgMetaLibrary..&_cstTrgTableDS (drop=state standardref);
    by table;
  run;

  proc sort data=&_cstRefLib..&_cstRefTableDS out=work.&_cstTempDS5(keep=table state standardref);
    by table;
  run;

  %*****************************************************;
  %*  Create FINAL pass of the Source_Tables data set  *;
  %*  Merge against the specified reference_tables to  *;
  %*  retrieve missing column information. Set date to *;
  %*  TODAY                                            *;
  %*****************************************************;
  data &_cstTrgMetaLibrary..&_cstTrgTableDS(label="Source Table Metadata");
    merge &_cstTrgMetaLibrary..&_cstTrgTableDS(in=ina) work.&_cstTempDS5(in=inb);
    by table;
    if ina;
  run;

  proc sort data=&_cstTrgMetaLibrary..&_cstTrgTableDS  out=&_cstTrgMetaLibrary..&_cstTrgTableDS(label="Source Table Metadata");
    by sasref table;
  run;

  %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgTableDS created.;
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

  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  * Clear the filename;
  filename &_cstNextCode;

  proc datasets lib=work nolist;
    delete &_cstTempDS1/memtype=data;
    delete &_cstTempDS2/memtype=data;
    delete &_cstTempDS3/memtype=data;
    delete &_cstTempDS4/memtype=data;
    delete &_cstTempDS5/memtype=data;
    delete &_cstNextCode/memtype=catalog;
  quit;

  %****************************;
  %*  Create COLUMN metadata  *;
  %****************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS2=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS3=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS4=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS5=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %**************************************************************************;
  %*  Create reference_columns template data set to obtain column metadata  *;
  %*  The CRTDDS data does not contain the original reference metadata.     *;
  %**************************************************************************;
  data work.&_cstTempDS1;
    set &_cstRefLib..&_cstRefColumnDS;
    if _n_=0;
    stop;
  run;

  %**************************************************;
  %*  Create list of columns from reference_column  *;
  %**************************************************;
  proc contents data=work.&_cstTempDS1 out=work.&_cstTempDS2(keep=name)noprint;
  run;

  %***************************************************************;
  %*  Assign a filename for the code that will be generated      *;
  %*  Generate code to compare incoming lengths of data against  *;
  %*  the defined standard.                                      *;
  %***************************************************************;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source" &_cstLRECL;

  data _null_;
    set work.&_cstTempDS2 end=eof;
    length line1-line5 $128 drop $255;
    retain drop;
    if _n_=1 then drop="drop";
    file &_cstNextCode;
    name=lowcase(name);
    line1="if length("||strip(left(name))||"1) gt lengthm("||strip(left(name))||") then";
    line2="do;";
    line3='put "Length of variable '||strip(left(upcase(name)))||' is too long.";';
    line4="end;";
    line5="else "||strip(left(name))||"="||strip(left(name))||"1;";
    put;
    put line1;
    put line2;
    put @2 line3;
    put line4;
    put line5;
    drop=strip(drop)||" "||strip(left(name))||"1";
    if eof then
    do;
      drop=strip(drop)||";";
      put;
      put drop;
    end;
  run;

  %***************************************************************************;
  %*  Read data from the appropriate CRTDDS tables to create as much of the  *;
  %*  reference_columns data set as possible given the data is incomplete.   *;
  %***************************************************************************;
  proc sql noprint;
    create table work.&_cstTempDS3 as select
      upcase("&_cstSDTMDataLib") as sasref1,
      case
        when not missing (ds4.Domain) then ds4.Domain
        else ds4.Name
      end as table1 'Table Name',
      ds1.name as column1 'Column Name',
      ds1.label as label1 'Column Description',
      ordernumber as order1 'Column Order',
      case when upcase(datatype) in ("INTEGER","FLOAT")
        then 'N'
        else 'C'
      end as type1 'Column Type',
      length as length1 'Column Length',
      displayformat as displayformat1 'Display Format',
      datatype as xmldatatype1 'XML Data Type',
      codelistref,
      ds1.origin as origin1 'Column Origin',
      ds2.role as role1 'Column Role',
      %* We are not using ds3.standardname and ds3.standardnameversion since these are the formal names;
      "&_cstStandard" as standard1 'Name of Standard',
      "&_cstStandardVersion" as standardversion1 'Version of Standard',
      ds1.comment as comment1 'Comment',
      ds5.method as algorithm1 'Computational Algorithm or Method'
    from &_cstCRTDataLib..itemdefs ds1,
      &_cstCRTDataLib..itemgroupdefitemrefs ds2,
      &_cstCRTDataLib..metadataversion ds3,
      &_cstCRTDataLib..itemgroupdefs ds4,
      (select method, dsid.oid
         from &_cstCRTDataLib..itemdefs dsid left join &_cstCRTDataLib..computationmethods dscm
         on dsid.computationmethodoid=dscm.oid) as ds5
    where (ds1.oid=ds2.itemoid and ds1.fk_metadataversion=ds3.oid and ds2.fk_itemgroupdefs=ds4.oid and ds5.oid=ds2.itemoid)
    order by domain;
  quit;

  proc sql;
    create table work.&_cstTempDS4(drop=codelistref) as
    select ds1.*,
      ds2.name as xmlcodelist1 'SAS Format/XML Codelist'
      from work.&_cstTempDS3 ds1 left join &_cstCRTDataLib..codelists ds2
    on ds1.codelistref = ds2.oid
    ;
  quit;

  %*********************************************************************;
  %*  Add missing metadata columns with the proper lengths and labels  *;
  %*********************************************************************;
  data work.&_cstTempDS5;
    length table $32 standardref1 qualifiers1 $200 core1 $10 term1 $80;
    label table='Table Name'
      core1='Column Required or Optional'
      term1='Controlled Term or Format in Standard'
      qualifiers1='Column qualifiers (space delimited)'
      standardref1='Associated reference(s) in Standard';
    set work.&_cstTempDS4;
    table=substr(left(table1),1,32);
    core1='';
    term1='';
    standardref1='';
    qualifiers1='';
  run;

  proc sort data=work.&_cstTempDS5;
    by table;
  run;

  %******************************************************;
  %*  Create first pass of the Source_Columns data set  *;
  %******************************************************;
  data &_cstTrgMetaLibrary..&_cstTrgColumnDS;
    merge work.&_cstTempDS1(in=ina) work.&_cstTempDS5(in=inb);
    by table;
    if inb;
    *  Process generated code  *;
    %include &_cstNextCode;
  run;

  proc sort data=&_cstTrgMetaLibrary..&_cstTrgColumnDS (drop=core term qualifiers standardref);
    by table column;
  run;

  proc sort data=&_cstRefLib..&_cstRefColumnDS out=work.&_cstTempDS5(keep=table column core term qualifiers standardref length rename=(length=length1));
    by table column;
  run;

  %******************************************************;
  %*  Create FINAL pass of the Source_Columns data set  *;
  %*  Merge against the specified reference_tables to   *;
  %*  retrieve missing column information.              *;
  %******************************************************;

  data &_cstTrgMetaLibrary..&_cstTrgColumnDS(label="Source Column Metadata" drop=length1);
    merge &_cstTrgMetaLibrary..&_cstTrgColumnDS(in=ina) work.&_cstTempDS5(in=inb);
    by table column;
    if ina;
    if missing(length) then length=length1;
  run;

  proc sort data=&_cstTrgMetaLibrary..&_cstTrgColumnDS out=&_cstTrgMetaLibrary..&_cstTrgColumnDS(label="Source Column Metadata");
    by sasref table order;
  run;

  %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgColumnDS created.;
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
  %end;

  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  * Clear the filename;
  filename &_cstNextCode;

  proc datasets lib=work nolist;
    delete &_cstTempDS1/memtype=data;
    delete &_cstTempDS2/memtype=data;
    delete &_cstTempDS3/memtype=data;
    delete &_cstTempDS4/memtype=data;
    delete &_cstTempDS5/memtype=data;
    delete &_cstNextCode/memtype=catalog;
  quit;

  %****************************;
  %*  Create STUDY metadata  *;
  %****************************;

  %cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                            _cstType=sourcemetadata,_cstSubType=study,
                            _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgStudyDS);

  proc sql;
    insert into &_cstTrgMetaLibrary..&_cstTrgStudyDS
    select
      upcase("&_cstSDTMDataLib") as sasref 'SAS metadata libref',
      ds2.fileoid as definedocumentname 'Unique study ID',
      ds1.studyname as StudyName 'Study name',
      ds1.studydescription as StudyDescription 'Description of the study',
      ds1.protocolname as ProtocolName 'Protocol name',
      "&_cstStandard" as Standard 'Name of Standard',
      "&_cstStandardVersion" as StandardVersion 'Version of Standard',
      ds3.StandardName as FormalStandardName 'Formal Name of Standard',
      ds3.StandardVersion as FormalStandardVersion 'Formal Version of Standard'
    from
      &_cstCRTDataLib..study ds1,
      &_cstCRTDataLib..definedocument ds2,
      &_cstCRTDataLib..metadataversion ds3
    where (ds1.fk_definedocument=ds2.fileoid) and
          (ds3.fk_study=ds1.oid) ;
  quit;

  proc sort data=&_cstTrgMetaLibrary..&_cstTrgStudyDS
            out=&_cstTrgMetaLibrary..&_cstTrgStudyDS (label="Source Study Metadata");
    by sasref studyname;
  run;

  %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgStudyDS created.;
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

  %****************************;
  %*  Create VALUE metadata   *;
  %****************************;

  %let _cstCreateValueMetadata=1;

  /* These data sets are needed for VALUE metadata */
  %let _cstList=&_cstCRTDataLib..valuelists|&_cstCRTDataLib..valuelistitemrefs|&_cstCRTDataLib..itemvaluelistrefs%str()
                ;
  %let _cstCounter=1;
  %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));
  %do %while (%length(&_cstListItem));

    %if not %sysfunc(exist(&_cstListItem)) %then
    %do;
      %put [CSTLOG%str(MESSAGE)] WAR%STR(NING): The &_cstListItem data set does not exist.;
      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=The &_cstListItem data set does not exist.,
          _cstResultFlagParm=0, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
      %end;
      %let _cstCreateValueMetadata=0;
    %end;

    %let _cstCounter = %eval(&_cstCounter + 1);
    %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));

  %end;

  %if &_cstCreateValueMetadata %then %do;

    %cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                              _cstType=sourcemetadata,_cstSubType=value,
                              _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgValueDS);

    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS1=_cst&_cstRandom;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS2=_cst&_cstRandom;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS3=_cst&_cstRandom;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS4=_cst&_cstRandom;

    proc sql noprint;
      create table work.&_cstTempDS1 as
      select
        ds4.oid as vloid,
        ds1.name as value 'Value',
        ds1.label as label 'Column Description',
        ordernumber as order 'Column Order',
        case when upcase(datatype)='TEXT'
          then 'C'
          else 'N'
        end as type 'Column Type',
        length as length 'Column Length',
        displayformat as displayformat 'Display Format',
        datatype as xmldatatype 'XML Data Type',
        codelistref,
        ds1.origin as origin 'Column Origin',
        ds2.role as role 'Column Role',
        ds1.comment as comment 'Comment',
        ds5.method as algorithm 'Computational Algorithm or Method'
      from
        &_cstCRTDataLib..itemdefs ds1,
        &_cstCRTDataLib..valuelistitemrefs ds2,
        &_cstCRTDataLib..metadataversion ds3,
        &_cstCRTDataLib..valuelists ds4,
        (select method, dsid.oid
           from &_cstCRTDataLib..itemdefs dsid left join &_cstCRTDataLib..computationmethods dscm
           on dsid.computationmethodoid=dscm.oid) as ds5
      where (ds1.oid=ds2.itemoid and
             ds1.fk_metadataversion=ds3.oid and
             ds2.fk_valuelists=ds4.oid and
             ds5.oid=ds2.itemoid)
      ;
      create table work.&_cstTempDS2 as
      select
        case
          when not missing (ds1.Domain) then ds1.Domain
          else ds1.Name
        end as table,
        ds3.name as column,
        ds5.oid
      from
        &_cstCRTDataLib..itemgroupdefs ds1,
        &_cstCRTDataLib..itemgroupdefitemrefs ds2,
        &_cstCRTDataLib..itemdefs ds3,
        &_cstCRTDataLib..itemvaluelistrefs ds4,
        &_cstCRTDataLib..valuelists ds5
      where ds5.oid=ds4.valuelistoid and
            ds4.fk_itemdefs=ds3.oid and
            ds3.oid=ds2.itemoid and
            ds2.fk_itemgroupdefs=ds1.oid
      ;
      create table work.&_cstTempDS3 as
      select
        ds1.*, ds2.table, ds2.column
      from work.&_cstTempDS1 ds1 left join work.&_cstTempDS2 ds2
        on (ds1.vloid = ds2.oid);
      create table work.&_cstTempDS4(drop=codelistref) as
      select ds1.*,
        ds2.name as xmlcodelist 'SAS Format/XML Codelist'
      from work.&_cstTempDS3 ds1 left join &_cstCRTDataLib..codelists ds2
        on ds1.codelistref = ds2.oid
      order by table, column, value
      ;
    quit;

    options varlenchk=nowarn;

    data &_cstTrgMetaLibrary..&_cstTrgValueDS(drop=vloid label="Source Value Metadata");
      set &_cstTrgMetaLibrary..&_cstTrgValueDS work.&_cstTempDS4;
      sasref=upcase("&_cstSDTMDataLib");
      standard="&_cstStandard";
      standardversion="&_cstStandardVersion";
    run;

    proc sort data=&_cstTrgMetaLibrary..&_cstTrgValueDS(label="Source Value Metadata");
      by sasref table column order;
    run;

    %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgValueDS created.;
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

  %end;
  %else %put [CSTLOG%str(MESSAGE)] WARN%STR(ING): &_cstTrgMetaLibrary..&_cstTrgValueDS not created.;

    %*****************************;
    %*  Cleanup temporary files  *;
    %*****************************;
    proc datasets lib=work nolist;
      delete &_cstTempDS1/memtype=data;
      delete &_cstTempDS2/memtype=data;
      delete &_cstTempDS3/memtype=data;
      delete &_cstTempDS4/memtype=data;
    quit;
    %****************************;

  %*******************************;
  %*  Create DOCUMENT metadata   *;
  %*******************************;

  %let _cstCreateDocumentMetadata=1;

  /* These data sets are needed for DOCUMENT metadata */
  %let _cstList=&_cstCRTDataLib..annotatedcrfs|&_cstCRTDataLib..supplementaldocs|%str()
                &_cstCRTDataLib..mdvleaf|&_cstCRTDataLib..mdvleaftitles;
  %let _cstCounter=1;
  %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));
  %do %while (%length(&_cstListItem));

    %if not %sysfunc(exist(&_cstListItem)) %then
    %do;
      %put [CSTLOG%str(MESSAGE)] WAR%STR(NING): The &_cstListItem data set does not exist.;
      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=The &_cstListItem data set does not exist.,
          _cstResultFlagParm=0, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
      %end;
      %let _cstCreateDocumentMetadata=0;
    %end;

    %let _cstCounter = %eval(&_cstCounter + 1);
    %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));

  %end;

  %if &_cstCreateDocumentMetadata %then %do;

    %cst_createdsfromtemplate(_cstStandard=&_cstStandard,_cstStandardVersion=&_cstStandardVersion,
                              _cstType=sourcemetadata,_cstSubType=document,
                              _cstOutputDS=&_cstTrgMetaLibrary..&_cstTrgDocumentDS);

    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS1=_cstcrfdoc&_cstRandom;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS2=_cstleafs&_cstRandom;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempDS3=_cstconcat&_cstRandom;

    proc sql;
    create table work.&_cstTempDS1 as
      (select *, "CRF" as DocType from &_cstCRTDataLib..AnnotatedCRFs
       outer union corresponding
       select *, "DOC" as DocType from &_cstCRTDataLib..SupplementalDocs);
    create table work.&_cstTempDS2 as
      (select * from &_cstCRTDataLib..mdvleaf m1 left join &_cstCRTDataLib..mdvleaftitles m2
       on m1.id = m2.fk_mdvleaf);
    create table work.&_cstTempDS3 as
      (select leafID, DocType, DocumentRef, href, title, m1.FK_MetaDataVersion
       from work.&_cstTempDS1 m1 left join work.&_cstTempDS2 m2
       on (m1.leafID = m2.ID) and (m1.FK_MetaDataVersion = m2.FK_MetaDataVersion));
    quit;

    data work.&_cstTempDS3(keep=doctype DocumentRef href title);
      attrib doctype length=$10 label="Document Type (CRF/DOC)";
      set work.&_cstTempDS3;
    run;

    data &_cstTrgMetaLibrary..&_cstTrgDocumentDS(label="Source Document Metadata");
      set &_cstTrgMetaLibrary..&_cstTrgDocumentDS work.&_cstTempDS3;
      sasref=upcase("&_cstSDTMDataLib");
      standard="&_cstStandard";
      standardversion="&_cstStandardVersion";
    run;

    proc sort data=&_cstTrgMetaLibrary..&_cstTrgDocumentDS(label="Source Document Metadata");
      by sasref doctype title;
    run;

    %put [CSTLOG%str(MESSAGE)] NOTE: &_cstTrgMetaLibrary..&_cstTrgDocumentDS created.;
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
  %end;
  %else %put [CSTLOG%str(MESSAGE)] WARN%STR(ING): &_cstTrgMetaLibrary..&_cstTrgDocumentDS not created.;

    %*****************************;
    %*  Cleanup temporary files  *;
    %*****************************;
    proc datasets lib=work nolist;
      delete &_cstTempDS1/memtype=data;
      delete &_cstTempDS2/memtype=data;
      delete &_cstTempDS3/memtype=data;
    quit;
    %****************************;

  %exit_macro:

    %let _cstSrcData=&sysmacroname;
    %if %symexist(_cstResultsDS) %then
    %do;
      %if &_cstErrorFlag=1 %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
            _cstResultID=CST0202,
            _cstResultParm1=%str(Process failed to complete successfully, please check results data set for more information),
            _cstResultFlagParm=1,
            _cstSeqNoParm=&_cstSeqCnt,
            _cstSrcDataParm=&_cstSrcData);
      %end;

      %******************************************************;
      %* Persist the results if specified in sasreferences  *;
      %******************************************************;
      %cstutil_saveresults();
    %end;

%mend sdtmutil_createsrcmetafromcrtdds;