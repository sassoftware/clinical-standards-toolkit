%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_notsorted                                                             *;
%*                                                                                *;
%* Identifies a domain that is not sorted by the keys defined in the metadata.    *;
%*                                                                                *;
%* Example validation check that uses this macro:                                 *;
%*    Identifies domain in a table that is not correctly sorted.                  *;
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
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_notsorted(_cstControl=)
    / des='CST: Checks if domains are sorted correctly';

  %local
    _cstCheckID
    _cstTableScope
    _cstUseSourceMetadata
    _cstSourceData
    ;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstDomCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;
  %let _cstSourceData=;
  %let _cstSeqCnt=0;
  %let _cstResultFlag=-1;

  %******************************************************************;
  %*  Read Control data set to retrieve information for the check.  *;
  %******************************************************************;

  %cstutil_readcontrol;

  %if &_cstDebug %then
  %do;
    %put >>> &sysmacroname.;
    %put '****************************************************';
    %put checkID=&_cstCheckID;
    %put tablescope=&_cstTableScope;
    %put useSourceMetadata =&_cstUseSourceMetadata;
    %put '****************************************************';
  %end;

  %****************************************************************************;
  %* Call cstutil_builddomlist to populate work._csttablemetadata by default  *;
  %****************************************************************************;
  %cstutil_builddomlist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %if &_cst_rc  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope);
      %let _cstSrcData=&sysmacroname;
      %goto EXIT_ERROR;
  %end;

  data _null_;
    if 0 then set work._csttablemetadata nobs=_numobs;
    call symputx('_cstDomCnt',_numobs);
    stop;
  run;

  %***************************************;
  %*  Metrics count of # domains tested  *;
  %***************************************;
  %if &_cstMetrics %then
  %do;
    %if &_cstMetricsNumRecs %then
    %do;
      %let _cstMetricsCntNumRecs=&_cstDomCnt;
      %******************************;
      %*  Write applicable metrics  *;
      %******************************;
      %cstutil_writemetric(
                _cstMetricParameter=# of data sets tested
                ,_cstResultID=&_cstCheckID
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstMetricCnt=&_cstMetricsCntNumRecs
                ,_cstSrcDataParm=&_cstTableScope
                );
    %end;
  %end;

  %if &_cst_rc or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope);
      %let _cstSrcData=&sysmacroname;
      %goto EXIT_ERROR;
  %end;

  %if &_cstDomCnt<=0 %then
  %do;
    %***********************************************************;
    %*  No tables evaluated-check validation control data set  *;
    %***********************************************************;
    %let _cst_MsgID=CST0002;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstSrcData=&sysmacroname;
    %let _cstResultFlag=-1;
    %goto EXIT_ERROR;
  %end;

  %*************************************************************;
  %*  Check for multiple sasrefs if not using source metadata  *;
  %*************************************************************;
  %if %upcase(&_cstUseSourceMetadata)=N %then
  %do;
    data work._csttemptablemetadata (drop=_cstLibCnt j);
      set work._csttablemetadata;
      _cstLibCnt = countw(symget('_cstSourceData'),' ');
      do j= 1 to _cstLibCnt;
        sasref = kscan(symget('_cstSourceData'),j,' ');
        output;
      end;
    run;
    data _null_;
      set work._csttemptablemetadata nobs=_numobs;
      call symputx('_cstTableCnt',_numobs);
      stop;
    run;
  %end;
  %else
  %do;
    %let _cstTableCnt=&_cstDomCnt;
  %end;

  %**************************************************;
  %* Cycle through requested or applicable domains  *;
  %**************************************************;
  %do i=1 %to &_cstTableCnt.;
    data _null_;
      length _csttemp $200;
      %if %upcase(&_cstUseSourceMetadata)=N %then
      %do;
        set work._csttemptablemetadata (keep=sasref table keys firstObs=&i);
      %end;
      %else
      %do;
        set work._csttablemetadata (keep=sasref table keys firstObs=&i);
      %end;
      _csttemp = catx('.',sasref,table);
      call symputx('_cstDSName',kstrip(_csttemp));
      call symputx('_cstDSKeys',kstrip(keys));
      stop;
    run;

    %if %sysfunc(exist(&_cstDSName))=0 %then
    %do;
      %****************************************************;
      %*  domain could not be found                       *;
      %****************************************************;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=&_cstDSname;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstSrcData=&_cstDSname;
      %let _cstResultFlag=1;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %goto NEXT_TABLE;
    %end;

    data _null_;
      if 0 then set &_cstDSName nobs=_numobs;
      call symputx('_cstDataRecords',_numobs);
      stop;
    run;
    %if &_cstDataRecords = 0 %then
    %do;
      %************************************************************;
      %* data set with zero observations - it must be sorted OK   *;
      %************************************************************;
      %let _cst_MsgID=CST0100;
      %let _cst_MsgParm1=&_cstDSName;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&_cstDSName;
      %let _cst_rc=0;
      %let _cstResultFlag=0;
      %goto NEXT_TABLE;
    %end;

    %***************************************************;
    %* Could not find any keys defining the sort order *;;
    %***************************************************;
    %if %length(&_cstDSKeys.)=0 %then
    %do;
      %let _cst_MsgID=CST0022;
      %let _cst_MsgParm1=&_cstDSname;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstSrcData=&_cstDSname;
      %let _cstResultFlag=-1;
      %goto NEXT_TABLE;
    %end;

    %*******************************************************************************;
    %* Do the keys exist on the dataset?                                           *;
    %*******************************************************************************;
    data _null_;
      attrib dsid           length=8;
      attrib keyname        length=$200;
      attrib i              length=8;
      attrib _cstResultFlag length=8.;
      attrib _cst_msgParm2  length=$200;
      call missing(dsid, keyname, i);
      _cstResultFlag=0;
      _cst_MsgParm2='';
      dsid=open("&_cstDSName.","i");
      if dsid=0 then
      do;
        _cstResultFlag=1;
        _cst_MsgParm2="Could not open dataset &_cstDSName.";
      end;
      else
      do;
        i=1;
        keyname=kscan("&_cstDSKeys.", i, ' ');
        do while (_cstResultFlag=0 and not missing(keyname));
          if varnum(dsid, keyname)=0 then
          do;
            _cstResultFlag=1;
            _cst_MsgParm2="&_cstDSName. is missing a required key (" || kstrip(keyname) || ").";
          end;
          else
          do;
            keyname=kscan("&_cstDSKeys.", i, ' ');
            i = i + 1;
          end;
        end;
      end;
      call symput('_cstResultFlag', kstrip(put(_cstResultFlag, best.)));
      call symput('_cst_MsgParm2', kstrip(_cst_MsgParm2));
    run;    %if &_cstResultFlag. > 0 %then
    %do;
      %*************************************************************;
      %* Error Condition exists - data set is NOT sorted correctly *;
      %*************************************************************;
      options nosyntaxcheck replace;
      %let _cst_MsgID=SDTM0601;
      %let _cst_MsgParm1=&_cstDSName.;
      %let _cst_MsgParm2=&_cst_MsgParm2;
      %let _cstSrcData=&_cstDSName;
      %let _cst_rc=0;
      %let _cstResultFlag=1;
      %goto NEXT_TABLE;
    %end;

    %*******************************************************************************;
    %* Check the sort order for the given dataset/domain.                          *;
    %*******************************************************************************;
    proc sort data=&_cstDSName.(keep=&_cstDSKeys.) out=work._cstTempNotSorted;
      by &_cstDSKeys.;
    run;
    %if &syserr. > 0 %then
    %do;
      %*************************************************************;
      %* Error Condition exists - data set is NOT sorted correctly *;
      %*************************************************************;
      options nosyntaxcheck replace;
      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=&sysmacroname could not sort by &_cstDSKeys - see SAS Log;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&_cstDSName;
      %let _cst_rc=0;
      %let _cstResultFlag=1;
      %goto NEXT_TABLE;
    %end;

    proc compare base=&_cstDSName.(keep=&_cstDSKeys.) compare=work._cstTempNotSorted noprint;
    run;
    %if &sysinfo. > 0 %then
    %do;
      %*************************************************************;
      %* Error Condition exists - data set is NOT sorted correctly *;
      %*************************************************************;
      %let _cst_MsgID=SDTM0601;
      %let _cst_MsgParm1=&_cstDSName;
      %let _cst_MsgParm2=;
      %let _cstSrcData=&_cstDSName;
      %let _cst_rc=0;
      %let _cstResultFlag=1;
      %goto NEXT_TABLE;
    %end;

    %*****************************************************;
    %* No Error Condition - data set is sorted correctly *;
    %*****************************************************;
    %let _cst_MsgID=CST0100;
    %let _cst_MsgParm1=&_cstDSName;
    %let _cst_MsgParm2=;
    %let _cstSrcData=&_cstDSName;
    %let _cst_rc=0;
    %let _cstResultFlag=0;

  %NEXT_TABLE:
    %*****************************************************;
    %* Write out what we learned about the last data set *;
    %*****************************************************;
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
    %********************;
    %* Delete work file *;
    %********************;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstTempNotSorted);;
  %end; %* Loop over individual data sets *;
%return;

%EXIT_ERROR:
  %* Write out errors that stopped processing for this macro *;
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

%mend cstcheck_notsorted;
