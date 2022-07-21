%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcreatechecksummap                                                       *;
%*                                                                                *;
%* Creates an XML map file that is used to read checksum XML files.               *;
%*                                                                                *;
%* @param  _cstMapFile - required - The full path to the XML map file to create.  *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcreatechecksummap(
  _cstMapFile=%sysfunc(pathname(work))/checksum.map
  ) / des='CST: Create a checksum XML Map';

  %* Check required parameter;
  %if %sysevalf(%superq(_cstMapFile)=, boolean) %then %do;
     %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstMapFile parameter value is required.;
     %goto exit_macro;
  %end;

  %local _cstRandom;
  %let _cstRandom=%sysfunc(putn(%sysevalf(%sysfunc(ranuni(0))*10000,floor),z4.));

  proc sql;
    create table work.checksummap&_cstRandom(
      table  char(32),
      order num,
      column char(32),
      table_path char(200),
      column_path char(200),
      column_retain num,
      column_description char(200),
      column_type char(20),
      column_datatype char(20),
      column_length num
    )
    ;
    insert into work.checksummap&_cstRandom
      values("checksums", 1, "folder", "/InstalledFiles/sasfile", "/InstalledFiles/@folder", 1,"Root Folder", "character", "string", 4000)
      values("checksums", 2, "creationdatetime", "/InstalledFiles/sasfile", "/InstalledFiles/@creationdatetime", 1,"Time of creation of the file containing the document.", "character", "string", 20)
      values("checksums", 3, "label", "/InstalledFiles/sasfile", "/InstalledFiles/@label", 1,"Description", "character", "string", 40)
      values("checksums", 4, "prodcode", "/InstalledFiles/sasfile", "/InstalledFiles/sasfile/@prodcode", 0, "SAS Production Code", "character", "string", 40)
      values("checksums", 5, "path", "/InstalledFiles/sasfile", "/InstalledFiles/sasfile/@name", 0, "Path", "character", "string", 4000)
      values("checksums", 6, "checksum", "/InstalledFiles/sasfile", "/InstalledFiles/sasfile/@checksum", 0, "Checksum", "character", "string", 128)
    ;
  quit;

  proc sort data=work.checksummap&_cstRandom;
    by table order;
  run;

  data _null_;
    set work.checksummap&_cstRandom end=end;
    by table order;
    file "&_cstMapFile";
    if _n_=1 then do;
      put '<?xml version="1.0" encoding="UTF-8"?>';
      put '<SXLEMAP name="CheckSum" version="2.1">';
      put '  <NAMESPACES count="0"/>';
    end;
    if first.table then do;
      put '  <TABLE description="' table +(-1) '" name="' table +(-1) '">';
      put '    <TABLE-PATH syntax="XPath">' table_path +(-1) '</TABLE-PATH>';
    end;

    put '      <COLUMN name="' column +(-1) '"' @;
    If column_retain then put ' retain="YES"' @;
    put '>';
    put '        <PATH syntax="XPath">' column_path +(-1) '</PATH>';
    put '        <DESCRIPTION>' column_description +(-1) '</DESCRIPTION>';
    put '        <TYPE>' column_type +(-1) '</TYPE>';
    put '        <DATATYPE>' column_datatype +(-1) '</DATATYPE>';
    put '        <LENGTH>' column_length +(-1) '</LENGTH>';
    put '      </COLUMN>';

    if last.table then put '  </TABLE>';
    if end then put '</SXLEMAP>';

  run;

  proc datasets library=work nolist;
    delete checksummap&_cstRandom;
  quit;

%exit_macro:

%mend cstutilcreatechecksummap;
