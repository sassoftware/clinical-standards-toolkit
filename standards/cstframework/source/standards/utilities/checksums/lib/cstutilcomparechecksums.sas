%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcomparechecksums                                                        *;
%*                                                                                *;
%* Compares two checksum files.                                                   *;
%*                                                                                *;
%* This macro compares two checksum files and, optionally, creates a report.      *;
%*                                                                                *;
%* The following results are reported:                                            *;
%*     Files are different                                                        *;
%*     Files are identical                                                        *;
%*     File not found in BASE (file is in _cstCompXMLFile but not in              *;
%*                             _cstBaseXMLFile)                                   *;
%*     File not found in COMP (file is in _cstBaseXMLFile but not in              *;
%*                             _cstCompXMLFile)                                   *;
%*                                                                                *;
%* @param  _cstMapFile - optional - The XML map file to use. If this parameter    *;
%*            is not specified, the map is created by the                         *;
%*            cstutilcreatechecksummap macro.                                     *;
%* @param  _cstBaseXMLFile - required - The full path and filename for the XML    *;
%*            checksum file to compare against.                                   *;
%* @param  _cstCompXMLFile - required - The full path and filename for the XML    *;
%*            checksum file to compare.                                           *;
%* @param  _cstIgnore - optional - The string that, if present in the path,       *;
%*            causes the path to be ignored.                                      *;
%* @param  _cstCompResults - required - The location to store the results.        *;
%* @param  _cstOutReportPath - optional - The path to the output folder for the   *;
%*            report file.                                                        *;
%*            NOTE: If a SAS Output Delivery System destination does not support  *;
%*            PATH, this value must be blank.                                     *;
%* @param  _cstOutReportFile - optional - The filename of the report file. If     *;
%*            _cstOutReportPath is not specified, this value must be a full       *;
%*            path.                                                               *;
%* @param  _cstODSReportType - optional - The type of report.                     *;
%*            Values:  html                                                       *;
%*            Default: html                                                       *;
%* @param  _cstODSStyle - optional - The SAS Output Delivery System style to use  *;
%*            for the report.                                                     *;
%* @param  _cstODSOptions - optional - Additional SAS Output Delivery System      *;
%*            options.                                                            *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcomparechecksums(
  _cstMapFile=,
  _cstBaseXMLFile=,
  _cstCompXMLFile=,
  _cstIgnore=installs,
  _cstCompResults=work._cstchecksums,
  _cstOutReportPath=,
  _cstOutReportFile=,
  _cstODSReportType=html,
  _cstODSStyle=SASWeb,
  _cstODSOptions=
  ) / des='CST: Compare checksum XML files';

  %local i _cstReqParams _cstReqParam _cstReqFile _cstReqFiles
         _cstCreateMapFile _cstRandom
         _cstDIFFERENT _cstIDENTICAL _cstMISSINGBASE _cstMISSINGCOMP
         BaseCRDateTime ComCRDateTime BaseLabel CompLabel;

  %let _cstDIFFERENT=Files are different;
  %let _cstIDENTICAL=Files are identical;
  %let _cstMISSINGBASE=File not found in BASE;
  %let _cstMISSINGCOMP=File not found in COMP;

  %* Check required parameters;
  %let _cstReqParams=_cstBaseXMLFile _cstCompXMLFile _cstCompResults;
  %do i=1 %to %sysfunc(countw(&_cstReqParams));
     %let _cstReqParam=%kscan(&_cstReqParams, &i);
     %if %sysevalf(%superq(&_cstReqParam)=, boolean) %then %do;
        %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstReqParam parameter value is required.;
        %goto exit_macro;
     %end;
  %end;

  %* Check required files;
  %let _cstReqFiles=_cstBaseXMLFile _cstCompXMLFile;
  %do i=1 %to %sysfunc(countw(&_cstReqFiles));
     %let _cstReqFile=%kscan(&_cstReqFiles, &i);
     %if %sysfunc(fileexist(&&&_cstReqFile))=0 %then %do;
        %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] File &&&_cstReqFile does not exist.;
        %goto exit_macro;
     %end;
  %end;

  %let _cstRandom=%sysfunc(putn(%sysevalf(%sysfunc(ranuni(0))*10000,floor),z4.));

  %* If XML Map was not specified, or does not exist, create it;
  %let _cstCreateMapFile=0;
  %if %sysevalf(%superq(_cstMapFile)=, boolean) %then %do;
    %let _cstCreateMapFile=1;
  %end;
  %else %do;
    %if %sysfunc(fileexist(&_cstMapFile))=0 %then
     %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] XML Map file &_cstMapFile does not exist.;
     %let _cstCreateMapFile=1;
  %end;
  %if %eval(&_cstCreateMapFile) %then %do;
    %let _cstMapFile=%sysfunc(pathname(work))/checksum&_cstRandom..map;
    %cstutilcreatechecksummap(_cstMapFile=%sysfunc(pathname(work))/checksum&_cstRandom..map);
  %end;

  filename  base&_cstRandom  "&_cstBaseXMLFile";
  filename  comp&_cstRandom  "&_cstCompXMLFile";
  filename  sxlemap "&_cstMapFile";

  libname base&_cstRandom xmlv2 xmlmap=sxlemap access=readonly;
  libname comp&_cstRandom xmlv2 xmlmap=sxlemap access=readonly;

  data checksums_base&_cstRandom(drop=l path CreationDateTime Label);
    set base&_cstRandom..checksums(rename=(checksum=checksum_base folder=baseroot));
    length file $4000;
    if _n_=1 then do;
      call symputx ("BaseCRDateTime", CreationDateTime);
      call symputx ("BaseLabel", Label);
    end;
    l=length(baseroot);
    file=ktranslate(path,"/","\");
    file=ksubstr(file, l+1);
    if ksubstr(file,1,1)="/" then file=ksubstr(file,2);
    file=tranwrd(file, "1.5/", "1.x/");
    file=tranwrd(file, "1.6/", "1.x/");
    if index(upcase(path), upcase("&_cstIgnore")) then delete;
  run;

  proc sort data=checksums_base&_cstRandom;
    by prodcode file;
  run;

  data checksums_comp&_cstRandom(drop=l path CreationDateTime Label);
    set comp&_cstRandom..checksums(rename=(checksum=checksum_comp folder=comproot));
    length file $4000;
    if _n_=1 then do;
      call symputx ("CompCRDateTime", CreationDateTime);
      call symputx ("CompLabel", Label);
    end;
    l=length(comproot);
    file=ktranslate(path,"/","\");
    file=ksubstr(file, l+1);
    if ksubstr(file,1,1)="/" then file=ksubstr(file,2);
    file=tranwrd(file, "1.5/", "1.x/");
    file=tranwrd(file, "1.6/", "1.x/");
    if index(upcase(path), upcase("&_cstIgnore")) then delete;
  run;

  proc sort data=checksums_comp&_cstRandom;
    by prodcode file;
  run;

  data &_cstCompResults;
    retain prodcode baseroot comproot file filename extension checksum_base checksum_comp result;
    length result $100 extension $32 filename $128;
    label checksum_base="Checksum (base)"
          checksum_comp="Checksum (comp)";
    merge checksums_base&_cstRandom checksums_comp&_cstRandom;
    by prodcode file;
    if missing(checksum_base) or missing(checksum_comp) then do;
      if missing(checksum_base) then result="&_cstMISSINGBASE";
      if missing(checksum_comp) then result="&_cstMISSINGCOMP";
    end;
    else do;
      if checksum_base ne checksum_comp
        then result="&_cstDIFFERENT";
        else result="&_cstIDENTICAL";
    end;
    extension=kscan(file, -1,".");
    filename=kscan(file, -1,"\/");
  run;




  %* Generate report;
  %if %sysevalf(%superq(_cstOutReportFile)=, boolean)=0 %then %do;

    %local BaseRoot CompRoot ProdCode BaseCRDateTime CompCRDateTime;

    data _null_;
      set &_cstCompResults(where=(not missing(baseroot) and not missing(comproot)));
      if _n_=1;
      call symputx ("BaseRoot", baseroot);
      call symputx ("CompRoot", comproot);
      call symputx ("ProdCode", prodcode);
    run;

    %if %sysevalf(%superq(_cstODSReportType)=, boolean) %then %do;
      %let _cstODSReportType=html;
      %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstODSReportType set to "&_cstODSReportType";
    %end;

    %if %sysevalf(%superq(_cstODSStyle)=, boolean) %then %do;
      %let _cstODSStyle=SASWeb;
      %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstODSStyle set to "&_cstODSStyle";
    %end;

    ods listing close;
    ods escapechar = '^';
    ods &_cstODSReportType %if %sysevalf(%superq(_cstOutReportPath)=, boolean)=0 %then path="&_cstOutReportPath"; file="&_cstOutReportFile" style=&_cstODSStyle &_cstODSOptions;

    title01 "Base Directory: &BaseRoot (&BaseCRDateTime)";
    title02 "Compare Directory: &CompRoot (&CompCRDateTime)";
    title03 "SAS Production Code: &ProdCode";

    title05 "Differences in Files";
    proc report nowd data=&_cstCompResults;
      column file checksum_base checksum_comp result;
      define file / "File";
      define checksum_base / "Checksum (&BaseLabel)";
      define checksum_comp / "Checksum (&CompLabel)";
      define result / "Result";
      where result eq "&_cstDIFFERENT";
    run;

    title05 "Missing Files";
    proc report nowd data=&_cstCompResults;
      column file checksum_base checksum_comp result;
      define file / "File";
      define checksum_base / "Checksum (&BaseLabel)";
      define checksum_comp / "Checksum (&CompLabel)";
      define result / "Result";
      where (result eq "&_cstMISSINGBASE") or (result eq "&_cstMISSINGCOMP");
    run;

    title05 "Identical Files";
    proc report nowd data=&_cstCompResults;
      column file checksum_base checksum_comp result;
      define file / "File";
      define checksum_base / "Checksum (&BaseLabel)";
      define checksum_comp / "Checksum (&CompLabel)";
      define result / "Result";
      where result eq "&_cstIDENTICAL";
    run;
    
    ods &_cstODSReportType close;
    ods listing;

  %end;
  %else 
  %do;
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstOutReportFile parameter not specified.;
  %end;

  %* Clean up;
  proc datasets library=work nolist;
    delete checksums_base&_cstRandom checksums_comp&_cstRandom;
  quit;

  libname base&_cstRandom clear;
  libname comp&_cstRandom clear;
  filename base&_cstRandom;
  filename comp&_cstRandom;
  filename sxlemap;

%exit_macro:

%mend cstutilcomparechecksums;
