%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilvalidationsummary                                                       *;
%*                                                                                *;
%* Summarizes the contents of the validation process Results data set.            *;
%*                                                                                *;
%* For validation processes, this macro evaluates the resultflag column of the    *;
%* process Results data set to provide an overall assessment of each validation   *;
%* process.  One of four summary conditions are reported:                         *;
%*       -1 No validation warnings or errors reported, but some checks not run    *;
%*        0 No validation warnings or errors reported                             *;
%*        1 1+ validation warnings or errors reported                             *;
%*        2 1+ validation warnings or errors reported, but some checks not run    *;
%*                                                                                *;
%*   Example usage:                                                               *;
%*     %cstutilvalidationsummary                                                  *;
%*     %cstutilvalidationsummary(_cstResDS=myreslts.results)                      *;
%*                                                                                *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cst_MsgID Results: Result or validation check ID                      *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1                                    *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2                                    *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstResDS - optional - The Results data set for the process.            *;
%*            Use the format (libname.)member.                                    *;
%*            Default: &_cstResultsDS                                             *;
%* @param _cstProcessSummary - optional - Generate a PROCESS SUMMARY: prefix to   *;
%*            the beginning of the message (when called by a SAS Clinical         *;
%*            Standards Toolkit validation macro).                                *;
%*            Values: N | Y                                                       *;
%*            Default: N                                                          *;
%* @param _cstSeverityList - optional - The list of check severity values, space- *;
%*            delimited, to include when summarizing the validation process.      *;
%*            Values: Note Warning Error                                          *;
%*            Default: Note Warning Error                                         *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilvalidationsummary(
    _cstResDS=&_cstResultsDS,
    _cstProcessSummary=N,
    _cstSeverityList=Note Warning Error
    )
    / des='CST: Summary of validation process';

  %* Declare local variables used in the macro  *;
  %local
    _cstexit_error
    _cstValidationSummary
  ;

  %let _cstexit_error=0;
  %let _cstValidationSummary=0;
  %let _cst_MsgParm2=;

  %if ^%sysfunc(exist(&_cstResDS)) %then
  %do;
      %let _cst_MsgID=CST0008;
      %let _cst_MsgParm1=&_cstResDS;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  proc sql noprint;
    create table work._cstVE as
      select distinct resultflag,resultseverity
        from &_cstResDS (where=(not missing(checkid)))
          order by resultflag,resultseverity;
  quit;

  data _null_;
    set work._cstVE end=last;
      attrib warnerr notrun format=8.
             _cstSevList format=$80.;
      retain warnerr notrun 0 _cstSevList '';
      
      if _n_=1 then
        _cstSevList=upcase(symget('_cstSeverityList'));

      if resultflag<0 then 
        notrun=1;
      else if resultflag=1 then 
      do;
        do i=1 to countw(_cstSevList,' ');
          if index(upcase(resultseverity),scan(_cstSevList,i,' ')) then
          warnerr=1;
        end;
      end;

      if last then do;
        if notrun=0 and warnerr=0 then
        do;
          call symputx('_cstValidationSummary',0);
          call symputx('_cst_MsgParm1','No');
        end;
        else if notrun=0 and warnerr=1 then
        do;
          call symputx('_cstValidationSummary',1);
          call symputx('_cst_MsgParm1','1+');
        end;
        else if notrun=1 and warnerr=0 then
        do;
          call symputx('_cstValidationSummary',-1);
          call symputx('_cst_MsgParm1','No');
          call symputx('_cst_MsgParm2','but some checks were not run');
        end;
        else if notrun=1 and warnerr=1 then
        do;
          call symputx('_cstValidationSummary',2);
          call symputx('_cst_MsgParm1','1+');
          call symputx('_cst_MsgParm2','and one or more checks were not run');
        end;
      end;
  run;

  proc datasets lib=work nolist;
    delete _cstVE;
  quit;

  %put [CSTLOG%str(MESSAGE)] &_cst_MsgParm1 validation warnings or errors reported &_cst_MsgParm2..;
  
  %if %upcase(&_cstProcessSummary)=Y %then
    %let _cst_MsgParm1=PROCESS SUMMARY: &_cst_MsgParm1;

  %cstutil_writeresult(
         _cstResultID=CST0018
        ,_cstResultParm1=&_cst_MsgParm1
        ,_cstResultParm2=&_cst_MsgParm2
        ,_cstResultSeqParm=1
        ,_cstSeqNoParm=1
        ,_cstSrcDataParm=CSTUTILVALIDATIONSUMMARY
        ,_cstResultFlagParm=0
        ,_cstRCParm=0
        ,_cstResultsDSParm=&_cstResultsDS
      );

%exit_error:

  %if &_cstexit_error %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
         _cstResultID=&_cst_MsgID
        ,_cstValCheckID=&_cst_MsgID
        ,_cstResultParm1=&_cst_MsgParm1
        ,_cstResultParm2=&_cst_MsgParm2
        ,_cstResultSeqParm=&_cstResultSeq
        ,_cstSeqNoParm=&_cstSeqCnt
        ,_cstSrcDataParm=&_cstSrcData
        ,_cstResultFlagParm=&_cstResultFlag
        ,_cstRCParm=&_cst_rc
        ,_cstResultsDSParm=&_cstResultsDS
        );
  %end;

%mend cstutilvalidationsummary;
