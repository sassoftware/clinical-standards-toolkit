%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_itemgroupdefitemrefs                                                    *;
%*                                                                                *;
%* Creates the SAS CRT-DDS ItemGroupDefItemRefs data set from source metadata.    *;
%*                                                                                *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column metadata for the Domain columns to include in the CRT-DDS   *;
%*             file.                                                              *;
%* @param  _cstSourceTables - required - The data set that contains the SDTM      *;
%*             table metadata for the domains to include in the CRT-DDS file.     *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param _cstitemdefsds2 - required - The temporary ItemDefs2 data set (for      *;
%*            example, work.ItemDefs2) as created by the crtdds_itemdefs macro.   *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*            library (for example, srcdata.MetaDataVersion).                     *;
%* @param _cstitemgroupdefsds - required - The ItemGroupDefs data set in the      *;
%*            output library (for example, srcdata.ItemGroupDefs).                *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*            (for example, srcdata.Study).                                       *;
%* @param _cstoutitemgroupdefitemrefsds - required - The ItemGroupDefItemRefs     *;
%*            data set to create (for example, srcdata.ItemDefs).                 *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_itemgroupdefitemrefs(
    _cstsourcecolumns=,
    _cstsourcetables=,
    _cstsourcestudy=,
    _cstitemdefsds2=,
    _cstmdvds=,
    _cstitemgroupdefsds=,
    _cststudyds=,
    _cstoutitemgroupdefitemrefsds=
    ) / des="Creates SAS CRT-DDS ItemGroupDefItemRefs data set";

%local _cstRandom ds0 ds1 ds2 ds3 ds4 ds5 ds6;
  %if %sysfunc(strip("&_cstsourcecolumns"))="" or %sysfunc(strip("&_cstsourcetables"))="" or %sysfunc(strip("&_cstsourcestudy"))="" or %sysfunc(strip("&_cststudyds"))=""
    or %sysfunc(strip("&_cstmdvDS"))=""  or %sysfunc(strip("&_cststudyds"))=""  or %sysfunc(strip("&_cstitemgroupdefsds"))=""
  or %sysfunc(strip("&_cstitemdefsds2"))=""  or %sysfunc(strip("&_cstoutitemgroupdefitemrefsds"))=""
  %then %goto exit;

%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcetables)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cststudyds)) %then %goto exit;
%if ^%sysfunc(exist(&_cstitemdefsds2)) %then %goto exit;
%if ^%sysfunc(exist(&_cstitemgroupdefsds)) %then %goto exit;

  %let keycnt=1;
%* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
%if %symexist(_cstsourcetables) %then %do;
      %if (%sysfunc(indexc("&_cstsourcetables",'.'))=0 )%then %let srctblds=&_cstsourcetables;
      %else %do;
        %let src2=%scan(&_cstsourcetables,2,'.');
    %let srctblds=&src2;
    %end;
  %end;

%if %symexist(_cstsourcecolumns) %then %do;
      %if (%sysfunc(indexc("&_cstsourcecolumns",'.'))=0 )%then %let srccolds=&_cstsourcecolumns;
      %else %do;
        %let srccol2=%scan(&_cstsourcecolumns,2,'.');
    %let srccolds=&srccol2;
    %end;
  %end;

  %if %symexist(_cstitemgroupdefsDS) %then %do;
      %if (%sysfunc(indexc("&_cstitemgroupdefsDS",'.'))=0) %then %let igdds=&_cstitemgroupdefsDS;
    %else %do;
        %let igd2=%scan(&_cstitemgroupdefsDS,2,'.');
    %let igdds=&igd2;
    %end;
  %end;
  %if %symexist(_cstitemdefsds2) %then %do;
      %if (%sysfunc(indexc("&_cstitemdefsds2",'.'))=0) %then %let idds=&_cstitemdefsds2;
    %else %do;
        %let id2=%scan(&_cstitemdefsds2,2,'.');
    %let idds=&id2;
    %end;
  %end;

  %if %symexist(_cststudyds) %then %do;
      %if (%sysfunc(indexc("&_cststudyds",'.'))=0) %then %let stdyds=&_cststudyds;
    %else %do;
        %let stdy2=%scan(&_cststudyds,2,'.');
    %let stdyds=&stdy2;
    %end;
  %end;

%if %symexist(_cstsourcestudy) %then %do;
      %if (%sysfunc(indexc("&_cstsourcestudy",'.'))=0) %then %let srcstdyds=&_cstsourcestudy;
    %else %do;
        %let srcstdy2=%scan(&_cstsourcestudy,2,'.');
    %let srcstdyds=&srcstdy2;
    %end;
  %end;

  %if %symexist(_cstmdvds) %then %do;
      %if (%sysfunc(indexc("&_cstmdvds",'.'))=0) %then %let mdds=&_cstmdvds;
    %else %do;
        %let md2=%scan(&_cstmdvds,2,'.');
    %let mdds=&md2;
    %end;
  %end;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds0=_d0&_cstRandom;
  %let ds1=_d1&_cstRandom;
  %let ds2=_d2&_cstRandom;
  %let ds3=_d3&_cstRandom;
  %let ds4=_d4&_cstRandom;
  %let ds5=_d5&_cstRandom;
  %let ds6=_d6_src_col&_cstRandom;

   data &ds6;
   set &_cstsourcecolumns;
   col_order=_n_;
   run;

proc sql;
  create table &ds0 as
  select  * from &ds6 left join &_cstsourcestudy(rename=sasref=sref drop=Standard StandardVersion)
  on (
    strip(upcase(&ds6..sasref))= strip(upcase(&srcstdyds..sref))
    );

    %* add the study foreign key *;
    create table &ds1 as
      select
    ifc(upcase(&ds0..core)='REQ','Yes','No')
         as Mandatory length = 3,
        &ds0..order as OrderNumber length = 8,
        . as KeySequence length = 8,
        "" as ImputationMethodOID length = 128,
        &ds0..role length = 128,
        "" as RoleCodeListOID length = 128,
      catx(' ', &ds0..standard,&ds0..standardversion) as mdName,
       &stdyds..OID as fk_study length=128,
       &ds0..sasref,
       &ds0..column,
       &ds0..table,
       &ds0..col_order
        from &ds0
      left join &_cststudyds
      on strip(upcase(&ds0..studyname))=strip(upcase(&stdyds..studyname))
      ;

    %* add the metadata foreign key *;
      create table &ds2 as
      select &ds1..fk_study length=128,
       &ds1..mandatory,
       &ds1..ordernumber,
       &ds1..imputationmethodoid,
       &ds1..role,
       &ds1..rolecodelistoid,
       strip(&mdds..OID) as fk_MetaDataVersion,
       &ds1..sasref,
       &ds1..column,
       &ds1..mdName,
       &ds1..table,
       &ds1..col_order
        from &ds1
      left join &_cstmdvds
      on &ds1..fk_study=&mdds..fk_study
      ;


 %* create table from source_columns info *;
   create table &ds3 as
   select
      &idds..OID as ItemOID length = 128,
      &ds2..mandatory,
    &ds2..ordernumber,
    &ds2..imputationmethodoid,
    &ds2..role,
    &ds2..rolecodelistoid,
    &ds2..fk_study,
    &ds2..fk_metadataversion,
    &ds2..mdName,
      &idds..Table length = 128,
    &idds..NAME as column,
      &ds2..SASref  as sasref1 length = 8,
      &ds2..col_order
   from
      &ds2 left join &_cstitemdefsds2
         on
         (
            strip(upcase(&idds..Name)) = strip(upcase(&ds2..column))
            and strip(upcase(&idds..table)) = strip(upcase(&ds2..table))
      and strip(upcase(&idds..fk_metadataversion))=strip(upcase(&ds2..fk_metadataversion))
         )
   where
      strip(upcase(&idds..Name)) = strip(upcase(&ds2..column)) ;

     %* add the table keys to generate keysequence *;
        create table &ds4 as
         select
       &srctblds..keys,
       &ds3..itemoid,
       &ds3..mandatory,
       &ds3..ordernumber,
       &ds3..imputationmethodoid,
       &ds3..role,
       &ds3..rolecodelistoid,
       &ds3..sasref1,
       &ds3..fk_study,
       &ds3..fk_metadataversion,
       &ds3..column,
       &ds3..table,
       &ds3..col_order
    from &ds3
     left join
        &_cstsourcetables
         on
         (
            &ds3..SASref1 = &srctblds..SASref
            and &ds3..table = &srctblds..table
         )
    ;

    %* add the foreign key to itemgroupdefs *;
    create table &ds5 as
       select
       &ds4..Keys,
       &ds4..Itemoid,
       &ds4..Mandatory,
       &ds4..OrderNumber,
       &ds4..Imputationmethodoid,
       &ds4..Role,
       &ds4..Rolecodelistoid,
       &ds4..Sasref1,
       &ds4..Column,
       &ds4..FK_Study,
       &ds4..FK_MetadataVersion,
       &ds4..Table,
       strip(&igdds..OID) as FK_ItemGroupDefs length = 128,
       &ds4..col_order
    from &ds4
        left join
        &_cstitemgroupdefsDS
         on
         (
            &ds4..Table = &igdds..Name
      and &ds4..fk_metadataversion=&igdds..fk_metadataversion
    )
    order by col_order
   ;
quit;




%* generate the keysequence *;
data &_cstoutitemgroupdefitemrefsds(drop=table sasref1 fk_study fk_metadataversion keys column col_order i);
  set &_cstoutitemgroupdefitemrefsds &ds5;
  KeySequence=.;
  if indexw(keys,column) then do;
    do i = 1 to countw(keys,' ');
      if column = scan(keys,i) then do;
        KeySequence=i;
        leave;
      end;
    end;
  end;
run;

%cleanup:
%exiterr:

%do i=0 %to 6;
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

%mend crtdds_itemgroupdefitemrefs;
