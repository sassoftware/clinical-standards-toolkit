%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilprocessfailed                                                           *;
%*                                                                                *;
%* Returns a boolean to indicate whether a process failed.                        *;
%*                                                                                *;
%* This macro returns a boolean to indicate whether a SAS Clinical Standards      *;
%* Toolkit process failed, where 0=successful completion and 1=failure.           *;
%*                                                                                *;
%*   Example usage:                                                               *;
%*     %put %cstutilprocessfailed                                                 *;
%*     %put %cstutilprocessfailed(_cstResDS=mylib.results)                        *;
%*     %put %cstutilprocessfailed(_cstResDS=_cstresultsDS)                        *;
%*     %if %cstutilprocessfailed(_cstResDS=results)=1 %then                       *;
%*       %put ====> Process failed                                                *;
%*                                                                                *;
%* @param _cstResDS - optional - The Results data set for the process. Must be in *;
%*            the format (libname.)member.                                        *;
%*            Default: &_cstResultsDS                                             *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilprocessfailed(_cstResDS=&_cstResultsDS)
    / des='CST: Did the Toolkit process succeed or fail?';

  %* Declare local variables used in the macro  *;
  %local _cstdsid _cstrc;

  %let _cstdsid=%sysfunc(open(&_cstResDS
                       (where=(_cst_rc ne 0)),i));

    %let _cstrc=0;

    %* Failed to open the data set *;
    %if &_cstdsid = 0
    %then %do;
      %put %sysfunc(sysmsg());
      %let _cstrc = .;
    %end;
    %else %do;
      %if %sysfunc(attrn(&_cstdsid,NLOBSF)) %then
          %let _cstrc=1;
      %let _cstdsid = %sysfunc(close(&_cstdsid));
    %end;

  &_cstrc

%mend cstutilprocessfailed;
