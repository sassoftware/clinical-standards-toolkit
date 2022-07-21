**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* resetautocallpath.sas                                                          *;
*                                                                                *;
* Sample code module used to reset the autocall path within a SAS session.       *;
*                                                                                *;
* Assumptions:                                                                   *;
*   Code is called whenever the autocall path requires modification or when      *;
*    filerefs in the autocall path need to be cleared (e.g. during process       *;
*    cleanup.                                                                    *;
*                                                                                *;
* CSTversion  1.3                                                                *;
**********************************************************************************;

%macro resetautocallpathpt1;
  %global __cstPath1;
  %let __cstPath1= %sysfunc(pathname(work));
  %if %sysfunc(fileref(cstpath1))>0 %then %do;
    filename cstpath1 "&__cstpath1";
  %end;
  
  %do i=0 %to 9;
    %if (&i=0) %then %let __macroCat=work.sasmacr;
    %else %let __macroCat=work.sasmac&i;

    %let __catEntry=&__macroCat..resetautocallpathpt2.macro;
    %if (%sysfunc(cexist(&__catEntry))) %then %do;
      * Deleting &__catEntry;
      proc catalog cat=&__macroCat et=macro;
        delete resetautocallpathpt2;
        quit;
      run;
    %end;
    %else %do;
      %*put Note: &__catEntry does not exist so ignoring this processing.;
    %end;
  %end;

%mend;
%resetautocallpathpt1;

filename __cstmac "&__cstpath1/resetautocallpathpt2.sas";
data _null_;
  file __cstmac;
  put '%macro resetautocallpathpt2;';
  put '  %put;';
  put '%mend;';
run;
* reset the autocall path and set mrecall to force lookthrough again; 
options sasautos=('!CSTHOME/macros' SASAUTOS cstpath1) MAUTOSOURCE MRECALL;
%resetautocallpathpt2;
