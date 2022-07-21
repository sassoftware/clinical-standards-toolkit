%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_writemetric                                                            *;
%*                                                                                *;
%* Adds a single record to the Metrics data set based on parameter values.        *;
%*                                                                                *;
%* This macro must be called outside the context of a DATA step. Instead, it can  *;
%* be called after a DATA step boundary.                                          *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstMetricsDS Metrics data set                                         *;
%*                                                                                *;
%* @param _cstMetricParameter - required - The extensible set of metrics. This    *;
%*            set can include, but is not limited to these:                       *;
%*                # of subjects                                                   *;
%*                # of records tested                                             *;
%*                # of distinct check invocations                                 *;
%*                Errors (severity=High) reported                                 *;
%*                Warnings (severity=Medium) reported                             *;
%*                Notes (severity=Low) reported                                   *;
%*                # of structural errors                                          *;
%*                # of content errors                                             *;
%*                                                                                *;
%* @param _cstResultID - optional - The result ID. Typically, this value is set   *;
%*            to either the validation check ID (for example, SDTM0001) or to a   *;
%*           some more general summary value, such as METRICS.                    *;
%* @param _cstResultSeqParm - optional - A link between the metrics and the       *;
%*            results. Typically, this value is 1, unless duplicate values of the *;
%*            results ID need to be distinguished. This distinction is needed in  *;
%*            certain instances, such as when the same validation check ID is     *;
%*            invoked multiple times.                                             *;
%* @param _cstMetricCnt - required - The record counter for _cstMetricParameter.  *;
%* @param _cstSrcDataParm - optional - The information that links the metric back *;
%*            to the source. Example sources are the SDTM domain name or the      *;
%*            calling validation code module.                                     *;
%* @param _cstMetricsDSParm - optional - The base (cross-check) Metrics data set  *;
%*            to which the record is appended. By default, this value is the data *;
%*            set that is referenced by &_cstMetricsDS.                           *;
%*            Default: &_cstMetricsDS                                             *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_writemetric(
    _cstMetricParameter=,
    _cstResultID=,
    _cstResultSeqParm=,
    _cstMetricCnt=,
    _cstSrcDataParm=,
    _cstMetricsDSParm=&_cstMetricsDS
    ) / des='CST: Create/write metrics dataset record';

  %cstutil_setcstgroot;

  %local
    _cstTemp
  ;

  %* Create a temporary metrics data set. *;
  data _null_;
    attrib _cstTemp label="Text string field for file names"  format=$char12.;
    _cstTemp = "_cs5" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_cstTemp',_cstTemp);
  run;

  * Add the record to the temporary results data set. *;
  data &_cstTemp;
    %cstutil_metricsdsattr;

    metricparameter="&_cstMetricParameter";
    resultid="&_cstResultID";
    resultseq=&_cstResultSeqParm;
    reccount=&_cstMetricCnt;
    srcdata="&_cstSrcDataParm";
    output;
  run;

  %if &_cstMetricsDSParm = %str() %then
  %do;

    * Add the temporary metrics data set to the process-wide metrics data set. *;
    proc append base=&_cstMetricsDS data=work.&_cstTemp force;
    run;

  %end;
  %else
  %do;

    * Add the temporary metrics data set to the metrics data set passed in via *;
    *  the _cstMetricsDSParm parameter.                                        *;
    proc append base=&_cstMetricsDSParm data=work.&_cstTemp force;
    run;

  %end;

  proc datasets lib=work nolist;
    delete &_cstTemp;
  quit;

  %* Write an equivalent record to the SAS log. *;
  %if &_cstDebug %then
  %do;
    %put Metrics record: resultid=&_cstResultID, metricparameter=&_cstMetricParameter, reccount=&_cstMetricCnt;
  %end;

%mend cstutil_writemetric;
