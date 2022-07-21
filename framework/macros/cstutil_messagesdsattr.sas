%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_messagesdsattr                                                         *;
%*                                                                                *;
%* Defines the column attributes of the Messages data set.                        *;
%*                                                                                *;
%* Use this macro in a statement level in a SAS DATA step, where a SAS ATTRIB     *;
%* statement might be used.                                                       *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_messagesdsattr(
    ) / des='CST: Messages data set column attributes';

  attrib
    resultid format=$8. label="Result identifier"
    standardversion format=$20. label="Standard version"
    checksource format=$40. label="Source of check"
    sourceid format=$8. label="Record identifier used by checksource"
    checkseverity format=$40. label="Severity of check"
    sourcedescription format=$500. label="Rule description from checksource"
    messagetext format=$500. label="Message text"
    parameter1 format=$100. label="Message parameter1 default value"
    parameter2 format=$100. label="Message parameter2 default value"
    messagedetails format=$200. label="Basis or explanation for result"
  ;

%mend cstutil_messagesdsattr;