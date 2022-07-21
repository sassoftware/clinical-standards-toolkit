%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_internalmanageresults                                                  *;
%*                                                                                *;
%* Saves and restores process results macro variables.                            *;
%*                                                                                *;
%* This macro is usually used outside of the normal SAS Clinical Standards Toolkit*;
%* process flow. (This means that cst_setStandardProperties() or                  *;
%* cstutil_processsetup() has not been called.)                                   *;
%*                                                                                *;
%* This macro is typically called twice in a calling module. The first call saves *;
%* global results macro variable values, and the second call restores them to     *;
%* their prior state.                                                             *;
%*                                                                                *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultsOverrideDS Name of override Results data set                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstAction - required - The primary action to perform. If this parameter*;
%*            is blank, no subsetting by standard is attempted.                   *;
%*            Values:  SAVE | RESTORE                                             *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_internalmanageresults(
    _cstAction=
    ) / des='CST: Manage result macro variable values';

  %cstutil_setcstgroot;

/*
%local
      _cstSaveResultSeq
      _cstSaveSeqCnt
      _cstThisResultsDS
      _cstThisResultsDSLib
      _cstThisResultsDSMem
      _cstUsingResultsOverride
  ;
*/

  %* Pre-requisite: The data set specified by &_cstMessages does not exist;
  %if ^%symexist(_cstResultsDS) %then %do;
    %global _cstResultsDS;
    %let _cstResultsDS=work._cstresults;
  %end;

  %if (%upcase(&_cstAction)=SAVE) %then %do;
    %* ensure that the variables exist and are set up;
      %if ((%symexist(_cstResultSeq)=0)) %then %do;
        %global _cstResultSeq;
      %end;
      %if (%length(&_cstResultSeq)=0) %then %do;
        %let _cstResultSeq=0;
      %end;
    %if ((%symexist(_cstSeqCnt)=0)) %then %do;
      %global _cstSeqCnt;
    %end;
    %if (%length(&_cstSeqCnt)=0) %then %do;
      %let _cstSeqCnt=0;
    %end;

    %if (%length(&_cstResultsOverrideDS)>0) %then %do;
      %let _cstUsingResultsOverride=1;
      %let _cstThisResultsDS=&_cstResultsOverrideDS;
      %* save the current values;
      %let _cstSaveResultSeq=&_cstResultSeq;
      %let _cstSaveSeqCnt=&_cstSeqCnt;
      %* reset the variables;
      %let _cstResultSeq=0;
      %let _cstSeqCnt=0;
    %end;
    %else %do;
      %let _cstUsingResultsOverride=0;
      %let _cstThisResultsDS=&_cstResultsDS;
    %end;

    %if %eval(%index(&_cstThisResultsDS,.)>0) %then %do;
      %let _cstThisResultsDSLib=%scan(&_cstThisResultsDS,1,.);
      %let _cstThisResultsDSMem=%scan(&_cstThisResultsDS,2,.);
    %end;
    %else %do;
      %let _cstThisResultsDSLib=work;
      %let _cstThisResultsDSMem=&_cstThisResultsDS;
    %end;

    %let _cst_rc=0;
  %end;
  %else %if (%upcase(&_cstAction)=RESTORE) %then %do;
    %if (_cstUsingResultsOverride=1) %then %do;
      %* reset the result sequence and sequence count to the saved values;
      %let _cstResultSeq=&_cstSaveResultSeq;
      %let _cstSeqCnt=&_cstSaveSeqCnt;
    %end;
    %let _cst_rc=0;
  %end;
  %else %do;
    %let _cst_rc=1;
  %end;

%mend cstutil_internalmanageresults;