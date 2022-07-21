%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckforeignkeynotfound                                                     *;
%*                                                                                *;
%* Compares the consistency of one or more columns across two tables.             *;
%*                                                                                *;
%* This macro comparises the consistency of one <table>.<column> with another     *;
%* <table>.<column>. (For example, in CDISC CRT-DDS, ItemGroupDefItemRefs.ItemOID *;
%* does not match any ItemDefs.OID).                                              *;
%*                                                                                *;
%* The column in the first table is a foreign key that points to a primary key    *;
%* in the second table.                                                           *;
%*                                                                                *;
%* The column in the second table is must be a key.                               *;
%*                                                                                *;
%* NOTE: This macro requires the use of _cstCodeLogic at a statement level in a   *;
%*       DATA step context. _cstCodeLogic identifies records in error by          *;
%*       setting _cstError=1.                                                     *;
%*                                                                                *;
%* NOTE: This macro requires that tableScope syntax specifies two sublists in the *;
%*       form [ItemGroupDefItemRefs][ItemDefs], which compares one or more        *;
%*       columnScope fields across the tables in these sublists. Only two         *;
%*       sublists with a single table specified is supported.                     *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstMetrics Enables or disables metrics reporting                      *;
%* @macvar _cstMetricsNumRecs Validation metrics: calculate number of records     *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumRecs Validation metrics: number of records evaluated  *;
%* @macvar _cstrunstd Primary standard                                            *;
%* @macvar _cstrunstdver Version of the primary standard                          *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstcheckforeignkeynotfound(_cstControl=)
    / des='CST: Column consistency across tables';

  %local

    _cstactual
    _cstCheckID
    _cstCheckSource
    _cstCodeLogic
    _cstColCnt
    _cstColCnt1
    _cstColCnt2
    _cstColStr1
    _cstColStr2
    _cstColumn
    _cstColumnScope
    _cstColumnStr
    _cstDom1
    _cstDom2
    _cstDSKeys1
    _cstDSKeys2
    _cstDSName1
    _cstDSName2
    _cstexit_error
    _cstReportingColumns
    _cstSQLColumns1
    _cstSQLColumns2
    _cstStandardRef
    _cstStandardVersion
    _cstSubCnt
    _cstTableScope
    _cstTableSublistCnt
    _csttemp
    _cstUseSourceMetadata
  ;

  %cstutil_readcontrol;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstSrcData=;
  %let _cstactual=;

  %if &_cstDebug %then
  %do;
    %local _cstRestoreQuoteLenMax;
    %let _cstRestoreQuoteLenMax=%sysfunc(getoption(QuoteLenMax));
    options NoQuoteLenMax;
    data _null_;
      put ">>> &sysmacroname.";
      put '****************************************************';
      put "checkID=&_cstCheckID";
      put "standardVersion=&_cstStandardVersion";
      put "checkSource=&_cstCheckSource";
      put "tableScope=&_cstTableScope";
      put "columnScope=&_cstColumnScope";
      put "codeLogic=%superq(_cstCodeLogic)";
      put "useSourceMetadata=&_cstUseSourceMetadata";
      put "standardref=&_cstStandardRef";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;

  %* Single call to cstutil_buildcollist that does all domain and column processing *;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstSrcData=&sysmacroname;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %if %upcase(&_cstUseSourceMetadata)=N %then
  %do;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=UseSourceMetadata;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  data _null_;
    if 0 then set work._cstcolumnmetadata nobs=_numobs;
    call symputx('_cstColCnt',_numobs);
    stop;
  run;
  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %if &_cstColCnt <= 0 %then
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0004;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if &_cstDomCnt <= 0 %then
  %do;
    %* No tables evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %else %if &_cstDomCnt ne 2 %then
  %do;
    %* Current implementation only supports two sublists with a single table specified.   *;
    %let _cst_MsgID=CST0016;
    %let _cst_MsgParm1=Both of the tables defined in tableScope;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %let _cstSrcData=;
  %if &_cstTableSublistCnt>1 %then
  %do;

    %do i=1 %to &_cstDomCnt;

      %************************************************************;
      %* Create _cstDSName values in TableSource order (tsublist) *;
      %************************************************************;

      data _null_;
        set work._csttablemetadata (keep=sasref table keys tsublist);
          attrib _csttemp format=$41. label="Temp variable";
          _csttemp = catx('.',sasref,table);
          call symputx(cats("_cstDSName",tsublist),_csttemp);
          call symputx(cats("_cstDom",tsublist),table);
          call symputx(cats("_cstDSKeys",tsublist),keys);
      run;

      %if ^%sysfunc(exist(&&_cstDSName&i)) %then
      %do;
          %******************************************************;
          %*  Check not run - data set could not be found       *;
          %******************************************************;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=&&_cstDSname&i;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstSrcData=&sysmacroname;
          %let _cstexit_error=1;
          %goto exit_error;
      %end;
      %if %length(&_cstSrcData)=0 %then
        %let _cstSrcData=&&_cstDSname&i;
      %else
        %let _cstSrcData=&_cstSrcData (&&_cstDSname&i);


      %* No key in the second data set is a problem... stop the check.;
      %if %length(&_cstDSKeys2)=0 %then
      %do;
        %* Check not run - _cstDSName key could not be found  *;
        %let _cst_MsgID=CST0022;
        %let _cst_MsgParm1=&_cstDSName2;
        %let _cst_MsgParm2=;
        %let _cstactual=;
        %let _cstSrcData=&sysmacroname;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      * Write applicable metrics *;
      %if &_cstMetrics %then %do;

        data _null_;
          if 0 then set &&_cstDSname&i nobs=_numobs;
          call symputx('_cstMetricsCntNumRecs',_numobs);
          stop;
        run;

        %if &_cstMetricsNumRecs %then
          %cstutil_writemetric(
                        _cstMetricParameter=# of records tested
                       ,_cstResultID=&_cstCheckID
                       ,_cstResultSeqParm=&_cstResultSeq
                       ,_cstMetricCnt=&_cstMetricsCntNumRecs
                       ,_cstSrcDataParm=&&_cstDSname&i
                      );
      %end;

    %end;

    %do _keys=1 %to %SYSFUNC(countw(&_cstDSKeys2,' '));
      %if %upcase(%SYSFUNC(kscan(&_cstDSKeys1,&_keys,' '))) = %upcase(%SYSFUNC(kscan(&_cstDSKeys2,&_keys,' '))) %then
      %do;
        %if %length(&_cstColumnStr)=0 %then
          %let _cstColumnStr = %SYSFUNC(kscan(&_cstDSKeys2,&_keys,' '));
        %else
          %let _cstColumnStr = &_cstColumnStr %SYSFUNC(kscan(&_cstDSKeys2,&_keys,' '));
      %end;
      %else
      %do;
        %* Stop processing to avoid later non-sequential common columns *;
        %let _keys=%SYSFUNC(countw(&_cstDSKeys2,' '));
      %end;
    %end;
  %end;

  %****************************************************************;
  %* Sort data based on original tableScope and columnScope order *;
  %****************************************************************;

  data work._cstcolumnmetadata;
    merge work._cstcolumnmetadata
          work._csttablemetadata (keep=sasref table tsublist);
      by sasref table;
  run;

  proc sort data=work._cstcolumnmetadata;
    by tsublist sublist suborder;
  run;

  data _null_;
    set work._cstcolumnmetadata end=last;
      by tsublist sublist;
        attrib _cstColStr format=$200. label="List of columns"
               _cstSQLColumns format=$200. label="List of keys+columns"
               _cstTabCnt format=8. label="Table #"
               _csttemp format=$41. label="Temp variable";

      retain _cstTabCnt 0 _cstColStr _cstSQLColumns;

      if first.tsublist then
      do;
         _cstColStr='';
         _cstTabCnt+1;
         _cstSQLColumns=symget(cats('_cstDSKeys',put(_cstTabCnt,8.)));

         * Check that we have the expected table and that we are building  *;
         *  _cstColStr for the right table.  If not, abort check.          *;
         _csttemp = symget(cats('_cstDSName',put(_cstTabCnt,8.)));
         if upcase(_csttemp) ne upcase(catx('.',sasref,table)) then
           call symputx('_cst_rc',1);
      end;
      if indexw(_cstColStr,column)=0 then
        _cstColStr = catx(' ',_cstColStr,column);

      if (indexw(symget(cats('_cstDSKeys',put(_cstTabCnt,8.))),column)=0 and
         indexw(_cstSQLColumns,column)=0) then
           _cstSQLColumns = catx(' ',_cstSQLColumns,column);

      if last.tsublist then
      do;
        call symputx(cats("_cstColStr",_cstTabCnt), _cstColStr);
        call symputx(cats("_cstColCnt",_cstTabCnt), countw(_cstColStr,' '));
        _cstSQLColumns = tranwrd(ktrim(_cstSQLColumns),' ',',');
        call symputx(cats("_cstSQLColumns",_cstTabCnt), _cstSQLColumns);
      end;
  run;
  %if &_cst_rc  %then
  %do;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=table and column metadata inconsistent;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %*************************************************************************
  %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
  %*  expected result is a work._cstproblems data set of records in error. *
  %*  If there are no errors, the data set should have 0 observations.     *
  %*                                                                       *;
  %* Macro variables available to codeLogic:                               *;
  %*  _cstDSName1                        _cstDSName2                       *;
  %*  _cstDom1                           _cstDom2                          *;
  %*  _cstColStr1                        _cstColStr2                       *;
  %*  _cstColCnt1                        _cstColCnt2                       *;
  %*  _cstDSKeys1                        _cstDSKeys2                       *;
  %*  _cstSQLColumns1                    _cstSQLColumns2                   *;
  %*                                                                       *;
  %*  _cstColumnStr (set of common keys)                                   *;
  %*                                                                       *;
  %*************************************************************************;

  &_cstCodeLogic;

  %if %symexist(sqlrc) %then %do;
    %if (&sqlrc gt 0) %then
    %do;
      %* Check failed - SAS error  *;
      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Codelogic processing failed;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
  %end;
  %if (&syserr gt 4) %then
  %do;
    %* Check failed - SAS error  *;

    * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
    options nosyntaxcheck obs=max replace;

    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Codelogic processing failed;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %let _cstDataRecords=0;

  %if %sysfunc(exist(work._cstproblems)) %then
  %do;
    data _null_;
      if 0 then set work._cstproblems nobs=_numobs;
      call symputx('_cstDataRecords',_numobs);
      stop;
    run;
  %end;

  %**************************************;
  %* One or more errors were found      *;
  %**************************************;

  %if &_cstDataRecords %then
  %do;

    %****************************************;
    %* Create a temporary results data set. *;
    %****************************************;
    %local
      _csttemp
    ;
    data _null_;
      attrib _csttemp label="Text string field for file names"  format=$char12.;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_csttemp',_csttemp);
    run;

    %******************************************************;
    %* Add the records to the temporary results data set. *;
    %******************************************************;
    data &_csttemp (label='Work error data set');
      %cstutil_resultsdskeep;

      set work._cstproblems end=last;

      attrib
        _cstSeqNo format=8. label="Sequence counter for result column"
      ;

      keep _cstMsgParm1 _cstMsgParm2;

      retain _cstSeqNo 0 resultid resultseq resultflag _cst_rc;

      %***********************************;
      %* Set results data set attributes *;
      %***********************************;
      %cstutil_resultsdsattr;
      retain message resultseverity resultdetails '';

      if _n_=1 then
      do;
        _cstSeqNo=&_cstSeqCnt;
        resultid="&_cstCheckID";
        resultseq=&_cstResultSeq;
        resultflag=1;
        _cst_rc=0;
      end;

      _cstMsgParm1="&_cstColStr2";
      _cstMsgParm2="&_cstDSname1";
      srcdata ="&_cstSrcData";
      _cstSeqNo+1;
      seqno=_cstSeqNo;
      keyvalues='';

      * Calculate keyvalues column.  *;
      %let _cstSubCnt=%SYSFUNC(countw(&_cstColumnStr,' '));
      %do i = 1 %to &_cstSubCnt;
        %let _cstColumn=%SYSFUNC(kscan(&_cstColumnStr,&i,' '));
        if vtype(&_cstColumn)='C' then
        do;
          if keyvalues='' then
            keyvalues = cats("&_cstColumn","=",&_cstColumn);
          else
            keyvalues = cats(keyvalues,",","&_cstColumn","=",&_cstColumn);
        end;
        else
        do;
          if keyvalues='' then
            keyvalues = cats("&_cstColumn","=",put(&_cstColumn,8.));
          else
            keyvalues = cats(keyvalues,",","&_cstColumn","=",put(&_cstColumn,8.));
        end;
      %end;

      * Calculate actual column.  *;
      %let _cstSubCnt=%SYSFUNC(countw(&_cstColStr1,' '));
      %do i = 1 %to &_cstSubCnt;
        %let _cstColumn=%SYSFUNC(kscan(&_cstColStr1,&i,' '));
        if vtype(&_cstColumn)='C' then
        do;
          if actual='' then
            actual = cats("&_cstColumn","=",&_cstColumn);
          else
            actual = cats(actual,",","&_cstColumn","=",&_cstColumn);
        end;
        else
        do;
          if actual='' then
            actual = cats("&_cstColumn","=",put(&_cstColumn,8.));
          else
            actual = cats(actual,",","&_cstColumn","=",put(&_cstColumn,8.));
        end;
      %end;

      checkid="&_cstCheckID";

      if last then
        call symputx('_cstSeqCnt',_cstSeqNo);
    run;
    %if (&syserr gt 4) %then
    %do;
      %* Check failed - SAS error  *;

      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %*******************************************************************;
    %* Parameters passed are check-level -- not record-level -- values *;
    %*******************************************************************;
    %cstutil_appendresultds(
                       _cstErrorDS=&_csttemp
                      ,_cstVersion=&_cstStandardVersion
                      ,_cstSource=&_cstCheckSource
                      ,_cstStdRef=&_cstStandardRef
                      );

    proc datasets lib=work nolist;
      delete &_csttemp;
    quit;
  %end;
  %else
  %do;
    %**************************************;
    %* No errors detected in source data  *;
    %**************************************;
    %let _cst_MsgID=CST0100;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultID=&_cst_MsgID
               ,_cstValCheckID=&_cstCheckID
               ,_cstResultParm1=&_cst_MsgParm1
               ,_cstResultParm2=&_cst_MsgParm2
               ,_cstResultSeqParm=&_cstResultSeq
               ,_cstSeqNoParm=&_cstSeqCnt
               ,_cstSrcDataParm=&_cstSrcData
               ,_cstResultFlagParm=0
               ,_cstRCParm=&_cst_rc
               ,_cstActualParm=
               ,_cstKeyValuesParm=
               ,_cstResultsDSParm=&_cstResultsDS
               );
  %end;

%exit_error:

  %if &_cstexit_error %then
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
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(exist(work._cstproblems)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstproblems;
      quit;
    %end;
  %end;
  %else
    %put <<< cstcheckforeignkeynotfound;

%mend cstcheckforeignkeynotfound;
