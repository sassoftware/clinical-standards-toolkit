%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_codelists                                                               *;
%*                                                                                *;
%* Creates the SAS CRT-DDS CodeLists data set from source metadata.               *;
%*                                                                                *;
%* @param  _cstSourceColumns - required - The data set that contains the SDTM     *;
%*             column  metadata for the Domain columns to include in the CRT-DDS  *;
%*             file.                                                              *;
%* @param  _cstSourceValues  - optional - The data set that contains the          *;
%*             metadata for the Value Level columns to include in the CRT-DDS     *;
%*             file.                                                              *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*            library (for example, srcdata.MetaDataVersion).                     *;
%* @param _cstmdvname - required - The MetadataVersion/@Name attribute.           *;
%* @param _cstoutcodelistsds - required - The CodeLists data set to create        *;
%*            (for example, srcdata.CodeLists).                                   *;
%*                                                                                *;
%* @history 2013-12-12  Added _cstSourceValues to ensure codelist references in   *;
%*             Value Level Metadata are kept                                      *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_codelists(
    _cstsourcecolumns=,
    _cstsourcevalues=,
    _cstmdvds=,
    _cstmdvname=,
    _cstoutcodelistsds=
    ) / des="Creates SAS CRT-DDS CodeLists data set";

%if %length(&_cstsourcecolumns)=0 or %length(&_cstmdvds)=0 or %length(&_cstmdvname)=0
  or %length(&_cstoutcodelistsds)=0
    %then %goto exit;

%if ^%sysfunc(exist(&_cstsourcecolumns)) %then %goto exit;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %goto exit;


/* options fmtsearch must point to sas format catalogs, or they must exist in work */
%local _cstRandom ds1 i ds2 ds3 ds4 ds5 ds6;
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

  %if %symexist(_cstmdvDS) %then %do;
    %if (%sysfunc(indexc("&_cstmdvDS",'.'))=0) %then %let mdvds=&_cstmdvds;
    %else %do;
      %let mdv2=%scan(&_cstmdvDS,2,'.');
      %let mdvds=&mdv2;
    %end;
  %end;
  %if %symexist(_cstoutcodelistsds) %then %do;
      %if %sysfunc(indexc("&_cstoutcodelistsds",'.'))=0 %then %let clds=&_cstoutcodelistsds;
      %else %do;
        %let cl=%scan(&_cstoutcodelistsds,2,'.');
        %let clds=&cl;
      %end;
  %end;

  %if %symexist(clds) %then %do;
    %if %sysfunc(exist(&_cstoutcodelistsds)) %then %do;
      %let dsidst=%sysfunc(open(&_cstoutcodelistsds,i));
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
  %let ds1=_c1&_cstRandom;

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
      proc format lib = work._cstfmts cntlout=&ds1 (rename=(fmtname=Name));
      run ;
      catname _cstfmts clear;
  %END;


  proc sort data=&ds1; by name; run;
  data &ds1 (keep=
        Name
        DataType
        SASFormatName
        );
      length SASFormatName $200;  
      set &ds1;
    by name;
      select(type);
        when('C') DataType='text';
        otherwise DataType='integer';
      end;

      select(type);
        when('C') SASFormatName=cats('$', Name);
        otherwise SASFormatName=Name;
      end;

      ;


      if last.Name then output;
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
  
  proc sort data=&ds1 out=&ds1;
    by name;
  run;

  %* only keep the formats specified in the source_columns and source_values datasets *;
  data &ds6;
    merge &ds1(in=cl) &ds5(in=src);
      by name;
    if src=1 and cl=1;
  run;

  %let ds2=_c2&_cstRandom;

  proc sql;
    create table &ds2 as
      select
            "" as OID length = 128 ,
            &ds6..Name as Name length = 128,
            &ds6..DataType as DataType length = 7,
            ifc(length(&ds6..SASFormatName) le 8, &ds6..SASFormatName, "") as SASFormatName length = 8,
            strip(&mdvDS..oid) as FK_MetaDataVersion length = 128
      from
        &ds6 left join &_cstmdvds
      on ( &ds6..name not is missing)
      where ( upcase(&mdvds..name)=upcase("&_cstmdvname"));
  quit;

%let ds3=_c3&_cstRandom;
data &ds3(drop=key);
  set &ds2;
  format name $128.;
  RETAIN KEY;
  IF _N_=1 THEN KEY=&KEYCNT;
  else key=sum(key,1);
  OID= upcase(name) || strip(key);
  OID = cats("CL.", upcase(name));
RUN;


%let ds4=_c4&_cstRandom;
%if &outDSexists=1 %then %do;
  data &ds4;
    set &_cstoutcodelistsds;
  run;
%end;

  proc append base=&ds4 data=&ds3 force;
  run;
  proc sort data=&ds4 out=&_cstoutcodelistsds nodupkey;
    by  name fk_MetaDataVersion;
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
        %end;
      %end;
    %end;
  %end;

%exit:

%mend crtdds_codelists;
