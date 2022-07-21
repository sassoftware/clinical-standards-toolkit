%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcheckforproblem                                                         *;
%*                                                                                *;
%* Handles any error condition that sets error condition _cst_rc to 1.            *;
%*                                                                                *;
%* The error condition results after a call to any SAS Clinical Standards Toolkit *;
%* macro.                                                                         *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param _cstRsltID - required - The error number (for example, CST0008) to      *;
%*            report in the Results data set.                                     *;
%* @param _cstChkID - optional - The check number to report in the Results data   *;
%*            set.                                                                *;
%* @param _cstType - required - Evaluate STD or SAMPLE files.                     *;
%*            Values: STD | SAMPLE                                                *;
%*            Default: SAMPLE                                                     *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilcheckforproblem(
    _cstRsltID=,
    _cstChkID=,
    _cstType=STD
    ) / des='CST: Handle _CST_RC Error Condition';

  %let _cstFoundStd=Y;
  %let _cstFoundSample=Y;
  %*****************************************************************************************;
  %* _cst_rc will have been set by a prior call if a problem was detected in another macro *;
  %*****************************************************************************************;
  %if &_cst_rc %then
  %do;
    %if &_cstType=SAMPLE %then
      %let _cstFoundSample=N;
    %else
      %let _cstFoundStd=N;
    %let _cst_rc=0;

    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                  _cstResultID=&_cstRsltID
                  ,_cstValCheckID=&_cstChkID
                  ,_cstResultParm1=%str(&_cst_rcmsg)
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=_CSTREADSTDS
                  ,_cstResultFlagParm=1
                  ,_cstRCParm=&_cst_rc
                  );
    %let _cst_rcmsg=;
  %end;

%mend cstutilcheckforproblem;
