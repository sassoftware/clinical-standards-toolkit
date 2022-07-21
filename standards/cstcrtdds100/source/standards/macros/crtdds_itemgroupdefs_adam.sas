%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_itemgroupdefs_adam                                                      *;
%*                                                                                *;
%* Creates the SAS CRT-DDS ItemGroupDefs data set from source metadata.           *;
%*                                                                                *;
%* This macro is ADaM-specific because ADaM does not have the Domain attribute.   *;
%*                                                                                *;
%* @param  _cstSourceTables - required - The data set that contains the SDTM      *;
%*             table metadata for the domains to include in the CRT-DDS file.     *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*            (for example, srcdata.Study).                                       *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*            library (for example, srcdata.MetaDataVersion).                     *;
%* @param _cstoutitemgroupdefsds - required - The ItemGroupDefs data set to       *;
%*            create (for example, srcdata.ItemGroupDefs).                        *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_itemgroupdefs_adam(
    _cstsourcetables=,
    _cstsourcestudy=,
    _cststudyds=,
    _cstmdvDS=,
    _cstoutitemgroupdefsds=
    ) / des="Creates SAS CRT-DDS ItemGroupDefs data set";

%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6;
%if %length(&_cstsourcetables)=0 or %length(&_cstsourcestudy)=0 or %length(&_cststudyds)=0
  or %length(&_cstmdvDS)=0 or %length(&_cstoutitemgroupdefsds)=0
    %then %goto exit;


%if ^%sysfunc(exist(&_cstStudyDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcetables)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvds)) %then %goto exit;

 %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_i1&_cstRandom;
  %let keycnt=1;
%* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
 %if %symexist(_cstsourcetables) %then %do;
      %if (%sysfunc(indexc("&_cstsourcetables",'.'))=0 )%then %let srctblds=&_cstsourcetables;
      %else %do;
        %let src2=%scan(&_cstsourcetables,2,'.');
    %let srctblds=&src2;
    %end;
  %end;
 %if %symexist(_cstsourcestudy) %then %do;
      %if (%sysfunc(indexc("&_cstsourcestudy",'.'))=0 )%then %let srcstudyds=&_cstsourcestudy;
      %else %do;
        %let srcst2=%scan(&_cstsourcestudy,2,'.');
    %let srcstudyds=&srcst2;
    %end;
  %end;
 %if %symexist(_cststudyds) %then %do;
      %if (%sysfunc(indexc("&_cststudyds",'.'))=0 )%then %let studyds=&_cststudyds;
      %else %do;
        %let studyds2=%scan(&_cststudyds,2,'.');
    %let studyds=&studyds2;
    %end;
  %end;

  %if %symexist(_cstmdvDS) %then %do;
      %if (%sysfunc(indexc("&_cstmdvDS",'.'))=0) %then %let mdvds=&_cstmdvds;
    %else %do;
        %let mdv2=%scan(&_cstmdvDS,2,'.');
    %let mdvds=&mdv2;
    %end;
  %end;
  %if %symexist(_cstoutitemgroupdefsds) %then %do;
      %if %sysfunc(indexc("&_cstoutitemgroupdefsds",'.'))=0 %then %let igdds=&_cstoutitemgroupdefsds;
      %else %do;
        %let igd2=%scan(&_cstoutitemgroupdefsds,2,'.');
    %let igdds=&igd2;
    %end;
  %end;

  %let ds5=_i5&_cstRandom;
  data &ds5;
  set &_cstsourcetables;
  tbl_order=_n_;
  run;

proc sql;
  create table &ds1 as
  select
   &ds5..sasref,
   &ds5..table as Name length = 128,
   ifc(indexw(upcase(strip(reverse(&ds5..keys))),"DIJBUSU")>1 , "Yes","No") as Repeating length = 3,
   ifc(INDEXW(UPCASE(&ds5..keys) ,"USUBJID"),'No','Yes') as IsReferenceData length = 3,
    ifc(length(&ds5..table) le 8, &ds5..table, "") as SASDatasetName length = 8,
    "" as Domain length = 2000,
    "" as Origin length = 2000,
    "" as Role length = 128,
   &ds5..Purpose  as Purpose length = 2000,
   &ds5..Comment as Comment length = 2000,
   &ds5..Label as Label length = 2000,
   &ds5..Class as Class length = 2000,
   &ds5..Structure as Structure length = 2000,
   tranwrd(compbl(strip(&ds5..Keys)),' ' ,', ' ) as DomainKeys length = 2000,
   "-" as ArchiveLocationID length = 128,
   &ds5..xmlPath as xmlPath length=2000,
   &srcstudyds..StudyName as stname,
   &ds5..tbl_order
from
&_cstsourcestudy left join &ds5
on ( &ds5..sasref= &srcstudyds..sasref);
quit;

 %let ds3=_i3&_cstRandom;
proc sql ;
  create table &ds3 as
  select strip(&studyds..oid) as fkstudy,
   * from &ds1 left join &_cststudyds(keep=oid studyname) on (&ds1..stname=&studyds..studyname);
  quit;

%let ds4=_i4&_cstRandom;
 proc sql ;
  create table &ds4 as
  select Strip(&mdvds..oid) as FK length=128,
   * from &ds3(drop=oid ) left join &_cstmdvds(keep=fk_study oid) on (&mdvds..fk_study=&ds3..fkstudy)
  order by tbl_order;
;
  quit;



data &_cstoutitemgroupdefsds(drop=fk fkstudy fk_study studyname stname sasref tbl_order xmlPath);
length OID $128 FK_MetaDataVersion $128;
set &_cstoutitemgroupdefsds &ds4(drop=oid);
FK_MetaDataVersion=strip(fk);
OID="IG."||kstrip(kcompress(Name));
if kstrip(xmlPath) ne '' then ArchiveLocationID="Location."||Strip(kcompress(Name));
else ArchiveLocationID='-'; /* no archive location found, must be a nonnull character*/
RUN;

%cleanup:
%do i=1 %to 6;
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

%mend crtdds_itemgroupdefs_adam;
