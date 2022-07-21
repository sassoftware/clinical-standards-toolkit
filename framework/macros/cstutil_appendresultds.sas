%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_appendresultds                                                         *;
%*                                                                                *;
%* Appends a check-level Results data set to the process Results data set.        *;
%*                                                                                *;
%* This macro appends a check-level Work Results data set to the process Work     *;
%* Results data set. The parameters that are passed are check-level values, not   *;
%* record-level values.                                                           *;
%*                                                                                *;
%* This macro must be called outside the context of a DATA step.                  *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_MsgID Results: Result or validation check ID                      *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1                                    *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2                                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstCheckSource Source of check found in validation master/control     *;
%*                                                                                *;
%* @param _cstErrorDS - required - A SAS Work data set that contains one or more  *;
%*            observations that document the results of check-level validation    *;
%*            processing on a source data set record level.                       *;
%* @param _cstVersion - required - The specific version of the model, which is    *;
%*            used to lookup an associated message in the Messages data set.      *;
%*            This value defaults to the value that is specified by               *;
%*            _cstStandardVersion.                                                *;
%*            Default: &_cstStandardVersion                                       *;
%* @param _cstSource - required - The source of the check, which enables source-  *;
%*            specific messaging. This value is used to look up an associated     *;
%*            message in the Messages data set.                                   *;
%*            Default: &_cstCheckSource                                           *;
%* @param _cstStdRef - optional - The reference in the standard that supports     *;
%*            checks.                                                             *;
%* @param _cstOrderBy - optional - The column order (SQL form, comma-separated    *;
%*            columns) that the _cstErrorDS must have when exiting this macro.    *;
%*            The order of the records is important.                              *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_appendresultds(
    _cstErrorDS=,
    _cstVersion=&_cstStandardVersion,
    _cstSource=&_cstCheckSource,
    _cstStdRef=,
    _cstOrderBy=
    ) /des='CST: Append records to results data set';

  %cstutil_setcstgroot;

  %if &_cstDebug %then
  %do;
    %put >>> cstutil_appendresultds;
    %put     _cstErrorDS=&_cstErrorDS;
    %put     _cstVersion=&_cstVersion;
    %put     _cstSource=&_cstSource;
    %put     _cstStdRef=&_cstStdRef;
  %end;

  %local
    _cstEType
    _cstexit_error
    _cstMessagesDSet
    _cstMessagesLibs
    _cstSpecialLookup
  ;

  %let _cstSpecialLookup=0;
  %let _cstexit_error=0;
  %let _cstSrcData=&sysmacroname;

  %if %klength(&_cstVersion)=0 or %klength(&_cstSource)=0 %then
  %do;
    * Input parameters to macro insufficient for macro to run  *;
    %let _cst_MsgID=CST0005;
    %let _cst_MsgParm1=cstutil_appendresultds;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if %symexist(_cstMessages) %then
  %do;
    %if %klength(&_cstMessages) > 0 and %sysfunc(exist(&_cstMessages)) %then
    %do;

      * Signals errors have been collected in the expected format.  Do lookup to   *;
      *  messages data set, then append to &_cstResultsDS                          *;
      %if %klength(&_cstErrorDS) > 0 and %sysfunc(exist(&_cstErrorDS)) %then
      %do;

        proc sql noprint;
          create table work._cstmessagelookup (label='Join of errors and messages') as
          select errors.*,

            case messages.messagetext
               when '' then '<Message lookup failed to find matching record>'
               else messages.messagetext
            end as _cstMessageText format=$500. label="Message text from messages file",
            messages.checkseverity as _cstMessageSeverity label="Message severity from messages file",
            messages.messagedetails as _cstMessageDetails label="Message details from messages file"
          from   &_cstErrorDS errors
            left join
               &_cstMessages (where=((standardversion="&_cstVersion" or standardversion="***") and
                      upcase(checksource)=upcase("&_cstSource"))) messages
            on upcase(messages.resultid) = upcase(errors.resultid)
      %if %klength(&_cstOrderBy)>0 %then
      %do;
          order by &_cstOrderBy
      %end;
            ;
        quit;
        %if (&sqlrc gt 0) %then
        %do;
          %* Check failed - SAS error  *;
          %let _cst_MsgID=CST0051;
          %let _cst_MsgParm1=Proc SQL creation of work._cstMessageLookup;
          %let _cst_MsgParm2=;
          %let _cst_rc=1;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;
      %end;
    %end;
    %else
    %do;
      %let _cstexit_error=1;
      %goto no_messages;
    %end;
  %end;
  %else
    %let _cstexit_error=1;

%no_messages:
    %if &_cstexit_error %then
    %do;
      data work._cstmessagelookup;
        set &_cstErrorDS;
          attrib
            _cstMessageText format=$500. label="Message text from messages file"
            _cstMessageSeverity format=$40. label="Message severity from messages file"
            _cstMessageDetails format=$200. label="Message details from messages file"
          ;
        _cstMessageText="<Message lookup failed to find matching record>";
        _cstMessageSeverity="<Unknown>";
        _cstMessageDetails="<Either the messages data set does not exist or it is incomplete>";
      run;
      %let _cstexit_error=0;
    %end;

  data &_cstErrorDS;
    set work._cstmessagelookup;
      %cstutil_resultsdskeep;

      attrib _cstparmcount format=8. label="# of messagetext substitution fields"
             _cstparm format=$40. label="Messagetext substitution field"
      ;
      * There are 3 indicators of message parameters:                              *;
      *   Substitution fields in messages.messagetext                              *;
      *   Non-missing values in messages.parameter1 and messages.parameter2        *;
      *   Non-missing MsgParm1 and MsgParm2 columns from input error data set      *;
      * Only the first is considered authoritative.  The latter two will be        *;
      *  ignored if they appear in conflict with messagetext substitution fields.  *;

      _cstparmcount = count(_cstMessageText,'&_cst');
      if _cstparmcount > 2 then
        put "Warning:  More message substitution fields found than supported.  Check the messages data set.";
      else do i = 1 to _cstparmcount;
        if i=1 then do;
          _cstparm = strip(kscan(ksubstr(_cstMessageText,kindex(_cstMessageText,'&_cst')),1,' '));
          _cstMessageText=compbl(tranwrd(_cstMessageText, ktrim(_cstparm) , ktrim(_cstMsgParm1)));
        end;
        else if i=2 then do;
          _cstparm = strip(kscan(ksubstr(_cstMessageText,kindex(_cstMessageText,'&_cst')),1,' '));
          _cstMessageText=compbl(tranwrd(_cstMessageText, ktrim(_cstparm) , ktrim(_cstMsgParm2)));
        end;
      end;

      message = _cstMessageText;
      resultseverity = _cstMessageSeverity;

      * Resultdetails may be populated from 3 sources:                         *;
      *   source records (_cstErrorDS.resultdetails)                           *;
      *   check metadata (control.standardref)                                 *;
      *   messages metadata (messages.messagedetails)                          *;
      * Generally, it is expected that the latter two are mutually exclusive   *;
      *  -- we will have one or the other but not both.  Regardless, the code  *;
      *  below defines the precedence of use.                                  *;

      if resultdetails='' then
        resultdetails = _cstMessageDetails;
      if resultdetails='' then
        resultdetails = "&_cstStdRef";

      if message = '<Message lookup failed to find matching record>' then
      do;
        resultseverity="<Unknown>";
        resultdetails="<Either the messages data set does not exist or it is incomplete>";
      end;

  run;

  %if %symexist(_cstResultsDS) %then
  %do;
    %if %klength(&_cstResultsDS) > 0 and %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      proc append base=&_cstResultsDS data=&_cstErrorDS force;
      run;
    %end;
    %else
    %do;
      %let _cstResultsDS=&_cstErrorDS;
    %end;
  %end;
  %else
    %let _cstResultsDS=&_cstErrorDS;

  * Note &_cstErrorDS should be cleaned up by the calling code module.  *;
  proc datasets lib=work nolist;
    delete _cstmessagelookup;
  quit;

%exit_error:

    %if &_cstexit_error %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %if %symexist(_cstCheckID) %then
         %let _cstEType=&_cstCheckID;
      %else
         %let _cstEType=&_cst_MsgID;
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstEType
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

%mend cstutil_appendresultds;