%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_itemgroupleaf                                                           *;
%*                                                                                *;
%* Creates the SAS CRT-DDS ItemGroupLeaf data set from source metadata.           *;
%*                                                                                *;
%* @param  _cstSourceTables - required - The data set that contains the SDTM      *;
%*             table metadata for the domains to include in the CRT-DDS file.     *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*             (for example, srcdata.Study).                                      *;
%* @param _cstmdvDS - required - The MetaDataVersion dataset in the output        *;
%*             library (for example,  srcdata.MetaDataVersion).                   *;
%* @param _cstoutitemgroupleafds - required - The ItemGroupLeaf data set to       *;
%*             create (for example, srcdata.ItemGroupLeaf).                       *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_itemgroupleaf(
    _cstsourcetables=,
    _cstsourcestudy=,
    _cststudyds=,
    _cstmdvDS=,
    _cstoutitemgroupleafds=
    ) / des="Creates SAS CRT-DDS ItemGroupLeaf data set";

%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6;
%if %length(&_cstsourcetables)=0 or %length(&_cstsourcestudy)=0 or %length(&_cststudyds)=0
  or %length(&_cstmdvDS)=0 or %length(&_cstoutitemgroupleafds)=0
    %then %goto exit;


%if ^%sysfunc(exist(&_cstStudyDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcetables)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;


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
  %if %symexist(_cstoutitemgroupleafds) %then %do;
      %if %sysfunc(indexc("&_cstoutitemgroupleafds",'.'))=0 %then %let iglds=&_cstoutitemgroupleafds;
      %else %do;
        %let igl2=%scan(&_cstoutitemgroupleafds,2,'.');
    %let iglds=&igl2;
    %end;
  %end;

  %let ds5=_i5&_cstRandom;
  data &ds5;
  set &_cstsourcetables;
  if kstrip(xmlpath) ne '';
  tbl_order=_n_;
  run;
  proc sql noprint;
      select count(table) into :akey from &ds5
      quit;
      run;

%if &akey<=0 %then %goto cleanup;

proc sql;
  create table &ds1 as
  select
   &ds5..sasref,
   &ds5..table as table length = 128,
   &ds5..xmlpath as href length = 512,
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


data &_cstoutitemgroupleafds(keep=id href fk_itemgroupdefs);
length ID $128 FK_ItemGroupDefs $ 128;
set &_cstoutitemgroupleafds &ds4(drop=oid);
ID="Location."||kstrip(kcompress(table));
FK_ItemGroupDefs="IG."||kstrip(kcompress(table));
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
%mend crtdds_itemgroupleaf;
