%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportgeneralprocess                                                   *;
%*                                                                                *;
%* Generates the General Process Reporting panel.                                 *;
%*                                                                                *;
%* This macro generates the General Process Reporting panel when running the      *;
%* sample driver cst_report.sas. This driver renders a SAS Clinical Standards     *;
%* Toolkit process Results data set (and, optionally, the Metrics data set) in a  *;
%* report-friendly format, such as PDF.                                           *;
%*                                                                                *;
%* This macro is called only by cstutil_createreport.                             *;
%*                                                                                *;
%* @macvar _cstResultsDset The results data set created by a SAS Clinical         *;
%*             Standards Toolit process                                           *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportgeneralprocess(
    ) / des='CST: General Process Reporting panel';

  title4 "General Process Reporting";

  %if &_cstResultsDset= %then
  %do;
    data work._cstTemp;
      attrib message format=$200.;
      message="The results data set is missing or cannot be found.";
      output;
    run;
    ods proclabel "General Process Reporting";
    proc report data=work._cstTemp nowd split="*" contents="" ;
      columns message;
      define message/display "Error" width=80 flow
                  style(header)={just=center};
    run;

    proc datasets nolist lib=work;
       delete _cstTemp;
    quit;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - The results data set is missing or cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTGENERALPROCESS);

  %end;
  %else
  %do;
    ods proclabel "General Process Reporting";
    proc report data=&_cstResultsDset(where=(checkid="")) nowd split="*"  contents=""
            style(report)={just=center outputwidth=9 in};
      columns seqno srcdata resultid resultseverity resultflag message;
      define seqno/display  "Seq*#"
                    style(column)={just=right font_size=1 cellwidth=0.50 in}
                    style(header)={cellwidth=0.50 in};
      define srcdata/display  "Source*Data" flow
                    style(column)={just=left font_size=1 cellwidth=1.65 in}
                    style(header)={cellwidth=1.65 in};
      define resultid/display  "Result*Identifier"
                    style(column)={just=left font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
      define resultseverity/display  "Severity" flow
                    style(column)={just=left font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
      define resultflag/display  format=YN. "Problem*Detected?"
                    style(column)={just=center font_size=1 cellwidth=0.75 in}
                    style(header)={cellwidth=0.75 in};
      define message/display  "Message" flow
                    style(column)={just=left font_size=1 cellwidth=4.50 in}
                    style(header)={cellwidth=4.50 in};

    run;
  %end;

%mend cstutil_reportgeneralprocess;
