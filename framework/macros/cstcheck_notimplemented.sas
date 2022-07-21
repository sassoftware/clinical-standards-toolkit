%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_notimplemented                                                        *;
%*                                                                                *;
%* Placeholder to report that a check is not yet implemented.                     *;
%*                                                                                *;
%* @macvar _cstResultsDS Results data set                                         *;
%*                                                                                *;
%* @param _cstControl - required - The single observation data set that contains  *;
%*            check-specific metadata                                             *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_notimplemented(_cstControl=)
    / des='CST: Checks not implemented';

  %local
    _cstCheckSource
    _cstSourceID
  ;

  %cstutil_readcontrol;

  %cstutil_writeresult(
      _cstResultID=CST0099
      ,_cstValCheckID=&_cstCheckID
      ,_cstResultParm1=&_cstCheckSource &_cstSourceID
      ,_cstResultSeqParm=1
      ,_cstSeqNoParm=1
      ,_cstSrcDataParm=&sysmacroname
      ,_cstResultFlagParm=-2
      ,_cstRCParm=1
      ,_cstResultsDSParm=&_cstResultsDS
      );


%mend cstcheck_notimplemented;

