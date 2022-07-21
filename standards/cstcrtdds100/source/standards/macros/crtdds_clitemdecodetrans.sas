%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_clitemdecodetrans                                                       *;
%*                                                                                *;
%* Creates the SAS CRT-DDS CLItemDecodeTrans data set from source metadata.       *;
%*                                                                                *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column metadata for the Domain columns to include in the CRT-DDS   *;
%*             file.                                                              *;
%* @param  _cstSourceValues  - optional - The data set that contains the          *;
%*             metadata for the Value Level columns to include in the CRT-DDS     *;
%*             file.                                                              *;
%* @param _cstcodelistitemsds - required - The CodeListsItems data set in the     *;
%*            output library (for example, srcdata.CodeListItems).                *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*             library (for example, srcdata.MetaDataVersion).                    *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*             (For example, srcdata.Study).                                      *;
%* @param _cstcodelistsds - required - The CodeLists data set in output library   *;
%*            (for example, srcdata.CodeLists).                                   *;
%* @param _cstCLlang - optional - The ODM TranslatedText/@lang attribute.         *;
%* @param _cstoutclitemdecodetransds - required - The CLItemDecodeTrans           *;
%*            data set to create (for example, srcdata.CLItemDecodeTrans).        *;
%*                                                                                *;
%* @history 2013-12-12  Added _cstSourceValues to ensure codelist references in   *;
%*             Value Level Metadata are kept                                      *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_clitemdecodetrans(
    _cstsourcestudy=,
    _cstsourcecolumns=,
    _cstsourcevalues=,
    _cstcodelistitemsds=,
    _cstmdvDS=,
    _cststudyds=,
    _cstcodelistsds=,
    _cstCLlang=,
    _cstoutclitemdecodetransds=
    ) / des="Creates SAS CRT-DDS CLItemDecodeTrans data set";

%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6 ds7 ds8 ds9 ds10 ds11;
%if %length(&_cstsourcecolumns)=0 or %length(&_cstcodelistitemsds)=0 or %length(&_cstCLlang)=0
  or %length(&_cstoutclitemdecodetransds)=0 or %length(&_cstmdvDS)=0 or %length(&_cststudyds)=0
  or %length(&_cstsourcestudy)=0 or %length(&_cstcodelistsds)=0
    %then %goto exit;

%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cststudyds)) %then %goto exit;
%if ^%sysfunc(exist(&_cstcodelistitemsds)) %then %goto exit;
%if ^%sysfunc(exist(&_cstcodelistsds)) %then %goto exit;


%cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_i1&_cstRandom;
  %let keycnt=1;
  %* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
  %if %symexist(_cstsourcecolumns) %then %do;
      %if (%sysfunc(indexc("&_cstsourcecolumns",'.'))=0 )%then %let srccols=&_cstsourcecolumns;
      %else %do;
        %let src2=%scan(&_cstsourcecolumns,2,'.');
    %let srccols=&src2;
    %end;
  %end;
  %if %symexist(_cstcodelistitemsds) %then %do;
      %if (%sysfunc(indexc("&_cstcodelistitemsds",'.'))=0) %then %let clids=&_cstcodelistitemsds;
    %else %do;
        %let cl2=%scan(&_cstcodelistitemsds,2,'.');
    %let clids=&cl2;
    %end;
  %end;
  %if %symexist(_cstoutclitemdecodetransds) %then %do;
      %if %sysfunc(indexc("&_cstoutclitemdecodetransds",'.'))=0 %then %let cldds=&_cstoutclitemdecodetransds;
      %else %do;
        %let cld=%scan(&_cstoutclitemdecodetransds,2,'.');
    %let cldds=&cld;
    %end;
  %end;

  %if %symexist(_cstmdvDS) %then %do;
      %if (%sysfunc(indexc("&_cstmdvDS",'.'))=0) %then %let mdvds=&_cstmdvds;
    %else %do;
        %let mdv2=%scan(&_cstmdvDS,2,'.');
    %let mdvds=&mdv2;
    %end;
  %end;

/*
  %if %symexist(_cstsourcestudy) %then %do;
      %if (%sysfunc(indexc("&_cstsourcestudy",'.'))=0 )%then %let srcstudyds=&_cstsourcestudy;
      %else %do;
        %let srcst2=%scan(&_cstsourcestudy,2,'.');
    %let srcstudyds=&srcst2;
    %end;
  %end;
*/
 %if %symexist(_cststudyds) %then %do;
      %if (%sysfunc(indexc("&_cststudyds",'.'))=0 )%then %let studyds=&_cststudyds;
      %else %do;
        %let studyds2=%scan(&_cststudyds,2,'.');
    %let studyds=&studyds2;
    %end;
  %end;
  %if %symexist(_cstcodelistsds) %then %do;
      %if (%sysfunc(indexc("&_cstcodelistsds",'.'))=0) %then %let clds=&_cstcodelistsds;
    %else %do;
        %let cl2=%scan(&_cstcodelistsds,2,'.');
    %let clds=&cl2;
    %end;
  %end;

%let ds1=_cl1&_cstRandom;

  data _null_;
        attrib _cstCatalog format=$char17.
               _cstfmts format=$char200.
               _cstCatalogs format=$char200.;
        _cstfmts = translate(getoption('FMTSEARCH'),'','()');
        do i = 1 to countw(_cstfmts,' ');
          _cstCatalog=scan(_cstfmts,i,' ');
          if index(_cstCatalog,'.') = 0 then do;
               if libref(_cstcatalog)=0 then
        _cstCatalog = catx('.',_cstCatalog,'FORMATS');
      end;
      if exist(_cstCatalog,'CATALOG') then
            _cstCatalogs = catx(' ',_cstCatalogs,_cstCatalog);
        end ;
    IF STRIP(_CSTCATALOG) NE ''
          then call symput('_cstCatalogs',STRIP(_cstCatalogs));
    else call symput('_cstCatalogs','');
      run;
      %if "&_cstCatalogs"="" %then %goto cleanup;


      %* Concatenate format catalogs into a single reference  *;
    %IF %SYSFUNC(STRIP("&_cstCatalogs")) NE "" %THEN %DO;
      catname _cstfmts ( &_cstCatalogs ) ;
      proc format lib = work._cstfmts cntlout=&ds1 (rename=(fmtname=Name));
      run ;
      catname _cstfmts clear;
    %END;

  proc sort data=&ds1 /*nodupkey*/;
     by name label; run;

  %if (%symexist(_cstCLlang)eq 0) %then %let _cstCLlang=;

   data &ds1 (keep=
        TranslatedText
        lang
    Name
    label
        );
      set &ds1(rename=(start=TranslatedText));
    by name label ;
    lang="&_cstCLlang";
    run;

  %let ds5=_c5&_cstRandom;
  %let ds6=_c6&_cstRandom;

  data &ds5(keep=sasref name);
  length name $128;
    set &_CSTSOURCECOLUMNS &_CSTSOURCEVALUES;
      name=upcase(xmlcodelist);
      if name ne '';
  run;

  proc sort data=&ds5 nodupkey;
    by name sasref;
  run;

  %* only keep the formats specified in the source_columns and source_values datasets *;
   proc sql;
    create table &ds6 as
   select *
     from &ds5 left join &ds1(rename=name=n) on (upcase(strip(&ds5..name))=upcase(strip(&ds1..n)))
    where &ds5..name ne '' ;
   quit;

%let ds11=_c11&_cstRandom;
  proc sort data=&_cstsourcestudy out=&ds11(keep=studyname sasref);
  by sasref;
  run;
proc sort data=&ds6 out=&ds6;
  by sasref;
  run;

%* match study columns to appropriate source_Study  ;
%let ds2=_c2&_cstRandom;
data &ds2(drop=studyname);
merge &ds6(in=a) &ds11;
by sasref;
stname=upcase(studyname);
if a=1;
run;

%* pick up the fkStudy id from Study;
%let ds3=_c3&_cstRandom;
proc sql ;
  create table &ds3 as
  select strip(&studyds..oid) as fkstudy,
   * from &ds2 left join &_cststudyds(keep=oid studyname) on (upcase(&ds2..stname)=upcase(&studyds..studyname));
  quit;

%* pick up the fk_metadataversion for the study;
%let ds4=_c4&_cstRandom;
 proc sql ;
  create table &ds4 as
  select Strip(&mdvds..oid) as FK_MDV length=128,
   * from &ds3(drop=oid ) left join &_cstmdvds(keep=fk_study oid) on (&mdvds..fk_study=&ds3..fkstudy);
  quit;

  %* pick up the codelist id for given format name and metadataversion;
  %let ds7=_c7&_cstRandom;
 proc sql ;
  create table &ds7 as
  select Strip(&clds..oid) as FK_Clist length=128,
   * from &ds4(drop=oid rename=name=n2 ) left join &_cstcodelistsds(keep=name oid fk_metadataversion)
    on (&clds..fk_metadataversion=&ds4..fk_mdv and upcase(&clds..name)=upcase(&ds4..n));
  quit;

%* pick up the codelist id for given format name and metadataversion;
%let ds8=_c8&_cstRandom;
 proc sql ;
  create table &ds8 as
  select Strip(&clids..oid) as fk_clItem length=128,
   * from &ds7(drop=oid ) left join &_cstcodelistitemsds(drop=rank)
  on (&clids..fk_codelists=&ds7..fk_clist and &clids..codedvalue=&ds7..label);
  quit;

%let ds9=_c9&_cstRandom;
proc sql;
    create table &ds9 as
      select
            &ds8..TranslatedText as TranslatedText length = 2000 label='',
            "&_cstCLlang" as lang length = 17,
      strip(&ds8..oid) as FK_CodeListItems length = 128
  from  &ds8  where fk_codelists ne '';
quit;
run;


%let ds10=_c0&_cstRandom;

  proc append base=&ds10 data=&ds9 force;
    run;
  proc sort data=&ds10   out=&_cstoutclitemdecodetransds nodupkey;
     by lang fk_codelistitems;
     run;

%cleanup:
%exiterr:

%do i=1 %to 11;
 %let d=ds&i;
 %if %symexist(&d)  %then %do;
  %let foo=&&&d;
  %if ("&foo" ne "") %then %do;
   %if %sysfunc(exist(&&&d)) %then %do;
  proc datasets nolist lib=work;
  delete &&&d;
  quit;
  run;
   %end;
  %end;
 %end;
%end;

%exit:

%mend crtdds_clitemdecodetrans;
