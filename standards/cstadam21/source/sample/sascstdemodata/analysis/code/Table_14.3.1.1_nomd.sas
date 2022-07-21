**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* Table_14.3.1.1_nomd.sas                                                        *;
*                                                                                *;
* Module to create Table_14.3.1.1 (Incidence of Treatment-Emergent Adverse       *;
* Events by System Organ Class and Preferred Term), a sample CSR table.          *;
* This version does not rely on the presence of supporting TLF metadata          *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%put NOTE: Running Table_14.3.1.1_nomd.sas;


proc format library=work.formats;
  value $trt
     'TRT A'='Placebo'
     'TRT B'='Low Dose'
     'TRT C'='High Dose'
     'TRT TOT'='Total';
  invalue intrt
     'TRT A'=1
     'TRT B'=2
     'TRT C'=3
     'TRT TOT'=4;
  value $stfmt
     'xx'='2.'
     'xxx'='3.'
     'xxx.'='3.0'
     'xx.x'='7.1'
     'x.xx'='8.2'
     'yyy.y'='7.1'
     other='12.3';    
run;

data work.adsl (drop=trt01pn);
  set &_cstSrcDataLib..adsl (rename=(trt01p=trtp) where=(trtp =: 'TRT' and saffl="Y"));
  attrib trtpn format=8. label='Planned treatment (n)';
  trtpn=input(trtp,intrt.);
  output;
  trtp='TRT TOT';
  trtpn=input(trtp,intrt.);
  output;
run;

proc sort data=work.adsl;
  by trtpn usubjid;
run;

**************************;
* Start row 1 processing *;
**************************;

proc sql noprint;
  create table work.adslcnt as
    select count(*) as patcntN, trt01p as trtp length=40 format=$40. label='Description of Planned Arm'
    from &_cstSrcDataLib..adsl (where=(trt01p =: 'TRT' and saffl="Y"))
    group by trt01p 
    order by trt01p;
  create table work.aefreq as
    select count(*) as anyae, trtp
    from srcdata.adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y"))
    group by trtp 
    order by trtp;
  create table work.aefreq2 as
    select count(distinct usubjid) as patcnt, trtp 
    from (
      select count(usubjid) as patae, trtp, usubjid
      from srcdata.adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y"))
      group by trtp, usubjid) 
    group by trtp 
    order by trtp;
quit;

data work.aefreq3 (drop=anyae_sd patcnt_sd patcntN_sd);
  merge work.aefreq
        work.aefreq2
        work.adslcnt end=last;
    by trtp;
  attrib trtpn format=8. label='Planned treatment (n)'
         value format=$char16.;
  retain anyae_sd patcnt_sd patcntN_sd 0;
  if trtp ne 'TRT A' then 
  do;
    anyae_sd=anyae_sd+anyae;
    patcnt_sd=patcnt_sd+patcnt;
    patcntN_sd=patcntN_sd+patcntN;
  end;
  value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
  trtpn=input(trtp,intrt.);
  output;
  if last then do;
    anyae=anyae_sd;
    patcnt=patcnt_sd;
    patcntN=patcntN_sd;
    value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
    trtp='TRT TOT';
    trtpn=input(trtp,intrt.);
    output;
  end; 
run;


data work.row1 (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4 row);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
  ;
  set work.aefreq3 end=last;
  retain row 1 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;
  
  if _n_=1 then
    rptcolumn='Any Adverse Events';
  
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(anyae,5.),value);
    when(2) _cstCol2=catx('   ',put(anyae,5.),value);
    when(3) _cstCol3=catx('   ',put(anyae,5.),value);
    when(4) _cstCol4=catx('   ',put(anyae,5.),value);
    otherwise;
  end;
  if last then
    output;

run;

proc datasets lib=work nolist;
  delete aefreq aefreq2;
quit;


**************************;
* Start row 2 processing *;
**************************;

proc sort data=&_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y")) out=work.adae;
  by trtp aebodsys usubjid;
run;
data work.soc_pre (keep=trtp aebodsys aedecod patcnt eventcnt type);
  set work.adae (keep=trtp aebodsys aedecod usubjid);
    by trtp aebodsys usubjid;
  attrib type format=$3.;
  retain eventcnt patcnt 0 type 'SOC';
  if first.aebodsys then
  do;
    patcnt=0;
    eventcnt=0;
  end;
  if last.usubjid then patcnt+1;
  eventcnt+1;
  aedecod='';
  if last.aebodsys then output;
run;
data work.soc_pre;
  merge work.soc_pre
        work.adslcnt;
    by trtp;
  attrib trtpn format=8. label='Planned treatment (n)';
  retain trtpn;
  if first.trtp then
    trtpn=input(trtp,intrt.);
run;
proc sort data=work.soc_pre;
  by aebodsys trtp;
run;
data work.aefreq_r2 (drop=eventcnt_sd patcnt_sd patcntN_sd);
  set work.soc_pre end=last;
    by aebodsys trtp;
  attrib value format=$char16.;
  retain eventcnt_sd patcnt_sd patcntN_sd 0;
  if first.aebodsys then 
  do;
    eventcnt_sd=0;
    patcnt_sd=0;
    patcntN_sd=0;
  end;
  if trtp ne 'TRT A' then 
  do;
    eventcnt_sd=eventcnt_sd+eventcnt;
    patcnt_sd=patcnt_sd+patcnt;
    patcntN_sd=patcntN_sd+patcntN;
  end;
  value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
  output;
  if last.aebodsys then do;
    eventcnt=eventcnt_sd;
    patcnt=patcnt_sd;
    patcntN=patcntN_sd;
    value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
    trtp='TRT TOT';
    trtpn=input(trtp,intrt.);
    output;
  end; 
run;

data work.row2 (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4 aebodsys aedecod row);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
  ;
  set work.aefreq_r2 end=last;
    by aebodsys;
  retain row 2 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;

  if first.aebodsys then
  do;
    rptcolumn=aebodsys;
    row=2;
  end;
    
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(eventcnt,5.),value);
    when(2) _cstCol2=catx('   ',put(eventcnt,5.),value);
    when(3) _cstCol3=catx('   ',put(eventcnt,5.),value);
    when(4) _cstCol4=catx('   ',put(eventcnt,5.),value);
    otherwise;
  end;
  if last.aebodsys then
    output;

run;


**************************;
* Start row 3 processing *;
**************************;

proc sort data=&_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y")) out=work.adae;
  by trtp aebodsys aedecod usubjid;
run;
data work.pt_pre (keep=trtp aebodsys aedecod patcnt eventcnt type);
  set work.adae (keep=trtp aebodsys aedecod usubjid);
    by trtp aebodsys aedecod usubjid;
  attrib type format=$3.;
  retain eventcnt patcnt 0 type 'PT';
  if first.aedecod then
  do;
    patcnt=0;
    eventcnt=0;
  end;
  if last.usubjid then patcnt+1;
  eventcnt+1;
  if last.aedecod then output;
run;

data work.pt_pre;
  merge work.pt_pre
        work.adslcnt;
    by trtp;
  attrib trtpn format=8. label='Planned treatment (n)';
  retain trtpn;
  if first.trtp then
    trtpn=input(trtp,intrt.);
run;
proc sort data=work.pt_pre;
  by aebodsys aedecod trtp;
run;
data work.aefreq_r3 (drop=eventcnt_sd patcnt_sd patcntN_sd);
  set work.pt_pre end=last;
    by aebodsys aedecod trtp;
  attrib value format=$char16.;
  retain eventcnt_sd patcnt_sd patcntN_sd 0;
  if first.aedecod then 
  do;
    eventcnt_sd=0;
    patcnt_sd=0;
    patcntN_sd=0;
  end;
  if trtp ne 'TRT A' then 
  do;
    eventcnt_sd=eventcnt_sd+eventcnt;
    patcnt_sd=patcnt_sd+patcnt;
    patcntN_sd=patcntN_sd+patcntN;
  end;
  value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
  output;
  if last.aedecod then do;
    eventcnt=eventcnt_sd;
    patcnt=patcnt_sd;
    patcntN=patcntN_sd;
    if patcntN=0 then
      value=catx(' ',put(patcnt,3.),'(0.00%)');
    else
      value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
    trtp='TRT TOT';
    trtpn=input(trtp,intrt.);
    output;
  end; 
run;

data work.row3 (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4 aebodsys aedecod row);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
  ;
  set work.aefreq_r3 end=last;
    by aebodsys aedecod;
  retain row 3 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;

  if first.aedecod then
  do;
    substr(rptcolumn,3)=aedecod;
    row=3;
  end;
    
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(eventcnt,5.),value);
    when(2) _cstCol2=catx('   ',put(eventcnt,5.),value);
    when(3) _cstCol3=catx('   ',put(eventcnt,5.),value);
    when(4) _cstCol4=catx('   ',put(eventcnt,5.),value);
    otherwise;
  end;
  if last.aedecod then
    output;

run;

data work.row23;
  set work.row2 (in=r2)
      work.row3 (in=r3);
run;
proc sort data=work.row23;
  by aebodsys row aedecod;
run;

data work.blankrow (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
  ;
  call missing(of _all_);
run;  
 
data work.row23;
  set work.row23;
    by aebodsys;
  output;
  if last.aebodsys then
  do;
    call missing(of _all_);
    output;
  end;
run;

data work.final (drop=row);
  set work.row1 (in=r1)
      work.blankrow (in=r1)
      work.row23 (drop=aebodsys aedecod in=r2);
  group=sum(r1*1,r2*2);
  if row=99 then
    rptcolumn='';
run;


proc datasets lib=work nolist;
  delete row1 row2 row3 row23 blankrow soc_pre pt_pre aefreq_r2 aefreq_r3 aefreq3 /* adslcnt */ adae;
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
%let trtvar=;
%let thistrt=;

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

%macro patientcount(trtvar=,whclause=);
  %trtcount(trtvar=&trtvar);
  %do i=1 %to &trtCnt;
    %let thistrt=%scan(&trts,&i,"|");
    proc sql noprint;
      select cats('(N=',put(count(*),4.),')') into :trt&i
      from work.adsl (where=(&whclause));
    quit;
    %****put trt&i=&&trt&i;
  %end;
%mend;
%patientcount(trtvar=trtp,whclause=%nrstr(&trtvar="&thistrt" and saffl="Y"));

%* Override for this report;
data _null_;
  set work.adslcnt (where=(trtp ne 'TRT A')) end=last;
  retain t4 0;
  t4=t4+patcntN;
  if last then
    call symputx('trt4',cats('(N=',put(t4,8.),')'));
run;


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
ods noproctitle /* proclabel "Table 14.3.1.1" */ ;

%let _cstTitle1=Table 14.3.1.1;
%let _cstTitle2=Incidence of Treatment-Emergent Adverse Events by System Organ Class and Preferred Term;
%let _cstTitle3=Safety Population;
%let _cstFootnote1=Note 1: A subject who reported two or more different preferred terms in the same system organ class is counted only once in the system organ class.;
%let _cstFootnote2=Note 2: Subjects with adverse events in different systems organ class are counted only once in the overall total.;
%let _cstFootnote3=Note 3: N is the number of subjects within the treatment group in the population, n is the number of subjects who reported the adverse event and % is calculated by n/N*100. [AEs] is the number of AE reports.;
%let _cstFootnote9=Produced by SAS Clinical Standards Toolkit at &_cstrundt;
%let _cstFootnote10=&_cstDisplayCode;

proc report data=work.final nowd spacing=1 /* headline headskip */ split="*" /* contents="" */
           style(report)={just=center outputwidth=9.25 in font_size=8pt asis=on} ;
       
       column (group rptcolumn _cstcol1 ('Study Drug' _cstcol2 _cstcol3 _cstcol4));
       define group  /order order=internal noprint;
       define rptcolumn  / display left width=50 "System Organ Class/Preferred Term" style(header)={just=l};
       define _cstcol1   / display width=16 " Placebo*&trt1**[AEs]      n (%)";
       define _cstcol2   / display width=16 "Low Dose*&trt2**[AEs]      n (%)";
       define _cstcol3   / display width=16 "High Dose*&trt3**[AEs]      n (%)";
       define _cstcol4   / display width=16 "  Total*&trt4**[AEs]      n (%)";
       break after group / skip;
       
       title1 "&_cstTitle1";
       title2 "&_cstTitle2";
       title3 "&_cstTitle3";
       footnote1  j=l h=9 pt "&_cstFootnote1 ";
       footnote2  j=l h=9 pt "&_cstFootnote2 ";
       footnote3  j=l h=9 pt "&_cstFootnote3 ";
       footnote9  j=l h=8 pt "&_cstFootnote9 ";
       footnote10 j=l h=8 pt "&_cstFootnote10 ";
run;

ods &_cstDisplayFormat close;
ods listing;
filename _cstrpt;

proc datasets lib=work nolist;
  delete adsl final;
quit;

