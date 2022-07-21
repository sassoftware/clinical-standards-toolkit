%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* ct_createformats                                                               *;
%*                                                                                *;
%* Derives codelists from terminology data sets as a catalog and as a data set.   *;
%*                                                                                *;
%* This macro derives code lists from the data sets that form the SAS             *;
%* representation of the controlled terminology XML files as published on the     *;
%* NCI EVS website (http://evs.nci.nih.gov/ftp1/CDISC).                           *;
%*                                                                                *;
%* These source metadata files are used by the SAS Clinical Standards Toolkit to  *;
%* create codelists as provided in the CDISC EVS/NCI XML files:                   *;
%*                                                                                *;
%*          odm                                                                   *;
%*          study                                                                 *;
%*          metadataversion                                                       *;
%*          codelists                                                             *;
%*          codelisttranslatedtext                                                *;
%*          codelistsynonym                                                       *;
%*          codelistitems                                                         *;
%*          clitemdecodetranslatedtext                                            *;
%*          codelistitemsynonym                                                   *;
%*          enumerateditemsynonym                                                 *;
%*          enumerateditems                                                       *;
%*                                                                                *;
%* This is the general strategy:                                                  *;
%*    1. Combine controlled terminology data.                                     *;
%*    1. Create the cntlin data set from the controlled terminology.              *;
%*    2. Read the cntlin data set using PROC FORMAT to create format catalog.     *;
%*                                                                                *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. The source data is read from a single SAS library. You can modify the    *;
%*       code to reference multiple libraries by using library concatenation.     *;
%*    2. You can specify only one study reference. Multiple study references      *;
%*       require modification of the code.                                        *;
%*    3. The following macro variables have been set either before invoking this  *;
%*       macro or be derived from the _cstSASRefs data set:                       *;
%*           _cstCTCat (type=fmtsearch, format catalog name)                      *;
%*           _cstCTLibrary (type=fmtsearch, target library for formats)           *;
%*           _cstSASrefLib (type=sourcedata, library of derived CT data sets)     *;
%*           _cstTrgDataLibrary (type=targetdata, library of derived format       *;
%*                               data set)                                        *;
%*           _cstCTData (type=targetdata, format catalog name)                    *;
%*    4. The following macro variables have been set previously:                  *;
%*           _cstStandard (CDISC-CT)                                              *;
%*           _cstStandardVersion (for example, 1.0.0)                             *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar studyRootPath Root path of the Study library                           *;
%* @macvar _cstCTLibrary Target library for formats catalog                       *;
%* @macvar _cstTrgDataLibrary Target library for formats data set                 *;
%* @macvar _cstSASrefLib Library of derived CDT-DDS data sets                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*            Standards Toolkit                                                   *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstSASRefs  Run-time SASReferences data set derived in process setup  *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstCTCat Format catalog name                                          *;
%* @macvar _cstCTData Format data set name                                        *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstLang - optional - Language tag for TranslatedText.                  *;
%*            Default: en                                                         *;
%* @param _cstCreateCatalog - optional - Create format catalog.                   *;
%*            1: This macro looks in SASReferences for a record with a type of    *;
%*            fmtsearch and uses that record.                                     *;
%*            0: This macro does not create a catalog, even if a record is        *;
%*            specified in SASReferences.                                         *;
%*            Values: 0 | 1                                                       *;
%*            Default: 1                                                          *;
%* @param _cstKillCatFirst - optional - Empty catalog first if it exists before   *;
%*            creating the new format catalog entries.                            *;
%*            1: The macro will empty the format catalog before creating the new  *;
%*               format catalog entries.                                          *;
%*            0: The macro does not empty the format catalog first.               *;
%*            Values: 0 | 1                                                       *;
%*            Default: 0                                                          *;
%* @param _cstUseExpression - optional - Expression to create the SAS format name.*;
%*            This expression will be assigned to the fmtname if it is not empty: *;
%*              fmtname = %unquote(&_cstUseExpression)                            *;
%*            Examples:                                                           *;
%*                - %str(strip(put(cdiscsubmissionvalue, $_qs32.)))               *;
%*                  where $_qs has values like:                                   *;
%*                  'ADAS-Cog CDISC Version TESTCD' = 'ADASCOGCD'                 *;
%*                - %str(cats("QS", put(_n_, z3.), "F"))                          *;
%*                - %str(cats(ExtCodeId, "F"))                                    *;
%*                - %nrstr(%MyMacro(param1=X, param2=Y))                          *;
%* @param _cstAppendChar - optional - Letter to append in case SAS format name    *;
%*            ends in a digit.                                                    *;
%*            Default: F                                                          *;
%* @param _cstDeleteEmptyColumns - optional - Delete columns that are completely  *;
%*            missing.                                                            *;
%*            1: The macro will delete columns in the output data set, both       *;
%*               numeric and character, that have only missing values.            *;
%*            0: No columns will be deleted from the output data set.             *;
%*            Values: 0 | 1                                                       *;
%*            Default: 1                                                          *;
%* @param _cstTrimCharacterData - optional - Truncate character data in output    *;
%*            data set to the minimum value needed.                               *;
%*            1: The macro will change the length of the character columns in the *;
%*               output data set to the minimum value needed to contain the data. *;
%*            0: No truncation will take place.                                   *;
%*            Values: 0 | 1                                                       *;
%*            Default: 1                                                          *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro ct_createformats(
         _cstLang=en,
         _cstCreateCatalog=1,
         _cstKillCatFirst=0,
         _cstUseExpression=,
         _cstAppendChar=F,
         _cstDeleteEmptyColumns=1,
         _cstTrimCharacterData=1
    ) / des='CST: Create Formats from CT Codelists';

  %local
    _cstDir
    _cstFileref
    _cstRandom
    _cstRC
    _cstrundt
    _cstTempDS1
    _cstTempDS2
    _cstTempDS3
    _cstTempDS4
    _cstTempDS5
    _cstTempDS6
    _cstTempDS7
    _cstTempDS8
    _cstTempDS9
    _cstTempDS10
    _cstTempDS11
    _cstDSLabel
    _cst_Error
    _cstErrorFlag
    _cstThisSrcData
    i
  ;

  %let _cstThisSrcData=&sysmacroname;

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
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: CREATE_CODELISTFROMCRTDDS,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
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

  %****************************************************;
  %*  Check for existence of required LIBNAME values  *;
  %****************************************************;
  %if %length(&_cstCTLibrary)<1 %then
    %cstutil_getsasreference(_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,_cstSASRefmember=_cstCTCat);

  %if "&_cstCTLibrary"="" %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): Location for output catalog required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for output catalog required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if %length(&_cstTrgDataLibrary)<1 %then
    %cstutil_getsasreference(_cstSASRefType=targetdata,_cstSASRefsasref=_cstTrgDataLibrary,_cstSASRefmember=_cstCTData);

  %if "&_cstTrgDataLibrary"="" %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): Location for output data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for output data sets required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;


  %if %length(&_cstSASrefLib)<1 %then
    %cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSASrefLib);

  %if "&_cstSASrefLib"="" %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): Location for CT input data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for CRTDDS input data sets required.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if &_cst_Error=1 %then %goto exit_macro;

  %*******************************************************************;
  %*  Set Error Flag to check existence of required CRTDDS Data Sets *;
  %*******************************************************************;
  %let _cstList=&_cstSASrefLib..odm|%str
              ()&_cstSASrefLib..study|%str
              ()&_cstSASrefLib..metadataversion|%str
              ()&_cstSASrefLib..codelists|%str
              ()&_cstSASrefLib..codelisttranslatedtext|%str
              ()&_cstSASrefLib..codelistsynonym|%str
              ()&_cstSASrefLib..codelistitems|%str
              ()&_cstSASrefLib..clitemdecodetranslatedtext|%str
              ()&_cstSASrefLib..codelistitemsynonym|%str
              ()&_cstSASrefLib..enumerateditemsynonym|%str
              ()&_cstSASrefLib..enumerateditems
                ;
  %let _cstCounter=1;
  %let _cstListItem=%scan(&_cstList, &_cstCounter, %str(|));
  %do %while (%length(&_cstListItem));

    %if not %sysfunc(exist(&_cstListItem)) %then
    %do;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): The &_cstListItem data set does not exist.;
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

  %****************************************************;
  %*  Check for existence of required locations       *;
  %****************************************************;

  %if &_cstErrorFlag=1 %then %goto exit_macro;

  %let _cstDir=%sysfunc(pathname(&_cstCTLibrary));
  %let _cstRC = %sysfunc(filename(_cstFileref,&_cstDir)) ;
  %if ^%sysfunc(fexist(&_cstFileref)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)&sysmacroname] ERR%STR(OR): Location for the &_cstCTLibrary catalog does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstCTLibrary  catalog library does not exist.,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %let _cstDir=%sysfunc(pathname(&_cstTrgDataLibrary));
  %let _cstRC = %sysfunc(filename(_cstFileref,&_cstDir)) ;
  %if ^%sysfunc(fexist(&_cstFileref)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%STR(OR): Location for the &_cstTrgDataLibrary data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstTrgDataLibrary data set library does not exist.,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if &_cst_Error=1 %then %goto exit_macro;

  %****************************************************;
  %*  Check _cstAppendChar                            *;
  %****************************************************;

  %if %length(&_cstAppendChar)<1 %then
  %do;
    %let _cstAppendChar=F;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The missing _cstAppendChar parameter value was set to &_cstAppendChar..;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
        _cstResultID=CST0200,
        _cstResultParm1=The missing _cstAppendChar parameter value was set to &_cstAppendChar,
        _cstSeqNoParm=&_cstSeqCnt,
        _cstSrcDataParm=&_cstThisSrcData);
  %end;
  %else %do;
    %if %sysfunc(compress(&_cstAppendChar, , lu)) ne %then %do;

      %let _cstParam1=_cstAppendChar;
      %let _cstParam2=&_cstAppendChar;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %STR(ERR)OR: Invalid value &_cstAppendChar for _cstAppendChar parameter was specified, only a letter allowed.;

      %if %symexist(_cstResultsDS) %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0201,_cstResultParm1=Invalid value &_cstAppendChar for _cstAppendChar parameter was specified - value set to F.,
          _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstThisSrcData);
      %end;
      %let _cstAppendChar=F;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: The _cstAppendChar parameter value was set to &_cstAppendChar..;
    %end;
  %end;


  %********************************;
  %*  Generate needed work files  *;
  %********************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst_cls&_cstRandom;
  %let _cstTempDS2=_cst_clis&_cstRandom;
  %let _cstTempDS3=_cst_enis&_cstRandom;
  %let _cstTempDS4=_cst_cl_&_cstRandom;
  %let _cstTempDS5=_cst_cl&_cstRandom;
  %let _cstTempDS6=_cst_cli&_cstRandom;
  %let _cstTempDS7=_cst_eni&_cstRandom;
  %let _cstTempDS8=_cst_items&_cstRandom;
  %let _cstTempDS9=_cst_cterms&_cstRandom;
  %let _cstTempDS10=_cst_cntlin&_cstRandom;


  data work.&_cstTempDS1;
  attrib codelist_synonym length=$2000 label="Applicable synonym for a CDISC Preferred Term";
  retain codelist_synonym;
    set &&_cstSASrefLib..codelistsynonym;
    by fk_codelists cdiscsynonym notsorted;
    if first.fk_codelists
      then codelist_synonym=cdiscsynonym;
      else codelist_synonym=catx("; ", codelist_synonym, cdiscsynonym);
    if last.fk_codelists then output;
  run;

  data work.&_cstTempDS2;
  attrib cdisc_synonym length=$2000 label="Applicable synonym for a CDISC Preferred Term";
  retain cdisc_synonym;
    set &&_cstSASrefLib..codelistitemsynonym;
    by fk_codelistitems cdiscsynonym notsorted;
    if first.fk_codelistitems
      then cdisc_synonym=cdiscsynonym;
      else cdisc_synonym=catx("; ", cdisc_synonym, cdiscsynonym);
    if last.fk_codelistitems then output;
  run;

  data work.&_cstTempDS3;
  attrib cdisc_synonym length=$2000 label="Applicable synonym for a CDISC Preferred Term";
  retain cdisc_synonym;
    set &&_cstSASrefLib..enumerateditemsynonym;
    by fk_enumerateditems cdiscsynonym notsorted;
    if first.fk_enumerateditems
      then cdisc_synonym=cdiscsynonym;
      else cdisc_synonym=catx("; ", cdisc_synonym, cdiscsynonym);
    if last.fk_enumerateditems then output;
  run;

  data work.&_cstTempDS4(drop=regex);
   length MarkToDelete 8;
   retain regex;
   length type $1 fmtname $32;
   label type="SAS datatype" fmtname="SAS format name";
   set &&_cstSASrefLib..codelists;
      if _n_=1 then do;
        regex = prxparse('m/^(?=.{1,32}$)([\$a-zA-Z_][a-zA-Z0-9_]*[a-zA-Z_])$/');
      end;

      if upcase(datatype) in ('STRING' 'TEXT') then type='C';
                                               else type='N';

      %* First try a user supplied expression, which will overrule all other options;
      %if %sysevalf(%superq(_cstUseExpression)=,boolean) eq 0 %then %do;
        fmtname = %unquote(&_cstUseExpression) ;
      %end;

      %* This will normally be empty in the EVS/NCI ODM files, but use it if it is there;
      if missing(fmtname) then fmtname=strip(sasformatname);

      %* Finally use the CDISC Submission Value to create the format;
      if missing(fmtname) then fmtname=strip(cdiscsubmissionvalue);

      MarkToDelete=0;

      %* Check if the last character is a digit;
      if (anydigit(fmtname , length(fmtname) * (-1)) eq length(fmtname)) then do;
           put "[CSTLOG%str(MESSAGE).&sysmacroname]: '" fmtname +(-1)
               "' will be updated to a valid SAS format name: " fmtname +(-1) "&_cstAppendChar";
        fmtname=ktrim(fmtname)||"&_cstAppendChar";
      end;

      %* Check if we have a valid format name;
      if not prxmatch(regex, trim(fmtname)) then do;
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: '" fmtname +(-1) "' is invalid and will not be used.";
        MarkToDelete=1;
        call missing(fmtname);
      end;
  run;

  proc sql;

    create table work.&_cstTempDS5 as
      select cl.*, codelist_synonym from
      work.&_cstTempDS4 cl left join work.&_cstTempDS1 cls
      on cl.oid=cls.fk_codelists;

    create table work.&_cstTempDS6 as
      select cli.*, clids.* from
      &&_cstSASrefLib..codelistitems cli left join
      (select clid.*, clis.cdisc_synonym from
       &&_cstSASrefLib..clitemdecodetranslatedtext clid left join work.&_cstTempDS2 clis
       on (clid.fk_codelistitems=clis.fk_codelistitems) and (clid.lang = "&_cstLang")
       ) clids
       on (cli.oid=clids.fk_codelistitems);

    create table work.&_cstTempDS7 as
      select ei.*, eis.cdisc_synonym from
      &_cstSASrefLib..enumerateditems ei left join work.&_cstTempDS3 eis
      on ei.oid=eis.fk_enumerateditems;

  quit;

  data work.&_cstTempDS8(drop=oid rename=(ExtCodeID=code PreferredTerm=nci_preferred_term));
   set work.&_cstTempDS6 work.&_cstTempDS7;
  run;

  proc sql;
    create table work.&_cstTempDS9 as
    select odm.sourcesystem, odm.sourcesystemversion, mdv.description, cl.*, clt.translatedtext as codelist_definition, cli.*
    from
      &&_cstSASrefLib..odm odm, &&_cstSASrefLib..study st, &&_cstSASrefLib..metadataversion mdv,
      work.&_cstTempDS5 cl, &_cstSASrefLib..codelisttranslatedtext clt, work.&_cstTempDS8 cli
    where (cli.fk_codelists=cl.oid) and
          (clt.fk_codelists=cl.oid) and
          (clt.lang = "&_cstLang") and
          (cl.fk_metadataversion=mdv.oid) and
          (mdv.fk_study=st.oid) and
          (st.fk_odm=odm.fileoid);
  quit;

  data work.&_cstTempDS9(drop=oid fk_metadataversion fk_codelists fk_codelistitems lang);
  retain sourcesystem sourcesystemversion description codelist codelist_code codelist_name codelist_extensible codelist_synonym codelist_definition
         codelist_preferred_term datatype type fmtname code cdisc_submission_value translatedtext cdisc_synonym cdisc_definition;
    set work.&_cstTempDS9(rename=(cdiscsubmissionvalue=codelist ExtCodeId=codelist_code codelistextensible=codelist_extensible
                            name=codelist_name PreferredTerm=codelist_preferred_term
                            codedvalue=cdisc_submission_value cdiscdefinition=cdisc_definition
                            ));
  run;

  %if &_cstCreateCatalog %then %do;

    data &_cstTempDS10(drop=MarkToDelete);
      set work.&_cstTempDS9
        (where=(MarkToDelete ne 1)
         keep=MarkToDelete codelist fmtname rank type cdisc_submission_value
         rename=(cdisc_submission_value=label));
      label=strip(label);
      start=strip(label);
      hlo='';
    run;

    proc sort data=&_cstTempDS10;
    by codelist fmtname rank label;
    run;

  %end;

  %* create data set label;
  data _null_;
    set &_cstSASrefLib..study;
    call symputx('_cstDSLabel',strip(studydescription));
  run;

  proc sort data=work.&_cstTempDS9(label="&_cstDSLabel" drop=MarkToDelete) out=&_cstTrgDataLibrary..&_cstCTData;
  by codelist rank cdisc_submission_value;
  run;


  %cstutil_writeresult(
        _cstResultId=CST0102
       ,_cstResultParm1=&_cstTrgDataLibrary..&_cstCTData (%cstutilnobs(_cstDatasetName=&_cstTrgDataLibrary..&_cstCTData) obs)
       ,_cstResultSeqParm=1
       ,_cstSeqNoParm=1
       ,_cstSrcDataParm=&_cstThisSrcData
       ,_cstResultFlagParm=0
       ,_cstRCParm=0
       ,_cstResultsDSParm=&_cstResultsDS
       );

  %if %cstutilnobs(_cstDatasetName=&_cstTrgDataLibrary..&_cstCTData) eq 0 %then %goto zero_obs;


  %**********************************************;
  %*  Optimize Controlled Terminology data set  *;
  %**********************************************;
  %if &_cstDeleteEmptyColumns %then %do;
  %cstutildropmissingvars(
      _cstDataSetName=&_cstTrgDataLibrary..&_cstCTData,
      _cstDataSetOutName=&_cstTrgDataLibrary..&_cstCTData,
      _cstNoDrop=
      );
  %end;

  %if &_cstTrimCharacterData %then %do;
  %cstutiltrimcharvars(
      _cstDataSetName=&_cstTrgDataLibrary..&_cstCTData,
      _cstDataSetOutName=&_cstTrgDataLibrary..&_cstCTData,
      _cstNoTrim=
      );
  %end;

  %if &_cstDebug %then %do;
    proc contents data=&_cstTrgDataLibrary..&_cstCTData varnum;
    run;
  %end;

  %zero_obs:

  %*****************************;
  %*  Create a format catalog  *;
  %*****************************;
  %if &_cstCreateCatalog %then %do;

    %if &_cstKillCatFirst eq 1 %then %do;
      %if %sysfunc(cexist(&_cstCTLibrary..&_cstCTCat)) %then %do;
        %put [CSTLOG%str(MESSAGE).&sysmacroname]: format catalog &_cstCTLibrary..&_cstCTCat will be emptied first.;
        proc catalog catalog=&_cstCTLibrary..&_cstCTCat kill;
        quit;
      %end;
    %end;

    proc format library=&_cstCTLibrary..&_cstCTCat cntlin=&_cstTempDS10;
    quit;

    %cstutil_writeresult(
          _cstResultId=CST0102
         ,_cstResultParm1=&_cstCTLibrary..&_cstCTCat (from %cstutilnobs(_cstDatasetName=&_cstTempDS10) obs)
         ,_cstResultSeqParm=1
         ,_cstSeqNoParm=1
         ,_cstSrcDataParm=&_cstThisSrcData
         ,_cstResultFlagParm=0
         ,_cstRCParm=0
         ,_cstResultsDSParm=&_cstResultsDS
         );

    %if &_cstDebug eq 0 %then %do;
      %cstutil_deleteDataSet(_cstDataSetName=work.&_cstTempDS10);
    %end;

    %***************************************************************;
    %*  Add descriptions to the format entries                     *;
    %*  Assign a filename for the code that will be generated      *;
    %*  Generate temp data set name for sort                       *;
    %***************************************************************;

    %let _cstNextCode=_cst&_cstRandom;
    %let _cstTempDS11=_cstdes&_cstRandom;

    proc sort data=&_cstTrgDataLibrary..&_cstCTData
              out=work.&_cstTempDS11(keep=fmtname codelist codelist_code codelist_name) nodupkey;
      by fmtname;
    run;

    filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source" &_cstLRECL;

    data _null_;
      set work.&_cstTempDS11 end=eof;
      file &_cstNextCode;
      length line1 $200;
      if _n_=1 then
      do;
        put 'proc catalog catalog=&_cstCTLibrary..&_cstCTCat;';
      end;
      codelist_name=compress(codelist_name, "'");
      codelist_name=compress(codelist_name, '"');
      if not missing(fmtname) then do;
        line1="modify "||strip(fmtname)||".formatc (description='"||strip(codelist_name)||" ("||strip(fmtname)||" - "||strip(codelist_code)||")');";
        line1=strip(left(line1));
        put @2 line1;
      end;
      if eof then
      do;
        put "quit;";
      end;
    run;

    %include &_cstNextCode;
    filename &_cstNextCode;

    proc datasets lib=work nolist;
      delete &_cstNextCode / memtype=catalog;
    quit;


    %if &_cstDebug eq 0 %then %do;
      %cstutil_deleteDataSet(_cstDataSetName=work.&_cstTempDS11);
    %end;

    %***************************************************************;


    %if &syserr ne 0 %then %let _cst_Error=1;

    %if &_cstDebug %then %do;
      proc catalog catalog=&_cstCTLibrary..&_cstCTCat;
        title01 "Contents for the &_cstCTCat Format Catalog";
        contents;
      quit;

      proc format library=&_cstCTLibrary..&_cstCTCat fmtlib;
        title01 "FMTLIB Output for the &_cstCTCat Format Catalog";
        title02 "in folder %sysfunc(pathname(&_cstCTLibrary))";
      quit;
    %end;


  %end;


%CLEANUP:
  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  %if &_cstDebug eq 0 %then %do;
    %do i=1 %to 9;
      %cstutil_deleteDataSet(_cstDataSetName=work.&&_cstTempDS&i);
    %end;
  %end;


%EXIT_MACRO:

  %let _cstSrcData=&sysmacroname;
  %if %symexist(_cstResultsDS) %then
  %do;
    %if &_cst_Error=1 %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,
                           _cstResultParm1=%str(Process failed to complete successfully, please check results data set for more information),
                           _cstResultFlagParm=1,
                           _cstSeqNoParm=&_cstSeqCnt,
                           _cstSrcDataParm=&_cstSrcData);
    %end;
    %else
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Process completed successfully,_cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %******************************************************;
    %* Persist the results if specified in sasreferences  *;
    %******************************************************;
    %cstutil_saveresults();
  %end;
  %else %if &_cst_Error= 1 %then
  %do;
    %let _cstSrcData=&sysmacroname;
    %put Error &_cstSrcData ended prematurely, please check log;
  %end;

%mend ct_createformats;