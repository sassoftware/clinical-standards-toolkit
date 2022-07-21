%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcheckjava                                                               *;
%*                                                                                *;
%* Determines whether issues related to Java exist in the previous DATA step.     *;
%*                                                                                *;
%* This macro must be called immediately after the DATA step that declares the    *;
%* Java object.                                                                   *;
%*                                                                                *;
%* The following Java issues and issues related to Java are caught:               *;
%*  1. No Java installed:                                                         *;
%*       ERROR: The Java proxy is not responding.                                 *;
%*       ERROR: The Java proxys JNI call to start the VM failed.                  *;
%*       ERROR: Could not create Java VM.                                         *;
%*       SYSERR 0                                                                 *;
%*       SYSERRORTEXT Could not create Java VM.                                   *;
%*                                                                                *;
%*  2. Missing JAR file:                                                          *;
%*       ERROR: Could not find class                                              *;
%*              com/sas/ptc/transform/xml/StandardXMLTransformerParams at line 3  *;
%*              column 22.  Please ensure that the CLASSPATH is correct.          *;
%*       ERROR: DATA STEP Component Object failure.                               *;
%*              Aborted during the EXECUTION phase.                               *;
%*       SYSERR 1012                                                              *;
%*       SYSERRORTEXT DATA STEP Component Object failure.                         *;
%*              Aborted during the EXECUTION phase                                *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%*                                                                                *;
%* @history 2022-03-15 removed picklist errors since no longer used               *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilcheckjava()
    / des='CST: Checks for Java issues in the datastep';

  %local
    _cst_SysErrorText
    _cst_SysErr
    ;

  * Save automatic macro variable text *;
  %let _cst_SysErrorText = &syserrortext;
  %let _cst_SysErr = &syserr;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstSeqCnt=0;
  %let _cstResultFlag=-1;

  %******************************************************************;
  %*                                                                *;
  %******************************************************************;

  %if &_cstDebug %then
  %do;
    %put >>> cstcheckjava;
    %put _cst_SysErrorText = &_cst_SysErrorText;
    %put _cst_SysErr       = &_cst_SysErr;
  %end;

  %if (%length(&_cst_SysErrorText) > 0) and
  (
    (%INDEX(%NRBQUOTE(%UPCASE(&_cst_SysErrorText)), %STR(COULD NOT CREATE JAVA VM)) > 0) or
    (%INDEX(%NRBQUOTE(%UPCASE(&_cst_SysErrorText)), %STR(COULD NOT INITIALIZE CLASSPATH)) > 0) or
    (%INDEX(%NRBQUOTE(%UPCASE(&_cst_SysErrorText)), %STR(DATA STEP COMPONENT OBJECT FAILURE)) > 0)
  )
  %then
  %do;
    %************************************************************;
    %* Error Condition exists -                                 *;
    %************************************************************;
    %let _cst_MsgID=CST0202;
    %let _cst_MsgParm1=SYSERR=&syserr &syserrortext;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=1;
  %end;
  %else
  %do;
    %**************************************************;
    %* No Error Condition -                           *;
    %**************************************************;
    %let _cst_MsgID=CST0200;
    %let _cst_MsgParm1=No Java issues;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=0;
  %end;


    %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultFlagParm=&_cstResultFlag
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstSrcDataParm=JAVA CHECK
                  ,_cstResultsDSParm=&_cstResultsDS
                  );

%mend cstutilcheckjava;
