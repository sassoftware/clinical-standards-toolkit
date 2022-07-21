%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_createmetadatareport                                                   *;
%*                                                                                *;
%* Creates a report that documents the metadata of a process.                     *;
%*                                                                                *;
%* The report for the SAS Clinical Standards Toolkit process is based on these    *;
%* data sets:                                                                     *;
%*           validation_master                                                    *;
%*           validation_control                                                   *;
%*           Messages                                                             *;
%*           validation_stdRef                                                    *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*                                                                                *;
%* @param _cstStandardTitle - optional - The title that defines the title2        *;
%*            statement for all reports.                                          *;
%* @param _cstValidationDS - required - The validation data set that is used by a *;
%*           SAS Clinical Standards Toolkit process. This is                      *;
%*           validation_master or validation_control, or a derivative specified   *;
%*           by you.                                                              *;
%* @param _cstValidationDSWhClause - optional - The WHERE clause that is applied  *;
%*            to _cstValidationDS.                                                *;
%* @param _cstMessagesDS - required - The Messages data set that is used by a     *;
%*            SAS Clinical Standards Toolkit process.                             *;
%* @param _cstStdRefDS - conditional - The Validation_stdref data set that is     *;
%*            created for a SAS Clinical Standards Toolkit standard. If           *;
%*            _cstStdRefReport=Y, this file is required.                          *;
%* @param _cstReportOutput - required - The file that contains the report.        *;
%*            The acceptable files are PDF, RTF, CSV, and HTML. The extension is  *;
%*            used to determine SAS ODS Graphics Editor output.                   *;
%* @param _cstCheckMDReport - optional - Generate the Run panel 2, Check Details. *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param _cstMessageReport - optional - Generate the Run panel 3, Message        *;
%*            Details.                                                            *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param _cstStdRefReport - optional - Generate the Run panel 4, Reference       *;
%*            Information.                                                        *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param _cstRecordView - optional - Generate a full listing of all available    *;
%*            check metadata, by check, in a single listing. Either this listing  *;
%*            or the multi-panel report can be generated in a single invocation   *;
%*            of this macro, but not both.                                        *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro cstutil_CreateMetadataReport(
    _cstStandardTitle=,
    _cstValidationDS=,
    _cstValidationDSWhClause=,
    _cstMessagesDS=,
    _cstStdRefDS=,
    _cstReportOutput=,
    _cstCheckMDReport=N,
    _cstMessageReport=N,
    _cstStdRefReport=N,
    _cstRecordView=N
    ) / des='CST: Create a metadata report';

  %local
    _cstControlMessages
    _cstError
    _cstIDVar
    _cstRandomNum
    _cstRecCnt
    _cstRefCnt
    _cstReportFormat
    _cstReportInfo
    _cstReportRuntime
    _cstSourceFolder
    _cstSourceDS
    _cstValidationStdRef
    _cstValidationMsg
    _cstWhereTitle
  ;

  %let _cstError=0;

  %*************************************************************;
  %*  Check for existence of needed parameters and data sets   *;
  %*************************************************************;
  %if &_cstreportoutput= %then
  %do;
    %put Note: The location for report output is required;
    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not run - The location for report output is required,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_CREATEMETADATAREPORT);
    %goto exit_macro;
  %end;
  %else
  %do;
    data _null_;
      length fname $2000;
      fname=strip(symget("_cstreportoutput"));
      if kindexc(fname,"/\:")>0 then
      do;
        lfname=klength(fname);
        doc=kreverse(ksubstr(kreverse(fname),1,kindexc(kreverse(fname),"/\")-1));
        ldoc=klength(doc);
        if ldoc gt 0 then ldoc+1;
        path=ksubstr(fname,1,lfname-ldoc);
        rc=filename("mydir",path);
        did=dopen("mydir");
        if did = 0 then
           call symputx('_cstError',1);
        else
          did=dclose(did);
      end;
    run;
  %end;
  %if &_cstError=1 %then
  %do;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not run - The location for report output (&_cstreportoutput) could not be opened,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_CREATEMETADATAREPORT);
    %goto exit_macro;
  %end;

  %if &_cstValidationDS= and &_cstMessagesDS= %then
  %do;
    %put Warning: Validation data set and Messages data set are not provided.  Please supply parameters;
    %goto exit_macro;
  %end;
  %else
  %do;
    %if not %sysfunc(exist(&_cstValidationDS)) %then
    %do;
      %put Warning: The validation data set &_cstValidationDS DOES NOT EXIST!;
      %goto exit_macro;
    %end;

    %if not %sysfunc(exist(&_cstMessagesDS)) %then
    %do;
      %put Warning: The messages data set &_cstMessagesDS DOES NOT EXIST!;
      %goto exit_macro;
    %end;

    %*******************************************************;
    %*  Extract the file extension from &_cstReportOutput  *;
    %*    to determine report style                        *;
    %*  Extract date and time this report is run           *;
    %*******************************************************;
    data _null_;
      length fout $2000;
      now=datetime();
      call symput('_cstReportRuntime',put(now, is8601dt.));
      fout=reverse(strip(symget("_cstReportOutput")));
      if indexc(fout,'.')>0 then ffmt=reverse(substr(fout,1,indexc(fout,".")-1));
      else ffmt='';
      call symput('_cstReportFormat',ffmt);
    run;

    %****************************************************************;
    %*  Check for allowable file extensions PDF, RTF, CSV and HTML  *;
    %****************************************************************;
    %if &_cstReportFormat= %then
    %do;
      %put Warning: No File extension. The specified Report file requires an extension of PDF, RTF, or HTML (current file is &_cstReportOutput )!;
      %goto exit_macro;
    %end;
    %else %if ("%upcase(&_cstReportFormat)" ne "PDF") and ("%upcase(&_cstReportFormat)" ne "RTF") and ("%upcase(&_cstReportFormat)" ne "CSV") and ("%upcase(&_cstReportFormat)" ne "HTML") %then
    %do;
      %put Warning: The specified Report file requires an extension of PDF, RTF, CSV or HTML.  Currently it is %upcase(&_cstReportFormat);
      %goto exit_macro;
    %end;

    %***************************;
    %*  Create needed formats  *;
    %***************************;
    proc format library=work.formats;
      value $YesNo 'N'='No'
                   'Y'='Yes'
                 other='N/A'
      ;
      value Status 0      ='Inactive'
                   1-high ='Active'
                   -1     ='Deprecated'
                   other  ='Unknown'
      ;
      value $Status '0'   ='Inactive'
                    '1'   ='Active'
                    '-1'  ='Deprecated'
                    other ='Unknown'
      ;
    run;

    %******************************************************;
    %*  Retrieve Footnote Information for Panels 1 and 2  *;
    %******************************************************;
    data _null_;
      length pfolder $2000;
      if index("&_cstValidationDS",'.') then
      do;
        libref=scan("&_cstValidationDS",1,'.');
        if upcase(libref) ne 'WORK' then
          pfolder=pathname(scan("&_cstValidationDS",1,'.'));
        else pfolder='WORK';
        psource=scan("&_cstValidationDS",2,'.');
      end;
      else
      do;
        pfolder='WORK';
        psource="&_cstValidationDS";
      end;
      call symput('_cstSourceFolder',trim(pfolder));
      call symput('_cstSourceDS',trim(psource));
    run;

    %*************************************************;
    %*  Initialize preliminary titles and footnotes  *;
    %*************************************************;
    title1 "SAS Clinical Standards Toolkit &_cstVersion";
    title2 "&_cstStandardTitle";
    title3 " ";
    footnote j=left h=6pt "Report generated: &_cstReportRuntime";
    footnote2 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

    %cstutil_getRandomNumber(_cstVarname=_cstControlMessages);

    %************************************************************************;
    %*  Check for existence of Where Clause parameter and apply if present  *;
    %************************************************************************;
    %let _cstWhereTitle=;
    %if %length(&_cstValidationDSWhClause)>0 %then
    %do;
      %let _cstWhereTitle=(Where &_cstValidationDSWhClause);
    %end;

    proc sql;
      create table work._cst&_cstControlMessages as
      select a.resultid, a.sourcedescription, a.messagetext, a.parameter1, a.parameter2, a.messagedetails, b.*
      %if %length(&_cstValidationDSWhClause)>0 %then
      %do;
        from &_cstMessagesDS as a,
             &_cstValidationDS(where=(&_cstValidationDSWhClause)) as b
      %end;
      %else
      %do;
        from &_cstMessagesDS as a,
             &_cstValidationDS as b
      %end;
      where a.resultid eq b.checkid and a.standardversion eq b.standardversion and a.checksource=b.checksource
      order by checkid;
    quit;

    %*****************************************************;
    %*  Check for possible Where clause error condition  *;
    %*****************************************************;
    %if &syserr=1012 %then
    %do;
      %put Warning: Possible error with SQL statement.  Check syntax of where clause (&_cstValidationDSWhClause);
      %goto exit_macro;
    %end;

    %cstutil_getRandomNumber(_cstVarname=_cstReportInfo);

    data work._cst&_cstReportInfo;
      set work._cst&_cstControlMessages;
      if trim(codelogic)='' then codelogic="No codelogic for this check";
    run;

    proc sort data=work._cst&_cstReportInfo;
      by checkid;
    run;

    %if %upcase(&_cstRecordView) ne Y %then
    %do;
      %*****************************;
      %*  Metadata Report Panel 1  *;
      %*****************************;
      ods listing close;
      options orientation=landscape;
      filename _cstrpt "&_cstReportOutput";

      ods &_cstReportFormat file=_cstrpt style=sasweb
      %if %upcase(&_cstReportFormat)=PDF %then
      %do;
         NOTOC
      %end;
      ;
      ods noproctitle;
      title4 "Check Overview";
      %if &_cstWhereTitle ne %then
      %do;
        title5 "&_cstWhereTitle";
      %end;

      %*************************************;
      %*  Panel 1 - Check Overview Report  *;
      %*************************************;
      proc report data=work._cst&_cstReportInfo nowd split="*" /* contents=" " */
           style(report)={just=center outputwidth=10.5 in font_size=8pt};
        column checkid standardversion checksource sourceid sourcedescription checkseverity tablescope columnscope;
        define checkid/order "Validation*Check*Identifier" id
               style(column)={just=center font_size=1 cellwidth=0.75 in}
               style(header)={cellwidth=0.75 in};
        define standardversion/display  "Version of*Standard"
               style(column)={just=left font_size=1 cellwidth=0.75 in}
               style(header)={cellwidth=0.75 in};
        define checksource/display  "Source*of*Check"
               style(column)={just=left font_size=1 cellwidth=0.75 in}
               style(header)={cellwidth=0.75 in};
        define sourceid/display  "Record*Identifier*used by*Check*Source"
               style(column)={just=left font_size=1 cellwidth=0.75 in}
               style(header)={cellwidth=0.75 in};
        define sourcedescription/display  "Rule Description from Checksource"
               style(column)={just=left font_size=1 cellwidth=3.67 in}
               style(header)={cellwidth=3.67 in};
        define checkseverity/display  "Severity*of Check"
               style(column)={just=left font_size=1 cellwidth=0.75 in}
               style(header)={cellwidth=0.75 in};
        define tablescope/display "Domains/Data Sets*to which*Check Applies"
               style(column)={just=left font_size=1 cellwidth=1.50 in}
               style(header)={cellwidth=1.50 in};
        define columnscope/display "Columns*to which*Check Applies"
               style(column)={just=left font_size=1 cellwidth=1.50 in}
               style(header)={cellwidth=1.50 in};
      run;

      %if %upcase(&_cstCheckMDReport)=Y %then
      %do;
        %*****************************;
        %*  Metadata Report Panel 2  *;
        %*****************************;
        title4 "Additional Check Details";
        %if &_cstWhereTitle ne %then
        %do;
          title5 "&_cstWhereTitle";
        %end;

        %***********************************************;
        %*  Panel 2 - Additional Check Details Report  *;
        %***********************************************;
        proc report data=work._cst&_cstReportInfo nowd split="*" /* contents="" */
             style(report)={just=center outputwidth=10.5 in font_size=5pt};
          column checkid checksource checktype codesource usesourcemetadata codelogic lookuptype lookupsource checkstatus reportall;
          define checkid/order "Validation*Check*Identifier" id
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define checksource/display  "Source*of*Check"
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define checktype/display  "Type*of*Check"
                 style(column)={just=left font_size=1 cellwidth=0.60 in}
                 style(header)={cellwidth=0.60 in};
          define codesource/display  "Code*Source"
                 style(column)={just=left font_size=1 cellwidth=1.00 in}
                 style(header)={cellwidth=1.00 in};
          define usesourcemetadata/display  "Use*Source*Metadata" format=$YesNo.
                 style(column)={just=left font_size=1 cellwidth=0.70 in}
                 style(header)={cellwidth=0.70 in};
          define codelogic/display  "Code Logic"
                 style(column)={just=left font_size=1 cellwidth=4.00 in}
                 style(header)={cellwidth=4.00 in};
          define lookuptype/display "Lookup*Standard*Type"
                 style(column)={just=left font_size=1 cellwidth=0.70 in}
                 style(header)={cellwidth=0.70 in};
          define lookupsource/display "SAS*Format*Name"
                 style(column)={just=left font_size=1 cellwidth=0.60 in}
                 style(header)={cellwidth=0.60 in};
          define checkstatus/display "Check*Status" format=status.
                 style(column)={just=left font_size=1 cellwidth=0.70 in}
                 style(header)={cellwidth=0.70 in};
          define reportall/display "Report*All?" format=$YesNo.
                 style(column)={just=left font_size=1 cellwidth=0.60 in}
                 style(header)={cellwidth=0.60 in};
        run;
      %end;

      %if %upcase(&_cstMessageReport)=Y %then
      %do;
        %**********************************************;
        %*  Metadata Report Panel 3                   *;
        %*  Retrieve Footnote Information for Panel 3 *;
        %**********************************************;
        data _null_;
          length pfolder $2000;
          if index("&_cstMessagesDS",'.') then
          do;
            libref=scan("&_cstMessagesDS",1,'.');
            if upcase(libref) ne 'WORK' then
              pfolder=pathname(scan("&_cstMessagesDS",1,'.'));
            else pfolder='WORK';
            psource=scan("&_cstMessagesDS",2,'.');
          end;
          else
          do;
            pfolder='WORK';
            psource="&_cstMessagesDS";
          end;
          call symput('_cstSourceFolder',trim(pfolder));
          call symput('_cstSourceDS',trim(psource));
        run;

        %cstutil_getRandomNumber(_cstVarname=_cstValidationMsg);

        proc sort data=&_cstMessagesDS out=work._cst&_cstValidationMsg(rename=(resultid=checkid));
          by resultid checksource;
        run;

        %cstutil_getRandomNumber(_cstVarname=_cstRandomNum);

        %****************************************************************;
        %*  Display only unique occurrences of CHECKID and CHECKSOURCE  *;
        %****************************************************************;
        proc sort data=work._cst&_cstReportInfo out=work._cst&_cstRandomNum(keep=checkid checksource) nodupkey;
          by checkid checksource;
        run;

        data work._cst&_cstValidationMsg;
          merge work._cst&_cstValidationMsg work._cst&_cstRandomNum(in=inrand);
          by checkid checksource;
          if inrand;
        run;

        title4 "Message Details";
        %if &_cstWhereTitle ne %then
        %do;
          title5 "&_cstWhereTitle";
        %end;
        footnote2 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

        %**************************************;
        %*  Panel 3 - Message Details Report  *;
        %**************************************;
        proc report data=work._cst&_cstValidationMsg nowd split="*" /* contents=" " */
             style(report)={just=center outputwidth=10.5 in font_size=5pt};
          column checkid checksource messagetext parameter1 parameter2 messagedetails;
          define checkid/order "Validation*Check*Identifier" id
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define checksource/display  "Source*of*Check"
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define messagetext/display "Message Text"
                 style(column)={just=left font_size=1 cellwidth=3.90 in}
                 style(header)={cellwidth=3.90 in};
          define parameter1/display "Message*Parameter 1*Default*Value"
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define parameter2/display "Message*Parameter 2*Default*Value"
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define messagedetails/display "Basis or Explanation for Result"
                 style(column)={just=left font_size=1 cellwidth=3.50 in}
                 style(header)={cellwidth=3.50 in};
        run;

        proc datasets lib=work nolist;
          delete _cst&_cstRandomNum/memtype=data;
          delete _cst&_cstValidationMsg/memtype=data;
        quit;

      %end;

      %if %upcase(&_cstStdRefReport)=Y and %sysfunc(exist(&_cstSTDRefDS)) %then
      %do;
        %***********************************************;
        %*  Metadata Report Panel 4                    *;
        %*  Retrieve Footnote Information for Panel 4  *;
        %***********************************************;
        data _null_;
          length pfolder $2000;
          if index("&_cstStdRefDS",'.') then
          do;
            libref=scan("&_cstStdRefDS",1,'.');
            if upcase(libref) ne 'WORK' then
              pfolder=pathname(scan("&_cstStdRefDS",1,'.'));
            else pfolder='WORK';
            psource=scan("&_cstStdRefDS",2,'.');
          end;
          else
          do;
            pfolder='WORK';
            psource="&_cstStdRefDS";
          end;
          call symput('_cstSourceFolder',trim(pfolder));
          call symput('_cstSourceDS',trim(psource));
        run;

        %cstutil_getRandomNumber(_cstVarname=_cstValidationStdRef);

        proc sort data=&_cstStdRefDS out=work._cst&_cstValidationStdRef;
          by checkid;
        run;

        %cstutil_getRandomNumber(_cstVarname=_cstRandomNum);

        %************************************************;
        %*  Display only unique occurrences of CHECKID  *;
        %************************************************;
        proc sort data=work._cst&_cstReportInfo out=work._cst&_cstRandomNum(keep=checkid) nodupkey;
          by checkid;
        run;

        data work._cst&_cstValidationStdRef;
          merge work._cst&_cstValidationStdRef work._cst&_cstRandomNum(in=inrand);
          by checkid;
          if inrand;
          if trim(sourcetext) = '' then sourcetext="No Source Text for this check";
        run;

        title4 "Reference Information";
        %if &_cstWhereTitle ne %then
        %do;
          title5 "&_cstWhereTitle";
        %end;
        footnote2 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

        %********************************************;
        %*  Panel 4 - Reference Information Report  *;
        %********************************************;
        proc report data=work._cst&_cstValidationStdRef nowd split="*" /* contents=" " */
             style(report)={just=center outputwidth=10.5 in font_size=5pt};
          column checkid informationsource sourcelocation sourcetext;
          define checkid/order "Validation*Check*Identifier" id
                 style(column)={just=left font_size=1 cellwidth=0.75 in}
                 style(header)={cellwidth=0.75 in};
          define informationsource/display "Source of Information"
                 style(column)={just=left font_size=1 cellwidth=1.50 in}
                 style(header)={cellwidth=1.50 in};
          define sourcetext/display "Source Text that Supports Check"
                 style(column)={just=left font_size=1 cellwidth=6.65 in}
                 style(header)={cellwidth=6.65 in};
          define sourcelocation/display "Reference in Source*Supporting Check"
                 style(column)={just=left font_size=1 cellwidth=1.50 in}
                 style(header)={cellwidth=1.50 in};
        run;

        proc datasets lib=work nolist;
          delete _cst&_cstRandomNum/memtype=data;
          delete _cst&_cstValidationStdRef/memtype=data;
        quit;

      %end;
      %else %if %upcase(&_cstStdRefReport)=Y and ^%sysfunc(exist(&_cstSTDRefDS)) %then
      %do;
        %put Warning: Standard Reference (&_cstStdRefDS) file either not supplied or does not exist;
      %end;
    %end;

    %*********************************;
    %* Generate Record View listing  *;
    %*********************************;
    %else
    %do;
      %**************************************************;
      %*  Retrieve Footnote Information for Footnote 2  *;
      %**************************************************;
      data _null_;
        if index("&_cstValidationDS",'.') then
        do;
          libref=scan("&_cstValidationDS",1,'.');
          if upcase(libref) ne 'WORK' then
            pfolder=pathname(scan("&_cstValidationDS",1,'.'));
          else pfolder='WORK';
          psource=scan("&_cstValidationDS",2,'.');
        end;
        else
        do;
          pfolder='WORK';
          psource="&_cstValidationDS";
        end;
        call symput('_cstSourceFolder',trim(pfolder));
        call symput('_cstSourceDS',trim(psource));
      run;

      footnote2 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

      %**************************************************;
      %*  Retrieve Footnote Information for Footnote 3  *;
      %**************************************************;
      data _null_;
        if index("&_cstMessagesDS",'.') then
        do;
          libref=scan("&_cstMessagesDS",1,'.');
          if upcase(libref) ne 'WORK' then
            pfolder=pathname(scan("&_cstMessagesDS",1,'.'));
          else pfolder='WORK';
          psource=scan("&_cstMessagesDS",2,'.');
        end;
        else
        do;
          pfolder='WORK';
          psource="&_cstMessagesDS";
        end;
        call symput('_cstSourceFolder',trim(pfolder));
        call symput('_cstSourceDS',trim(psource));
      run;

      footnote3 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

      %********************************************************;
      %*  Check for existence of Standard Reference data set  *;
      %********************************************************;
      %if %sysfunc(exist(&_cstSTDRefDS)) %then
      %do;
        %**************************************************;
        %*  Standard Reference data set exists            *;
        %*  Retrieve Footnote Information for Footnote 4  *;
        %**************************************************;
        data _null_;
          if index("&_cstStdRefDS",'.') then
          do;
            libref=scan("&_cstStdRefDS",1,'.');
            if upcase(libref) ne 'WORK' then
              pfolder=pathname(scan("&_cstStdRefDS",1,'.'));
            else pfolder='WORK';
            psource=scan("&_cstStdRefDS",2,'.');
          end;
          else
          do;
            pfolder='WORK';
            psource="&_cstStdRefDS";
          end;
          call symput('_cstSourceFolder',trim(pfolder));
          call symput('_cstSourceDS',trim(psource));
        run;

        footnote4 j=left h=6pt "Report source: (folder) &_cstSourceFolder (data set) &_cstSourceDS";

        %cstutil_getRandomNumber(_cstVarname=_cstValidationStdRef);

        proc sort data=&_cstStdRefDS out=work._cst&_cstValidationSTDRef;
          by checkid seqno;
        run;

        proc sql noprint;
          select strip(put(max(seqno),2.)) into :_cstRefCnt
          from work._cst&_cstValidationSTDRef;
        quit;

        data work._cst&_cstValidationSTDRef;
          set work._cst&_cstValidationSTDRef;
            by checkid;

          attrib ref1-ref&_cstRefCnt format=$5000. label='Basis for check from information source';
          retain ref1-ref&_cstRefCnt;

          %do i=1 %to &_cstRefCnt;
            if first.checkid then ref&i='';
            if &i = seqno then
              ref&i=catx(' ',cats('(',seqno,')'),cats(informationsource,','),cats(sourcelocation,':'),sourcetext);
          %end;
          if last.checkid then output;
        run;

        data work._cst&_cstReportInfo;
          merge work._cst&_cstControlMessages (in=intest)
                work._cst&_cstValidationSTDRef;
            by checkid;
              if intest;
        run;

        data work._cstformview;
          retain checkid standardversion checksource sourceid checkseverity tablescope columnscope checktype codesource usesourcemetadata
                 codelogic lookuptype lookupsource standardref reportingcolumns checkstatus reportall uniqueid
                 sourcedescription messagetext parameter1 parameter2 messagedetails
                 ref1-ref&_cstRefCnt;
          set work._cst&_cstReportInfo (keep=checkid standardversion checksource sourceid checkseverity tablescope columnscope checktype codesource usesourcemetadata
                 codelogic lookuptype lookupsource standardref reportingcolumns checkstatus reportall uniqueid
                 sourcedescription messagetext parameter1 parameter2 messagedetails
                 ref1-ref&_cstRefCnt) end=last;
          checkrecord=_n_;
          if last then
            call symputx('_cstRecCnt',checkrecord);
        run;
      %end;
      %else
      %do;
        %************************************************;
        %*  Standard Reference data set does NOT exist  *;
        %************************************************;
        data work._cst&_cstReportInfo;
          set work._cst&_cstControlMessages;
        run;

        data work._cstformview;
          retain checkid standardversion checksource sourceid checkseverity tablescope columnscope checktype codesource usesourcemetadata
                 codelogic lookuptype lookupsource standardref reportingcolumns checkstatus reportall uniqueid
                 sourcedescription messagetext parameter1 parameter2 messagedetails;
          set work._cst&_cstReportInfo (keep=checkid standardversion checksource sourceid checkseverity tablescope columnscope checktype codesource usesourcemetadata
                 codelogic lookuptype lookupsource standardref reportingcolumns checkstatus reportall uniqueid
                 sourcedescription messagetext parameter1 parameter2 messagedetails) end=last;
          checkrecord=_n_;
          if last then
            call symputx('_cstRecCnt',checkrecord);
        run;
      %end;

      proc transpose data=work._cstformview out=work._cstrptinput (where=(_name_ ne 'checkrecord'));
        by checkrecord;
        var _all_;
      run;

      options orientation=portrait;
      ods listing close;
      filename _cstrpt "&_cstReportOutput";

      ods &_cstReportFormat file=_cstrpt style=sasweb
      %if %upcase(&_cstReportFormat)=PDF %then
      %do;
         NOTOC
      %end;
      ;
      ods noproctitle;

      %do i= 1 %to &_cstRecCnt;

        %let _cstIDVar=;

        data _temp&i;
          set work._cstrptinput (where=(checkrecord=&i and (substr(_name_,1,3) ne "ref" or (substr(_name_,1,3)="ref" and col1 ne '')) ));
            if upcase(_name_)="CHECKID" then
              call symputx('_cstIDVar',col1);
            select (upcase(_name_));
              when("USESOURCEMETADATA", "REPORTALL") col1=put(col1,$YesNo.);
              when("CHECKSTATUS") col1=put(strip(col1),$Status.);
              otherwise;
            end;
        run;

        title4 "Full Metadata Listing for Checkid &_cstIDVar";
        %if &_cstWhereTitle ne %then
        %do;
          title5 "&_cstWhereTitle";
        %end;

        proc report data=_temp&i nowd split="*"  /* contents=" "  */
             style(report)={just=center outputwidth=6.5 in font_size=8pt};
          column _label_ col1;
          define _label_/display "Metadata Item"
                 style(column)={just=left font_size=1 cellwidth=2.00 in}
                 style(header)={cellwidth=2.00 in};
          define col1/display "Value"
                 style(column)={just=left font_size=1 cellwidth=4.45 in}
                 style(header)={cellwidth=4.45 in};
        run;

        proc datasets nolist lib=work;
          delete _temp&i;
        quit;

      %end;

      %******************************************************;
      %*  Cleanup temporary files from Record View Listing  *;
      %******************************************************;
      proc datasets nolist lib=work;
        delete _cst&_cstValidationSTDRef;
        delete _cstrptinput;
        delete _cstformview;
      quit;

    %end;

    ods &_cstReportFormat close;
    ods listing;

    %*****************************;
    %*  Cleanup temporary files  *;
    %*****************************;
    proc datasets lib=work nolist;
      delete _cst&_cstReportInfo/memtype=data;
      delete _cst&_cstControlMessages/memtype=data;
    quit;

  %end;

  filename _cstrpt;

  %if &_cstDebug=1 %then
  %do;
    %put leaving macro &sysmacroname;
    %put cstStandardTitle=&_cstStandardTitle;
    %put cstValidationDS=&_cstValidationDS;
    %put cstValidationDSWhClause=&_cstValidationDSWhClause;
    %put cstMessagesDS=&_cstMessagesDS;
    %put cstStdRefDS=&_cstStdRefDS;
    %put cstReportOutput=&_cstReportOutput;
    %put cstCheckMDReport=&_cstCheckMDReport;
    %put cstMessageReport=&_cstMessageReport;
    %put cstStdRefReport=&_cstStdRefReport;
    %put cstRecordView=&_cstRecordView;
  %end;

  %exit_macro:

%mend cstutil_createmetadatareport;