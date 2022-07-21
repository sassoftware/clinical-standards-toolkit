%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportprocessmetrics                                                   *;
%*                                                                                *;
%* Generates the Process Metrics panel.                                           *;
%*                                                                                *;
%* This macro generates the Process Metrics panel when running the sample driver  *;
%* cst_report.sas. This driver renders a SAS Clinical Standards Toolkit process   *;
%* Results data set (and, optionally, the Metrics data set) in a report-friendly  *;
%* format, such as PDF.                                                           *;
%*                                                                                *;
%* This macro is called only by cstutil_createreport.                             *;
%*                                                                                *;
%* @macvar _cstMetricsDset Data set used to accumulate metrics for a validation   *;
%*             process                                                            *;
%* @macvar _cstReportByTable Report results by table/domain (Y), rather than by   *;
%*             CheckID (N)                                                        *;
%* @macvar _cstRptResultsDS Results data set created by a SAS Clinical Standards  *;
%*             Toolkit process                                                    *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportprocessmetrics (
    ) / des='CST: Process Metrics report panel';

  %local
    _cstError
    _cstUniqueTables
    _cstUniqueTablesCnt
    reportMetDS
    reportTypeLabel
    reportVar
    reportVarLabel
  ;

  %let _cstError=0;
  title4 "Process Metrics";

  %*******************************************************************;
  %* The metrics data set is required to produce this panel.         *;
  %*******************************************************************;

  %if &_cstMetricsDset= %then
    %let _cstError=1;
  %else %if ^%sysfunc(exist(&_cstMetricsDset)) %then
    %let _cstError=1;

  %if &_cstError=1 %then
  %do;
    data work._cstTemp;
      attrib message format=$200.;
      message="The metrics data set is missing or cannot be found.";
      output;
    run;
    ods proclabel "Process Metrics";
    proc report data=work._cstTemp nowd split="*" contents="" ;
      columns message;
      define message/display "Error" width=80 flow
                  style(header)={just=center};
    run;
    proc datasets nolist lib=work;
       delete _cstTemp;
    quit;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - The metrics data set is missing or cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSMETRICS);

  %end;
  %else
  %do;

    %**************;
    %* Report 1   *;
    %**************;
    %if %upcase(&_cstReportByTable) ne Y %then
    %do;
      %let reportVar=checkid;
      %let reportVarLabel=Check*ID;
      %let reportTypeLabel='Check Metrics';
      %let reportMetDS=work._cstrpt1metrics;

      **********************************************************************************;
      * Extract metrics from results data set.                                         *;
      **********************************************************************************;
      proc sort data=&_cstRptResultsDS (where=(checkid ne '')) out=work._cstrptresults;
        by checkid resultseq seqno;
      run;

      data work._cstrpt1metrics (keep=checkid _cstinvocations _cstrecords _csterrors _cstfailures);
        set work._cstrptresults end=last;
          by checkid resultseq seqno;
        attrib _cstrecords format=8. label="Record counter";

        if first.checkid then
        do;
          _cstinvocations=1;
          _cstrecords=1;
          _csterrors=0;
          _cstfailures=0;
        end;
        else
        do;
          _cstrecords+1;
        end;

        select(resultflag);
          when(1) _csterrors+1;
          when(-1) _cstfailures+1;
          otherwise;
        end;

        if last.checkid then
        do;
          _cstinvocations=resultseq;
          output;
        end;
      run;

    %end;
    %**************;
    %* Report 2   *;
    %**************;
    %else %do;
      %let reportVar=table;
      %let reportVarLabel=Table;
      %let reportTypeLabel='Table Metrics';
      %let reportMetDS=work._cstrpt2metrics;
      %let _cstUniqueTablesCnt=0;
      %let _cstUniqueTables=;

      %if ^%sysfunc(exist(&reportMetDS)) %then
        %cstutil_reporttabledata();

      %if ^%sysfunc(exist(work._cstrptresultsdom)) %then
        %let _cstError=1;
      %else
      %do;
        proc sort data=work._cstrptresultsdom;
          by table checkid resultseq;
        run;

        * Create table-level metrics data set, 1 record per table with required counts.  *;
        data work._cstrpt2metrics (keep=table _cstinvocations _csterrors _cstfailures _cstrecords);
          set work._cstrptresultsdom (keep=table checkid resultseq resultflag) end=last;
            by table checkid resultseq;

          if first.table then
          do;
            _cstinvocations=0;
            _csterrors=0;
            _cstfailures=0;
            _cstrecords=0;
          end;

          if first.checkid and first.resultseq then
          do;
            _cstinvocations+1;
            if resultflag<0 then
              _cstfailures+1;
          end;

          select(resultflag);
            when(1) _csterrors+1;
            otherwise;
          end;

          _cstrecords+1;

          if last.table then
            output;
        run;

      %end;
    %end;

    options missing=" ";

    %if &_cstError=0 %then
    %do;
      data work._cstRptDS (drop=resultid);
        merge &reportMetDS
              &_cstMetricsDset (keep=metricparameter reccount resultid where=(resultid="METRICS"));
        length spacer $1;
        spacer=' ';
      run;

      ods proclabel "Process Metrics";
      proc report data=work._cstRptDS nowd split="*" contents="" ;
        columns ('Summary Metrics' metricparameter reccount spacer)
          (&reportTypeLabel &reportVar _cstinvocations _cstrecords _csterrors _cstfailures);
        define metricparameter/display "Metric";
        define reccount/display "#";
        define spacer/display " " width=1;
        define &reportVar/display "&reportVarLabel" width=10 ;
        define _cstinvocations/display "# Check*Invocations"
                  style(column)={just=center cellwidth=1.00 in}
                  style(header)={cellwidth=1.00 in};
        define _cstrecords/display "# Recs*(if available)"
                  style(column)={just=center cellwidth=1.00 in}
                  style(header)={cellwidth=1.00 in};
        define _csterrors/display "#*Errors"
                  style(column)={just=center};
        define _cstfailures/display "# Check*Invocations*Not Run"
                  style(column)={just=center};

        compute spacer;
          call define(_col_,'style','style=[cellwidth=0.1 in background=#6495ED]');
        endcomp;

        compute after/style=[just=center font_size=6pt];
          line ' ';
          line 'Note:  "# Check Invocations Not Run" includes both checks that did not run and checks that failed to complete successfully.';
        endcomp;
      run;

      proc datasets nolist lib=work;
         delete _cstRptDS;
      quit;
    %end;
    %else
    %do;
      data work._cstTemp;
        attrib message format=$200.;
        message="Insufficient information is available to report table-specific metrics.";
        output;
        message="Check report parameters and/or the process results data set.";
        output;
      run;
      ods proclabel "Process Metrics";
      proc report data=work._cstTemp nowd split="*" contents="" ;
        columns message;
        define message/display "Error" width=80 flow
                    style(header)={just=center};
      run;
      proc datasets nolist lib=work;
         delete _cstTemp;
      quit;

      %* Write information to the results data set about this run. *;
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - work._cstrptresultsdom cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTPROCESSMETRICS);

    %end;

    %if %upcase(&_cstReportByTable) ne Y %then
    %do;
      proc datasets nolist lib=work;
         delete _cstrptresults _cstrpt1metrics;
      quit;

    %end;
    %else %do;
      proc datasets nolist lib=work;
         delete _cstrptresultsdom _cstrpt2metrics;
      quit;
    %end;
  %end;

%mend cstutil_reportprocessmetrics;
