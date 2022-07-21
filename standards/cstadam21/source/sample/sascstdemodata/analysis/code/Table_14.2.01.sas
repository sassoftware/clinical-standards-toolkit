**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* Table_14.2.01.sas                                                              *;
*                                                                                *;
* Module to create Table 14.2.01 (Summary of Demographic and Baseline            *;
* Characteristics), a sample CSR table.                                          *;
*                                                                                *;
* CSTversion  1.4                                                                *;
**********************************************************************************;

%put NOTE: Running Table_14.2.01.sas;


proc format library=work.formats;
  value agegrp
     low-30 = '<30 years'
     30-45 = '30-45 years'
     46-high = '>45 years';
  invalue $inage
     '<30 years'=1
     '30-45 years'=2
     '>45 years'=3;
  value $sex
     'M'='Male'
     'F'='Female';
  value $race
     'ASIAN'='Asian'
     'BLACK'='Black'
     'CAUCASIAN'='Caucasian'
     'HISPANIC'='Hispanic'
     'OTHER'='Other';
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
  value $stfmt
     'xx'='2.'
     'xxx'='3.'
     'xxx.'='3.0'
     'xx.x'='7.1'
     'x.xx'='8.2'
     'yyy.y'='7.1'
     other='12.3';    
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

**************************;
* Start row 1 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='1'));
%adamutil_settlfparmvalues(_cstTLFDS=tlf_statistics,_cstTLFDSWhereClause=%str(upcase(parent)='ROW' and parentid='1'));

filename nextCode CATALOG "work._csttlf.row1.source";

data _null_;
  set &_cstTLFLibrary..tlf_statistics (where=(upcase(parent)='ROW' and parentid='1')) end=last;
    attrib tempvar format=$200.
           origlist format=$500.
           cstlist format=$500.;
  file nextcode;
  retain origlist cstlist;

  if upcase(stattype)='DESCRIPTIVE' then
  do;
    if _n_=1 then do;
      put @1 "proc univariate data=work.adsl noprint;";
      put @3 "by trt01pn;";
      put @5 "var &_CSTTLF_ROWSCOLUMN;";
      put @5 "output out=work.&_CSTTLF_ROWSCOLUMN._U";
    end;
    origlist=catx(' ',origlist,statlabel);
    cstlist=catx(' ',cstlist,cats('_cst',statlabel));
    tempvar=cats(statlabel,'=_cst',statlabel);
    put @12 tempvar;
    if last then do;
      put @1 ';run;';
      call symputx('origlist',origlist);
      call symputx('cstlist',cstlist);
    end;
  end;
  else
    put 'ERROR:  ---> NOT YET CODED STATTYPE';
run;

data _null_;
  set &_cstTLFLibrary..tlf_statistics (where=(upcase(parent)='ROW' and parentid='1')) end=last;
    attrib tempvar format=$200.
           tempvar2 format=$200.;
  file nextcode mod;
  retain origlist cstlist;
  
  origlist=symget('origlist');
  cstlist=symget('cstlist');
  
  if upcase(stattype)='DESCRIPTIVE' then
  do;
    if _n_=1 then do;
      put @1 "data work.&_CSTTLF_ROWSCOLUMN (drop=&cstlist);";
      put @3 "set work.&_CSTTLF_ROWSCOLUMN._U;";
      put @5 "format &origlist $14.;";
    end;
    tempvar=scan(origlist,_n_);
    tempvar2=cats(tempvar,'=put(',scan(cstlist,_n_),',',put(statformat,$stfmt.),');');
    put @7 tempvar2;
    if last then do;
      put @1 'run;';
      put @1 "proc transpose data=work.&_CSTTLF_ROWSCOLUMN out=work.&_CSTTLF_ROWSCOLUMN._T prefix=_cstcol;";
      put @3 "var &origlist;";
      put @3 'id trt01pn;';
      put @1 'run;';
    end;
  end;
  else
    put 'ERROR:  ---> NOT YET CODED STATTYPE';
run;

%include nextcode;

data work.row1 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
         spacing  length=$200
  ;
  set work.&_CSTTLF_ROWSCOLUMN._T end=last;
  
  if _n_=1 then
    rptcolumn="&_CSTTLF_ROWSROWLABEL";
  select(_NAME_);
    when('n') rptvalue='n';
    when('mean') rptvalue='Mean';
    when('std') rptvalue='SD';
    when('median') rptvalue='Median';
    when('min') rptvalue='Min';
    when('max') rptvalue='Max';
    otherwise rptvalue=_NAME_;
  end;
  output;
  if last then
  do;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      call missing(of _all_);
      output;
    end;
  end;
run;

proc datasets lib=work nolist;
  delete &_CSTTLF_ROWSCOLUMN &_CSTTLF_ROWSCOLUMN._T &_CSTTLF_ROWSCOLUMN._U;
quit;

  
**************************;
* Start row 2 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='2'));

proc freq data=work.adsl noprint;
  tables trt01pn*agegrpn / outpct out=work.agefreq;
run;
data work.agefreq2;
  set work.agefreq (where=(agegrpn ne .));
  length value $20;
  value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));
run;
proc sort data=work.agefreq2;
  by agegrpn;
run;
proc transpose data=work.agefreq2 out=work.agegrp_t (drop=_NAME_) prefix=_cstcol;
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
         spacing  length=$200
  ;
  set work.agegrp_t end=last;
  
  if _n_=1 then
    rptcolumn='Age';
  select(agegrpn);
    when(1) rptvalue='<30 years';
    when(2) rptvalue='30-45 years';
    when(3) rptvalue='>45 years';
    otherwise;
  end;
  output;
  if last then
  do;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      call missing(of _all_);
      output;
    end;
  end;
run;

/*
NOTE:      _CSTTLF_ROWSBYROWSPACE          =Double
NOTE:      _CSTTLF_ROWSCOLJUST             =L
NOTE:      _CSTTLF_ROWSCOLUMN              =AGE
NOTE:      _CSTTLF_ROWSCOLUMNTYPE          =Numeric
NOTE:      _CSTTLF_ROWSDISPID              =Table 14.2.01
NOTE:      _CSTTLF_ROWSID                  =1
NOTE:      _CSTTLF_ROWSROWLABEL            =Age (Years)
NOTE:      _CSTTLF_ROWSROWSPACE            =Single
NOTE:      _CSTTLF_ROWSROWTYPE             =Column
*/

proc datasets lib=work nolist;
  delete agefreq agefreq2 agegrp_t;
quit;


**************************;
* Start row 3 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='3'));
%adamutil_settlfparmvalues(_cstTLFDS=tlf_statistics,_cstTLFDSWhereClause=%str(upcase(parent)='ROW' and parentid='3'));

filename nextCode CATALOG "work._csttlf.row3.source";

data _null_;
  file nextcode;

    put @1 "proc freq data=work.adsl noprint;";
    put @3 "tables trt01pn*&_CSTTLF_ROWSCOLUMN / outpct out=work.&_CSTTLF_ROWSCOLUMN.freq;";
    put @1 "run;";
    put @1 "data work.&_CSTTLF_ROWSCOLUMN.freq;";
    put @3 "  set work.&_CSTTLF_ROWSCOLUMN.freq (where=(&_CSTTLF_ROWSCOLUMN ne ''));";
    put @3 "length value $20;";
    put @3 "value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));";
    put @1 "run;";
    put @1 "proc sort data=&_CSTTLF_ROWSCOLUMN.freq;";
    put @3 "by &_CSTTLF_ROWSCOLUMN;";
    put @1 "run;";
    put @1 "proc transpose data=work.&_CSTTLF_ROWSCOLUMN.freq out=work.&_CSTTLF_ROWSCOLUMN._T (drop=_NAME_) prefix=_cstcol;";
    put @3 "by &_CSTTLF_ROWSCOLUMN;";
    put @3 "var value;";
    put @3 "id trt01pn;";
    put @1 "run;";
run;

%include nextcode;


data work.row3 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
         spacing  length=$200
  ;
  set work.&_CSTTLF_ROWSCOLUMN._T end=last;
  
  if _n_=1 then
    rptcolumn="&_CSTTLF_ROWSROWLABEL";
  rptvalue=put(&_CSTTLF_ROWSCOLUMN,&_CSTTLF_ROWSCOLUMNFMT);
  output;
  if last then
  do;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      call missing(of _all_);
      output;
    end;
  end;
run;

proc datasets lib=work nolist;
  delete &_CSTTLF_ROWSCOLUMN.freq &_CSTTLF_ROWSCOLUMN._T;
quit;


**************************;
* Start row 4 processing *;
**************************;
%adamutil_settlfparmvalues(_cstTLFDS=tlf_rows,_cstTLFDSWhereClause=%nrstr(id='4'));
%adamutil_settlfparmvalues(_cstTLFDS=tlf_statistics,_cstTLFDSWhereClause=%str(upcase(parent)='ROW' and parentid='4'));

filename nextCode CATALOG "work._csttlf.row4.source";

data _null_;
  file nextcode;

    put @1 "proc freq data=work.adsl noprint;";
    put @3 "tables trt01pn*&_CSTTLF_ROWSCOLUMN / outpct out=work.&_CSTTLF_ROWSCOLUMN.freq;";
    put @1 "run;";
    put @1 "data work.&_CSTTLF_ROWSCOLUMN.freq;";
    put @3 "  set work.&_CSTTLF_ROWSCOLUMN.freq (where=(&_CSTTLF_ROWSCOLUMN ne ''));";
    put @3 "length value $20;";
    put @3 "value=catx(' ',put(count,3.),cats('(', put(pct_row,5.1),'%)'));";
    put @1 "run;";
    put @1 "proc sort data=&_CSTTLF_ROWSCOLUMN.freq;";
    put @3 "by &_CSTTLF_ROWSCOLUMN;";
    put @1 "run;";
    put @1 "proc transpose data=work.&_CSTTLF_ROWSCOLUMN.freq out=work.&_CSTTLF_ROWSCOLUMN._T (drop=_NAME_) prefix=_cstcol;";
    put @3 "by &_CSTTLF_ROWSCOLUMN;";
    put @3 "var value;";
    put @3 "id trt01pn;";
    put @1 "run;";
run;

%include nextcode;

data work.row4 (keep=rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
  attrib rptcolumn format=$14. label='Report column'
         rptvalue  format=$12. label='Value or statistic'
         _cstcol1 length=$20 format=$20.
         _cstcol2 length=$20 format=$20.
         _cstcol3 length=$20 format=$20.
         _cstcol4 length=$20 format=$20.
         spacing  length=$200
  ;
  set work.&_CSTTLF_ROWSCOLUMN._T end=last;
  
  if _n_=1 then
    rptcolumn="&_CSTTLF_ROWSROWLABEL";
  rptvalue=put(&_CSTTLF_ROWSCOLUMN,&_CSTTLF_ROWSCOLUMNFMT);
  output;
  if last then
  do;
    spacing=symget('_CSTTLF_ROWSBYROWSPACE');
    if upcase(spacing)='DOUBLE' then
    do;
      call missing(of _all_);
      output;
    end;
  end;
run;

proc datasets lib=work nolist;
  delete &_CSTTLF_ROWSCOLUMN.freq &_CSTTLF_ROWSCOLUMN._T;
quit;

  
data work.final;
  set work.row1 (in=r1)
      work.row2 (in=r2)
      work.row3 (in=r3)
      work.row4 (in=r4);
  group=sum(r1*1,r2*2,r3*3,r4*4);
run;


proc datasets lib=work nolist;
  delete row1 row2 row3 row4;
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
    attrib tempvar format=$200.;

    tempvar=catx(' ',cats('Footnote',put(linenum,2.)),'bold');
    if just ne '' then
      tempvar=catx(' ',tempvar,'j=',just);
    if fontsize ne '' then
      tempvar=catx(' ',tempvar,'h=',fontsize,'pt');
    tempvar=catx(' ',tempvar,'"',text,'"') || ';'; 
    call execute(tempvar);
run;

proc report data=work.final nowd spacing=1 /* headline headskip */ split="*" /* contents="" */
       /*    style(report)={just=center outputwidth=10.5 in font_size=8pt} */;
       
       column (group rptcolumn rptvalue _cstcol1 _cstcol2 _cstcol3 _cstcol4);
       define group  /order order=internal noprint;
       define rptcolumn  / display width=14 " ";
       define rptvalue   / display width=12 " ";
       define _cstcol1   / display width=20 "Placebo*&trt1**n(%)";
       define _cstcol2   / display width=20 "Low Dose*&trt2**n(%)";
       define _cstcol3   / display width=20 "High Dose*&trt3**n(%)";
       define _cstcol4   / display width=20 "Total*&trt4**n(%)";
       
       break after group / skip;
run;

ods &_cstDisplayFormat close;
ods listing;
filename _cstrpt;

proc datasets lib=work nolist;
  delete adsl final;
quit;

