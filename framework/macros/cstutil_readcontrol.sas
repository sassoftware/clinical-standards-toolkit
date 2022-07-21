%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_readcontrol                                                            *;
%*                                                                                *;
%* Reads a single validation_control record and creates macro variables.          *;
%*                                                                                *;
%* This macro reads a single validation_control record, as passed in through the  *;
%* data set referenced by the _cstThisCheckDS global macro variable, and creates  *;
%* local macro variables for each column in the control file. These macro         *;
%* variables are available in the context of each specific check macro.           *;
%*                                                                                *;
%* This macro is called by each check macro.                                      *;
%*                                                                                *;
%* @macvar _cstThisCheckDS Metadata for a specific validation check               *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_readcontrol(
    ) / des="CST: Create control file macro variables";

  %cstutil_setcstgroot;

  %local
    _cstExitError
    _cstRecCnt
    _cstThisTableScope
  ;

  %let _cstResultFlag=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstSrcData=&sysmacroname;
  %let _cstExitError=0;

  %if ^%sysfunc(exist(&_cstThisCheckDS)) %then
  %do;
    %* If we have a failure in this call we will abort the process. *;
    %let _cst_MsgID=CST0003;
    %let _cst_MsgParm1=Data set containing the single check metadata;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  data _null_;
    set &_cstThisCheckDS nobs=_numobs;
      call symputx('_cstRecCnt',_numobs);
      call symputx('_cstThisTableScope',tableScope);
  run;

  %if &_cstRecCnt=0 %then
  %do;
      %let _cst_MsgID=CST0112;
      %let _cst_MsgParm1=containing the single check metadata;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstExitError=1;
      %goto exit_error;
  %end;

  data _null_;
    set &_cstThisCheckDS;
    * These two temporary variables are only created to prevent the warning messages that *;
    * occur when an array is created with undefined variables.                            *;
    attrib _forceNumVarToExist_  length=8  label="Avoids Array Warning If Dataset Lacks a Num Var"
           _forceCharVarToExist_ length=$1 label="Avoids Array Warning If Dataset Lacks a Char Var"
           ;
    drop _forceNumVarToExist_ _forceCharVarToExist_;
    array _allCharVars_{*} _character_;
    array _allNumVars_{*}  _numeric_;
    length _varname_ $32;
    do _i_=lbound(_allCharVars_) to hbound(_allCharVars_);
      call vname(_allCharVars_{_i_}, _varName_);
      if (_varName_ ^= "_forceCharVarToExist_") then
      do;
        call symputx("_cst" || _varName_, _allCharVars_{_i_} ,'F');
      end;
    end;
    do _i_=lbound(_allNumVars_) to hbound(_allNumVars_);
      call vname(_allNumVars_{_i_}, _varName_);
      if (_varName_ ^= "_forceNumVarToExist_") then
      do;
        call symputx("_cst" || _varName_, _allNumVars_{_i_} ,'F');
      end;
    end;
  run;
  %if (%symexist(_cstDebug)) %then
  %do;
    data work._cstmacros;
      set sashelp.vmacro (where=(lowcase(name) =: "_cst")) end=last;
        attrib newname format=$80.;
        retain maxlen 0;
        newname=cats(catx(' ',name,'('),lowcase(scope),')');
        maxlen=max(maxlen,length(newname));
        if last then
          call symputx('_cstmacrovaluelength',maxlen);
    run;
    proc sort data=work._cstmacros;
      by newname;
    run;
    data _null_;
      set work._cstmacros;
      if _n_ = 1 then
      do;
        put "NOTE: The following SAS Clinical Standards Toolkit macro variables are known:";
      end;
      put "NOTE: " +1 newname &_cstmacrovaluelength.. " ="  value;
    run;
    proc datasets lib=work nolist;
      delete _cstmacros;
    quit;
  %end;

%exit_error:

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
                   ,_cstSrcDataParm=&_cstSrcData
                   ,_cstResultFlagParm=&_cstResultFlag
                   ,_cstRCParm=&_cst_rc
                   ,_cstActualParm=
                   ,_cstKeyValuesParm=
                   ,_cstResultsDSParm=&_cstResultsDS
                   );

  %end;

%mend cstutil_readcontrol;
