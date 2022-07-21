%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutillogevent                                                                *;
%*                                                                                *;
%* Logs a file operation in the specified log file.                               *;
%*                                                                                *;
%* This macro attempts to get a data set lock before making updates to that data  *;
%* set. If a lock cannot be obtained, the attempt is aborted. If a lock is        *;
%* obtained, a subsequent call to cstutilreleasedslock is required.               *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code (1 indicates an error)            *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstLockDS - required - The data set <libref.dset> that contains        *;
%*            transactions of interest. This is the data set locked by            *;
%*            cstutilgetdslock.                                                   *;
%* @param _cstUpdateDS - required - The data set <libref.dset> that contains      *;
%*            transactions to log.                                                *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutillogevent(
    _cstLockDS=,
    _cstUpdateDS=
    ) / des='CST: Log a file operation';

  %cstutil_setcstgroot;

  %local
    _cstGlobalLoggingDS
    _cstGlobalLoggingPath
    _cstLockDSLib
    _cstParam1
    _cstParam2
    _cstSrcMacro
    _cstThisMacroRC
    _cstThisMacroRCmsg
    _cstUseResultsDS
  ;

  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstThisMacroRC=0;
  %let _cstUseResultsDS=0;
  
  %if (%symexist(_cstResultDS)=1) %then %do;
    %if (%klength(&_cstResultDS)>0) and %sysfunc(exist(&_cstResultDS)) %then %do;  
      %let _cstUseResultsDS=1;
    %end;
  %end;

  %* Pre-requisite: _cstLockDS must be provided *;
  %if (%klength(&_cstLockDS)=0) %then %do;
    %let _cstMsgID=CST0081;
    %let _cstParam1=_cstLockDS;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=A required parameter in &_cstSrcMacro was not supplied (&_cstParam1).;
    %goto ABORT_LOGGING;
  %end;
  %else %if ^%sysfunc(exist(&_cstLockDS)) %then %do;
    %let _cstMsgID=CST0008;
    %let _cstParam1=&_cstLockDS;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=&_cstParam1 could not be found.;
    %goto ABORT_LOGGING;
  %end;

  %* Pre-requisite: _cstUpdateDS must be provided *;
  %if (%klength(&_cstUpdateDS)=0) %then %do;
    %let _cstMsgID=CST0081;
    %let _cstParam1=_cstUpdateDS;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=A required parameter in &_cstSrcMacro was not supplied (&_cstParam1).;
    %goto ABORT_LOGGING;
  %end;
  %else %if ^%sysfunc(exist(&_cstUpdateDS)) %then %do;
    %let _cstMsgID=CST0008;
    %let _cstParam1=&_cstUpdateDS;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=&_cstParam1 could not be found.;
    %goto ABORT_LOGGING;
  %end;

  %**************************************;
  %* Append transaction(s) to log file  *;
  %**************************************;

  %* STEP 1:  Make sure information to-be-appended is compatible with log file structure *;
  %cstutilcomparestructure(_cstBaseDSName=&_cstLockDS,
                         _cstCompDSName=&_cstUpdateDS,
                         _cstReturn=_cst_rc, 
                         _cstReturnMsg=_cst_rcmsg,
                         _cstResultsDS= work._cstproblems);

  %if &_cst_rc>15 %then %do;
    %let _cstMsgID=CST0125;
    %let _cstParam1=&_cstUpdateDS;
    %let _cstParam2=&_cstLockDS;
    %let _cstThisMacroRCmsg=Differences found between data set &_cstParam1 and the template dataset &_cstParam2.;
    %goto ABORT_LOGGING;
  %end;

  %* STEP 2:  Attempt append operation *;
  proc append base=&_cstLockDS data=&_cstUpdateDS;
  run;
  %if (&syserr gt 4) %then
  %do;
    %let _cstMsgID=CST0051;
    %let _cstParam1=proc append failed;
    %let _cstParam2=;
    %let _cstThisMacroRCmsg=Code failed due to SAS error - &_cstParam1.;
    %goto ABORT_LOGGING;
  %end;

  %goto CLEANUP;

%ABORT_LOGGING:
  %let _cstThisMacroRC=1;
  %if (&_cstUseResultsDS=1) %then %do;
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

  %if (%klength(&_cstLockDS)>0) and %sysfunc(exist(&_cstLockDS)) %then %do;  
    %* Clear data set lock *;
    lock &_cstLockDS clear;
  %end;
  
  %let _cst_rc=&_cstThisMacroRC;
  %let _cst_rcmsg=&_cstThisMacroRCmsg;

%mend cstutillogevent;
