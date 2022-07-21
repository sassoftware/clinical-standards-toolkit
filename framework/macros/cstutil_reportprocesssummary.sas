%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportprocesssummary                                                   *;
%*                                                                                *;
%* Generates the Process Summary panel.                                           *;
%*                                                                                *;
%* This macro generates the Process Summary panel when running the sample driver  *;
%* cst_report.sas. This driver renders a SAS Clinical Standards Toolkit process   *;
%* Results data set (and, optionally, the Metrics data set) in a report-friendly  *;
%* format, such as PDF.                                                           *;
%*                                                                                *;
%* This macro is called only by cstutil_createreport.                             *;
%*                                                                                *;
%* @macvar _cstDate Date the processs was run                                     *;
%* @macvar _cstKeepTableChecklist Keep the derived list of tables                 *;
%*             (_csttablechecklist) to reuse in subsequent report requests        *;
%* @macvar _cstMetricsReport Generate Process Metrics panel (Y/N)                 *;
%* @macvar _cstMetricsDset Data set used to accumulate metrics for a validation   *;
%*             process                                                            *;
%* @macvar _cstReportByTable  Report results by table/domain (Y), rather than by  *;
%*             CheckID (N)                                                        *;
%* @macvar _cstReportErrorsOnly Print only non-informational result data set      *;
%*             records                                                            *;
%* @macvar _cstReportObs Number of result data set records (per checkid) to print *;
%* @macvar _cstReportOutput Path/filename where report output is written          *;
%* @macvar _cstResultsDset Results data set created by a SAS Clinical Standards   *;
%*             Toolkit process                                                    *;
%* @macvar _cstRptResultsDS The results data set created by a SAS Clinical        *;
%*            Standards Toolkit process                                           *;
%* @macvar _cstSASReferencesDset SASReferences data set used by a process         *;
%* @macvar _cstTableChecksDset Data set providing a list of tables for each check *;
%* @macvar _cstTableChecksCode Macro to build _cstTableChecksDset                 *;
%* @macvar _cstTableSubset Subset Results data set by source data set (for        *;
%*            example, DM)                                                        *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportprocesssummary(
    ) / des='CST: Process Summary report panel';

  %local
    rtr
    _cstCnt
  ;

  %if &_cstReportObs= %then
    %let rtr=All;
  %else
    %let rtr=&_cstReportObs;

  Title5 "Report Summary";
  data work._cstRptDS;
    length parm $60  value $200;

      parm="SASReferences data set"; value="&_cstSASReferencesDset" ;output;
      parm="Results data set" ; value="&_cstResultsDset";output;
      %if %upcase(&_cstMetricsReport) ne N %then
      %do;
        parm="Metrics data set" ; value="&_cstMetricsDset" ;output;
      %end;
      parm= "CST Process datetime"; value= "&_cstDate";output;
      parm= "Report only errors, warnings & notes?"; value=put("&_cstReportErrorsOnly",$YesNo.);output;
      parm= "# records to report"; value="&rtr" ;output;
      parm= "Report results by table"; value=put("&_cstReportByTable",$YesNo.);output;
      %if %upcase(&_cstReportByTable)=Y %then
      %do;
        %if %length(&_cstTableSubset)=0 or %upcase(&_cstTableSubset)=_ALL_ %then
        %do;
           parm= "Tables to include" ; value= "All" ;output;
        %end;
        %else %do;
           parm= "Tables to include" ; value= "&_cstTableSubset" ;output;
        %end;
        %if %length(&_cstTableChecksDset)>0 %then
        %do;
          parm= "Supplemental checks by table data set used"; value= "&_cstTableChecksDset" ;output;
        %end;
        %else %do;
          parm= "Supplemental checks by table data set created by macro"; value= "&_cstTableChecksCode" ;output;
          parm= "Supplemental checks by table data set (work) saved for reuse"; value=put("&_cstKeepTableChecklist",$YesNo.);output;
        %end;
      %end;
      parm= "Report output file" ; value="&_cstReportOutput" ;output;
  run;

  %let _cstCnt=0;

  data _null_;
    set &_cstRptResultsDS (where=(checkid='' and substr(message,1,7)="PROCESS")) end=last;

    attrib _csttemp format=$200.;
    retain cstCnt 0;

    _csttemp = translate(scan(message,2,''),'',':');
    select(_csttemp);
      when("TYPE") cstCnt+1;
      otherwise;
    end;
    if last then
      call symputx('_cstCnt',cstCnt);
  run;


  ods proclabel "Report Summary";
  proc report data=work._cstRptDS nowd split="*" contents=""
          style(report)={just=center outputwidth=8.0 in};
    columns parm value;
    define parm/display "Report Parameter" width=30 flow
                  style(header)={just=left};
    define value/display "Value" width=120 flow
                  style(header)={just=left};

    %if &_cstCnt>1 %then
    %do;
      compute after/style=[BACKGROUND=lightYELLOW just=center font_size=9pt];
        text2='*** IMPORTANT NOTE ***';
        text3='The results data set appears to contain results from two or more processes.  In this case, results may be more difficult';
        text4='to interpret and may appear inconsistent across report panels.  It is recommended that reporting be run on single processes.';
        line text2 $char132.;
        line text3 $char132.;
        line text4 $char132.;
      endcomp;
    %end;
  run;

  proc datasets nolist lib=work;
     delete _cstRptDS;
  quit;

%mend cstutil_reportprocesssummary;
