%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckcompareallcolumns                                                      *;
%*                                                                                *;
%* Compares all columns in one domain with the same columns in other domains.     *;
%*                                                                                *;
%* This macro compares values for one or more columns in one domain with values   *;
%* for those same columns in another domain. For example, an ADaM data set column *;
%* found with same name as an ADSL column but whose values do not match.          *;
%*                                                                                *;
%* Note: This macro requires use of _cstCodeLogic at a DATA step level (for       *;
%*       example, a full DATA step or PROC SQL invocation). _cstCodeLogic creates *;
%*       a work file (_cstproblems) that contains the records in error.           *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    ADaM column of ADSL origin but values do not match. COLUMNSCOPE=_ALL_ and   *;
%*    TABLESCOPE=[_ALL_-ADSL] [ADSL].                                             *;
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
%*            check-specific metadata                                             *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstcheckcompareallcolumns(_cstControl=)
    / des='CST: Matching _ALL_ column values not found';

  %local
    _cstCheckID
    _cstCheckSource
    _cstCodeLogic
    _cstColumnScope
    _cstCommonColumns
    _cstCommonColumnsCnt
    _cstCommonSQLColumns
    _cstDataRecords
    _cstDataRecords1
    _cstDom1
    _cstDom2
    _cstDSKeys1
    _cstDSKeys2
    _cstDSName1
    _cstDSName2
    _cstexit_error
    _cstexit_loop
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
  %let _cstexit_loop=0;
  %let _cstSrcData=&sysmacroname;
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

  %if ^%kindex(%upcase(&_cstColumnScope),_ALL_) %then
  %do;
    %***************************************************************************************;
    %* Columnscope contains improper value - check validation_master/control specification *;
    %***************************************************************************************;
    %let _cst_MsgID=CST0202;
    %let _cst_MsgParm1=Columnscope has improper value must contain keyword _ALL_;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  
  %**********************************************************************************;
  %* Single call to cstutil_buildcollist that does all domain and column processing *;
  %**********************************************************************************;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstDomSubOverride=Y);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
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

  %if &_cstTableSublistCnt ne 2 %then
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0023;
    %let _cst_MsgParm1=tableScope;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %****************************************************;
  %* Code should find columns common in both sublists *;
  %* and subset work._cstcolumnmentadata to match     *;
  %****************************************************;
  proc sort data=work._cstcolumnmetadata;
    by column;
  run;

  data work._cstcolumnmetadata;
    set work._cstcolumnmetadata;
    by column;
    if first.column and last.column then delete;
  run; 
  
  %*********************************************************************;
  %* This step keeps only the tables that have ALL columns of interest *;
  %*********************************************************************;
  proc sql noprint;
    create table work._csttablesubset1 as
      select * from work._csttablemetadata (where=(tsublist=1))
      where table in (select distinct table from work._cstcolumnmetadata);
    create table work._csttablesubset2 as
      select * from work._csttablemetadata (where=(tsublist=2))
      where table in (select distinct table from work._cstcolumnmetadata);
  quit;

  %*********************************;
  %* Handle any processing errors. *;
  %*********************************;
  %if (&syserr gt 4) %then
  %do;
    %*****************************;
    %* Check failed - SAS error  *;
    %*****************************;
    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Subsetting _cstTableMetadata failed;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if (&sqlrc gt 0) %then
  %do;
    %*****************************;
    %* Check failed - SAS error  *;
    %*****************************;
    %let _cst_MsgID=CST0050;
    %let _cst_MsgParm1=Subsetting _cstTableMetadata failed;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._csttablesubset1 nobs=_numobs;
    call symputx('_cstSubCnt1',_numobs);
    stop;
  run;

  data _null_;
    if 0 then set work._csttablesubset2 nobs=_numobs;
    call symputx('_cstSubCnt2',_numobs);
    stop;
  run;

  %if &_cstSubCnt1 <= 0 or &_cstSubCnt2 <= 0 %then
  %do;
    %***************************************************************;
    %* No tables evaluated - check validation_master specification *;
    %***************************************************************;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cstSrcData=&sysmacroname;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %let _cstDataRecords1=0;

  %do i=1 %to &_cstSubCnt1;
    data _null_;
      set work._csttablesubset1 (keep=sasref table keys firstObs=&i obs=&i);
        attrib _csttemp format=$41. label="Temp variable";
        _csttemp = catx('.',sasref,table);
        call symputx('_cstDSName1',_csttemp);
        call symputx('_cstDom1',table);
        call symputx('_cstDSKeys1',keys);
    run;

    %if ^%sysfunc(exist(&_cstDSName1)) %then
    %do;
      %******************************************************;
      %*  Check not run - data set could not be found       *;
      %******************************************************;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstDSname1;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_loop=1;
      %goto exit_loop;
    %end;

    %do j=1 %to &_cstSubCnt2;

      data _null_;
        set work._csttablesubset2 (keep=sasref table keys firstObs=&j obs=&i);
        attrib _csttemp format=$41. label="Temp variable";
        _csttemp = catx('.',sasref,table);
        call symputx('_cstDSName2',_csttemp);
        call symputx('_cstDom2',table);
        call symputx('_cstDSKeys2',keys);
      run;

      %if ^%sysfunc(exist(&_cstDSName2)) %then
      %do;
        %******************************************************;
        %*  Check not run - data set could not be found       *;
        %******************************************************;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=&_cstDSname2;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstSrcData=&sysmacroname;
        %let _cstexit_loop=1;
        %goto exit_loop;
      %end;

      %* Output metric only once for each target domain _cstDSName1) *;
      %if &i=1 %then 
      %do;
        %****************************;
        %* Write applicable metrics *;
        %****************************;
        %if &_cstMetrics %then 
        %do;

          data _null_;
            if 0 then set &_cstDSName2 nobs=_numobs;
            call symputx('_cstMetricsCntNumRecs',_numobs);
            stop;
          run;

          %if &_cstMetricsNumRecs %then
            %cstutil_writemetric(
               _cstMetricParameter=# of records tested
              ,_cstResultID=&_cstCheckID
              ,_cstResultSeqParm=&_cstResultSeq
              ,_cstMetricCnt=&_cstMetricsCntNumRecs
              ,_cstSrcDataParm=&_cstDSName2
              );
        %end;
      %end;

      %*************************************************************;
      %* Extract data needed from _cstColumnMetadata based on data *;
      %* sets from list 1 (_cstDom1) and list 2 (_cstDom2). This   *;
      %* needs to be split out by each data set in list 1 in order *;
      %* to create common variable list between list 1 and list 2  *;
      %* data set.                                                 *;
      %*************************************************************;
      data work._cstCommonCols;
        set work._cstcolumnmetadata;
        if table in ("&_cstDom1","&_cstDom2");
      run;
      
      %*******************************************;
      %* Remove non paired columns if they exist *;
      %*******************************************;
      data work._cstCommonCols;
        set work._cstCommonCols;
        by column;
        if first.column and last.column then delete;
      run;

      %******************************************************;
      %* Create macro variables available for codelogic and *; 
      %* count number of common columns being evaulated.    *;
      %******************************************************;
      %let _cstCommonColumnsCnt=0;
      proc sql noprint;
        select distinct column into :_cstCommonColumns separated by ' ' from work._cstCommonCols;
        select distinct column into :_cstCommonSQLColumns separated by ',' from work._cstCommonCols;
        select count(distinct column) into :_cstCommonColumnsCnt from work._cstCommonCols;
      quit;
      
      %if &_cstCommonColumnsCnt <= 0 %then
      %do;
        %*****************************************************************;
        %* No columns evaluated - check validation_master specification  *;
        %*****************************************************************;
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
  
      %do k = 1 %to &_cstCommonColumnsCnt;
        %let _cstSrcData=&_cstDSname1 (&_cstDSname2);     
        %let _cstColumn=%SYSFUNC(kscan(&_cstCommonColumns,&k,' '));

        %*************************************************************************
        %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *
        %*  expected result is a work._cstproblems data set of records in error. *
        %*  If there are no errors, the data set should have 0 observations.     *
        %*                                                                       *;
        %* Macro variables available to codeLogic:                               *;
        %*  _cstDSName1                        _cstDSName2                       *;
        %*  _cstDom1                           _cstDom2                          *;
        %*  _cstDSKeys1                        _cstDSKeys2                       *;
        %*                                                                       *;
        %*  _cstCommonColumns (column list from columnScope, space delimited)    *;
        %*  _cstCommonSQLColumns (column list from columnScope, comma delimited) *;
        %*  _cstColumn (column names from _cstCommomColumns)                     *;
        %*                                                                       *;
        %*************************************************************************;

        &_cstCodeLogic;
 
        %if %symexist(sqlrc) %then 
        %do;
          %if (&sqlrc gt 0) %then
          %do;
            %****************************;
            %* Check failed - SAS error *;
            %****************************;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Codelogic processing failed;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;
        %end;
        %if (&syserr gt 4) %then
        %do;
          %*************************************************************;
          %* Check failed - SAS error  Reset SAS options to accomodate *; 
          %* syntax-only checking that occurs with batch processing    *;
          %*************************************************************;
          options nosyntaxcheck obs=max replace;

          %let _cst_MsgID=CST0050;
          %let _cst_MsgParm1=Codelogic processing failed;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstexit_loop=1;
          %goto exit_loop;
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
          
        %if &_cstDataRecords gt 0 %then %let _cstDataRecords1=1;

        %******************************;
        %* Check for error conditions *;
        %******************************;
        %if &k le &_cstCommonColumnsCnt %then
        %do;
          %if &k=1 %then 
          %do;
            %****************************************;
            %* Create a temporary results data set. *;
            %****************************************;
            %local _csttemp;
            data _null_;
              attrib _csttemp label="Text string field for file names"  format=$char12.;
              _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
              call symputx('_csttemp',_csttemp);
            run;
          %end;

          %if &_cstDataRecords %then 
          %do;
            %******************************************************;
            %* Add the records to the temporary results data set. *;
            %******************************************************;
            data &_csttemp (label='Work error data set');
              %cstutil_resultsdskeep;
              set work._cstproblems end=last;
              attrib _cstSeqNo format=8. label="Sequence counter for result column";
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

              _cstMsgParm1='';
              _cstMsgParm2='';
              srcdata ="&_cstSrcData";
              _cstSeqNo+1;
              seqno=_cstSeqNo;
              keyvalues='';

              %let _subCnt=%SYSFUNC(countw(&_cstDSKeys1,' '));
              %*******************************;
              %* Calculate keyvalues column. *;
              %*******************************;
              %do _currentKey = 1 %to &_subCnt;
                %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys1,&_currentKey,' '));
                if vtype(&_cstKey)='C' then
                do;
                  if keyvalues='' 
                  then keyvalues = cats("&_cstKey","=",&_cstKey);
                  else keyvalues = cats(keyvalues,",","&_cstKey","=",&_cstKey);
                end;
                else
                do;
                  if keyvalues='' 
                  then keyvalues = cats("&_cstKey","=",put(&_cstKey,8.));
                  else keyvalues = cats(keyvalues,",","&_cstKey","=",put(&_cstKey,8.));
                end;
              %end;

              %let _cstCol=&_cstColumn;
              if vtype(&_cstCol)='C' then
              do;
                if actual='' 
                then actual = cats("&_cstCol","=",&_cstCol);
                else actual = cats(actual,",","&_cstCol","=",&_cstCol);
              end;
              else
              do;
                if actual=''
                then actual = cats("&_cstCol","=",put(&_cstCol,8.));
                else actual = cats(actual,",","&_cstCol","=",put(&_cstCol,8.));
              end;
              checkid="&_cstCheckID";
   
              if last then call symputx('_cstSeqCnt',_cstSeqNo);
            run;

            %if (&syserr gt 4) %then
            %do;
              %***************************************************************;
              %* Check failed - SAS error - Reset SAS options to accommodate *:
              %* syntax-only checking that occurs with batch processing      *;
              %***************************************************************;
              options nosyntaxcheck obs=max replace;
              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
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
          %end;
          %else %if &k=&_cstCommonColumnsCnt and &_cstDataRecords1=0 %then
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
               ,_cstActualParm=%str(&_cstactual)
               ,_cstKeyValuesParm=
               ,_cstResultsDSParm=&_cstResultsDS
               );
          %end;  %* End of _cstDataRecords check *;
        %end;  %* End of One or More Records check *;
      %end;  %* End of _cstCommonColumnCnt loop *;
      proc datasets lib=work nolist;
        delete &_csttemp;
      quit;
    %end;  %* End of sublist 2 loop *;

    * Write applicable metrics *;
    %if &_cstMetrics %then %do;

      data _null_;
        if 0 then set &_cstDSName1 nobs=_numobs;
        call symputx('_cstMetricsCntNumRecs',_numobs);
        stop;
      run;

      %if &_cstMetricsNumRecs %then
        %cstutil_writemetric(
                          _cstMetricParameter=# of records tested
                         ,_cstResultID=&_cstCheckID
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstMetricCnt=&_cstMetricsCntNumRecs
                         ,_cstSrcDataParm=&_cstDSName1
                        );
    %end;

%exit_loop:

      %if %sysfunc(exist(work._cstproblems)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstproblems;
        quit;
      %end;
      %if %length(&_csttemp)>0 %then
      %do;
        %if %sysfunc(exist(&_csttemp)) %then
        %do;
          proc datasets lib=work nolist;
            delete &_csttemp;
          quit;
        %end;
      %end;

      %if &_cstexit_loop %then
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

        %let _cstexit_loop=0;
        %let _cstexit_error=0;
      %end;

  %end;  %* End of sublist 1 loop *;



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
    %if %sysfunc(exist(work._csttablesubset1)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablesubset1;
      quit;
    %end;
    %if %sysfunc(exist(work._csttablesubset2)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablesubset2;
      quit;
    %end;
    %if %sysfunc(exist(work._cstCommonCols)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstCommonCols;
      quit;
    %end;
  %end;
  %else %put <<< cstcheckcompareallcolumns;

%mend cstcheckcompareallcolumns;