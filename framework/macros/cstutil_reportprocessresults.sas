%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportprocessresults                                                   *;
%*                                                                                *;
%* Generates the Process Results panel.                                           *;
%*                                                                                *;
%* This macro generates the Process Results panel when running the sample driver  *;
%* cst_report.sas. This driver renders a SAS Clinical Standards Toolkit process   *;
%* Results data set (and, optionally, the Metrics data set) in a report-friendly  *;
%* format, such as PDF.                                                           *;
%*                                                                                *;
%* This macro is called only by cstutil_createreport.                             *;
%*                                                                                *;
%* @macvar _cstDate Date the processs was run                                     *;
%* @macvar _cstMessages Cross-standard work Messages data set                     *;
%* @macvar _cstReportByTable Report results by table and domain (Y), rather than  *;
%*             by CheckID (N)                                                     *;
%* @macvar _cstReportErrorsOnly Print only non-informational Result data set      *;
%*             records                                                            *;
%* @macvar _cstReportObs Number of Result data set records (per checkid) to print *;
%* @macvar _cstReportRuntime Datetime of the report                               *;
%* @macvar _cstResultsDset Results data set created by a SAS Clinical Standards   *;
%*             Toolkit process                                                    *;
%* @macvar _cstRptControl Run-time validation control (check) data set            *;
%* @macvar _cstTableChecksDset Data set that provides the list of tables for each *;
%*             check                                                              *;
%* @macvar _cstTableChecksCode Macro that builds _cstTableChecksDset              *;
%* @macvar _cstTableSubset Subset Results data set by source data set (for        *;
%*             example, DM)                                                       *;
%* @macvar _cstTypeType of process (for example, VALIDATION)                      *;
%* @macvar _cstValDSType Validation check file as a data set or a data view       *;
%*                                                                                *;
%* @history 2013-07-16 Removed hard-coded font reference for reports. User default*;
%*             font is now used for reports. This might cause format problems     *;
%*             with the data fitting into the cells properly.                     *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportprocessresults(
    ) / des='CST: Process Results panel';

  %local
    _cstError
    _cstFoot2
    _cstNumObs
    _cstRecordCnt
    _cstUniqueTablesCnt
    _cstUniqueTables
    anylookup
    description
    diffcnt
    dsid
    i
    IDVar
    Lookup
    MSource
    nobs
    rc
    reccount
    reportVar
    reportVarLabel
    reportResDS
    Scope
    Source
    whereclause
  ;

  %let _cstError=0;

  %if %upcase(&_cstReportByTable) ne Y %then
  %do;
    title4 "Process Results, by CheckID";
  %end;
  %else
  %do;
    title4 "Process Results, by Table";
  %end;

  %if &_cstResultsDset= %then
    %let _cstError=1;
  %else %if ^%sysfunc(exist(&_cstResultsDset)) %then
    %let _cstError=1;

  %if &_cstError=1 %then
  %do;
    data work._cstTemp;
      attrib message format=$200.;
      message="The results data set is missing or cannot be found.";
      output;
    run;
    ods proclabel "Process Results";
    proc report data=work._cstTemp nowd split="*" contents="" ;
      columns message;
      define message/display "Error" width=80 flow
                  style(header)={just=center};
    run;

    proc datasets nolist lib=work;
       delete _cstTemp;
    quit;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - The results data set is missing or cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSRESULTS);

  %end;
  %else
  %do;

    %let _cstFoot2=;
    %let _cstRecordCnt=0;
    %let _cstNumObs=&_cstReportObs;

    %**************;
    %* Report 1   *;
    %**************;
    %if %upcase(&_cstReportByTable) ne Y %then
    %do;
      %let reportVar=checkid;
      %let reportVarLabel=CheckID;
      %let reportResDS=&_cstResultsDset;

      %if %upcase(%str("&_cstType"))="VALIDATION" %then
      %do;

        %let nobs=0;

        %if &_cstRptControl= %then
          %let _cstError=1;
        %else 
        %do;
          %if ^%sysfunc(exist(&_cstRptControl,&_cstValDSType)) %then
            %let _cstError=1;
        %end;

        %if &_cstError=1 %then
        %do;
          data work._cstTemp;
            attrib message format=$200.;
            message="The validation check data set is missing or cannot be found.";
            output;
          run;
          ods proclabel "Process Results";
          proc report data=work._cstTemp nowd split="*" contents="" ;
            columns message;
            define message/display "Error" width=80 flow
                        style(header)={just=center};
          run;

          proc datasets nolist lib=work;
             delete _cstTemp;
          quit;

          %* Write information to the results data set about this run. *;
          %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - The validation check data set is missing or cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSRESULTS);

        %end;
        %else
        %do;
          proc sql noprint;
            create table work._cstControlDS(compress=no) as
              select c.*,m.sourcedescription
               from &_cstRptControl as c left join &_cstMessages as m
                on c.checkid=m.resultid and
                   c.standardversion=m.standardversion and
                   c.checksource=m.checksource /* and
                   c.checkseverity=m.checkseverity */
            ;
          quit;

          %let dsid = %sysfunc(open(work._cstControlDS));
          %if &dsid %then
          %do;
            %let nobs =%sysfunc(attrn(&dsid,NOBS));
            %let rc = %sysfunc(close(&dsid));
          %end;
        %end;
      %end;
      %else
      %do;
        proc sql noprint;
          select count(distinct checkid) into :nobs
            from &reportResDS (where=(checkid ne ''));
          create table work._cstUniqueIDs(compress=no) as
            select distinct checkid
              from &reportResDS (where=(checkid ne ''));
        quit;
      %end;

      %if &nobs>0 %then
      %do;
        %do i=1 %to &nobs;
          %if %upcase(%str("&_cstType"))="VALIDATION" %then
          %do;
            data _null_;
              i=&i;
              set work._cstControlDS point=i;
                call symput('IDVar',strip(checkid));
                %*************************************************************************************************************************************;
                %* Length of description field cannot be longer than 260, must include concatenation of Description: text below in the cat statement *;
                %*************************************************************************************************************************************;
                if length(sourcedescription)>246 then
                do;
                  sourcedescription=strip(substr(sourcedescription,1,246));
                  put "NOTE:  Description longer than 260 characters, truncating the value for title in cstutil_reportprocessresults";
                end;
                %*********************************************************************************************************************************;
                %* Macro variable description is used in a title statement convert double quotes to single quotes to avoid quotation resolution  *;
                %*********************************************************************************************************************************;
                call symput('description',cat('Description:  ',strip(ktranslate(sourcedescription,"'",'"'))));
                call symput('Scope',cat('Check scope:  (Tables) ',strip(tableScope),',  (Columns) ',strip(columnScope)));
                call symput('Source',cat('Source:  ',strip(checksource),' (',strip(sourceid),')'));
                call symput('Lookup',cat('Lookup type:  ',strip(lookupType),', Lookup source:  ',strip(lookupSource)));
                if upcase(usesourcemetadata)="Y" then
                  call symput('MSource',cat('Validation check macro:  ',strip(codeSource),', using source metadata'));
                else
                  call symput('MSource',cat('Validation check macro:  ',strip(codeSource),', using reference metadata'));
                call symput('anylookup',strip(lookupType));
              stop;
            run;
            title4 "Process Results, &reportVarLabel: &IDVar";
            title5 " ";
            title6 bold h=10 pt c=cx002288 "&description";
            title7  bold j=c h=10 pt c=cx002288 "&Scope";
            title8 bold j=c h=10 pt c=cx002288 "&Source";
            %if %length(&anylookup)=0 %then
            %do;
              title9 bold j=c h=10 pt c=cx002288 "&MSource";
            %end;
            %else
            %do;
              title9 bold j=c h=10 pt c=cx002288 "&Lookup";
              title10 bold j=c h=10 pt c=cx002288 "&MSource";
            %end;
          %end;
          %else
          %do;
            data _null_;
              i=&i;
              set work._cstUniqueIDs point=i;
                call symput('IDVar',strip(checkid));
              stop;
            run;

            title4 "Process Results, &reportVarLabel: &IDVar";
          %end;

          footnote2 " ";

          %if %upcase(&_cstReportErrorsOnly) ne N %then
            %let whereclause=%str(checkid="&IDVar" and resultflag=1);
          %else
            %let whereclause=%str(checkid="&IDVar");

          proc sql noprint;
            create table _temp&i as
              select checkid ,resultseq, seqno, srcdata, resultid, message, resultseverity, resultflag, actual, keyvalues
                from &reportResDS
                  where &whereclause;

          %if &_cstReportObs ne %then
          %do;
              select count(*) into :reccount from _temp&i ;
            quit;
            %if &_cstReportObs<1 or %sysfunc(notdigit(&_cstReportObs))>0 %then
               %let _cstNumObs=0;
            %else %if %eval(&reccount > &_cstReportObs) %then
            %do;
              data _temp&i;
                set _temp&i (obs=&_cstReportObs);
              run;
              %let diffcnt=%eval(&reccount - &_cstReportObs);
              %if &diffcnt=1 %then
              %do;
                %let _cstFoot2=One record has not been printed because a printing limit of &_cstReportObs was requested;
              %end;
              %else
              %do;
                %let _cstFoot2=&diffcnt records have not been printed because a printing limit of &_cstReportObs was requested;
              %end;
            %end;
          %end;
          %else %do;
            quit;
          %end;

          data _null_;
            if 0 then set _temp&i nobs=_numobs;
            call symputx('_cstRecordCnt',_numobs);
            stop;
          run;

          %if &_cstNumObs=0 %then
          %do;
            data work._cstTemp;
              attrib message format=$200.;
              message="No results data set records available. The _cstReportObs parameter has been set to &_cstReportObs..";
              output;
            run;
            ods proclabel "Process Results, &reportVarLabel: &IDVar";
            proc report data=work._cstTemp nowd split="*" contents="" ;
              columns message;
              define message/display "Error" width=80 flow
                          style(header)={just=center};
            run;
            proc datasets nolist lib=work;
               delete _cstTemp;
            quit;
          %end;
          %else %if &_cstRecordCnt=0 %then
          %do;
            data work._cstTemp;
              attrib message format=$200.;
              message="No results data set records available.";
              output;
            run;
            ods proclabel "Process Results, &reportVarLabel: &IDVar";
            proc report data=work._cstTemp nowd split="*" contents="" ;
              columns message;
              define message/display "Note" width=80 flow
                          style(header)={just=center};
            run;
            proc datasets nolist lib=work;
               delete _cstTemp;
            quit;
          %end;
          %else
          %do;
            %if %length(&_cstFoot2)>0 %then
            %do;
              footnote  h=6pt "&_cstFoot2";
              footnote2 h=6pt "Report generated &_cstReportRuntime on process run &_cstDate";
            %end;

            ods proclabel "Process Results, &reportVarLabel: &IDVar";
            proc report data=_temp&i nowd split="*" contents=""
                style(report)={just=center outputwidth=10 in};
              columns checkid resultseq seqno srcdata resultid message resultseverity resultflag actual keyvalues;
              define checkid/order noprint ;
              define resultseq/display  "Check*Invocation"
                    style(column)={just=center font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
              define seqno/display  "Seq*#"
                    style(column)={just=right font_size=1 cellwidth=0.50 in}
                    style(header)={cellwidth=0.50 in};
              define srcdata/display  "Source*Data" flow
                    style(column)={just=left font_size=1 cellwidth=1.15 in}
                    style(header)={cellwidth=1.15 in};
              define resultid/display  "Result*Identifier"
                    style(column)={just=left font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
              define message/display  "Message" flow
                    style(column)={just=left font_size=1 cellwidth=1.75 in}
                    style(header)={cellwidth=1.75 in};
              define resultseverity/display  "Severity" flow
                    style(column)={just=left font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
              define resultflag/display  format=YN. "Problem*Detected?"
                    style(column)={just=center font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
              define actual/display  "Actual*Value" flow
                    style(column)={just=left font_size=1 cellwidth=1.75 in}
                    style(header)={cellwidth=1.75 in};
              define keyvalues/display "Keys" flow
                    style(column)={just=left font_size=1 cellwidth=1.75 in}
                    style(header)={cellwidth=1.75 in};
            run;

          %end;
          proc datasets nolist lib=work;
            delete _temp&i;
          quit;

        %end;
      %end;
      %else %if &_cstError<1 %then
      %do;
        data work._cstTemp;
          attrib message format=$200.;
          message="No results data set records available.";
          output;
        run;
        ods proclabel "Process Results, by CheckID";
        proc report data=work._cstTemp nowd split="*" contents="" ;
          columns message;
          define message/display "Note" width=80 flow
                      style(header)={just=center};
        run;
        proc datasets nolist lib=work;
           delete _cstTemp;
        quit;
      %end;

      %if %sysfunc(exist(work._cstControlDS)) %then
      %do;
        proc datasets nolist lib=work;
          delete _cstControlDS;
        quit;
      %end;
      %if %sysfunc(exist(work._cstUniqueIDs)) %then
      %do;
        proc datasets nolist lib=work;
          delete _cstUniqueIDs;
        quit;
      %end;

    %end;
    %**************;
    %* Report 2   *;
    %**************;
    %else %do;
      %let reportVar=table;
      %let reportVarLabel=Table;
      %let reportResDS=work._cstrptresultsdom;

      %if &_cstTableChecksDset= and &_cstTableChecksCode= %then
      %do;

        %let _cstError=1;
        data work._cstTemp;
          attrib message format=$200.;
          message="Parameter specifications are incomplete.";
          output;
          message="If the _cstTableChecksDset value is not provided, a code module must be provided in _cstTableChecksCode.";
          output;
        run;
        ods proclabel "Process Results, by Table";
        proc report data=work._cstTemp nowd split="*" contents="" ;
          columns message;
          define message/display "Error" width=80 flow
                      style(header)={just=center};
        run;

        proc datasets nolist lib=work;
           delete _cstTemp;
        quit;

        %* Write information to the results data set about this run. *;
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - _cstReportByTable=Y sub-parameter specifications are incomplete,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSRESULTS);

      %end;
      %else %if %length(&_cstTableChecksDset)>0 %then
      %do;
        %if ^%sysfunc(exist(&_cstTableChecksDset)) %then
        %do;

          %let _cstError=1;
          data work._cstTemp;
            attrib message format=$200.;
            message="A problem was detected with the parameter specifications.";
            output;
            message="The data set provided in the _cstTableChecksDset parameter does not exist.";
            output;
          run;
          ods proclabel "Process Results, by Table";
          proc report data=work._cstTemp nowd split="*" contents="" ;
            columns message;
            define message/display "Error" width=80 flow
                        style(header)={just=center};
          run;
          proc datasets nolist lib=work;
             delete _cstTemp;
          quit;

          %* Write information to the results data set about this run. *;
          %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - The data set provided in the _cstTableChecksDset parameter does not exist,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSRESULTS);
        %end;
      %end;

      %if &_cstTableSubset= %then
      %do;
        %put Note: Report By Table was selected, and the Table Subset value was not provided.;
        %put Note: The report is being run on ALL tables.;
      %end;

      %if &_cstError=0 %then
      %do;

        %if ^%sysfunc(exist(&reportResDS)) %then
        %do;
          %let _cstUniqueTablesCnt=0;
          %let _cstUniqueTables=;

          %cstutil_reporttabledata();

          %if ^%sysfunc(exist(work._cstrptresultsdom)) %then
          %do;
            %let _cstError=1;
            data work._cstTemp;
              attrib message format=$200.;
              message="Insufficient information is available to report table-specific results.";
              output;
              message="Check report parameters and/or the process results data set.";
              output;
            run;
            ods proclabel "Process Results, by Table";
            proc report data=work._cstTemp nowd split="*" contents="" ;
              columns message;
              define message/display "Error" width=80 flow
                          style(header)={just=center};
            run;
            proc datasets nolist lib=work;
               delete _cstTemp;
            quit;

            %* Write information to the results data set about this run. *;
            %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - work._cstrptresultsdom cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSRESULTS);

          %end;
          %else
          %do;
            proc sort data=work._cstrptresultsdom;
              by table checkid resultseq;
            run;
          %end;
        %end;

        %if &_cstError=0 %then
        %do;
          %if &_cstUniqueTablesCnt>0 %then
          %do;
            %do i=1 %to &_cstUniqueTablesCnt;
              data _null_;
                attrib table format=$32.;
                table=scan("&_cstUniqueTables",&i);
                call symput('IDVar',strip(table));
              run;

              title4 "Process Results, &reportVarLabel: &IDVar";

              %let _cstfoot2=;
              footnote2 " ";

              %if &_cstReportErrorsOnly=Y %then
                %let whereclause=%str(table="&IDVar" and resultflag=1);
              %else
                %let whereclause=%str(table="&IDVar");

              proc sql noprint;
                create table _temp&i as
                  select table, checkid ,resultseq, seqno, srcdata, resultid, message, resultseverity, resultflag, actual, keyvalues
                    from &reportResDS
                      where &whereclause;

              %if &_cstReportObs ne %then
              %do;
                  select count(*) into :reccount from _temp&i ;
                quit;
                %if &_cstReportObs<1 or %sysfunc(notdigit(&_cstReportObs))>0 %then
                  %let _cstNumObs=0;
                %else %if %eval(&reccount > &_cstReportObs) %then
                %do;

                  proc sort data=_temp&i;
                    by checkid resultseq seqno;
                  run;

                  data _temp&i;
                    set _temp&i end=last;
                      by checkid;
                    retain reportobs chkcount excluded 0;

                    if _n_=1 then
                      reportobs=input(symget('_cstReportObs'),8.);
                    if first.checkid then
                      chkcount=1;
                    else chkcount+1;
                    if chkcount le reportobs then
                      output;
                    else if excluded=0 then
                      excluded=1;

                    if last and excluded=1 then
                      call symputx('_cstFoot2',"One or more records have not been printed because a printing limit of &_cstReportObs was requested");
                  run;

                %end;
              %end;
              %else %do;
                quit;
              %end;

              data _null_;
                if 0 then set _temp&i nobs=_numobs;
                call symputx('_cstRecordCnt',_numobs);
                stop;
              run;

              %if &_cstNumObs=0 %then
              %do;
                data work._cstTemp;
                  attrib message format=$200.;
                  message="No results data set records available. The _cstReportObs parameter has been set to &_cstReportObs..";
                  output;
                run;
                ods proclabel "Process Results, &reportVarLabel: &IDVar";
                proc report data=work._cstTemp nowd split="*" contents="" ;
                  columns message;
                  define message/display "Error" width=80 flow
                          style(header)={just=center};
                run;
                proc datasets nolist lib=work;
                   delete _cstTemp;
                quit;
              %end;
              %else %if &_cstRecordCnt=0 %then
              %do;
                data work._cstTemp;
                  attrib message format=$200.;
                  message="No results data set records available.";
                  output;
                run;
                ods proclabel "Process Results, &reportVarLabel: &IDVar";
                proc report data=work._cstTemp nowd split="*" contents="" ;
                  columns message;
                  define message/display "Note" width=80 flow
                              style(header)={just=center};
                run;
                proc datasets nolist lib=work;
                   delete _cstTemp;
                quit;
                ods proclabel "Process Results, &reportVarLabel: &IDVar";
              %end;
              %else
              %do;
                %if %length(&_cstFoot2)>0 %then
                %do;
                  footnote h=6pt "&_cstFoot2";
                  footnote2 h=6pt "Report generated &_cstReportRuntime on process run &_cstDate";
                %end;

                ods proclabel "Process Results, &reportVarLabel: &IDVar";
                proc report data=_temp&i nowd split="*" contents=""
                    style(report)={just=center outputwidth=9.85 in};
                  columns table checkid resultseq seqno srcdata resultid message resultseverity resultflag actual keyvalues;
                  define table/order noprint ;
                  define checkid/display  "Check*ID"
                        style(column)={just=left font_size=1 cellwidth=0.75 in}
                        style(header)={cellwidth=0.75 in};
                  define resultseq/display  "Check*Invocation"
                        style(column)={just=center font_size=1 cellwidth=0.75 in}
                        style(header)={cellwidth=0.75 in};
                  define seqno/display  "Seq*#"
                        style(column)={just=right font_size=1 cellwidth=0.50 in}
                        style(header)={cellwidth=0.50 in};
                  define srcdata/display  "Source*Data" flow
                        style(column)={just=left font_size=1 cellwidth=1.00 in}
                        style(header)={cellwidth=1.00 in};
                  define resultid/display  "Result*Identifier"
                        style(column)={just=left font_size=1 cellwidth=0.75 in}
                        style(header)={cellwidth=0.75 in};
                  define message/display  "Message" flow
                        style(column)={just=left font_size=1 cellwidth=1.50 in}
                        style(header)={cellwidth=1.50 in};
                  define resultseverity/display  "Severity" flow
                        style(column)={just=left font_size=1 cellwidth=0.75 in}
                        style(header)={cellwidth=0.75 in};
                  define resultflag/display  format=YN. "Problem*Detected?"
                        style(column)={just=center font_size=1 cellwidth=0.75 in}
                        style(header)={cellwidth=0.75 in};
                  define actual/display  "Actual*Value" flow
                        style(column)={just=left font_size=1 cellwidth=1.50 in}
                        style(header)={cellwidth=1.50 in};
                  define keyvalues/display "Keys" flow
                        style(column)={just=left font_size=1 cellwidth=1.50 in}
                        style(header)={cellwidth=1.50 in};
                run;

                proc datasets nolist lib=work;
                  delete _temp&i;
                quit;

              %end;
            %end;
          %end;
          %else
          %do;
            data work._cstTemp;
              attrib message format=$200.;
              message="No results data set records available.";
              output;
            run;
            ods proclabel "Process Results, by Table";
            proc report data=work._cstTemp nowd split="*" contents="" ;
              columns message;
              define message/display "Note" width=80 flow
                          style(header)={just=center};
            run;
            proc datasets nolist lib=work;
               delete _cstTemp;
            quit;
          %end;
        %end;

        proc datasets nolist lib=work;
          delete _cstrptresultsdom;
        quit;

      %end;
    %end;
  %end;


%mend cstutil_reportprocessresults;
