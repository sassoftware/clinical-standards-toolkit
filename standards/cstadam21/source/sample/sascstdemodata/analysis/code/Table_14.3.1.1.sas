**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* Table_14.3.1.1.sas                                                             *;
*                                                                                *;
* Module to create Table_14.3.1.1 (Incidence of Treatment-Emergent Adverse       *;
* Events by System Organ Class and Preferred Term), a sample CSR table.          *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%put NOTE: Running Table_14.3.1.1.sas;


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
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='1'));

proc sql noprint;
  create table work.adslcnt as
    select count(*) as patcntN, trt01p as trtp length=40 format=$40. label='Description of Planned Arm'
    from &_cstSrcDataLib..adsl (where=(trt01p =: 'TRT' and saffl="Y"))
    group by trt01p 
    order by trt01p;
  create table work.aefreq as
    select count(*) as &_CSTTLF_ROWSCOLUMN, trtp
    from &_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y"))
    group by trtp 
    order by trtp;
  create table work.aefreq2 as
    select count(distinct usubjid) as patcnt, trtp 
    from (
      select count(usubjid) as patae, trtp, usubjid
      from &_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y"))
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
         spacing  length=$200
  ;
  set work.aefreq3 end=last;
  retain row 1 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;
  
  if _n_=1 then
    rptcolumn="&_CSTTLF_ROWSROWLABEL";
  
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(&_CSTTLF_ROWSCOLUMN,5.),value);
    when(2) _cstCol2=catx('   ',put(&_CSTTLF_ROWSCOLUMN,5.),value);
    when(3) _cstCol3=catx('   ',put(&_CSTTLF_ROWSCOLUMN,5.),value);
    when(4) _cstCol4=catx('   ',put(&_CSTTLF_ROWSCOLUMN,5.),value);
    otherwise;
  end;
  if last then
  do;
    output;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      call missing(of _all_);
      row=1;
      output;
    end;
  end;
run;

/*
NOTE:      _CSTTLF_ROWSBYROWSPACE          =Double
NOTE:      _CSTTLF_ROWSCOLJUST             =L
NOTE:      _CSTTLF_ROWSCOLUMN              =ANYAE
NOTE:      _CSTTLF_ROWSCOLUMNFMT           =
NOTE:      _CSTTLF_ROWSCOLUMNTYPE          =Numeric
NOTE:      _CSTTLF_ROWSDISPID              =Table_14.3.1.1
NOTE:      _CSTTLF_ROWSID                  =1
NOTE:      _CSTTLF_ROWSPARENTROW           =
NOTE:      _CSTTLF_ROWSREPEATING           =
NOTE:      _CSTTLF_ROWSROWLABEL            =Any Adverse Events
NOTE:      _CSTTLF_ROWSROWSPACE            =Single
NOTE:      _CSTTLF_ROWSROWTYPE             =Column
*/

proc datasets lib=work nolist;
  delete aefreq aefreq2;
quit;


**************************;
* Start row 2 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='2'));
%adamutil_settlfparmvalues(_cstTLFDS=tlf_statistics,_cstTLFDSWhereClause=%str(upcase(parent)='ROW' and parentid='2'));

proc sort data=&_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y")) out=work.adae;
  by trtp &_CSTTLF_ROWSCOLUMN usubjid;
run;
data work.soc_pre (keep=trtp aebodsys aedecod patcnt eventcnt type);
  set work.adae (keep=trtp &_CSTTLF_ROWSCOLUMN aedecod usubjid);
    by trtp &_CSTTLF_ROWSCOLUMN usubjid;
  attrib type format=$3.;
  retain eventcnt patcnt 0 type 'SOC';
  if first.&_CSTTLF_ROWSCOLUMN then
  do;
    patcnt=0;
    eventcnt=0;
  end;
  if last.usubjid then patcnt+1;
  eventcnt+1;
  aedecod='';
  if last.&_CSTTLF_ROWSCOLUMN then output;
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
  by &_CSTTLF_ROWSCOLUMN trtp;
run;
data work.aefreq_r2 (drop=eventcnt_sd patcnt_sd patcntN_sd);
  set work.soc_pre end=last;
    by &_CSTTLF_ROWSCOLUMN trtp;
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
  if last.&_CSTTLF_ROWSCOLUMN then do;
    eventcnt=eventcnt_sd;
    patcnt=patcnt_sd;
    patcntN=patcntN_sd;
    value=catx(' ',put(patcnt,3.),cats('(', put((patcnt/patcntN)*100,5.1),'%)'));
    trtp='TRT TOT';
    trtpn=input(trtp,intrt.);
    output;
  end; 
run;

data work.row2 (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4 &_CSTTLF_ROWSCOLUMN aedecod row);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
         spacing  length=$200
  ;
  set work.aefreq_r2 end=last;
    by &_CSTTLF_ROWSCOLUMN;
  retain row 2 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;

  if first.&_CSTTLF_ROWSCOLUMN then
  do;
    rptcolumn=&_CSTTLF_ROWSCOLUMN;
    row=2;
  end;
    
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(eventcnt,5.),value);
    when(2) _cstCol2=catx('   ',put(eventcnt,5.),value);
    when(3) _cstCol3=catx('   ',put(eventcnt,5.),value);
    when(4) _cstCol4=catx('   ',put(eventcnt,5.),value);
    otherwise;
  end;

  if last.&_CSTTLF_ROWSCOLUMN then
  do;
    output;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      _cstCol1='';
      _cstCol2='';
      _cstCol3='';
      _cstCol4='';
      row=99;
      output;
    end;
  end;
run;


**************************;
* Start row 3 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='3'));
%adamutil_settlfparmvalues(_cstTLFDS=tlf_statistics,_cstTLFDSWhereClause=%str(upcase(parent)='ROW' and parentid='3'));


proc sort data=&_cstSrcDataLib..adae (where=(trtp =: 'TRT' and saffl="Y" and trtemfl="Y")) out=work.adae;
  by trtp aebodsys &_CSTTLF_ROWSCOLUMN usubjid;
run;
data work.pt_pre (keep=trtp aebodsys &_CSTTLF_ROWSCOLUMN patcnt eventcnt type);
  set work.adae (keep=trtp aebodsys &_CSTTLF_ROWSCOLUMN usubjid);
    by trtp aebodsys &_CSTTLF_ROWSCOLUMN usubjid;
  attrib type format=$3.;
  retain eventcnt patcnt 0 type 'PT';
  if first.&_CSTTLF_ROWSCOLUMN then
  do;
    patcnt=0;
    eventcnt=0;
  end;
  if last.usubjid then patcnt+1;
  eventcnt+1;
  if last.&_CSTTLF_ROWSCOLUMN then output;
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
  by aebodsys &_CSTTLF_ROWSCOLUMN trtp;
run;
data work.aefreq_r3 (drop=eventcnt_sd patcnt_sd patcntN_sd);
  set work.pt_pre end=last;
    by aebodsys &_CSTTLF_ROWSCOLUMN trtp;
  attrib value format=$char16.;
  retain eventcnt_sd patcnt_sd patcntN_sd 0;
  if first.&_CSTTLF_ROWSCOLUMN then 
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
  if last.&_CSTTLF_ROWSCOLUMN then do;
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

data work.row3 (keep=rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4 aebodsys &_CSTTLF_ROWSCOLUMN row);
  attrib rptcolumn format=$char40. label='Report column'
         _cstcol1 length=$16 format=$char16.
         _cstcol2 length=$16 format=$char16.
         _cstcol3 length=$16 format=$char16.
         _cstcol4 length=$16 format=$char16.
         spacing  length=$200
  ;
  set work.aefreq_r3 end=last;
    by aebodsys &_CSTTLF_ROWSCOLUMN;
  retain row 3 rptcolumn _cstcol1 _cstcol2 _cstcol3 _cstcol4;

  if first.&_CSTTLF_ROWSCOLUMN then
  do;
    substr(rptcolumn,3)=&_CSTTLF_ROWSCOLUMN;
    row=3;
  end;
    
  select(trtpn);
    when(1) _cstCol1=catx('   ',put(eventcnt,5.),value);
    when(2) _cstCol2=catx('   ',put(eventcnt,5.),value);
    when(3) _cstCol3=catx('   ',put(eventcnt,5.),value);
    when(4) _cstCol4=catx('   ',put(eventcnt,5.),value);
    otherwise;
  end;

  if last.&_CSTTLF_ROWSCOLUMN then
  do;
    output;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      _cstCol1='';
      _cstCol2='';
      _cstCol3='';
      _cstCol4='';
      row=99;
      output;
    end;
  end;
run;

data work.row23;
  set work.row2 (in=r2)
      work.row3 (in=r3);
run;
proc sort data=work.row23;
  by aebodsys row aedecod;
run;

  
data work.final (drop=row);
  set work.row1 (in=r1)
      work.row23 (drop=aebodsys aedecod in=r2);
  group=sum(r1*1,r2*2);
  if row=99 then
    rptcolumn='';
run;


proc datasets lib=work nolist;
  delete row1 row2 row3 row23 soc_pre pt_pre aefreq_r2 aefreq_r3 aefreq3 /* adslcnt */ adae;
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

data _null_;
  set &_cstTLFLibrary..tlf_titles;
    attrib tempvar format=$200.;

    tempvar=catx(' ',cats('Title',put(linenum,2.)),'bold');
    if just ne '' then
      tempvar=catx(' ',tempvar,'j=',just);
    if fontsize ne '' then
      tempvar=catx(' ',tempvar,'h=',fontsize,'pt');
    tempvar=catx(' ',tempvar,cats('"',text,'";'));
    call execute(tempvar);
*            title8 bold j=c h=10 pt c=cx002288 "&Source"  *;
run;

data _null_;
  set &_cstTLFLibrary..tlf_footnotes;
    attrib tempvar format=$char500.;

    tempvar=catx(' ',cats('Footnote',put(linenum,2.)));
    if just ne '' then
      tempvar=catx(' ',tempvar,'j=',just);
    if fontsize ne '' then
      tempvar=catx(' ',tempvar,'h=',fontsize,'pt');
    tempvar=catx(' ',tempvar,'"',text,'"') || ';'; 
    call execute(tempvar);
run;

proc report data=work.final nowd spacing=1 /* headline headskip */ split="*" contents=" "
           style(report)={just=center outputwidth=9.25 in font_size=8pt asis=on} ;
       
       column (group rptcolumn _cstcol1 ('Study Drug' _cstcol2 _cstcol3 _cstcol4));
       define group  /order order=internal noprint;
       define rptcolumn  / display left width=50 "System Organ Class/Preferred Term" style(header)={just=l};
       define _cstcol1   / display width=16 " Placebo*&trt1**[AEs]      n (%)";
       define _cstcol2   / display width=16 "Low Dose*&trt2**[AEs]      n (%)";
       define _cstcol3   / display width=16 "High Dose*&trt3**[AEs]      n (%)";
       define _cstcol4   / display width=16 "  Total*&trt4**[AEs]      n (%)";
       break after group / skip;
run;

ods &_cstDisplayFormat close;
ods listing;
filename _cstrpt;

proc datasets lib=work nolist;
  delete adsl final;
quit;

