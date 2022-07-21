%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_buildformatsfromxml                                                    *;
%*                                                                                *;
%* Creates format catalogs from codelist information in XML-based standards.      *;
%*                                                                                *;
%* This macro reads codelist information from CDISC XML-based standards to create *;
%* one or more SAS format catalogs, based on the xml:lang language tags.          *;
%*                                                                                *;
%* This macro is for use with CDISC XML-based standards such as CRT-DDS and ODM.  *;
%* Those standards capture acceptable values in codelists.                        *;
%*                                                                                *;
%* This macro is called by the odm_read and crtdds_read macros.                   *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   - If EnumeratedItems are encountered, these items are added to each          *;
%*     language-specific format catalog that is created.                          *;
%*                                                                                *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstStdMnemonic Standard mnemonic provided by the SAS Clinical         *;
%*            Standards Toolkit                                                   *;
%* @macvar _cstSrcDataLibrary Source library being evaluated                      *;
%*                                                                                *;
%* @param _cstFmtLib - optional - The location where catalogs are written. If     *;
%*            this parameter is not specified, the default value is first derived *;
%*            from SASReferences, then WORK.                                      *;
%* @param _cstReplaceFmtCat - optional - Replace an existing format catalog by    *;
%*            the same name in _cstFmtLib.                                        *;
%*            Default behavior:  Y (overwrite existing catalog)                   *;
%*            Values:  N | Y                                                      *;
%*            Default: Y                                                          *;
%* @param _cstFmtCatPrefix - optional - The prefix to use for catalog names. If   *;
%*            this parameter is not specified, the default value is               *;
%*            <standard mnemonic>FmtCat (such as ODMFmtCat). This default         *;
%*            produces an English format catalog name of ODMFmtCat_en.            *;
%* @param _cstFmtCatLang - optional - Create a format catalog only for the        *;
%*            specified language. Example: _cstFmtCatLang=en. If no records exist *;
%*            for the specified language, an empty catalog is created.            *;
%* @param _cstFmtCatLangOption - optional - The action to take when no language   *;
%*            tag is provided in the XML:                                         *;
%*            Ignore:            Records are ignored (but they are reported in    *;
%*                               the SAS log).                                    *;
%*            English:           Records are added to the English catalog.        *;
%*            Use_cstFmtCatLang: Records are added to the language catalog that is*;
%*                               specified by _cstFmtCatLang.                     *;
%*            Values: Ignore | English  |Use_cstFmtCatLang                        *;
%*            Default: English                                                    *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cstutil_buildformatsfromxml(
    _cstFmtLib=,
    _cstReplaceFmtCat=Y,
    _cstFmtCatPrefix=,
    _cstFmtCatLang=,
    _cstFmtCatLangOption=English
    ) /des='CST: Build formats from xml codelists';

  %local
    _cstCatalogName
    _cstCLLanguages
    _cstLangCount
    _cstNullLang
    _cstParam1
    _cstParam2
    _cstRecords
    _cstSubMsg1
    _cstSubMsg2
    _cstTempDS1
    _cstTempDS2
    _cstThisMacroRC
    _thisLang
  ;

  %let _cstThisMacroRC=0;
  %let _cstSrcData=&sysmacroname;

  %if (%length(&_cstFmtLib)>0) %then %do;
    %if %sysfunc(libref(&_cstFmtLib)) ne 0 %then %do;
       %let _cstParam1=&_cstFmtLib;
       %let _cstParam2=;
       %goto MISSING_ASSIGNMENT;
    %end;
  %end;
  %else
  %do;
    %let _cstFmtLib=work;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Destination library for format catalogs set to WORK,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
  %end;

  %* Set default catalog name prefix if one is not provided via parameters  *;
  %if (%length(&_cstFmtCatPrefix)<1) %then %do;
    %let _cstFmtCatPrefix=&_cstStdMnemonic.fmtcat;
    %let _cstCatalogName=&_cstFmtCatPrefix;
  %end;


  ******************************************;
  * Are there any EnumeratedItems records? *;
  ******************************************;

  data work.codelists_upd(drop=regex);
   retain regex;
   set &_cstSrcDataLibrary..codelists;
      if _n_=1 then do;
        regex = prxparse('m/^(?=.{1,32}$)([\$a-zA-Z_][a-zA-Z0-9_]*[a-zA-Z_])$/');
      end;
      %* try name if SASFormatName is missing;
      if missing(sasformatname) then do;
        sasformatname=kcompress(kstrip(name));
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Missing SASFormatName "
            "replaced with " sasformatname "(" OID= +(-1) ").";
      end;

      %* Check if the last character is a digit. If yes, add F;
      if (anydigit(sasformatname , length(sasformatname) * (-1)) eq length(sasformatname)) then do;
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Invalid SASFormatName " sasformatname +(-1)
            " updated to: " sasformatname +(-1) "F (" OID= +(-1) ").";
        sasformatname=ktrim(sasformatname)||"F";
      end;

      %* Check if we have a valid format name. If not, then set SASFormatName to missing;
      if not prxmatch(regex, trim(sasformatname)) then do;
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Invalid SASFormatName " sasformatname +(-1) 
            " will not be used, set to missing (" OID= name= +(-1) ").";
        call missing(sasformatname);
      end;
  run;


  ******************************************;
  * Are there any EnumeratedItems records? *;
  ******************************************;
  data _null_;
    if 0 then set &_cstSrcDataLibrary..EnumeratedItems nobs=_numobs;
    call symputx('_cstRecords',_numobs);
    stop;
  run;

  %if &_cstRecords>0 %then
  %do;

    * NOTE:  Rank is optional, if present it is numeric and assumed to order codedValues *;
    *        If rank absent/null, all we have to use is codedValue.                      *;

    proc sort data=&_cstSrcDataLibrary..enumerateditems out=work._cstTempEnum1;
      by FK_Codelists rank codedvalue;
    run;
    data work._cstTempEnum1 (keep=start label type fk_codelists rank hlo);
      set work._cstTempEnum1;
      attrib start format=$512. label format=$2000. type format=$1. hlo format=$1.;
      select(rank);
        when (.) do;
          start=codedvalue;
          label=codedvalue;
          type='C';
          hlo="";
        end;
        otherwise do;
          start=put(rank,8.);
          label=codedvalue;
          type='N';
          hlo="";
        end;
      end;
    run;

    proc sql noprint;
      create table work._cstTempEnum (drop=fk_codelists) as
      select ds1.*, ds2.sasformatname as fmtname
      from work._cstTempEnum1 ds1
             left join
           work.codelists_upd ds2
      on ds1.fk_codelists=ds2.oid
      order by fmtname, start;
    quit;

  %end;

  *****************************************************;
  * Are there any CLItemDecodeTranslatedText records? *;
  *****************************************************;
  %let _cstRecords=0;

  data _null_;
    if 0 then set &_cstSrcDataLibrary..CLItemDecodeTranslatedText nobs=_numobs;
    call symputx('_cstRecords',_numobs);
    stop;
  run;

  %if &_cstRecords>0 %then
  %do;

    *****************************************************;
    * How many languages are present in the CodeLists?  *;
    *****************************************************;
    %let _cstLangCount=0;
    %let _cstNullLang=0;

    proc sql noprint;
      select distinct(lang) into :_cstCLLanguages separated by ' '
      from &_cstSrcDataLibrary..CLItemDecodeTranslatedText;
      select count(distinct lang) into :_cstLangCount from &_cstSrcDataLibrary..CLItemDecodeTranslatedText;
      select count(*) into :_cstNullLang from &_cstSrcDataLibrary..CLItemDecodeTranslatedText (where=(lang=''));
    quit;
    %if &_cstDebug %then
    %do;
      %put _cstCLLanguages=&_cstCLLanguages;
      %put _cstLangCount=&_cstLangCount;
    %end;

    %************************************;
    %* Iterate through each lang value  *;
    %************************************;
    %do i_lang=1 %to &_cstLangCount;
      %let _thisLang=%SYSFUNC(scan(&_cstCLLanguages,&i_lang,' '));

      %* Are we subsetting the processing to a single language?  *;
      %if (%length(&_cstFmtCatLang)<1 or
           (%length(&_cstFmtCatLang)>0 and "%upcase(&_cstFmtCatLang)"="%upcase(&_thisLang)")) %then
      %do;

        * Assumes 1-to-1 correspondence between CLItemDecodeTranslatedText and CodeListItems *;
        * Is this reliably true?      *;

        %cstutil_getRandomNumber(_cstVarname=_cstRandom);
        %let _cstTempDS1=_cst&_cstRandom;

        proc sql noprint;
          create table work.&_cstTempDS1 as
          select cl.sasformatname as fmtname,
                 dc.CodedValue as start format=$512.,
                 dc.TranslatedText as label format=$2000.,
                 dc.rank,
                 "" as hlo format=$1.,
                 case when upcase(cl.DataType)='TEXT' then 'C'
                   else 'N'
                 end as type from
          (select decode.translatedtext, items.codedvalue, items.FK_CodeLists, items.rank
          from &_cstSrcDataLibrary..CLItemDecodeTranslatedText decode
            left join
               &_cstSrcDataLibrary..CodeListItems items
          on decode.FK_CodeListItems = items.OID
          where lang="&_thisLang") dc
            left join
               work.codelists_upd cl
          on dc.FK_CodeLists = cl.OID
          order by fmtname, rank;
        ;
        quit;

        %***************************************************;
        %* Proc append any EnumeratedItems to each catalog *;
        %***************************************************;
        %if %sysfunc(exist(work._cstTempEnum)) %then
        %do;
          proc append base=work.&_cstTempDS1 data=work._cstTempEnum force;
          run;
        %end;

        %if &_cstNullLang>0 %then
        %do;

          %***************************************************;
          %* Capture the lang-null records in a data set     *;
          %***************************************************;
          %cstutil_getRandomNumber(_cstVarname=_cstRandom);
          %let _cstTempDS2=_cst&_cstRandom;

          proc sql noprint;
            create table work.&_cstTempDS2 as
            select cl.sasformatname as fmtname,
                   dc.CodedValue as start format=$512.,
                   dc.TranslatedText as label format=$2000.,
                   dc.rank,
                   "" as hlo format=$1.,
                   case when upcase(cl.DataType)='TEXT' then 'C'
                     else 'N'
                   end as type from
            (select decode.translatedtext, items.codedvalue, items.FK_CodeLists, items.rank
            from &_cstSrcDataLibrary..CLItemDecodeTranslatedText decode
              left join
                 &_cstSrcDataLibrary..CodeListItems items
            on decode.FK_CodeListItems = items.OID
            where lang="") dc
              left join
                 work.codelists_upd cl
            on dc.FK_CodeLists = cl.OID
            order by fmtname, rank;
          ;
          quit;

          %* Decide what we need to do with lang-null records  *;
          %if (%upcase(&_cstFmtCatLangOption)=IGNORE) %then %do;
            %if &_cstNullLang>50 %then
            %do;
              %put NOTE: &_cstNullLang records with no language specified have been excluded based on the _cstFmtCatLangOption parameter;
            %end;
            %else
            %do;
              data _null_;
                set work.&_cstTempDS2;
                  attrib _csttempvar format=$72.;
                  if _n_=1 then
                    put "NOTE: The following codelist values with no language specified have been excluded based on the _cstFmtCatLangOption parameter.";
                  _csttempvar=catx(' ','SASformatname=',strip(fmtname),'CodedValue=',strip(label));
                  put @8 _csttempvar;
              run;
            %end;
          %end;
          %else %if (%upcase(&_cstFmtCatLangOption)=USE_CSTFMTCATLANG) %then %do;
            %if %upcase("&_thisLang")=%upcase("&_cstFmtCatLang") %then
            %do;
              proc append base=work.&_cstTempDS1 data=work.&_cstTempDS2 force;
              run;
            %end;
          %end;
          %else %do;
            %if %upcase("&_thisLang")="EN" %then
            %do;
              proc append base=work.&_cstTempDS1 data=work.&_cstTempDS2 force;
              run;
            %end;
          %end;

          proc datasets nolist lib=work;
            delete &_cstTempDS2 / memtype=data;
          quit;


        %end;  %* end of _cstNullLang>0 processing *;

        ***************************;
        * Build the catalog name  *;
        ***************************;
        %let _thisLang=%sysfunc(translate(&_thisLang,'_','-'));
        %let _cstCatalogName=&_cstFmtCatPrefix._&_thisLang;

        ***************************************;
        * Create the catalog and data set     *;
        ***************************************;
        %let _cstSubMsg1=;
        %let _cstSubMsg2=;
        %* Do not overwrite an existing catalog *;
        %if (%upcase(&_cstReplaceFmtCat)=N and %sysfunc(cexist(&_cstFmtLib..&_cstCatalogName))) %then
        %do;
          %let _cstSubMsg2=catalog;
        %end;
        %else
        %do;

          proc format library=&_cstFmtLib..&_cstCatalogName cntlin=work.&_cstTempDS1(where=(not missing(fmtname)));
          run;
          %let _cstSubMsg1=catalog;
          
        %end;

        %* Do not overwrite an existing data set *;
        %if (%upcase(&_cstReplaceFmtCat)=N and %sysfunc(exist(&_cstFmtLib..&_cstCatalogName))) %then
        %do;
          %if %length(&_cstSubMsg2)<1 %then
            %let _cstSubMsg2=data set;
          %else
            %let _cstSubMsg2=&_cstSubMsg2 and data set;
        %end;
        %else
        %do;
          proc sort data=work.&_cstTempDS1 out=&_cstFmtLib..&_cstCatalogName(drop=hlo);
            by fmtname rank;
          run;
          %if %length(&_cstSubMsg1)<1 %then
            %let _cstSubMsg1=data set;
          %else
            %let _cstSubMsg1=&_cstSubMsg1 and data set;
        %end;

        proc datasets nolist lib=work;
          delete &_cstTempDS1 / memtype=data;
        quit;

        %if %length(&_cstSubMsg1)>0 %then
        %do;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %let _cstSrcData=&sysmacroname;
          %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=&_cstFmtLib..&_cstCatalogName &_cstSubMsg1 created,
                               _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
        %end;

        %if %length(&_cstSubMsg2)>0 %then
        %do;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %let _cstSrcData=&sysmacroname;
          %cstutil_writeresult(_cstResultID=CST0200,
                               _cstResultParm1=&_cstFmtLib..&_cstCatalogName &_cstSubMsg2 not created based on _cstReplaceFmtCat parameter,
                               _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
        %end;

      %end;
    %end;
  %end;
  %else
  %do;
    %if %sysfunc(exist(work._cstTempEnum)) %then
    %do;

      %let _cstCatalogName=&_cstFmtCatPrefix._enums;
      proc format library=&_cstFmtLib..&_cstCatalogName cntlin=work._cstTempEnum(where=(not missing(fmtname)));
      run;

    %end;
  %end;

  %goto CLEANUP;

%MISSING_ASSIGNMENT:
  %if (&_cstDebug) %then %do;
     %put In MISSING_ASSIGNMENT;
  %end;

  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %let _cstSrcData=&sysmacroname;
  %cstutil_writeresult(
                _cstResultId=CRT0101
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcData
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );

%CLEANUP:
  %if (&_cstDebug) %then %do;
     %put In CLEANUP;
  %end;

  %if %sysfunc(exist(work._cstTempEnum)) %then
  %do;
    proc datasets nolist lib=work;
      delete _cstTempEnum _cstTempEnum1 / memtype=data;
    quit;
  %end;

  %let _cst_rc=&_cstThisMacroRC;

%mend cstutil_buildformatsfromxml;