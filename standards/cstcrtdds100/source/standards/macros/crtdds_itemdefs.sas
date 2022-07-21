%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_itemdefs                                                                *;
%*                                                                                *;
%* Creates the SAS CRT-DDS ItemDefs data set from source metadata.                *;
%*                                                                                *;
%* Two output tables are generated: one for itemdefs and one for a copy of        *;
%* itemdefs with an extra variable TABLE, which is used in the                    *;
%* crtdds_itemgroupdefitemref macro.                                              *;
%*                                                                                *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column metadata for the Domain columns to include in the CRT-DDS   *;
%*             file.                                                              *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%* @param _cststudyds - required - The Study data set in the output library       *;
%*            (for example, srcdata.Study).                                       *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*             library (for example, srcdata.MetaDataVersion).                    *;
%* @param _cstcodelistsds - required - The CodeLists data set in the output       *;
%*             library (for example, srcdata.CodeLists).                          *;
%* @param _cstoutitemdefsds - required - The ItemDefs output data set to create   *;
%*            (for example, srcdata.ItemDefs).                                    *;
%* @param _cstoutitemdefsds2 - required - The temporary ItemDefs data set to      *;
%*            create (for example, work.ItemDefs2).                               *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_itemdefs(
    _cstsourcecolumns=,
    _cstsourcestudy=,
    _cststudyds=,
    _cstmdvds=,
    _cstcodelistsDS=,
    _cstoutitemdefsds=,
    _cstoutitemdefsds2=
    ) / des="Creates SAS CRT-DDS ItemDefs data set";

%local _cstRandom ds1 ds2 ds3 ds4 ds5 ds6 ds7 ds8 ds9;

%if %length(&_cstsourcecolumns)=0 or %length(&_cstsourcestudy)=0 or %length(&_cststudyds)=0
  or %length(&_cstmdvds)=0 or %length(&_cstoutitemdefsds)=0 or %length(&_cstoutitemdefsds2)=0
    %then %goto exit;
/* note, it is ok if the codelistsDS is not passed in, Codelists are not required */
%if ^%length(&_cstcodelistsds)=0 %then %LET nocodelist=0;
%else %let nocodelist=1;


%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;
%if ^%sysfunc(exist(&_cststudyds)) %then %goto exit;
/* codelists are not required*/
%if ^%sysfunc(exist(&_cstcodelistsds)) %then %LET nocodelist=1;
%else %let nocodelist=0;

%* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
    %if %symexist(_cstsourcecolumns) %then %do;
      %if (%sysfunc(indexc("&_cstsourcecolumns",'.'))=0 )%then %let srccollds=&_cstsourcecolumns;
      %else %do;
        %let srccol2=%scan(&_cstsourcecolumns,2,'.');
    %let srccolds=&srccol2;
    %end;
  %end;

  %if %symexist(_cstsourcestudy) %then %do;
      %if (%sysfunc(indexc("&_cstsourcestudy",'.'))=0 )%then %let srcstdyds=&_cstsourcestudy;
      %else %do;
        %let src2=%scan(&_cstsourcestudy,2,'.');
    %let srcstdyds=&src2;
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

   %if &nocodelist=0 and  %symexist(_cstcodelistsDS) %then %do;
      %if (%sysfunc(indexc("&_cstcodelistsDS",'.'))=0) %then %let clds=&_cstcodelistsDS;
    %else %do;
        %let cl2=%scan(&_cstcodelistsDS,2,'.');
    %let clds=&cl2;
    %end;
    %let clexist=0;
    %if (%sysfunc(exist(&_cstcodelistsDS))) %then %do;
      %let dsidcl=%sysfunc(open(&_cstcodelistsDS,i));
           %if &dsidcl>0 %then %do;
            %let n=%sysfunc(attrn(&dsidcl, nlobs));
            %if &n<=0 %then %let clexist=1;
       %end;
       %let rc=%sysfunc(close(&dsidcl));
    %end;
  %end;

  %if %symexist(_cstoutitemdefsds2) %then %do;
      %if %sysfunc(indexc("&_cstoutitemdefsds2",'.'))=0 %then %let idds2=&_cstoutitemdefsds2;
      %else %do;
        %let id22=%scan(&_cstoutitemdefsds2,2,'.');
    %let idds2=&id22;
    %end;
  %end;

  %if %symexist(_cstoutitemdefsds) %then %do;
      %if %sysfunc(indexc("&_cstoutitemdefsds",'.'))=0 %then %let idds=&_cstoutitemdefsds;
      %else %do;
        %let id2=%scan(&_cstoutitemdefsds,2,'.');
    %let idds=&id2;
    %end;
  %end;
%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds4=_c4&_cstRandom;
%let ds5=_c5&_cstRandom;
proc sort data=&_cstsourcecolumns out=&ds4; by sasref;
run;
proc sort data=&_cstsourcestudy out=&ds5; by sasref;
run;

%let ds1=_c1&_cstRandom;
data &ds1(drop=studyname);
merge &ds4(in=a) &ds5(keep=studyname sasref);
by sasref;
col_order=_n_;
stname=studyname;
if a=1;
run;

%* pick up the fkStudy id from Study;
%let ds2=_c2&_cstRandom;
proc sql ;
  create table &ds2 as
  select strip(&stdyds..oid) as fkstudy,
   * from &ds1 left join &_cststudyds(keep=oid studyname) on (upcase(&ds1..stname)=upcase(&stdyds..studyname));
  quit;

%* pick up the fk_metadtaversion for the study;
%let ds3=_c3&_cstRandom;
 proc sql ;
  create table &ds3 as
  select Strip(&mdds..oid) as FK_MDV length=128,
   * from &ds2(drop=oid ) left join &_cstmdvds(keep=fk_study oid) on (upcase(&mdds..fk_study)=upcase(&ds2..fkstudy));
  quit;
/* codelists are not required*/
%if &nocodelist=1 %then %do;
  %let stmt1="" as CodeListRef length=128,;
  %let stmt2=from &ds3 ;
%end;
%else %do;
  %let stmt1=strip(upcase(&ds3..xmlcodelist)) as CodeListRef length = 128, ;
  %let stmt2=from &ds3 left join &_cstcodelistsds on (upcase(&ds3..xmlcodelist)=upcase(&clds..name) and upcase(&ds3..fk_mdv)=upcase(&clds..fk_metadataversion));
%end;
 %let ds6=_i6&_cstRandom;
proc sql;
  create table &ds6 as
  select
      '' as OID length=128 ,
      &ds3..column as  Name length=128,
      &ds3..xmldatatype as DataType length = 8,
      case when &ds3..xmldatatype in ('text' 'string' 'integer' 'float')
        then &ds3..length
        else .
      end as Length length = 8,
      . as SignificantDigits length = 8,
      ifc(length(&ds3..column) le 8, &ds3..column, "") as SASFieldName length = 8,
      "" as SDSVarName length = 8,
      &ds3..origin as Origin length = 2000,
      &ds3..comment as Comment length = 2000,
      &stmt1
      &ds3..label as Label length = 2000,
      &ds3..displayformat as DisplayFormat length = 2000,
      &ds3..algorithm as ComputationMethodOID length = 128,
      &ds3..sasref ,
      &ds3..table ,
      &ds3..fk_study as fk_study length=128,
      &ds3..fk_mdv as FK_MetaDataVersion length = 128,
      &ds3..col_order
      &stmt2
      order by col_order ;
;
quit;
data &_cstoutitemdefsds(drop=sasref fk_study table col_order) &_cstoutitemdefsds2(drop=sasref fk_study col_order);
  set &_cstoutitemdefsds &ds6;
  if ComputationMethodOID ne '' then
    ComputationMethodOID=catx(".", "CM", table, name);
  if CodeListRef ne '' then CodeListRef = cats("CL.", CodeListRef);
  OID=catx(".", "IT", table, name);
  if DataType="float" and missing(SignificantDigits) and not missing(DisplayFormat) and index(DisplayFormat, ".") 
    then SignificantDigits=input(scan(DisplayFormat, 2, "."), ? best.); 
RUN;

%cleanup:
%exiterr:
%do i=1 %to 8;
 %let d=ds&i;
 %if %symexist(&d) %then %do;
  %let foo=&&&d;
  %if "&foo" ne "" %then %do;
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

%mend crtdds_itemdefs;
