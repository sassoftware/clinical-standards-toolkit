%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_parsetablescope                                                        *;
%*                                                                                *;
%* Parses _cstTableScope to add or remove columns from _ cstTableMetadata.        *;
%*                                                                                *;
%* _cstTableMetadata is a data set in Work. This macro is called only by          *;
%* cstutil_builddomlist.                                                          *;
%*                                                                                *;
%* Required file inputs (created in calling cstutil_builddomlist macro):          *;
%*   work._csttablemetadata                                                       *;
%*   work._csttemptablemetadata                                                   *;
%*                                                                                *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstTableScope Table scope as defined in validation check metadata     *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstScopeStr - required - The string value to parse. Typically,         *;
%*            this is the entire tableScope value (if there are no sublists), or  *;
%*            a specific sublist.                                                 *;
%* @param _cstOpSource - required - A modified string value to populate           *;
%*            _cstRefValue.                                                       *;
%* @param _cstSublistNum - required - The sublist number within tableScope. If    *;
%*            there is no sublist, this is set to 1.                              *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_parsetablescope(
    _cstScopeStr=,
    _cstOpSource=,
    _cstSublistNum=
    ) / des ='CST: Parse tableScope value';

  %cstutil_setcstgroot;

  %local
    j
    _cstDomain
    _cstDotCnt
    _cstExitError
    _cstLibPart
    _cstOperator
    _cstRefValue
    _cstSpecialColumn
    _cstSubsetClause
    _cstTabPart
    _cstTabVariable
    _cstTCnt
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
    %put cstutil_parsetablescope >>>;
    %put _cstScopeStr=&_cstScopeStr;
  %end;

  %* By default, countw will return a 1 if the delimiter is not found *;
  %let _cstTCnt = %SYSFUNC(countw(&_cstScopeStr,'+-'));
  %let _cstTempIndex=0;
  %let _cstOperator=;

  * _cstappend is a clone of _csttablemetadata *;
  data work._cstappend (label="Adds records during tablescope parsing");
    set work._csttablemetadata;
    tsublist=1;
    stop;
  run;

  %do j= 1 %to &_cstTCnt;

    %let _cstExitError=0;
    %let _cstLibPart=;
    %let _cstTabPart=;
    %let _cstTabVariable=;
    %let _cstTString=;
    %let _cstSubsetClause=;
    %let _cstDomain = %scan(&_cstScopeStr, &j , "+-");
    %let _cstDotCnt = %sysfunc(countc(&_cstDomain,'.'));
    %let _cstSpecialColumn = %SYSFUNC(indexc(&_cstDomain,':'));

    %* _cstSpecialColumn allows specification of any _cstTableMetadata  *;
    %*  column and value in the form of <column>:<value>                *;
    %if &_cstSpecialColumn>0 %then
    %do;
      %let _cstTabVariable=%scan(&_cstDomain,1,":");
      %let _cstTabPart=%scan(&_cstDomain,2,":");
    %end;
    %else %if &_cstDotCnt=1 %then
    %do;
      %* We have a <libref>.<table> value  *;
      %let _cstLibPart=%scan(&_cstDomain,1,".");
      %let _cstTabPart=%scan(&_cstDomain,2,".");
    %end;
    %else %if &_cstDotCnt=0 %then
    %do;
      %* We have only a table value  *;
      %let _cstLibPart=;
      %let _cstTabPart=%scan(&_cstDomain,1,".");
    %end;
    %else
    %do;
      %* Report as an error - functionality not supported in the current release of CST *;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=&_cstDomain;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstExitError=1;
      %goto exit_error;
    %end;

    %* Go create code to do the <column>:<value> request *;
    %if %length(&_cstTabVariable)>0 %then
    %do;
      %cstutil_parsescopesegment(_cstPart=&_cstTabPart,_cstVarName=&_cstTabVariable,_cstMessageID=CST0002,_cstLengthOverride=Y);
      %if &_cst_rc %then
        %goto exit_error;
      %let _cstSubsetClause=&_cstTString;
    %end;
    %else
    %do;

      %* Go create code to do the library request *;
      %if %length(&_cstLibPart)>0 %then
      %do;
        %cstutil_parsescopesegment(_cstPart=&_cstLibPart,_cstVarName=sasref,_cstMessageID=CST0002);
        %if &_cst_rc %then
          %goto exit_error;
      %end;
      %let _cstSubsetClause=&_cstTString;

      %* Go create code to do the table request *;
      %if %length(&_cstTabPart)>0 %then
      %do;
        %cstutil_parsescopesegment(_cstPart=&_cstTabPart,_cstVarName=table,_cstMessageID=CST0002,_cstLengthOverride=Y);
        %if &_cst_rc %then
          %goto exit_error;
      %end;
      %if %length(&_cstSubsetClause)>0 %then
        %let _cstSubsetClause=&_cstSubsetClause and &_cstTString;
      %else
        %let _cstSubsetClause=&_cstTString;
    %end;

    %if %length(&_cstSubsetClause)=0 %then
    %do;
       %* Report as an error - nothing evaluable *;
       %let _cst_MsgID=CST0002;
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
      %* Remove any tables  *;
       ; if &_cstSubsetClause then delete;
    %end;
    %else
    %do;
      %* Subset tables  *;
      work._csttablemetadata (where=(&_cstSubsetClause));
    %end;


     ;tsublist=&_cstSublistNum;
    run;
    %if (&syserr gt 4) %then
    %do;
        %* Check failed - SAS error  *;
        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=See TableScope value;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstExitError=1;
        %goto exit_error;
    %end;

    %* Set at bottom of loop for use in the next iteration *;
    %let _cstTempIndex = %SYSFUNC(indexc(&_cstRefValue,'+-'));
    %if &_cstTempIndex %then
    %do;
      %let _cstOperator = %SYSFUNC(substr(&_cstRefValue,&_cstTempIndex,1));
      %let _cstRefValue = %SYSFUNC(substr(&_cstRefValue,%eval(&_cstTempIndex+1)));
    %end;

  %end;  %* end of do j=1 to &_cstTCnt loop *;

  proc append base=work._csttemptablemetadata data=work._cstappend;
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
      delete _cstAppend;
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
                  ,_cstActualParm=&_cstTableScope
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_parsetablescope;
  %end;

%mend cstutil_parsetablescope;