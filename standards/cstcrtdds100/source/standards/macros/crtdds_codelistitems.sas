%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_codelistitems                                                           *;
%*                                                                                *;
%* Creates the SAS CRT-DDS CodeListItems data set from source metadata.           *;
%*                                                                                *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column metadata for the Domain columns to include in the CRT-DDS   *;
%*             file.                                                              *;
%* @param  _cstSourceValues  - optional - The data set that contains the          *;
%*             metadata for the Value Level columns to include in the CRT-DDS     *;
%*             file.                                                              *;
%* @param _cstcodelistsds - required - The CodeLists data set in the output       *;
%*            library (for example, srcdata.CodeLists).                           *;
%* @param _cstoutcodelistitemsds - required - The CodeListItems data set to       *;
%*            create (for example, srcdata.CodeListItems).                        *;
%*                                                                                *;
%* @history 2013-12-12  Added _cstSourceValues to ensure codelist references in   *;
%*             Value Level Metadata are kept                                      *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_codelistitems(
    _cstsourcecolumns=,
    _cstsourcevalues=,
    _cstcodelistsds=,
    _cstoutcodelistitemsds=
    ) / des="Creates SAS CRT-DDS CodeListItems data set";

%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6;
%if %length(&_cstsourcecolumns)=0 or %length(&_cstcodelistsds)=0 or %length(&_cstoutcodelistitemsds)=0
    %then %goto exit;

%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstcodelistsds)) %then %goto exit;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_i1&_cstRandom;
  %let keycnt=1;
  %* need to check if 2 level name passed in for parameters, pull off dataset name for use in proc sql *;
  %if %symexist(_cstsourcecolumns) %then %do;
      %if (%sysfunc(indexc("&_cstsourcecolumns",'.'))=0 )%then %let srccols=&_cstsourcecolumns;
      %else %do;
        %let src2=%scan(&_cstsourcecolumns,2,'.');
    %let srccols=&src2;
    %end;
  %end;

  %if %symexist(_cstcodelistsds) %then %do;
      %if (%sysfunc(indexc("&_cstcodelistsds",'.'))=0) %then %let clds=&_cstcodelistsds;
    %else %do;
        %let cl2=%scan(&_cstcodelistsds,2,'.');
    %let clds=&cl2;
    %end;
  %end;
  %if %symexist(_cstoutcodelistitemsds) %then %do;
      %if %sysfunc(indexc("&_cstoutcodelistitemsds",'.'))=0 %then %let clids=&_cstoutcodelistitemsds;
      %else %do;
        %let cli=%scan(&_cstoutcodelistitemsds,2,'.');
    %let clids=&cli;
    %end;
  %end;

  %* if there are already records in the codelists dataset, we need to get the max value of keycnt *;
  %if %symexist(clids) %then %do;
    %if %sysfunc(exist(&_cstoutcodelistitemsds)) %then %do;
      %let dsidst=%sysfunc(open(&_cstoutcodelistitemsds,i));
      %if &dsidst>0 %then %do;
        %let key=%sysfunc(attrn(&dsidst, nlobs));
        %let rc=%sysfunc(close(&dsidst));
      %end;
      data _null_;
        keycnt=strip(sum(&key,1));
        call symput('keycnt',keycnt);
      run;
      %let outDSexists=1;
    %end;
    %else %let outDSexists=0;
  %end;


  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds1=_ci1&_cstRandom;

  data _null_;
        attrib _cstCatalog format=$char17.
               _cstfmts format=$char200.
               _cstCatalogs format=$char200.;
        _cstfmts = translate(getoption('FMTSEARCH'),'','()');
        do i = 1 to countw(_cstfmts,' ');
          _cstCatalog=scan(_cstfmts,i,' ');
          if index(_cstCatalog,'.') = 0 then do;
               if libref(_cstcatalog)=0 then
        _cstCatalog = catx('.',_cstCatalog,'FORMATS');
      end;
      if exist(_cstCatalog,'CATALOG') then
            _cstCatalogs = catx(' ',_cstCatalogs,_cstCatalog);
        end ;
    IF STRIP(_CSTCATALOG) NE ''
          then call symput('_cstCatalogs',STRIP(_cstCatalogs));
    else call symput('_cstCatalogs','');
      run;
      %if "&_cstCatalogs"="" %then %goto cleanup;

      %* Concatenate format catalogs into a single reference  *;
    %IF %SYSFUNC(STRIP("&_cstCatalogs")) NE "" %THEN %DO;
      catname _cstfmts ( &_cstCatalogs ) ;
      proc format lib=work._cstfmts cntlout=&ds1 (rename=(fmtname=Name));
      run ;
      catname _cstfmts clear;
    %END;
    data &ds1; set &ds1; name=upcase(name); run;
  proc sort data=&ds1 nodupkey; by name label; run;
    data work.&ds1 (keep=CodedValue Rank Name);
      set &ds1 (rename=(label=CodedValue));
        by Name codedvalue;
        Rank = .;
      * Rank can not be derived, but needs to be created by the user;
      /*
      if first.Name and first.codedvalue then Rank=1;
      else Rank+1;
      */
    run;

    %let ds5=_c5&_cstRandom;
    %let ds6=_c6&_cstRandom;
    
    data &ds5(rename=(xmlcodelist=name) keep=xmlcodelist);
      set &_CSTSOURCECOLUMNS &_CSTSOURCEVALUES;
        xmlcodelist=upcase(xmlcodelist);
        if xmlcodelist ne '';
    run;
    
    proc sort data=&ds5 nodupkey;
      by name;
    run;
    
    proc sort data=&ds1
    out=&ds1;
    by name;
    run;

 %* only keep the formats specified in the source_columns dataset *;

   data &ds6;
    merge &ds1(in=cl) &ds5(in=src);
  by name;
  if src=1 and cl=1;
  run;

   proc sort data=&ds6 nodupkey; by name codedvalue; run;
  %let ds2=_c2&_cstRandom;

proc sql;
    create table &ds2 as
      select
            "" as OID length = 128,
            &ds6..CodedValue as CodedValue label='' length = 512,
      strip(&clds..oid) as FK_CodeLists length = 128,
      &ds6..Rank as Rank
  from &ds6 as one left  join &_cstcodelistsds as two
  on ( one.name=two.name and &ds6..CodedValue not is missing);
quit;
proc sort data=&ds2 out=&ds2 nodupkey; by codedvalue fk_codelists; run;

%let ds3=_c3&_cstRandom;
data &ds3(drop=key);
  set &ds2;
  RETAIN KEY;
  IF _N_=1 THEN KEY=&KEYCNT;
  else key=sum(key,1);
  OID=strip(key);
RUN;


%let ds4=_c4&_cstRandom;

%if &outDSexists=1 %then %do;
  data &ds4;
    set &_cstoutcodelistitemsds;
  run;
%end;

  proc append base=&ds4 data=&ds3 force;
    run;
    proc sort data=&ds4 out=&_cstoutcodelistitemsds nodupkey;
      by  codedvalue fk_CodeLists ;
    run;

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

%mend crtdds_codelistitems;
