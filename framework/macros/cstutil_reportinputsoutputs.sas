%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reportinputsoutputs                                                    *;
%*                                                                                *;
%* Generates the Process Inputs/Outputs panel.                                    *;
%*                                                                                *;
%* This macro generates the Process Inputs/Outputs panel when running the         *;
%* sample driver cst_report.sas. This driver renders a SAS Clinical Standards     *;
%* Toolkit process Results data set (and, optionally, the Metrics data set) in a  *;
%* report-friendly format, such as PDF.                                           *;
%*                                                                                *;
%* This macro is called only by cstutil_createreport.                             *;
%*                                                                                *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reportinputsoutputs(
    ) / des='CST: Process Inputs/Outputs report panel';

  %local
    _cstError
  ;

  Title5 "Process Inputs/Outputs";

  %if &_cstSASRefs = %then
    %let _cstError=1;
  %else %if ^%sysfunc(exist(&_cstSASRefs)) %then
    %let _cstError=1;
  %else
  %do;
    proc format library=work.formats;
      value $ type 'SOURCEDATA'       ='Source Data'
                   'SOURCEMETADATA'   ='Source Metadata'
                   'REFERENCEMETADATA'='Reference Metadata'
                   'AUTOCALL'         ='Autocall Libraries'
                   'FMTSEARCH'        ='Format Search Path Libraries'
                   other              ='Not Supported'
      ;
    run;

    proc sort data=&_cstSASRefs;
         by type order;
    run;

    data work._cstprocessio (keep=type path tcnt);
      set &_cstSASRefs (keep = type order path sasref) end=last;
         by type order;
      attrib allrefs format=$200.;
      retain allrefs;
      type=upcase(type);
      path=resolve(path);
      if first.type then
      do;
        allrefs='';
        tcnt=1;
      end;
      select(type);
        when ("SOURCEDATA")
        do;
          output;
          tcnt+1;
        end;
        when ("SOURCEMETADATA")
        do;
          if first.type then
            output;
        end;
        when ("REFERENCEMETADATA")
        do;
          if first.type then
            output;
        end;
        when ("AUTOCALL")
        do;
          path = cat(kstrip(sasref),': ',kstrip(path));
          output;
          tcnt+1;
          allrefs=catx(' ',allrefs,sasref);
          if last.type then
          do;
            path="%sysget(CSTHOME)/macros";
            allrefs=cat(kstrip(allrefs),': ',kstrip(path));
            tcnt=0;
            path=allrefs;
            output;
          end;
        end;
        when ("FMTSEARCH")
        do;
          path = cat(kstrip(sasref),': ',kstrip(path));
          output;
          tcnt+1;
          allrefs=catx(' ',allrefs,sasref);
          if last.type then
          do;
            allrefs=cat('(',kstrip(allrefs),')');
            tcnt=0;
            path=allrefs;
            output;
          end;
        end;
        otherwise
        do;
          * Ignoring CONTROL and RESULTS (and any others not excluded in the sort or code above) here... *;
        end;
      end;
    run;

    proc sort data=work._cstprocessio;
      by type tcnt;
    run;

    ods proclabel "Process Inputs/Outputs";
    proc report data=work._cstprocessio nowd split="*" contents="" ;
      columns type path;
      define type/order "Type" format=$type.
                  style(header)={just=left};
      define path/display "Path" width=60 flow
                  style(header)={just=left};
    run;

    proc datasets nolist lib=work;
       delete _cstprocessio;
    quit;

  %end;

  %if &_cstError=1 %then
  %do;

    data work._cstTemp;
      attrib message format=$200.;
      message="SASReferences data set is missing or cannot be found.";
      output;
    run;
    ods proclabel "Process Inputs/Outputs";
    proc report data=work._cstTemp nowd split="*" contents="" ;
      columns message;
      define message/display "Error" width=80 flow
                  style(header)={just=center};
    run;

    proc datasets nolist lib=work;
       delete _cstTemp;
    quit;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Report not complete - SASReferences data set is missing or cannot be found,_cstSeqNoParm=1,_cstSrcDataParm=CSTUTIL_REPORTINPUTSOUTPUTS);

  %end;

%mend cstutil_reportinputsoutputs;
