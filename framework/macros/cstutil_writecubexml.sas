%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_writecubexml                                                           *;
%*                                                                                *;
%* Creates a temporary XML file that is used by the define.xml process.           *;
%*                                                                                *;
%* The sole input to this macro is the MDP SAS data set that contains the         *;
%* member names and the library references that are needed for the define process.*;
%* The sole output is the XML file, as specified by you.                          *;
%*                                                                                *;
%* Example:                                                                       *;
%*   %cstutil_writecubexml(_cstXMLOut=c:\crtdds\test2.xml,                        *;
%*                         _cstMDPFile=srcdata.mdp,                               *;
%*                         _cstDebug=1)                                           *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*                                                                                *;
%* @param _cstXMLOut - required - The destination and the filename for the XML    *;
%*            output.                                                             *;
%* @param _cstEncoding - optional - The XML encoding to use for the XML cube file.*;
%*            Default: UTF-8                                                      *;
%* @param _cstMDPFile - required - The SAS data set that specifies the pointers   *;
%*            to the data. This value must contain a libref (for example,         *;
%*            srcdata.mdp). If a libref is omitted, this macro fails.             *;
%*                                                                                *;
%* @since  1.3                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_writecubexml(
    _cstXMLOut=,
    _cstEncoding=UTF-8,
    _cstMDPFile=
    ) / des='CST: Create cube XML file';

  %cstutil_setcstgroot;

  %local
    libn
    rc
    _numRecs
  ;

  %let rc=0;

  %*************************************************************;
  %*  Check for existence of REQUIRED input libname parameter  *;
  %*  Check for existence of libname                           *;
  %*************************************************************;

  %let libn = %sysfunc(scan(&_cstMDPFile,1,.));
  %if %length(&libn) = 0 %then
  %do;
    %let rc=1;
    %put "************************************************";
    %put "* MDP data set is missing a LIBNAME reference. *";
    %put "************************************************";
  %end;
  %else
  %do;
    proc sort data=sashelp.vslib out=_libn nodupkey;
      by libname;
      where libname = "%upcase(&libn)";
    run;

    data _null_;
      if 0 then set _libn nobs=_numobs;
      call symputx('_numRecs',_numobs);
      stop;
    run;

    proc datasets nolist lib=work;
       delete _libn / memtype=data;
       quit;
    run;

    %if &_numRecs = 0 %then
    %do;
      %let rc=1;
      %put "*******************************************************************";
      %put "* %upcase(&libn) LIBNAME reference for MDP data set does not exist.";
      %put "*******************************************************************";
    %end;
    %else
    %do;
      %if %sysfunc(exist(&_cstMDPFile)) ne 1 %then
      %do;
        %let rc=1;
        %put "*****************************************************";
        %put "* %upcase(&_cstMDPFile) data set does not exist.";
        %put "*****************************************************";
      %end;
    %end;
  %end;

  %if &rc = 0 %then
  %do;

    %***********************;
    %*  Setup output file  *;
    %***********************;

    filename testxml "&_cstXMLOut";

    data _null_;
      %************************;
      %*  Create output file  *;
      %************************;

      %if %sysevalf(%superq(_cstEncoding)=, boolean)=0 %then %do;
        file testxml encoding="&_cstEncoding" &_cstLRECL;
      %end;
      %else %do;
        file testxml &_cstLRECL;
      %end;

      %*************************************************************;
      %*  Bring in the MDP file to read retrieve appropriate data  *;
      %*************************************************************;
      set &_cstMDPFile end=last;

      retain init 0;
      length name dsname1 dsname2 $32 content $2000 varlist $32767;

      %************************************************************;
      %*  Retrieve data set from values supplied in the MDP file  *;
      %*  If data set exists DSID = 1 otherwise = 0               *;
      %************************************************************;
      dsid=open(mdpmemname,"i");

      %*************************************************;
      %*  Initialize output file when data set exists  *;
      %*************************************************;
      if dsid = 1 and init = 0 then
      do;
        if ("&_cstEncoding" ne '') then do;
          put '<?xml version="1.0" encoding="' "&_cstEncoding" '"?>';
        end;
        else
          put '<?xml version="1.0"?>';
        put "<LIBRARY>";
        init = 1;
      end;

      %******************************************************;
      %*  Data present - loop through the columns and data  *;
      %******************************************************;
      if dsid > 0 then
      do;
        %**********************************;
        %*  Retrieve number of variables  *;
        %**********************************;
        num=attrn(dsid,"nvars");
        dsname1="<"||kcompress(mdpname)||">";
        obscnt=0;
        do while (fetch(dsid)=0);
          obscnt +1;
          put @2 dsname1;
          do i=1 to num;
            name=varname(dsid,i);
            /*********************************************************
            *  Determine variable types                              *
            *  If character 'C' need to check for &, ", <, and >.    *
            *    These are tags in XML and need to be converted      *
            *    to xml friendly code.                               *
            *  If numeric 'N' need to handle the '.'(missing) that   *
            *    is prevalent in SAS data.  These will be converted  *
            *    to blanks                                           *
            *********************************************************/
            if (vartype(dsid,i)='C') then
            do;
              content=ktrim(getvarc(dsid,i));
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
            end;
            else if (vartype(dsid,i)='N') then
            do;
              ncontent=getvarn(dsid,i);
              content=put(ncontent,best12.);
              content=compress(content);
            end;
            %**********************************************************;
            %*  If data is missing or blank, output a blank XML tag   *;
            %*  If data is present, output correct XML tags and data  *;
            %**********************************************************;
            if kcompress(content)='' or kcompress(content)='.' then
              varlist='<'||trim(name)||"/>";
            else
              varlist='<'||compress(name)||">"||ktrim(content)||"</"||compress(name)||">";
            put @4 varlist;
          end;
          %*********************************;
          %*  End of data set processing   *;
          %*********************************;
          dsname2="</"||kcompress(mdpname)||">";
          put @2 dsname2;
        end;
      end;

      rc=close(dsid);

      %**************************************;
      %*  End of data in specified library  *;
      %**************************************;
      if last and init=1 then put "</LIBRARY>";

    run;

    filename testxml;
  %end;

%mend cstutil_writecubexml;
