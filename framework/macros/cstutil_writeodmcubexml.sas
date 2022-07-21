%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_writeODMcubexml                                                        *;
%*                                                                                *;
%* Creates a temporary XML file that is used in the derivation of an ODM XML file.*;
%*                                                                                *;
%* The ODM XML create (write) process defines a SAS libref (&_cstTempRefMdTable)  *;
%* that is referenced here. This libref points to the ODM standard table and      *;
%* column metadata used to build the ODMcubexml file.                             *;
%*                                                                                *;
%* EXAMPLE:                                                                       *;
%*   %cstutil_ODMwritecubexml(_cstXMLOut=c:\odm\test.xml)                         *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstTempRefMdTable  Library containing reference ODM table and         *;
%*             column metadata                                                    *;
%*                                                                                *;
%* @param _cstXMLOut - required - The destination and the filename for the XML    *;
%*            output.                                                             *;
%* @param _cstEncoding - optional - The XML encoding to use for XML cube file.    *;
%*            Default: UTF-8                                                      *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_writeODMcubexml(
    _cstXMLOut=,
    _cstEncoding=UTF-8
    ) / des='CST: Create cube ODM XML file';

  %cstutil_setcstgroot;

  %local
    colcnt
    colnames
    coltypes
    dsname
    i
    j
    rc
    thisvar
    vartype
    _cstDSCnt
  ;

  %let rc=0;


  %if &rc = 0 %then
  %do;

    %***********************;
    %*  Setup output file  *;
    %***********************;

    filename testxml "&_cstXMLOut";

    data _null_;
      %if %sysevalf(%superq(_cstEncoding)=, boolean)=0 %then %do;
        file testxml encoding="&_cstEncoding" &_cstLRECL;
        put '<?xml version="1.0" encoding="' "&_cstEncoding" '"?>';
      %end;
      %else %do;
        file testxml &_cstLRECL;
        put '<?xml version="1.0"?>';
      %end;
      put "<LIBRARY>";
    run;

    data _null_;
      set &_cstTempRefMdTable..reference_tables end=last;
      if last then
      do;
        call symput('_cstDSCnt',put(_n_, best12.));
      end;
    run;

    %******************************;
    %* Loop through the Data Sets *;
    %******************************;
    %do i = 1 %to &_cstDSCnt;
      %let dsname=;
      %let colnames=;
      %let colcnt=;
      %let thisvar=;

      %****************************************************************;
      %*  Bring in the Reference_tables to retrieve appropriate data  *;
      %****************************************************************;
      data _null_;
        set &_cstTempRefMdTable..reference_tables (firstObs=&i obs=&i);
          call symputx('dsname',xmlelementname);
      run;

      %*****************************************************************;
      %*  Bring in the Reference_columns to retrieve appropriate data  *;
      %*****************************************************************;
      data _null_;
        set &_cstTempRefMdTable..reference_columns (keep=table xmlattributename type where=(table=upcase("&dsname"))) end=last;
        length varnames $2000 vartypes $100;
        retain varnames vartypes;
        varnames=catx(' ',varnames,xmlattributename);
        vartypes=catx(' ',vartypes,type);
        if last then
        do;
          call symput('colnames', varnames);
          call symput('coltypes', vartypes);
          call symputx('colcnt', put(_n_, best12.));
        end;
      run;

      %*************************************;
      %* Build all columns and all records *;
      %*************************************;
      data _null_;
        set srcdata.&dsname;
        length varlist $32767 content $2000 ncontent 8.;

        %************************;
        %*  Create output file  *;
        %************************;
        %if %sysevalf(%superq(_cstEncoding)=, boolean)=0 %then %do;
          file testxml mod encoding="&_cstEncoding" &_cstLRECL;
        %end;
        %else %do;
          file testxml mod &_cstLRECL;
        %end;

        put @3 "<%trim(&dsname)>";

        %do j=1 %to &colcnt;
          %let thisvar = %scan(&colnames,&j,' ');
          %let vartype = %scan(&coltypes,&j,' ');
          ncontent=.;
          content="";
          /**********************************************************
           *  Determine variable types                              *
           *  If character 'C' need to check for &, ", <, and >.    *
           *    These are tags in XML and need to be converted      *
           *    to xml friendly code.                               *
           *  If numeric 'N' need to handle the '.'(missing) that   *
           *    is prevalent in SAS data.  These will be converted  *
           *    to blanks                                           *
           **********************************************************/;
          %if &vartype eq C %then
          %do;
            content=&thisvar;
            %***************************;
            %* Convert Ampersand first *;
            %***************************;
            if kindexc(content,'&') then
            do;
              content=tranwrd(content,'&','&amp;');
            end;
            if kindexc(content,'"') then
            do;
              content=tranwrd(content,'"','&quot;');
            end;
            if kindexc(content,'<>') then
            do;
              content=tranwrd(content,"<",'&lt;');
              content=tranwrd(content,">",'&gt;');
            end;
          %end;
          %else %if &vartype eq N %then
          %do;
            ncontent=&thisvar;
            content=put(ncontent,best12.);
            content=compress(content);
          %end;

          %**********************************************************;
          %*  If data is missing or blank, output a blank XML tag   *;
          %*  If data is present, output correct XML tags and data  *;
          %**********************************************************;
          if kcompress(content)='' or kcompress(content)='.' then
            varlist=cats("<%trim(&thisvar)/>");
          else
            varlist=cats("<%trim(&thisvar)>",content,"</%trim(&thisvar)>");

          put @6 varlist;

        %end;

        %*********************************;
        %*  End of data set processing   *;
        %*********************************;
        put @3 "</%trim(&dsname)>";

      run;
    %end;

    data _null_;
      %if %sysevalf(%superq(_cstEncoding)=, boolean)=0 %then %do;
        file testxml mod encoding="&_cstEncoding" &_cstLRECL;
      %end;
      %else %do;
        file testxml mod &_cstLRECL;
      %end;
      put "</LIBRARY>";
    run;


    %***************************************;
    %* Deassign Reference Metadata Library *;
    %***************************************;
    libname &_cstTempRefMdTable;

    filename testxml;
  %end;

%mend cstutil_writeODMcubexml;
