**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* Table_14.2.01_nomd.sas                                                         *;
*                                                                                *;
* Module to create Table 14.2.01 (Summary of Demographic and Baseline            *;
* Characteristics), a sample CSR table.                                          *;
* This version does not rely on the presence of supporting TLF metadata          *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%put NOTE: Running Table_14.2.01_nomd.sas;


proc format library=work.formats;
  value agegrp
     low-30 = '<30 years'
     30-45 = '30-45 years'
     46-high = '>45 years';
  invalue $inage
     '<30 years'=1
     '30-45 years'=2
     '>45 years'=3;
  value $race
     'ASIAN'='Asian'
     'BLACK'='Black'
     'CAUCASIAN'='Caucasian'
     'HISPANIC'='Hispanic'
     'OTHER'='Other';
  value $sex
     'M'='Male'
     'F'='Female';
  value $trt
     'TRT A'='Placebo'
     'TRT B'='Low Dose'
     'TRT C'='High Dose'
     'TRT TOT'='Total';
  invalue $intrt
     'TRT A'=1
     'TRT B'=2
     'TRT C'=3
     'TRT TOT'=4;
run;


data work.adsl;
  set &_cstSrcDataLib..adsl (where=(trt01p =: 'TRT' and ittfl="Y"));
  attrib trt01pn format=8. label='Planned treatment (n)'
         agegrp format=$12. label='Age by group'
         agegrpn format=8. label='Age by group (n)';
  if missing(age) then
    agegrp='';
  else
    agegrp=put(age,agegrp.);
  agegrpn=input(agegrp,$inage.);
  trt01pn=input(trt01p,$intrt.);
  output;
  trt01p='TRT TOT';
  trt01pn=input(trt01p,$intrt.);
  output;
run;

proc sort data=work.adsl;
  by trt01pn usubjid;
run;

proc univariate data=work.adsl noprint;
  by trt01pn;
  var age;
  output out=work.age_u n=_cstn mean=_cstmean std=_cststd median=_cstmedian min=_cstmin max=_cstmax;
run;

data work.age (drop=_cstn _cstmean _cststd _cstmedian _cstmin _cstmax);
  set work.age_u;
  format n mean std median min max $14.;
 
 n=put(_cstn,3.);
 mean=put(_cstmean,7.1);
 std=put(_cststd,8.2);
 median=put(_cstmedian,3.);
 min=put(_cstmin,3.);
 max=put(_cstmax,3.);
run;

proc transpose data=work.age out=work.age_t prefix=_cstcol;
  var n mean std median min max;
  id trt01pn;
run;

data work.row1 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
  ;
  set work.age_t;
  
  if _n_=1 then
    rptcolumn='Age (Years)';
  select(_NAME_);
    when('n') rptvalue='n';
    when('mean') rptvalue='Mean';
    when('std') rptvalue='STD';
    when('median') rptvalue='Median';
    when('min') rptvalue='Min';
    when('max') rptvalue='Max';
    otherwise rptvalue=_NAME_;
  end;
run;

proc datasets lib=work nolist;
  delete age age_u age_t;
quit;

  
proc freq data=work.adsl noprint;
  tables trt01pn*agegrpn / outpct out=work.agefreq;
run;
data work.agefreq;
  set work.agefreq (where=(agegrpn ne .));
  length value $20;
  value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));
run;
proc sort data=work.agefreq;
  by agegrpn;
run;
proc transpose data=work.agefreq out=work.agegrp_t (drop=_NAME_) prefix=_cstcol;
  by agegrpn;
  var value;
  id trt01pn;
run;

data work.row2 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
  ;
  set work.agegrp_t;
  
  if _n_=1 then
    rptcolumn='Age';
  select(agegrpn);
    when(1) rptvalue='<30 years';
    when(2) rptvalue='30-45 years';
    when(3) rptvalue='>45 years';
    otherwise;
  end;
run;

proc datasets lib=work nolist;
  delete agefreq agegrp_t;
quit;


proc freq data=work.adsl noprint;
  tables trt01pn*sex / outpct out=work.sexfreq;
run;
data work.sexfreq;
  set work.sexfreq (where=(sex ne ''));
  length value $20;
  value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));
run;
proc sort data=work.sexfreq;
  by sex;
run;
proc transpose data=work.sexfreq out=work.sex_t (drop=_NAME_) prefix=_cstcol;
  by sex;
  var value;
  id trt01pn;
run;

data work.row3 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
  ;
  set work.sex_t;
  
  if _n_=1 then
    rptcolumn='Sex';
  rptvalue=put(sex,$sex.);
run;

proc datasets lib=work nolist;
  delete sexfreq sex_t;
quit;


proc freq data=work.adsl noprint;
  tables trt01pn*race / outpct out=work.racefreq;
run;
data work.racefreq;
  set work.racefreq (where=(race ne ''));
  length value $20;
  value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));
run;
proc sort data=work.racefreq;
  by race;
run;
proc transpose data=work.racefreq out=work.race_t (drop=_NAME_) prefix=_cstcol;
  by race;
  var value;
  id trt01pn;
run;


data work.row4 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
  ;
  set work.race_t;
  
  if _n_=1 then
    rptcolumn='Race';
  rptvalue=put(race,$race.);
run;

proc datasets lib=work nolist;
  delete racefreq race_t;
quit;


data work.blankrow (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
  ;
  call missing(of _all_);
run;  
  
data work.final;
  set work.row1 (in=r1)
      work.blankrow (in=r1)
      work.row2 (in=r2)
      work.blankrow (in=r2)
      work.row3 (in=r3)
      work.blankrow (in=r3)
      work.row4 (in=r4);
  group=sum(r1*1,r2*2,r3*3,r4*4);
run;

proc datasets lib=work nolist;
  delete row1 row2 row3 row4 blankrow;
quit;


%let trtCnt=0;
%let trts=;
%let trt1=0;
%let trt2=0;
%let trt3=0;
%let trt4=0;
%let trt5=0;
%let trt6=0;
%let trt7=0;

%macro trtcount(trtvar=);
  proc sql noprint;
    select count(distinct &trtvar) into :trtCnt
    from work.adsl (where=(missing(&trtvar)=0 and &trtvar =: 'TRT'));
    select distinct (&trtvar) into :trts separated by '|'
    from work.adsl (where=(missing(&trtvar)=0 and &trtvar =: 'TRT'));
  quit;
  %do i=1 %to &trtCnt;
    %let trt&i=0;
  %end;
%mend;

%macro patientcount(trtvar=,flagvar=);
  %trtcount(trtvar=&trtvar);
  %do i=1 %to &trtCnt;
    %let thistrt=%scan(&trts,&i,"|");
    proc sql noprint;
      select cats('(N=',put(count(*),4.),')') into :trt&i
      from work.adsl (where=(&trtvar="&thistrt" and &flagvar="Y"));
    quit;
    %****put trt&i=&&trt&i;
  %end;
%mend;
%patientcount(trtvar=trt01p,flagvar=ittfl);

%let _cstDisplayTOC=;
data _null_;
  select(upcase("&_cstDisplayFormat"));
    when("PDF") call symputx('_cstDisplayTOC','NOTOC');
    otherwise;
  end;
run;

options nodate nonumber ls=132 missing="" formchar="|----|+|---+=|-/\<>*";

ods listing close;
options orientation=landscape;

filename _cstrpt "&_cstDisplayPath";
ods &_cstDisplayFormat file=_cstrpt style=sasweb &_cstDisplayTOC;
ods noproctitle /* proclabel "Table 14.2.01" */ ;

%let _cstTitle1=Table 14.2.01;
%let _cstTitle2=Summary of Demographic and Baseline Characteristics;
%let _cstTitle3=Intent to Treat;
%let _cstFootnote1=Produced by SAS Clinical Standards Toolkit at &_cstrundt;
%let _cstFootnote2=&_cstDisplayCode;

proc report data=work.final nowd spacing=1 /* headline headskip */ split="*" /* contents="" */
       /*    style(report)={just=center outputwidth=10.5 in font_size=8pt} */;
       
       column (/* "--" */ group rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
       define group  /order order=internal noprint;
       define rptcolumn  / display width=14 " ";
       define rptvalue   / display width=12 " ";
       define _cstcol1   / display width=20 "Placebo*&trt1**n(%)";
       define _cstcol2   / display width=20 "Low Dose*&trt2**n(%)";
       define _cstcol3   / display width=20 "High Dose*&trt3**n(%)";
       define _cstcol4   / display width=20 "Total*&trt4**n(%)";
       
       break after group / skip;
       
       title1 "&_cstTitle1";
       title2 "&_cstTitle2";
       title3 "&_cstTitle3";
       footnote1 "&_cstFootnote1 ";
       footnote2 "&_cstFootnote2 ";
run;

ods &_cstDisplayFormat close;
ods listing;
filename _cstrpt;

proc datasets lib=work nolist;
  delete adsl final;
quit;
