%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_metricsdsattr                                                          *;
%*                                                                                *;
%* Defines the column attributes of the Metrics data set.                         *;
%*                                                                                *;
%* Use this macro in a statement level in a SAS DATA step, where a SAS ATTRIB     *;
%* statement might be used.                                                       *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_metricsdsattr(
    ) / des='CST: Metrics data set column attributes';

  attrib
    metricparameter format=$40. label="Metric parameter"
    reccount format=8. label="Count of records"
    resultid format=$8. label="Result identifier"
    srcdata format=$200. label="Source data"
    resultseq format=8. label="Unique invocation of resultid"
  ;

%mend cstutil_metricsdsattr;