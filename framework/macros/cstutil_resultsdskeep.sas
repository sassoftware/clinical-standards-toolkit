%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_resultsdskeep                                                          *;
%*                                                                                *;
%* Specifies the Results data set columns to keep in a DATA step.                 *;
%*                                                                                *;
%* Use this macro in a statement level in a SAS DATA step, where a SAS KEEP       *;
%* statement might be used.                                                       *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_resultsdskeep(
    ) / des='CST: Results data set columns';

   keep checkid resultid resultseq seqno srcdata message resultseverity resultflag _cst_rc actual keyvalues resultdetails;

%mend cstutil_resultsdskeep;