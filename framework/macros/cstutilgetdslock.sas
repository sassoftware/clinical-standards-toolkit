%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilgetdslock                                                               *;
%*                                                                                *;
%* Attempts to get a data set lock to support subsequent data set updates.        *;
%*                                                                                *;
%* This macro attempts to get a data set lock before making updates to that data  *;
%* set. If a lock cannot be obtained, the attempt is aborted. If a lock is        *;
%* obtained, a subsequent call to cstutilreleasedslock is required.               *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code (1 indicates an error)            *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%* @macvar _cstTransactionDS: Data set that contains one or more transactions to  *;
%*             be logged                                                          *;
%*                                                                                *;
%* @param _cstLockDS - optional - The data set <libref.dset> to lock and update.  *;
%*            A parameter value is not required, and if this parameter is not     *;
%*            specified, the default data set used is derived from the            *;
%*            CST_LOGGING_PATH and CST_LOGGING_DS static variables.               *;
%* @param _cstWaitTime - optional - The number of seconds to attempt to get the   *;
%*            data set lock before aborting the attempt.                          *;
%*            Default: 60                                                         *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutilgetdslock(
    _cstLockDS=,
    _cstWaitTime=60
    ) / des='CST: Get data set lock';

  %cstutil_setcstgroot;

  %local
    _cstDSLib
    _cstGlobalLoggingDS
    _cstGlobalLoggingPath
    _cstMsgID
    _cstParam1
    _cstParam2
    _cstSrcMacro
    _cstThisMacroRC
    _cstThisMacroRCmsg
    _cstTime
    _cstUseResultsDS
  ;

  %let _cstDSLib=_cstlog;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstThisMacroRC=0;
  %let _cstUseResultsDS=0;

  %**************************************************************************************;
  %* As a best-practice recommendation, all logging of production updates should go     *;
  %* to the static-variable location referenced below.  However, for testing purposes,  *;
  %* the _cstTransactionDS macro variable can be set prior to the call to this macro    *;
  %* and will be used to log updates.                                                   *;
  %**************************************************************************************;
  %if (%symexist(_cstTransactionDS)=1) %then 
  %do;
    %if (%klength(&_cstTransactionDS)>0 and %sysfunc(exist(&_cstTransactionDS))) %then 
    %do;
      %if (%klength(&_cstLockDS)=0) %then
      %do;
        %let _cstLockDS=&_cstTransactionDS;
        %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cstTransactionDS is being used to log events;
        %if %sysfunc(countc("&_cstTransactionDS",'.'))=1 and %sysfunc(upcase(%SYSFUNC(scan(&_cstTransactionDS,1,'.')))) ne WORK %then
          %let _cstDSLib=%SYSFUNC(scan(&_cstTransactionDS,1,'.'));
      %end;
    %end;
  %end;

  %if (%symexist(_cstResultDS)=1) %then 
  %do;
    %if (%klength(&_cstResultDS)>0) and %sysfunc(exist(&_cstResultDS)) %then  
    %do;
      %let _cstUseResultsDS=1;
    %end;
  %end;

  %* Pre-requisite: _cstLockDS must be provided or we must be able to derive the default;
  %if (%klength(&_cstLockDS)=0) %then %do;

    %* retrieve static variables as defaults;
    %cst_getStatic(_cstName=CST_LOGGING_PATH,_cstVar=_cstGlobalLoggingPath);
    %cst_getStatic(_cstName=CST_LOGGING_DS,_cstVar=_cstGlobalLoggingDS);
    
    libname &_cstDSLib "&_cstGlobalLoggingPath";
    %if ^%sysfunc(exist(&_cstDSLib..&_cstGlobalLoggingDS)) %then 
    %do;
      %let _cstMsgID=CST0081;
      %let _cstParam1=_cstLockDS;
      %let _cstParam2=;
      %let _cstThisMacroRCmsg=A required parameter in CSTUTILGETDSLOCK was not supplied (&_cstParam1).;
      %goto ABORT_LOCK;
    %end;
    %let _cstLockDS=&_cstDSLib..&_cstGlobalLoggingDS;
  %end;
  %else %if ^%sysfunc(exist(&_cstLockDS)) %then 
  %do;
    %let _cstMsgID=CST0008;
    %let _cstParam1=&_cstLockDS;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=&_cstLockDS could not be found.;
    %goto ABORT_LOCK;
  %end;

  %*****************;
  %* Attempt lock  *;
  %*****************;

  %* Data set exists, but can it be opened with write access?  *;
  %cstutilcheckwriteaccess(_cstfiletype=DATASET,_cstfilepath=,_cstfileref=&_cstLockDS);            
  %let _cstThisMacroRC=&_cst_rc;
  %let _cstThisMacroRCmsg=&_cst_rcmsg;
  %if (&_cstThisMacroRC=0) %then;
  %else %do;
    %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cstThisMacroRCmsg;
    %let _cstMsgID=CST0111;
    %let _cstParam1=&_cstLockDS with write access;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=Unable to open data set &_cstParam1.;
    %goto ABORT_LOCK;
  %end;

  %let i=0;
  lock &_cstLockDS;
  %if (&syslckrc=0) %then;
  %else %do %until(&syslckrc=0 or &i=%sysevalf(&_cstWaitTime/10, ceil));
    data _null_; 
      call sleep(10,1); 
      call symputx('_cstTime',put(datetime(),datetime20.2)); 
    run;
    lock &_cstLockDS;
    %if (&syslckrc=0) %then;
    %else %do;
      %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: Unable to acquire exclusive lock on the logging data set at &_cstTime.;
      %if &i=%sysevalf(&_cstWaitTime/10, ceil) %then 
      %do;
        %let _cstMsgID=CST0104;
        %let _cstParam1=;
        %let _cstParam2=;
        %let _cstThisMacroRCmsg=Unable to acquire exclusive lock on the global metadata data set (&_cstLockDS).;
        %goto ABORT_LOCK;
      %end;
    %end;
    %let i=%eval(&i+1);  
  %end;
  %goto CLEANUP;

%ABORT_LOCK:
  %let _cstThisMacroRC=1;
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=_cstMsgID
                ,_cstResultParm1=&_cstParam1
                ,_cstResultParm2=&_cstParam2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                );
  %end;
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cstThisMacroRCmsg;
  %goto CLEANUP;

%CLEANUP:

  %let _cst_rc=&_cstThisMacroRC;
  %let _cst_rcmsg=&_cstThisMacroRCmsg;
  %let _cstTransactionDS=&_cstLockDS;

%mend cstutilgetdslock;
