%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcreateattribfromds                                                      *;
%*                                                                                *;
%* Creates a DATA step ATTRIB statement for all columns in a specified data set.  *;
%*                                                                                *;
%* If the data set does not exist or cannot be opened, an error occurs.           *;
%*                                                                                *;
%* NOTE: An external filename statement is required before calling this macro.    *;
%*       For example:                                                             *;
%*           filename incCode CATALOG "work._cstCode.attrib.source" &_cstLRECL    *;
%*                                                                                *;
%*                                                                                *;
%* @param _cstDataSetName - required - The (libname.)memname of the data set.     *;
%*            If a libname is not specified, WORK is assumed.                     *;
%* @param _cstAttrFileref - required - The fileref that points to the physical    *;
%*            file or catalog entry that contains the generated ATTRIB statement. *;
%*            It is assumed that this fileref will be %included in the calling    *;
%*            program.                                                            *;
%* @param _cstRptType - optional - Report any problems in the SAS log or in the   *;
%*            Results data set.                                                   *;
%*            Default:  LOG                                                       *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilcreateattribfromds(
    _cstDataSetName=,
    _cstAttrFileref=,
    _cstRptType=LOG)
    / des='CST: Create ATTRIB statement from a data set';

  %local
    _cstexit_error
  ;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;


  %if %klength(&_cstDataSetName)<1 or %klength(&_cstAttrFileref)<1 %then
  %do;
    %let _cst_MsgID=CST0005;
    %let _cst_MsgParm1=cstutilcreateattribfromds;
    %let _cstResultFlag=1;
    %let _cstactual=%str(_cstDataSetName=&_cstDataSetName,_cstAttrFileref=&_cstAttrFileref);
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if ^%sysfunc(exist(&_cstDataSetName)) %then
  %do;
    %let _cst_MsgID=CST0008;
    %let _cst_MsgParm1=&_cstDataSetName;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&_cstSrcData;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if %length(%sysfunc(pathname(&_cstAttrFileref,'F')))<1 %then %do;
    %let _cst_MsgID=CST0008;
    %let _cst_MsgParm1=The file referenced by the fileref &_cstAttrFileref;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&_cstSrcData;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  proc contents data=&_cstDataSetName 
                out=work._cstColDS (keep=name length varnum label format formatl) noprint ;
  run;
  proc sort data=work._cstColDS;
    by varnum;
  run;
  
  data _null_;
    set work._cstColDS end=last;
      attrib tempvar format=$200.;
    file &_cstAttrFileref;
  
    if _n_=1 then 
      put @3 'attrib';
  
    tempvar=catx(' ',strip(name),cats('length=',format,put(length,8.)),cats('format=',format,put(formatl,8.),'.'),
            cats('label="',strip(label),'"'));
    put @5 tempvar ;
    if last then
      put @3 ';';
  run;

  %if %sysfunc(fileref(&_cstAttrFileref))>0 %then %do;
    %let _cst_MsgID=CST0101;
    %let _cst_MsgParm1=&_cstAttrFileref;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&_cstSrcData;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;


  %cstutil_deleteDataSet(_cstDataSetName=work._cstColDS);

%exit_error:

  %if &_cstexit_error %then
  %do;
    %if &_cstRptType=LOG %then
    %do;
      %if &_cst_MsgID=CST0005 %then
        %put Input parameters to macro insufficient for &_cst_MsgParm1 macro to run;
      %else %if &_cst_MsgID=CST0008 %then
        %put &_cst_MsgParm1 could not be found;
      %else %if &_cst_MsgID=CST0008 %then
        %put The fileref &_cst_MsgParm1 must be assigned prior to calling the macro;
    %end;
    %else
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=%upcase(&sysmacroname)
                  ,_cstResultFlagParm=&_cstResultFlag
                  ,_cstRCParm=1
                  ,_cstActualParm=%str(&_cstactual)
                  );

    %end;
  %end;


%mend cstutilcreateattribfromds;