%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_parsecolumnscope                                                       *;
%*                                                                                *;
%* Parses _cstColumnScope to add or remove columns from _cstColumnMetadata.       *;
%*                                                                                *;
%* _cstColumnMetadata is a data set in Work. This macro is called only by the     *;
%* cstutil_buildcollist() macro.                                                  *;
%*                                                                                *;
%* Required file inputs (created in calling cstutil_buildcollist macro):          *;
%*   work._csttempcolumnmetadata                                                  *;
%*   work._cstcolumnmetadata                                                      *;
%*                                                                                *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstColumnScope Column scope as defined in validation check metadata   *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstScopeStr - required - The string value to parse. Typically, this is *;
%*            the entire columnScope value (if there are no sublists), or a       *;
%*            specific sublist.                                                   *;
%* @param _cstOpSource - required - A modified string value to populate           *;
%*            _cstRefValue.                                                       *;
%* @param _cstSublistNum - required - The sublist number in columnScope. If there *;
%*            is no sublist, this is set to 1.                                    *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_parsecolumnscope(
    _cstScopeStr=,
    _cstOpSource=,
    _cstSublistNum=
    ) / des ='CST: Parse columnScope value';

  %cstutil_setcstgroot;

  %local
    j
    _cstColPart
    _cstColumn
    _cstDotCnt
    _cstExitError
    _cstLibPart
    _cstListType
    _cstOperator
    _cstRefValue
    _cstSpecialColumn
    _cstSubsetClause
    _cstTabPart
    _cstTCnt
    _cstTempColumn
    _cstTempIndex
    _cstTString
  ;

  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstRefValue=&_cstOpSource;
  %let _cst_rc=0;
  %let _cstExitError=0;

  %if &_cstDebug %then
  %do;
    %put cstutil_parsecolumnscope >>>;
    %put _cstScopeStr=&_cstScopeStr;
  %end;

  %let _cstTCnt = %SYSFUNC(countw(&_cstScopeStr,'+-'));
  %let _cstTempIndex=0;
  %let _cstOperator=;
  %let _cstTempColumn=;

  data work._cstappend (label="Adds records during columnscope parsing");
    set work._cstcolumnmetadata;
    sublist=1;
    suborder=1;
    varorder=1;
    stop;
  run;

  %do j= 1 %to &_cstTCnt;

    %let _cstExitError=0;
    %let _cstLibPart=;
    %let _cstTabPart=;
    %let _cstColPart=;
    %let _cstTString=;
    %let _cstSubsetClause=;
    %let _cstColumn = %scan(&_cstScopeStr, &j , "+-");
    %let _cstDotCnt = %sysfunc(countc(&_cstColumn,'.'));
    %let _cstSpecialColumn = %SYSFUNC(indexc(&_cstColumn,':'));

    %* _cstSpecialColumn allows specification of any unique column      *;
    %*  identification mechanisms such as _cstList: var1+var2           *;
    %if &_cstSpecialColumn>0 %then
    %do;
      %let _cstListType=%scan(&_cstColumn,1,":");
      %if %upcase(&_cstListType)=_CSTLIST %then
      %do;
        %* Keep all columns at this point ;
        %*let _cstTString=%str(column ne '');
        %let _cstColumn=%upcase(&_cstColumn);
        %let _cstColumn=%sysfunc(tranwrd(%sysfunc(trim(&_cstColumn)),%str(_CSTLIST:),%str()));
      %end;
      %else
      %do;
        %* Report as an error - functionality not supported in the current release of CST;
        %let _cst_MsgID=CST0099;
        %let _cst_MsgParm1=&_cstColumn;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstExitError=1;
        %goto exit_error;
      %end;
    %end;

    %if &_cstDotCnt=2 %then
    %do;
      %let _cstLibPart=%scan(&_cstColumn,1,".");
      %let _cstTabPart=%scan(&_cstColumn,2,".");
      %let _cstColPart=%scan(&_cstColumn,3,".");
    %end;
    %else %if &_cstDotCnt=1 %then
    %do;
      %let _cstLibPart=;
      %let _cstTabPart=%scan(&_cstColumn,1,".");
      %let _cstColPart=%scan(&_cstColumn,2,".");
    %end;
    %else %if &_cstDotCnt=0 %then
    %do;
      %let _cstLibPart=;
      %let _cstTabPart=;
      %let _cstColPart=&_cstColumn;
    %end;
    %else
    %do;
      %* Report as an error - functionality not supported in the current release of CST;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=&_cstColumn;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstExitError=1;
      %goto exit_error;
    %end;

    %if %length(&_cstLibPart)>0 %then
    %do;
      %cstutil_parsescopesegment(_cstPart=&_cstLibPart,_cstVarName=sasref);
      %if &_cst_rc %then
        %goto exit_error;
    %end;
    %let _cstSubsetClause=&_cstTString;

    %if %length(&_cstTabPart)>0 %then
    %do;
      %cstutil_parsescopesegment(_cstPart=&_cstTabPart,_cstVarName=table);
      %if &_cst_rc %then
        %goto exit_error;
    %end;
    %if %length(&_cstSubsetClause)>0 %then
      %let _cstSubsetClause=&_cstSubsetClause and &_cstTString;
    %else
      %let _cstSubsetClause=&_cstTString;

    %if %length(&_cstColPart)>0 %then
    %do;
      %cstutil_parsescopesegment(_cstPart=&_cstColPart,_cstVarName=column);
      %if &_cst_rc %then
        %goto exit_error;
    %end;
    %if %length(&_cstSubsetClause)>0 %then
      %let _cstSubsetClause=&_cstSubsetClause and &_cstTString;
    %else
      %let _cstSubsetClause=&_cstTString;

    %if %length(&_cstSubsetClause)=0 %then
    %do;
       %* Report as an error - nothing evaluable;
       %let _cst_MsgID=CST0004;
       %let _cst_MsgParm1=;
       %let _cst_MsgParm2=;
       %let _cst_rc=0;
       %let _cstExitError=1;
       %goto exit_error;
    %end;

    data work._cstappend;
      set work._cstappend

    %if "&_cstOperator"="-" %then
    %do;
       ; if &_cstSubsetClause then delete;
    %end;
    %else
    %do;
      work._cstcolumnmetadata (where=(&_cstSubsetClause));
    %end;


      ;sublist=&_cstSublistNum;
      suborder=_n_;
      if varorder=. then
        varorder=&j;
    run;
    %if (&syserr gt 4) %then
    %do;
        %* Check failed - SAS error  *;
        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=See ColumnScope value;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstExitError=1;
        %goto exit_error;
    %end;

    %* Set at bottom of loop for use in the next iteration;
    %let _cstTempIndex = %SYSFUNC(indexc(&_cstRefValue,'+-'));
    %if &_cstTempIndex %then
    %do;
      %let _cstOperator = %SYSFUNC(substr(&_cstRefValue,&_cstTempIndex,1));
      %let _cstRefValue = %SYSFUNC(substr(&_cstRefValue,%eval(&_cstTempIndex+1)));
    %end;

  %end;

  proc append base=work._csttempcolumnmetadata data=work._cstappend;
  run;

  * Above processing may result in duplicate records in _csttempcolumnmetadata  *;
  * The following steps remove any duplicates and set sublist and suborder.     *;

  proc sort data=work._csttempcolumnmetadata;
    by sublist sasref table column;
  run;
  data work._csttempcolumnmetadata;
    set work._csttempcolumnmetadata;
      by sublist sasref table column;
      if first.column;
  run;

  proc sort data=work._csttempcolumnmetadata;
    by sublist suborder;
  run;
  data work._csttempcolumnmetadata;
    set work._csttempcolumnmetadata (drop=suborder);
      by sublist;
      if first.sublist then suborder=1;
      else suborder+1;
  run;

  %if (&syserr gt 4) %then
  %do;
    %* Check failed - SAS error  *;
    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Proc Append failed;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

%exit_error:

  %if %sysfunc(exist(work._cstappend)) %then
  %do;
    proc datasets lib=work nolist;
      delete _cstappend;
    quit;
  %end;

  %if &_cstExitError %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&sysmacroname
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=&_cstColumnScope
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_parsecolumnscope;
  %end;

%mend cstutil_parsecolumnscope;