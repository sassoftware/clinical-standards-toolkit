%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_computationmethods                                                      *;
%*                                                                                *;
%* Creates the SAS CRT-DDS ComputationMethods data set from source metadata.      *;
%*                                                                                *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column metadata for the Domain columns to include in the CRT-DDS   *;
%*             file.                                                              *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*            library (for example, srcdata.MetaDataVersion).                     *;
%* @param _cstitemdefsds - required - The ItemDefs data set in the output library *;
%*            (for example, srcdata.ItemDefs).                                    *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*            (for example, srcdata.Study).                                       *;
%* @param _cstoutcomputationmethodsds - required - The ComputationMethods data    *;
%*             set to create (for example, srcdata.ComputationMethods).           *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_computationmethods(
    _cstsourcecolumns=,
    _cstsourcestudy=,
    _cstmdvds=,
    _cstitemdefsds=,
    _cststudyds=,
    _cstoutcomputationmethodsds=
    ) / des="Creates SAS CRT-DDS ComputationMethods data set";

%if %sysfunc(strip("&_cstsourcecolumns"))="" or %sysfunc(strip("&_cstmdvds"))=""
    or %sysfunc(strip("&_cstoutcomputationmethodsds"))="" or %sysfunc(strip("&_cstitemdefsds"))=""
  or %sysfunc(strip("&_cststudyds"))="" or %sysfunc(strip("&_cstsourcestudy"))=""
  %then %goto exit;

%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;
%if ^%sysfunc(exist(&_cstitemdefsds)) %then %goto exit;
%if ^%sysfunc(exist(&_cststudyds)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%* check to see if there are any algorithms defined for source columns;

  proc sql noprint;
    select count(distinct algorithm) into :cnt
          from &_cstsourcecolumns
          where (strip(algorithm) ne "");
  quit;
%if &cnt le 0 %then %goto  exit;

%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6;
 %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_i1&_cstRandom;
  %***let keycnt=1;
  %* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
  %if %symexist(_cstsourcecolumns) %then %do;
      %if (%sysfunc(indexc("&_cstsourcecolumns",'.'))=0 )%then %let srccols=&_cstsourcecolumns;
      %else %do;
        %let src2=%scan(&_cstsourcecolumns,2,'.');
    %let srccols=&src2;
    %end;
  %end;

   %if %symexist(_cstsourcestudy) %then %do;
      %if (%sysfunc(indexc("&_cstsourcestudy",'.'))=0 )%then %let srcstdyds=&_cstsourcestudy;
      %else %do;
        %let src2=%scan(&_cstsourcestudy,2,'.');
    %let srcstdyds=&src2;
    %end;
  %end;
  %if %symexist(_cstitemdefsds) %then %do;
      %if (%sysfunc(indexc("&_cstitemdefsds",'.'))=0 )%then %let itemdefsds=&_cstitemdefsds;
      %else %do;
        %let id2=%scan(&_cstitemdefsds,2,'.');
    %let idds=&id2;
    %end;
  %end;

  %if %symexist(_cststudyDS) %then %do;
      %if (%sysfunc(indexc("&_cststudyDS",'.'))=0 )%then %let stdyds=&_cststudyDS;
      %else %do;
        %let src2=%scan(&_cststudyDS,2,'.');
    %let stdyds=&src2;
    %end;
  %end;
      %if %symexist(_cstmdvds) %then %do;
      %if (%sysfunc(indexc("&_cstmdvds",'.'))=0) %then %let mdds=&_cstmdvds;
    %else %do;
        %let md2=%scan(&_cstmdvds,2,'.');
    %let mdds=&md2;
    %end;
  %end;
  %if %symexist(_cstoutcomputationmethodsds) %then %do;
      %if %sysfunc(indexc("&_cstoutcomputationmethodsds",'.'))=0 %then %let cmds=&_cstoutcomputationmethodsds;
      %else %do;
        %let cm=%scan(&_cstoutcomputationmethodsds,2,'.');
    %let cmds=&cm;
    %end;
  %end;
/*
 %if %symexist(cmds) %then %do;
    %if %sysfunc(exist(&_cstoutcomputationmethodsds)) %then %do;
      proc sql noprint;
      select max(input(oid,8.)) into :key from &_cstoutcomputationmethodsds
      quit;
      data _null_;
      keycnt=strip(sum(&key,1));
      call symput('keycnt',keycnt);
      run;
      %let outDSexists=1;
    %end;
    %else %let outDSexists=0;
  %end;
*/
%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds4=_m4&_cstRandom;
%let ds5=_m5&_cstRandom;
proc sort data=&_cstsourcecolumns(where=(algorithm ne '')) out=&ds4; by sasref;
run;
proc sort data=&_cstsourcestudy out=&ds5; by sasref;
run;

%let ds1=_m1&_cstRandom;
data &ds1(drop=studyname);
merge &ds4(in=a) &ds5(keep=studyname sasref);
by sasref;
col_order=_n_;
stname=studyname;
if a=1;
run;

%* pick up the fkStudy id from Study;
%let ds2=_m2&_cstRandom;
proc sql ;
  create table &ds2 as
  select strip(&stdyds..oid) as fkstudy,
   * from &ds1 left join &_cststudyds(keep=oid studyname) on (&ds1..stname=&stdyds..studyname);
  quit;

%* pick up the fk_metadtaversion for the study;
%let ds3=_m3&_cstRandom;
 proc sql ;
  create table &ds3 as
  select Strip(&mdds..oid) as FK_MDV length=128,
   * from &ds2(drop=oid ) left join &_cstmdvds(keep=fk_study oid) on (&mdds..fk_study=&ds2..fkstudy);
  quit;

%* pick up which columns have a computation method defined;
%let ds6=_m6&_cstRandom;

data &_cstoutcomputationmethodsds(keep= OID method fk_metadataversion);
  set &_cstoutcomputationmethodsds &ds3;
  OID=catx(".", "CM", table, column);
  method=algorithm;
  fk_metadataversion=fk_mdv;
RUN;

%cleanup:
%exiterr:
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

%mend crtdds_computationmethods;
