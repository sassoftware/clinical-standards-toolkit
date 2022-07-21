%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilprocessxmllog                                                           *;
%*                                                                                *;
%* Processes the XML log file that was created by the Java XMLTransformer process.*;
%*                                                                                *;
%* Processes the log file that was created by the XMLTransform Java process and   *;
%* adds messages to the Results dataset.                                          *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%*                                                                                *;
%* @param _cstReturn - required - The macro variable that contains the return     *;
%*            value that is set by this macro. 0=No error, 1=Error                *;
%*            Default: _cst_rc                                                    *;
%* @param _cstReturnMsg - required - The macro variable that contains the return  *;
%*            message that is set by this macro. If _cstReturn=1 there is a       *;
%*            message.                                                            *;
%*            Default: _cst_rcmsg                                                 *;
%* @param _cstLogXMLPath - required - The complete path to the XML log file       *;
%* @param _cstScope - required - The space-separated list of the message scope    *;
%*            values be add to the Results data set.                              *;
%*            Values: USER | SYSTEM | _ALL_                                       *;
%*            Default: USER                                                       *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilprocessxmllog(
  _cstReturn=_cst_rc,
  _cstReturnMsg=_cst_rcmsg,
  _cstLogXMLPath=,
  _cstScope=USER  
  ) / des='CST: Process the XML Process Log file';
  
  
  %***************************************************;
  %*  Check _cstReturn and _cstReturnMsg parameters  *;
  %***************************************************;
  %if %sysevalf(%superq(_cstReturn)=, boolean)  or %sysevalf(%superq(_cstReturnMsg)=, boolean) %then 
  %do;
    %**********************************************************;
    %*  We are not able to communicate other than to the LOG  *;
    %**********************************************************;
    %put %str(ERR)OR:(&sysmacroname) %str
      ()Macro parameters _CSTRETURN and _CSTRETURNMSG cannot be missing.;
    %goto exit_macro;
  %end;
    
  %if (%eval(not %symexist(&_cstReturn))) %then %global &_cstReturn;
  %if (%eval(not %symexist(&_cstReturnMsg))) %then %global &_cstReturnMsg;


  %local
    _cstUseResultsDS
    _cstSrcMacro
    _cstRandom
    _cstXMLEngine
    _cstXMLTransformLogExists
    _cstLineNumberColExists
    _cstLclReturn
    _cstLclReturnMsg
    _cstMessageLength
    _cstSaveOptions
    _cstLogXMLName
    ;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstSrcMacro=&sysmacroname;

  %if (%symexist(_cstResultsDS)=1) %then 
  %do;
    %if (%klength(&_cstResultsDS)>0) and %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      %let _cstUseResultsDS=1;
      %******************************************************;
      %*  Create a temporary messages data set if required  *;
      %******************************************************;
      %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);
    %end;
  %end;

  %***************************************************;
  %*  Check _cstLogXMLPath parameter                 *;
  %***************************************************;
  %if %sysevalf(%superq(_cstLogXMLPath)=, boolean) %then 
  %do;
    %let _cstLclReturn=1;
    %let _cstLclReturnMsg=Macro parameter _cstLogXMLPath cannot be missing;
    %goto exit_macro;
  %end;

  %***************************************************;
  %*  Check _cstScope parameter                      *;
  %***************************************************;
  %if %sysevalf(%superq(_cstScope)=, boolean) %then 
  %do;
    %let _cstLclReturn=1;
    %let _cstLclReturnMsg=Macro parameter _cstScope cannot be missing;
    %goto exit_macro;
  %end;

  %if %upcase(&_cstScope) ne USER and
      %upcase(&_cstScope) ne SYSTEM and
      %upcase(&_cstScope) ne _ALL_ %then
  %do;
    %let _cstLclReturn=1;
    %let _cstLclReturnMsg=Macro parameter _cstScope=&_cstScope is invalid;
    %goto exit_macro;
  %end;

  %if %upcase(&_cstScope) eq _ALL_ %then %let _cstScope=USER SYSTEM;

  %* Determine XML engine;
  %let _cstXMLEngine=xml;
  %if %eval(&SYSVER EQ 9.2) %then %let _cstXMLEngine=xml92;
  %if %eval(&SYSVER GE 9.3) %then %let _cstXMLEngine=xmlv2;
  
  %*******************************************************;
  %*  Set _cstLclReturn and _cstLclReturnMsg parameters  *;
  %*******************************************************;
  %let _cstLclReturn=0;
  %let _cstLclReturnMsg=;

  %if %sysfunc(fileexist("&_cstLogXMLPath")) %then
  %do;

    * check to see if the log file is empty;
    %let _cstXMLTransformLogExists=0;
    data _null_;
      retain TABLE XMLTransformLog 0;
      infile "&_cstlogXMLPath" missover firstobs=2 length=lg;
      input @;
      vlg=lg;
      input line $varying200. vlg;
      if strip(line)='<TABLE>' then TABLE=1;
      if strip(line)='<XMLTransformLog>' then XMLTransformLog=1;
      if TABLE and XMLTransformLog then do;
        call symput('_cstXMLTransformLogExists','1');
        stop;
      end;
    run;

    %if &_cstXMLTransformLogExists %then
    %do;

      %* Generate the random names used in the macro;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstLogXMLName=_log&_cstRandom;

      %* Assign a libname to the log XML file;
      libname &_cstLogXMLName &_cstXMLEngine "&_cstLogXMLPath";

      * Check to see if the line number/column number info was generated;
      %let _cstLineNumberColExists = %cstutilgetattribute(_cstDataSetName=&_cstLogXMLName..XMLTransformLog, 
                                                          _cstVarName=LINENUMBER, _cstAttribute=VARNUM);

      %if (&_cstDebug) %then
      %do;
        %put Results from the Java call:;
        data _null_;
          set &_cstLogXMLName..XMLTransformLog;
          put message=;
        run;
      %end;

      %cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=results,_cstSubType=results,_cstOutputDS=work._cstxmllog);
      
      %let _cstMessageLength = %cstutilgetattribute(_cstDataSetName=work._cstxmllog,
                                                    _cstVarName=MESSAGE, _cstAttribute=VARLEN);
      
      * The message variable might get very long, but it is ok if it gets truncated;
      %let _cstSaveOptions = %sysfunc(getoption(varlenchk, keyword));
      options varlenchk=nowarn;

      * Create a work results data set to capture the XML log information;
      data work._cstxmllog;
        length _cstmsgParm1 $&_cstMessageLength _cstmsgParm2 $1;

        set work._cstxmllog &_cstLogXMLName..XMLTransformLog;
        call missing(actual,keyvalues,resultdetails,_cstmsgParm2);

        seqno=_n_;
        resultseq=1;
        checksource='XMLTRANSFORM';

        %if (&_cstLineNumberColExists) %then
        %do;
          if (lineNumber^=.) then do;
            _cstMsgParm1='(Line ' || compress(put(lineNumber,8.)) ||
               '/Column ' || compress(put(columnNumber,8.)) || ') ' || ktrim(kleft(message));
            message='(Line ' || compress(put(lineNumber,8.)) ||
               '/Column ' || compress(put(columnNumber,8.)) || ') ' || ktrim(kleft(message));
          end;
          else do;
            _cstmsgparm1=ktrim(kleft(message));
            message=ktrim(kleft(message));
          end;
        %end;
        %else
        %do;
          _cstmsgparm1=ktrim(kleft(message));
          message=ktrim(kleft(message));
        %end;

        if length(message) GT &_cstMessageLength.-3 then
          message = ksubstr(message,1, &_cstMessageLength.-4)||' ...';
        if length(_cstMsgParm1) GT &_cstMessageLength.-3 then
          _cstMsgParm1 = ksubstr(_cstMsgParm1,1, &_cstMessageLength.-4)||' ...';

        resultseverity=severity;
        srcdata=ktrim(kleft(origin));
        checkId='';
        ResultFlag=0;

        if (severity='INFO') then
          ResultId='CST0191';
        else if (severity='WARNING') then
          ResultId='CST0192';
        else do;
          * ERROR/CRITICAL ERROR;
          ResultId='CST0193';
          ResultFlag=1;
          call symputx("_cstLclReturn",'1','L');
          call symputx("_cstLclReturnMsg",message,'L');
        end;
        _cst_RC=ResultFlag;

        * Only keep the records that are in Scope;
        if findw("&_cstScope", scope, ' ', 'ir');

      run;
  
      options &_cstSaveOptions;

      %if %symexist(_cstResultsDS) %then
      %do;
        %if %klength(&_cstResultsDS) > 0 and %sysfunc(exist(&_cstResultsDS)) %then
        %do;
          %cstutil_appendresultds(
             _cstErrorDS=work._cstxmllog,
             _cstSource=XMLTRANSFORM,
             _cstVersion=%str(***),
             _cstOrderBy=seqno);
        %end;
      %end;

      * Clear the libname;
      libname &_cstLogXMLName;

      * Cleanup;
      %if (&_cstDebug=0) %then %do;
        %cstutil_deleteDataSet(_cstDataSetName=work._cstxmllog);
      %end;

    %end;
    %else %do;
      %let _cstLclReturnMsg=XML Log file &_cstLogXMLPath does not contain a <TABLE> or <XMLTransformLog> tag;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] Info: %nrbquote(&_cstLclReturnMsg);
      %if (&_cstUseResultsDS=1) %then 
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultId=CST0200
                    ,_cstResultParm1=%nrbquote(&_cstLclReturnMsg)
                    ,_cstResultSeqParm=&_cstResultSeq
                    ,_cstSeqNoParm=&_cstSeqCnt
                    ,_cstSrcDataParm=&_cstSrcMacro
                    ,_cstResultsDSParm=&_cstResultsDS
                    );
      %end;
    %end;  
  %end;
  %else %do;
    %let _cstLclReturnMsg=XML Log file &_cstLogXMLPath does not exist;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] Info: %nrbquote(&_cstLclReturnMsg);
    %if (&_cstUseResultsDS=1) %then 
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultId=CST0200
                  ,_cstResultParm1=%nrbquote(&_cstLclReturnMsg)
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcMacro
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;
  %end;  

  %**********;
  %*  Exit  *;
  %**********;
  
  %exit_macro:

  %let &_cstReturn = &_cstLclReturn;
  %let &_cstReturnMsg = %nrbquote(&_cstLclReturnMsg);
  %if &_cstLclReturn %then %put [CSTLOG%str(MESSAGE).&sysmacroname]%str(ERR)OR: %nrbquote(&_cstLclReturnMsg);
 
%mend cstutilprocessxmllog;
