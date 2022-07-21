%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_metadataversion                                                         *;
%*                                                                                *;
%* Creates the SAS CRT-DDS MetaDataVersion data set from source metadata.         *;
%*                                                                                *;
%* @param _cstname - required - The /ODM/Study/MetaDataVersion/@Name attribute.   *;
%* @param _cstdescr - required - The /ODM/Study/MetaDataVersion/@Description      *;
%*            attribute.                                                          *;
%* @param _cststandard - required - The /ODM/Study/MetaDataVersion/@StandardName  *;
%*            attribute.                                                          *;
%* @param _cstversion - required - The /ODM/Study/MetaDataVersion/@StandardVersion*;
%*            attribute.                                                          *;
%* @param _cstdefineversion - required - The                                      *;
%*            /ODM/Study/MetaDataVersion/@DefineVersion attribute.                *;
%* @param _cststudyds - required - The Study dataset in the output library        *;
%*            (for example, srcdata.Study).                                       *;
%* @param _cststudyname - required - The value of the Study column in the         *;
%*            _cststudyds data set.                                               *;
%* @param _cstoutmdvds - required - The MetaDataVersion data set to create        *;
%*            (for example, srcdata.MetaDataVersion).                             *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_metadataversion(
    _cstname=,
    _cstdescr=,
    _cststandard=,
    _cstversion=,
    _cstdefineversion=,
    _cststudyds=,
    _cststudyname=,
    _cstoutmdvds=
    ) / des="Creates SAS CRT-DDS MetaDataVersion data set";

%local _cstRandom ds1 ds2 i keycnt key src2 stdyds outdsexists
       rc dsidmd d foo;

%if %length(&_cstname)=0 or %length(&_cstdescr)=0 or %length(&_cststandard)=0
  or %length(&_cstversion)=0 or %length(&_cstdefineversion)=0 or %length(&_cststudyds)=0
  or %length(&_cststudyname)=0 or %length(&_cstoutmdvds)=0
    %then %goto exit;


%if "%nrbquote(%sysfunc(strip(&_cstname)))"="" or "%nrbquote(%sysfunc(strip(&_cstdescr)))"="" or
     "%nrbquote(%sysfunc(strip(&_cstStandard)))"="" or "%nrbquote(%sysfunc(strip(&_cstVersion)))"="" or
     "%nrbquote(%sysfunc(strip(&_cstdefineversion)))"="" or %sysfunc(strip("&_cststudyDS"))="" or
   "%nrbquote(%sysfunc(strip(&_cststudyname)))"="" or %sysfunc(strip("&_cstoutmdvds"))=""
    %then %goto exit;

%if ^%sysfunc(exist(&_cstStudyDS)) %then %goto exit;

 %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_m&_cstRandom;
  %let ds2=_m2&_cstRandom;
  %let keycnt=1;
  %let key=0;


%* need to check if 2 level name passed in  *;
  %if %symexist(_cststudyDS) %then %do;
      %if (%sysfunc(indexc("&_cststudyDS",'.'))=0 )%then %let stdyds=&_cststudyDS;
      %else %do;
        %let src2=%scan(&_cststudyDS,2,'.');
    %let stdyds=&src2;
    %end;
  %end;
  %else %goto exit;
 %if %symexist(_cstoutmdvds) %then %do;
    %if %sysfunc(exist(&_cstoutmdvds)) %then %do;
        %let outdsexists=1;
      %let dsidmd=%sysfunc(open(&_cstoutmdvds,i));
      %if &dsidmd>0 %then %do;
        %let key=%sysfunc(attrn(&dsidmd, nlobs));
        %let rc=%sysfunc(close(&dsidmd));
       %end;
      data _null_;
      keycnt=strip(sum(&key,1));
      call symput('keycnt',keycnt);
      run;
        %end;
    %else %let outdsexists=0;
  %end;
  %else %goto exit;


  proc sql;
  create table &ds1 as
  select
      strip("MDV.&keycnt") as OID length=128,
      "&_cstname" as Name length=128,
      "&_cstdescr" as Description length=2000,
      "" as IncludedOID length=128,
      "" as IncludedStudyOID length=128,
      strip("&_cstdefineversion") as  DefineVersion length=2000,
      strip("&_cstStandard") as  StandardName length=2000,
      strip("&_cstVersion") as StandardVersion length=2000,
      &stdyds..oid as FK_Study length=128
    from &_cststudyDS
    where ( upcase(studyname) = upcase("&_cststudyname"));
    quit;

    %if &outdsexists=1 and &key^=0 %then %do;
       data &ds2;
        set &_cstoutmdvds;
       run;
    %end;

    proc append base=&ds2 data=&ds1 force;
    run;
    proc sort data=&ds2 out=&_cstoutmdvds nodupkey;
      by standardname standardversion fk_study;
    run;

%do i=1 %to 2;
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

%mend crtdds_metadataversion;
