%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_notunique                                                             *;
%*                                                                                *;
%* Assesses the uniqueness of records within data sets.                           *;
%*                                                                                *;
%* Each of these three assessments accesses different code sections within the    *;
%* macro.                                                                         *;
%*                                                                                *;
%*   Assessment 1: Determine whether a data set is unique by a set of columns.    *;
%*      Data sets: It is assumed that if control column columnScope is blank,     *;
%*              code cycles through domains that are specified in control column  *;
%*              tableScope. Code identifies any records that are not unique by the*;
%*              domain keys defined in the table-level metadata.                  *;
%*      Multiple columns: This option allows the specification of a single set of *;
%*              columns (in the form var1+var2+...varn). Code identifies any      *;
%*              records that are not unique by the specified set of columns within*;
%*              each domain specified in tableScope. For the purposes of          *;
%*              reporting, the specified columns are treated as the domain keys.  *;
%*              No codeLogic is used or currently checked.                        *;
%*   Assessment 2: For any subject, determine whether column values are unique.   *;
%*      Single columns: For single columns (for example, **SEQ), code checks for  *;
%*              uniqueness in USUBJID (except TSSEQ, in TSPARMCD). No codeLogic   *;
%*              is used or currently checked.                                     *;
%*   Assessment 3: Determine whether a combination of two columns has unique      *;
%*              values.                                                           *;
%*      Column pairs: For multiple columns (for example, **TEST and **TESTCD), the*;
%*              code checks that there are a unique set of values for the pair of *;
%*              columns. These must be specified in the form of matching          *;
%*              columnScope sublists. Two, and only two, sublists can be          *;
%*              specified. No codeLogic is used or currently checked.             *;
%*   Assessment 4: Determine whether the values in one column (Column2) are       *;
%*              consistent with the values in another column (Column1).           *;
%*      Column pairs: For multiple columns (for example, **TESTCD and **STRESU),  *;
%*              the code checks that there is a unique value in Column2 for each  *;
%*              value of Column1. These must be specified in the form of matching *;
%*              columnScope sublists. Two, and only two, sublists can be          *;
%*              specified. The first sublist contains Column1 (for example,       *;
%*              VSTESTCD), and the second sublist contains Column2 (for example,  *;
%*              VSSTRESU). codeLogic is required. It is the presence of codeLogic *;
%*              that distinguishes Assessment 3 from Assessment 4.                *;
%*                                                                                *;
%*  The columnScope sublists must be bounded by brackets in this style:           *;
%*       [LBTEST+VSTEST][LBTESTCD+VSTESTCD]                                       *;
%*                                                                                *;
%*  The following limitations apply:                                              *;
%*       1. The two lists must resolve to the same number of columns.             *;
%*       2. The columns to be compared must be in the same data set.              *;
%*       3. The first item in list 1 is paired with the first item in list 2,     *;
%*          and so on.                                                            *;
%*                                                                                *;
%* Here are example combinations of tableScope and columnScope:                   *;
%*                                                                                *;
%*   tableScope columnScope        How code interprets                            *;
%*   ---------- -----------        ---------------------------------------------  *;
%*   ALL                           For all domains, determine whether each domain *;
%*                                 is unique by its keys                          *;
%*   FINDINGS   [**TEST][**TESTCD] For all FINDINGS domains, **TEST and **TESTCD  *;
%*                                 must map 1:1                                   *;
%*   ALL        **SEQ              For all domains, check **SEQ for uniqueness    *;
%*                                 within USUBJID                                 *;
%*   DM                            Is DM unique by its keys (STUDYID+USUBJID)?    *;
%*   DV         [DVTERM][DVDECOD]  For DV, DVTERM and DVDECOD must map 1:1        *;
%*   SUPP**                        For all SUPP** domains, determine whether      *;
%*                                 records are unique by their keys               *;
%*   DV         USUBJID+DVTERM     For DV, determine whether records are unique   *;
%*                                 by USUBJID and DVTERM                          *;
%*   ALL        ALL                Not supported thru the SAS Clinical Standards  *;
%*                                 Toolkit 1.4, this will signal in future release*;
%*                                 a check for duplicate (non unique) records     *;
%*                                 across all columns.                            *;
%*                                 For now, columnScope=_ALL_ will be treated     *;
%*                                 as columnScope=<blank>.                        *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstMetrics Enables or disables metrics reporting                      *;
%* @macvar _cstMetricsNumRecs Validation metrics: calculate number of records     *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumRecs Validation metrics: number of records evaluated  *;
%* @macvar _cstMetricsNumSubj Validation metrics: calculate number of subjects    *;
%*             evaluated                                                          *;
%* @macvar _cstMetricsCntNumSubj Validation metrics: number of subjects evaluated *;
%* @macvar _cstrunstd Primary standard                                            *;
%* @macvar _cstrunstdver Version of the primary standard                          *;
%* @macvar _cstSubjectColumns Standard-specific set of columns that identify a    *;
%*             subject                                                            *;
%*                                                                                *;
%* @param _cstControl - required - The single-observation data set that contains  *;
%*            check-specific metadata.                                            *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_notunique(_cstControl=)
    / des='CST: Checks file or column uniqueness';

  %local
    _csttempds
    _cstclds

    _cstColList
    _cstColCnt
    _cstDomCnt
    _cstDomainOnly
    _cstDSName
    _cstDSName1
    _cstDSName2
    _cstRefOnly
    _cstColStr
    _cstColumn
    _cstColumn1
    _cstColumn2
    _cstDSKeys
    _cstKeyCnt
    _cstKey
    _cstDataRecords
    _cstBadColumn
    _cstStr
    _cstStrCnt
    _cstKeysOK

    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstCodeLogic
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstStandardRef
    _cstReportAll
    _cstReportingColumns
    _cstResetDomainName
    _cstLastError
    _cstLastErrorKeys

    _cstColumnSublistCnt
    _cstSubCnt
    _cstSQLKeys
    _col1Cnt
    _col2Cnt
    _uniqueCnt
    _cstRptCol
    _cstErrorRecords
    _cstexit_error
    _cstexit_loop
  ;

  %cstutil_readcontrol;

  %let _cstactual=;
  %let _cstSrcData=&sysmacroname;
  %let _cstResultFlag=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;
  %let _cstexit_loop=0;
  %let _cstResetDomainName=0;

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
      put "reportAll=&_cstReportAll";
      put "reportingColumns=&_cstReportingColumns";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;

  %****************************************************************;
  %*  Function 1:  Is data set unique by a set of columns?        *;
  %****************************************************************;
  %if %length(&_cstColumnScope)=0 or
         (%SYSFUNC(kindex(%upcase(&_cstColumnScope),_ALL_))) or
         (%SYSFUNC(countc(&_cstColumnScope,'['))=0 and
         (%SYSFUNC(countw(&_cstColumnScope,' '))>1 or %SYSFUNC(countw(&_cstColumnScope,'+'))>1)) %then
  %do;

    %if %SYSFUNC(kindex(%upcase(&_cstColumnScope),_ALL_)) %then
    %do;
      %* See explanatory note above  *;
      %let _cstColumnScope=;
    %end;

    %if %length(&_cstCodeLogic)>0 %then
    %do;
      %* Check run but non-missing codeLogic is not used  *;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0020
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

    %if %length(&_cstColumnScope)=0 %then
    %do;

      %* What domains are we to run this check against?                       *;
      %* This information is contained in the _cstTableScope macro variable   *;
      %*  derived from the input control data set.                            *;
      %* The call to cstutil_builddomlist builds work._csttablemetadata       *;

      %cstutil_builddomlist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
      %if &_cst_rc  or ^%sysfunc(exist(work._csttablemetadata)) %then
      %do;
        %* Problems with tableScope  *;
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

      data _null_;
        if 0 then set work._csttablemetadata nobs=_numobs;
        call symputx('_cstDomCnt',_numobs);
        stop;
      run;
    %end;
    %else
    %do;
      %let _cstColList=;
      %let _cstColCnt=0;

      %* What domains are we to run this check against?                       *;
      %* This information is contained in the _cstTableScope macro variable   *;
      %*  derived from the input control data set.                            *;
      %* What columns are we to run this check against?                       *;
      %* This information is contained in the _cstColumnScope macro variable  *;
      %*  derived from the input control data set.                            *;
      %* The call to cstutil_buildcollist builds work._cstcolumnmetadata      *;
      %*  and sets the _cstColList and _cstColCnt macro variables.            *;

      %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);

      %if &_cst_rc or ^%sysfunc(exist(work._csttablemetadata)) %then
      %do;
        %* Problems with columnScope  *;
        %let _cst_MsgID=CST0004;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_rc=1;
        %let _cstResultFlag=-1;
        %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
        %let _cstSrcData=&sysmacroname;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      data _null_;
        if 0 then set work._csttablemetadata nobs=_numobs;
        call symputx('_cstDomCnt',_numobs);
        stop;
      run;
      proc sql noprint;
        select column into :_cstColList separated by ' '
          from work._cstcolumnmetadata;
        select count(*) into :_cstColCnt
          from work._cstcolumnmetadata;
      quit;

      %if &_cstColCnt=0 %then
      %do;
        %* Problems with columnScope  *;
        %let _cst_MsgID=CST0004;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
        %let _cstSrcData=&sysmacroname;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;


    %* Cycle through requested or applicable domains  *;
    %if &_cstDomCnt > 0 %then
    %do;

      %* Initialize metrics record count to missing *;
      %if &_cstMetrics %then
      %do;
        %if &_cstMetricsNumRecs %then
          %let _cstMetricsCntNumRecs=.;
      %end;

      %do i=1 %to &_cstDomCnt;
        %let _cst_rc=0;

        data _null_;
          set work._csttablemetadata (keep=sasref table keys firstObs=&i);
            attrib _csttemp format=$char200. label="Text string field";
            _csttemp = catx('.',sasref,table);
            call symputx('_cstDSName',kstrip(_csttemp));
            call symputx('_cstRefOnly',sasref);
            if exist(table) then
              call symputx('_cstDomainOnly',cats('_',table));
            else
              call symputx('_cstDomainOnly',table);
            call symputx('_cstDSKeys',keys);
          stop;
        run;

        %if %length(&_cstColumnScope)>0 %then
        %do;
          %let _cstDSKeys=&_cstColList;
        %end;

        %* No keys is a problem... stop the check.;
        %if %length(&_cstDSKeys)=0 %then
        %do;
          %* Check not run - _cstDSName keys could not be found  *;
          %let _cst_MsgID=CST0022;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=;
          %let _cstactual=;
          %let _cstSrcData=&sysmacroname;
          %let _cstResultFlag=-1;
          %let _cstexit_loop=1;
          %goto exit_domloop;
        %end;

        %let _cstDataRecords=0;

        %if %sysfunc(exist(&_cstDSName)) %then
        %do;
          %if &_cstMetricsNumRecs and &_cstReportAll=Y %then
          %do;
            * Set metrics record count to # records in domain *;
            data _null_;
              if 0 then set &_cstDSName nobs=_numobs;
              call symputx('_cstMetricsCntNumRecs',_numobs);
              stop;
            run;
          %end;

          proc sort data=&_cstDSName (keep=&_cstDSKeys) out=work.&_cstDomainOnly nodupkey dupout=work._cstdups;
            by &_cstDSKeys;
          run;
          %if (&syserr gt 4) %then
          %do;
            %* Check failed - SAS error  *;

            * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
            options nosyntaxcheck obs=max replace;

            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Proc sort failed;
            %let _cst_MsgParm2=;
            %let _cstactual=%str(keys=&_cstDSKeys);
            %let _cstSrcData=&_cstDSName;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_domloop;
          %end;

          %if %sysfunc(exist(work._cstdups)) %then
          %do;
            data _null_;
              if 0 then set work._cstdups nobs=_numobs;
              call symputx('_cstDataRecords',_numobs);
              stop;
            run;

            %if &_cstDataRecords %then
            %do;
              %* Create a temporary results data set. *;
              data _null_;
                attrib _csttemp label="Text string field for file names"  format=$char12.;
                _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
                call symputx('_csttempds',_csttemp);
              run;

              %* Write multiple records to the results data set for the domain in error *;
              data &_csttempds (label='Work error data set');
                  %cstutil_resultsdskeep;

                set work._cstdups (keep=&_cstDSKeys) end=last;
                  by &_cstDSKeys;

                attrib
                    _cstSeqNo format=8. label="Sequence counter for result column"
                    _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
                    _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
                    _cstDetails format=$char200. label="Message details"
                    _cstLastKeyValues format=$char2000. label="Last keyvalues"
                  ;

                  retain _cstSeqNo 0 ;
                  if _n_=1 then _cstSeqNo=&_cstSeqCnt;

                  keep _cstMsgParm1 _cstMsgParm2;

                  * Set results data set attributes *;
                  %cstutil_resultsdsattr;
                  retain message resultseverity resultdetails '';
                  retain _cstDetails _cstLastKeyValues;

                  resultid="&_cstCheckID";
                  _cstMsgParm1='';
                  _cstMsgParm2='';
                  resultseq=&_cstResultSeq;
                  resultflag=1;
                  srcdata = "&_cstDSName";
                  _cst_rc=0;
                  keyvalues='';

                  * Calculate keyvalues column.  *;
                  %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));
                  %do _currentKey = 1 %to &_cstSubCnt;
                    %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys,&_currentKey,' '));
                    if vtype(&_cstKey)='C' then
                    do;
                      if keyvalues='' then
                        keyvalues = cats("&_cstKey","=",&_cstKey);
                      else
                        keyvalues = cats(keyvalues,",","&_cstKey","=",&_cstKey);
                    end;
                    else
                    do;
                      if keyvalues='' then
                        keyvalues = cats("&_cstKey","=",put(&_cstKey,8.));
                      else
                        keyvalues = cats(keyvalues,",","&_cstKey","=",put(&_cstKey,8.));
                    end;
                  %end;
                  actual = cats("keys=","&_cstDSKeys");

                  _cstDetails=actual;
                  _cstLastKeyValues=keyvalues;

                  _cstSeqNo+1;
                  seqno=_cstSeqNo;

                  checkid="&_cstCheckID";

                  if last then
                  do;
                    call symputx('_cstSeqCnt',_cstSeqNo);
                    call symputx('_cstLastError',cats('%nrstr( ','Last invalid result:',_cstDetails,' )'));
                    call symputx('_cstLastErrorKeys',cats('%nrstr( ',_cstLastKeyValues,' )'));
                  end;

              run;
              %if (&syserr gt 4) %then
              %do;
                %* Check failed - SAS error  *;

                * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
                options nosyntaxcheck obs=max replace;

                %let _cst_MsgID=CST0050;
                %let _cst_MsgParm1=Duplicate record reporting step failed;
                %let _cst_MsgParm2=;
                %let _cstactual=%str(keys=&_cstDSKeys);
                %let _cstSrcData=&_cstDSName;
                %let _cstResultFlag=-1;
                %let _cstexit_loop=1;
                %goto exit_domloop;
              %end;

              %* Write only one record to the results data set for the domain in error *;
              %if %upcase(&_cstReportAll)=N %then
              %do;

                %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
                %cstutil_writeresult(
                     _cstResultID=&_cstCheckID
                    ,_cstValCheckID=&_cstCheckID
                    ,_cstResultParm1=
                    ,_cstResultParm2=
                    ,_cstResultSeqParm=&_cstResultSeq
                    ,_cstSeqNoParm=&_cstSeqCnt
                    ,_cstSrcDataParm=&_cstDSName
                    ,_cstResultFlagParm=1
                    ,_cstActualParm=%str(&_cstLastError)
                    ,_cstKeyValuesParm=%str(&_cstLastErrorKeys)
                    ,_cstResultDetails=%str(All results may not be reported because reportAll=N)
                    ,_cstResultsDSParm=&_cstResultsDS
                );

                %let _cstexit_loop=0;
                %goto exit_domloop;
              %end;
              %else
              %do;

                %* Parameters passed are check-level -- not record-level -- values *;
                %cstutil_appendresultds(
                                       _cstErrorDS=&_csttempds
                                      ,_cstVersion=&_cstStandardVersion
                                      ,_cstSource=&_cstCheckSource
                                      ,_cstStdRef=&_cstStandardRef
                                      );
              %end;
            %end;
            %else
            %do;
              %* No errors detected for _cstDSName  *;
              %let _cst_MsgID=CST0100;
              %let _cst_MsgParm1=&_cstDSName;
              %let _cst_MsgParm2=;
              %let _cstactual=;
              %let _cstSrcData=&_cstDSName;
              %let _cstResultFlag=0;
              %let _cstexit_loop=1;
              %goto exit_domloop;
            %end;

          %end;
          %else
          %do;
            %* Check not run - work._cstdups could not be found  *;
            %let _cst_MsgID=CST0003;
            %let _cst_MsgParm1=work._cstdups;
            %let _cst_MsgParm2=;
            %let _cstactual=;
            %let _cstSrcData=&_cstDSName;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_domloop;
          %end;

        %end;
        %else
        %do;
          %* Check not run - &_cstDSName could not be found  *;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=;
          %let _cstactual=;
          %let _cstSrcData=&sysmacroname;
          %let _cstResultFlag=1;
          %let _cstexit_loop=1;
          %goto exit_domloop;
        %end;

%exit_domloop:

        %if %sysfunc(exist(work._cstdups)) %then
        %do;
          proc datasets lib=work nolist;
            delete _cstdups;
          quit;
        %end;
        %if %symexist(_csttempds) %then
        %do;
          %if %length(&_csttempds)>0 %then
          %do;
            %if %sysfunc(exist(&_csttempds)) %then
            %do;
              proc datasets lib=work nolist;
                delete &_csttempds;
              quit;
            %end;
          %end;
        %end;
        %if %symexist(_cstDomainOnly) %then
        %do;
          %if %sysfunc(exist(&_cstDomainOnly)) %then
          %do;
            proc datasets lib=work nolist;
              delete &_cstDomainOnly;
            quit;
          %end;
        %end;

        * Write applicable metrics *;
        %if &_cstMetrics %then %do;
          %if &_cstMetricsNumRecs %then
            %cstutil_writemetric(
                              _cstMetricParameter=# of records tested
                             ,_cstResultID=&_cstCheckID
                             ,_cstResultSeqParm=&_cstResultSeq
                             ,_cstMetricCnt=&_cstMetricsCntNumRecs
                             ,_cstSrcDataParm=&_cstDSName
                            );
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

      %end;  %* do i=1 %to &_cstDomCnt loop;


    %end; %* if &_cstDomCnt > 0 loop;

    %else
    %do;
      %* No tables evaluated-check validation control data set  *;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstactual=;
      %let _cstSrcData=&sysmacroname;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

  %end;  %* length(&_cstColumnScope) loop;
  %else
  %do;

    %************************************************************************;
    %* This section assumes we are checking uniqueness at the column level  *;
    %*    across records within a domain                                    *;
    %************************************************************************;

    %let _cstColumnSublistCnt=0;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
    %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
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

    %if &_cstColCnt=0 %then
    %do;
      %* Problems with columnScope  *;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&sysmacroname;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %***********************************************************************;
    %*  Function 2:  For any given subject, are column values unique?      *;
    %*                                                                     *;
    %*  Only one column (e.g. AESEQ or **SEQ) has been specified           *;
    %*  Is it unique within subject?                                       *;
    %***********************************************************************;

    %if %SYSFUNC(countw(&_cstColumnScope,' ')) = 1 and &_cstColumnSublistCnt<2 %then
    %do;

      %if %length(&_cstCodeLogic)>0 %then
      %do;
        %* Check run but non-missing codeLogic is not used  *;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                  _cstResultID=CST0020
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
      %end;

      %if ^%symexist(_cstSubjectColumns) %then
      %do;
        %* Global macro variable xxx could not be found or contains an invalid value ;
        %let _cst_MsgID=CST0027;
        %let _cst_MsgParm1=_cstSubjectColumns;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      %if %length(&_cstSubjectColumns)=0 %then
      %do;
        %* Global macro variable xxx could not be found or contains an invalid value ;
        %let _cst_MsgID=CST0027;
        %let _cst_MsgParm1=_cstSubjectColumns;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
      %let _cstSubjectColumns=%upcase(&_cstSubjectColumns);

      %do i=1 %to &_cstDomCnt;

        data _null_;
          set work._csttablemetadata (keep=sasref table keys firstObs=&i);
            attrib _csttemp format=$char200. label="Text string field";
            _csttemp = catx('.',sasref,table);
            call symputx('_cstDSName',kstrip(_csttemp));
            call symputx('_cstRefOnly',sasref);
            if exist(table) then
            do;
              call symputx('_cstDomainOnly',cats('_',table));
              call symputx('_cstResetDomainName','1');
            end;
            else
              call symputx('_cstDomainOnly',table);
            call symputx('_cstDSKeys',keys);
          stop;
        run;

        %if %sysfunc(exist(&_cstDSName)) %then
        %do;

          %let _cstColStr=;
          %let _cstColCnt=0;

          %if &_cstMetricsNumRecs %then
          %do;
            * Set metrics record count to # records in domain *;
            data _null_;
              if 0 then set &_cstDSName nobs=_numobs;
              call symputx('_cstMetricsCntNumRecs',_numobs);
              stop;
            run;
          %end;

          %if %length(&_cstDSKeys)=0 %then
          %do;
            %* Check not run - Domain &_cstDSName keys not found  *;
            %let _cst_MsgID=CST0022;
            %let _cst_MsgParm1=&_cstDSName;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstSrcData=&sysmacroname;
            %let _cstResultFlag=-1;
            %let _cstactual=%str(keys=&_cstDSKeys);
            %let _cstexit_loop=1;
            %goto exit_colloop;
          %end;

          %* Determine if the _cstSubjectColumns exist in the specified data set *;
          data _null_;
            _cstStr = symget('_cstSubjectColumns');
            _cstStr=tranwrd(ktrim(_cstStr),',',' ');
            _cstStr=compbl(_cstStr);
            call symputx('_cstStr',_cstStr);
            call symputx('_cstStrCnt',countw(_cstStr,' '));
          run;
          %let dsid = %sysfunc(open(&_cstDSName));
          %let _cstKeysOK=1;
          %let _cstBadColumn=;
          %do _sk = 1 %to &_cstStrCnt;
            %if ^%sysfunc(varnum(&dsid,%SYSFUNC(kscan(&_cstStr,&_sk,' ')))) %then
            %do;
              %let _cstKeysOK=0;
              %let _cstBadColumn=%SYSFUNC(kscan(&_cstStr,&_sk,' '));
            %end;
          %end;
          %if &_cstKeysOK=0 %then
          %do;
            %let dsid = %sysfunc(close(&dsid));
            %* Check not run - Domain &_cstDSName does not contain &_cstSubjectColumns columns  *;
            %let _cst_MsgID=CST0021;
            %let _cst_MsgParm1=&_cstDSName;
            %let _cst_MsgParm2=&_cstBadColumn;
            %let _cst_rc=0;
            %let _cstSrcData=&sysmacroname;
            %let _cstResultFlag=-1;
            %let _cstactual=%str(_cstSubjectColumns=&_cstSubjectColumns);
            %let _cstexit_loop=1;
            %goto exit_colloop;
          %end;
          %let dsid = %sysfunc(close(&dsid));

          data _null_;

          %if &_cstResetDomainName %then
          %do;
            set work._cstcolumnmetadata (keep=sasref table column where=(upcase(sasref)=upcase("&_cstRefOnly") and
                             upcase(table)=upcase(substr("&_cstDomainOnly",2)))) nobs=_numobs end=last;
            %let _cstResetDomainName=0;
          %end;
          %else
          %do;
            set work._cstcolumnmetadata (keep=sasref table column where=(upcase(sasref)=upcase("&_cstRefOnly") and
                             upcase(table)=upcase("&_cstDomainOnly"))) nobs=_numobs end=last;
          %end;

            retain _cstColStr;
            attrib _cstColStr format=$char2000. label="list of columns";
            attrib _cstRecCnt format=8. label="Record counter";

            if _n_=1 then _cstRecCnt=1;
            else _cstRecCnt+1;

            if _cstColStr ne '' then
              _cstColStr = catx(" ",_cstColStr,column);
            else
              _cstColStr = column;


            if last then
            do;
              call symputx('_cstColStr',_cstColStr);
              call symputx('_cstColCnt',_cstRecCnt);
            end;
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
            %let _cstexit_error=1;
            %goto exit_error;
          %end;

          %* Cycle through columns  *;
          %do j=1 %to &_cstColCnt;

            %let _cstColumn = %scan(&_cstColStr, &j , " ");

            %* Determine if this column exists in the specified data set *;
            %let dsid = %sysfunc(open(&_cstDSName));
            %if ^%sysfunc(varnum(&dsid,&_cstColumn)) %then
            %do;
              %let dsid = %sysfunc(close(&dsid));
              %* Check not run - Domain &_cstDSName does not contain &_cstColumn column  *;
              %let _cst_MsgID=CST0021;
              %let _cst_MsgParm1=&_cstDSName;
              %let _cst_MsgParm2=&_cstColumn;
              %let _cst_rc=0;
              %let _cstSrcData=&sysmacroname;
              %let _cstResultFlag=-1;
              %let _cstactual=;
              %let _cstexit_loop=1;
              %goto exit_colloop;
            %end;
            %let dsid = %sysfunc(close(&dsid));

            %if %SYSFUNC(kindex(%upcase(&_cstSubjectColumns),%upcase(&_cstColumn))) %then
            %do;
              proc sort data=&_cstDSName (keep=&_cstDSKeys) out=work.&_cstDomainOnly nodupkey dupout=work._cstdups;
                by &_cstSubjectColumns;
              run;
            %end;
            %else
            %do;
              proc sort data=&_cstDSName (keep=&_cstDSKeys &_cstColumn) out=work.&_cstDomainOnly nodupkey dupout=work._cstDups;
                by &_cstSubjectColumns &_cstColumn;
              run;
            %end;
            %if (&syserr gt 4) %then
            %do;
              %* Check failed - SAS error  *;

              * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
              options nosyntaxcheck obs=max replace;

              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=Proc sort failed;
              %let _cst_MsgParm2=;
              %let _cstactual=%str(Subjectkeys=&_cstSubjectColumns,Column=&_cstColumn);
              %let _cstSrcData=&_cstDSName;
              %let _cstResultFlag=-1;
              %let _cstexit_loop=1;
              %goto exit_colloop;
            %end;

            %if %sysfunc(exist(work._cstdups)) %then
            %do;
              data _null_;
                if 0 then set work._cstdups nobs=_numobs;
                call symputx('_cstDataRecords',_numobs);
                stop;
              run;

              %if &_cstDataRecords %then
              %do;
                %* Create a temporary results data set. *;
                data _null_;
                  attrib _csttemp label="Text string field for file names"  format=$char12.;
                  _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
                  call symputx('_csttempds',_csttemp);
                run;

                %* Write multiple records to the results data set for the domain in error *;
                data &_csttempds (label='Work error data set');
                  %cstutil_resultsdskeep;
                  set work._cstdups end=last;
                    by &_cstSubjectColumns;

                    attrib
                      _cstSeqNo format=8. label="Sequence counter for result column"
                      _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
                      _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
                      _cstDetails format=$char200. label="Message details"
                      _cstLastKeyValues format=$char2000. label="Last keyvalues"
                    ;

                    retain _cstSeqNo 0 ;
                    if _n_=1 then _cstSeqNo=&_cstSeqCnt;

                    keep _cstMsgParm1 _cstMsgParm2;

                    * Set results data set attributes *;
                    %cstutil_resultsdsattr;
                    retain message resultseverity resultdetails '';
                    retain _cstDetails _cstLastKeyValues;

                    resultid="&_cstCheckID";
                    _cstMsgParm1='';
                    _cstMsgParm2='';
                    resultseq=&_cstResultSeq;
                    resultflag=1;
                    srcdata = "&_cstDSName";
                    _cst_rc=0;
                    actual = cats("&_cstColumn","=",&_cstColumn);

                    * Calculate keyvalues column.  *;
                    %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));
                    %do _currentKey = 1 %to &_cstSubCnt;
                      %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys,&_currentKey,' '));
                      if vtype(&_cstKey)='C' then
                      do;
                        if keyvalues='' then
                          keyvalues = cats("&_cstKey","=",&_cstKey);
                        else
                          keyvalues = cats(keyvalues,",","&_cstKey","=",&_cstKey);
                      end;
                      else
                      do;
                        if keyvalues='' then
                          keyvalues = cats("&_cstKey","=",put(&_cstKey,8.));
                        else
                          keyvalues = cats(keyvalues,",","&_cstKey","=",put(&_cstKey,8.));
                      end;
                    %end;

                    _cstDetails=actual;
                    _cstLastKeyValues=keyvalues;

                    _cstSeqNo+1;
                    seqno=_cstSeqNo;

                    checkid="&_cstCheckID";

                    if last then
                    do;
                      call symputx('_cstSeqCnt',_cstSeqNo);
                      call symputx('_cstLastError',cats('%nrstr( ','Last invalid result:',_cstDetails,' )'));
                      call symputx('_cstLastErrorKeys',cats('%nrstr( ',_cstLastKeyValues,' )'));
                    end;
                run;
                %if (&syserr gt 4) %then
                %do;
                  %* Check failed - SAS error  *;

                  * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
                  options nosyntaxcheck obs=max replace;

                  %let _cst_MsgID=CST0050;
                  %let _cst_MsgParm1=Duplicate record reporting step failed;
                  %let _cst_MsgParm2=;
                  %let _cstactual=%str(keys=&_cstDSKeys);
                  %let _cstSrcData=&_cstDSName;
                  %let _cstResultFlag=-1;
                  %let _cstexit_loop=1;
                  %goto exit_colloop;
                %end;

                %* Write only one record to the results data set for the domain in error *;
                %if %upcase(&_cstReportAll)=N %then
                %do;

                  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
                  %cstutil_writeresult(
                       _cstResultID=&_cstCheckID
                      ,_cstValCheckID=&_cstCheckID
                      ,_cstResultParm1=
                      ,_cstResultParm2=
                      ,_cstResultSeqParm=&_cstResultSeq
                      ,_cstSeqNoParm=&_cstSeqCnt
                      ,_cstSrcDataParm=&_cstDSName
                      ,_cstResultFlagParm=1
                      ,_cstActualParm=%str(&_cstLastError)
                      ,_cstKeyValuesParm=%str(&_cstLastErrorKeys)
                      ,_cstResultDetails=%str(All results may not be reported because reportAll=N)
                      ,_cstResultsDSParm=&_cstResultsDS
                  );

                  %let _cstexit_loop=0;
                  %goto exit_colloop;
                %end;
                %else
                %do;

                  %* Parameters passed are check-level -- not record-level -- values *;
                  %cstutil_appendresultds(
                                       _cstErrorDS=&_csttempds
                                      ,_cstVersion=&_cstStandardVersion
                                      ,_cstSource=&_cstCheckSource
                                      ,_cstStdRef=&_cstStandardRef
                                      );
                %end;

                %if %sysfunc(exist(&_csttempds)) %then
                %do;
                  proc datasets lib=work nolist;
                    delete &_csttempds;
                  quit;
                %end;

              %end;  %* %if _cstDataRecords loop  ;
              %else
              %do;
                %* No errors detected for _cstDSName  *;
                %let _cst_MsgID=CST0100;
                %let _cst_MsgParm1=&_cstDSName;
                %let _cst_MsgParm2=;
                %let _cst_rc=0;
                %let _cstSrcData=&_cstDSName;
                %let _cstResultFlag=0;
                %let _cstactual=%str(Subjectkeys=&_cstSubjectColumns,Column=&_cstColumn);
                %let _cstexit_loop=1;
              %end;

            %end;  %* %if %sysfunc(exist(work._cstdups)) loop  ;
            %else
            %do;
              %* Check not run - work._cstdups could not be found  *;
              %let _cst_MsgID=CST0003;
              %let _cst_MsgParm1=work._cstdups;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstSrcData=&_cstDSName;
              %let _cstResultFlag=-1;
              %let _cstactual=;
              %let _cstexit_loop=1;
            %end;

            * Write applicable metrics *;
            %if &_cstMetrics %then %do;

              %if &_cstMetricsNumRecs %then
                %cstutil_writemetric(
                              _cstMetricParameter=# of records tested
                             ,_cstResultID=&_cstCheckID
                             ,_cstResultSeqParm=&_cstResultSeq
                             ,_cstMetricCnt=&_cstMetricsCntNumRecs
                             ,_cstSrcDataParm=&_cstDSName
                            );
            %end;

          %end;  %* j=1 to colCnt loop;
        %end;  %* %if %sysfunc(exist(_cstDSName)) loop;
        %else
        %do;
          %* Check not run - &_cstDSName could not be found  *;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstSrcData=&sysmacroname;
          %let _cstResultFlag=1;
          %let _cstactual=;
          %let _cstexit_loop=1;
        %end;

%exit_colloop:

        %if %sysfunc(exist(work._cstdups)) %then
        %do;
          proc datasets lib=work nolist;
            delete _cstdups;
          quit;
        %end;
        %if %symexist(_cstDomainOnly) %then
        %do;
          %if %sysfunc(exist(&_cstDomainOnly)) %then
          %do;
            proc datasets lib=work nolist;
              delete &_cstDomainOnly;
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

      %end; %* %do i=1 %to _cstDomCnt loop;
    %end;  %* single column loop  ;

    %***********************************************************************;
    %*  Function 3:  Does a combination of 2 columns have unique values?   *;
    %*  Function 4:  Are the values in one column (Column2) consistent     *;
    %*     within each value of another column (Column1)?                  *;
    %*                                                                     *;
    %*  Multiple sublists (e.g. [**TEST][**TESTCD] have been specified     *;
    %***********************************************************************;

    %else %if &_cstColumnSublistCnt>1 %then
    %do;

      %if &_cstColumnSublistCnt>2 %then
      %do;
        %* Problems with tableScope  *;
        %let _cst_MsgID=CST0099;
        %let _cst_MsgParm1=More than two sublists;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      proc sql noprint;
        create table work._cstsublists (label="Joined sublist work file") as
        select sub1.sasref,
               sub1.table,
               kstrip(sub1.sasref) || '.' || kstrip(sub1.table) as _cstDSName1,
               sub1.column as _cstColumn1,
               _cstSubOrder1,
               kstrip(sub2.sasref) || '.' || kstrip(sub2.table) as _cstDSName2,
               sub2.column as _cstColumn2,
               _cstSubOrder2,
               coalesce(sub1._cstSubOrder1,sub2._cstSubOrder2) as suborder
        from work._cstcolumnmetadata (rename=(suborder=_cstSubOrder1) where=(sublist=1)) sub1
                full join
             work._cstcolumnmetadata (rename=(suborder=_cstSubOrder2) where=(sublist=2)) sub2
                on sub1._cstSubOrder1 = sub2._cstSubOrder2 ;
        select count(*) into :_cstSubCnt1 from work._cstsublists (where=(_cstSubOrder1 ne .));
        select count(*) into :_cstSubCnt2 from work._cstsublists (where=(_cstSubOrder2 ne .));
      quit;
      %if (&sqlrc gt 0) %then
      %do;
            %* Check failed - SAS error  *;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Proc SQL sublist derivation from work._cstcolumnmetadata;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstexit_error=1;
            %goto exit_error;
      %end;

      %if &_cstSubCnt1 ne &_cstSubCnt2 %then
      %do;
        %* Problems with columnScope  *;
        %let _cst_MsgID=CST0023;
        %let _cst_MsgParm1=columnScope;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstactual=%str(Sublist1=&_cstSubCnt1,Sublist2=&_cstSubCnt2);
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      %do i=1 %to &_cstSubCnt1;
        %let _cst_rc=0;

        data _null_;
          set work._cstsublists (firstObs=&i);
            call symputx('_cstDSName',_cstDSName1);
            call symputx('_cstDSName1',_cstDSName1);
            call symputx('_cstDSName2',_cstDSName2);
            call symputx('_cstColumn1',_cstColumn1);
            call symputx('_cstColumn2',_cstColumn2);
            call symputx('_cstRefOnly',sasref);
            if exist(table) then
            do;
              call symputx('_cstDomainOnly',cats('_',table));
              call symputx('_cstResetDomainName','1');
            end;
            else
              call symputx('_cstDomainOnly',table);
          stop;
        run;

        %if %upcase(&_cstDSName1) ne %upcase(&_cstDSName2) %then
        %do;
          %* Problems with columnScope  *;
          %let _cst_MsgID=CST0023;
          %let _cst_MsgParm1=columnScope;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstactual=%str(DSName1=&_cstDSName1,DSName2=&_cstDSName2);
          %let _cstexit_loop=1;
          %goto exit_subloop;
        %end;

        %if %sysfunc(exist(&_cstDSName)) %then
        %do;
          %if &_cstMetrics %then
          %do;
            %if &_cstMetricsNumRecs %then
            %do;
              * Set metrics record count to # records in domain *;
              data _null_;
                if 0 then set &_cstDSName nobs=_numobs;
                call symputx('_cstMetricsCntNumRecs',_numobs);
                stop;
              run;
            %end;
            %if &_cstMetricsNumSubj %then
            %do;
              %cstutil_getsubjectcount(_cstDS=&_cstDSName,_cstsubid=&_cstSubjectColumns);
            %end;
          %end;

          data _null_;

          %if &_cstResetDomainName %then
          %do;
            set work._csttablemetadata (keep=sasref table keys where=(upcase(sasref)=upcase("&_cstRefOnly") and
                            upcase(table)=upcase(substr("&_cstDomainOnly",2))));
          %end;
          %else
          %do;
            set work._csttablemetadata (keep=sasref table keys where=(upcase(sasref)=upcase("&_cstRefOnly") and
                            upcase(table)=upcase("&_cstDomainOnly")));
          %end;

              call symputx('_cstDSKeys',keys);
              call symputx('_cstKeyCnt',countw(keys,' '));
            stop;
          run;

          %* Note _cstSQLKeys will exclude the target columns ;
          %let _cstSQLKeys=;
          %if &_cstKeyCnt > 0 %then
          %do;
            %do scnt=1 %to &_cstKeyCnt;
              %let _cstColumn = %SYSFUNC(kscan(&_cstDSKeys,&scnt,' '));
              %if %upcase(&_cstColumn) ne %upcase(&_cstColumn1) and %upcase(&_cstColumn) ne %upcase(&_cstColumn2) %then
              %do;
                %if &_cstSQLKeys= %then
                  %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstColumn));
                %else
                  %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstSQLKeys,&_cstColumn));
              %end;
            %end;
          %end;

          *******************************************************************;
          * Now we can finally start actual processing of source data set,  *;
          *  comparing column values.                                       *;
          *******************************************************************;

          %let _col1Cnt=0;
          %let _col2Cnt=0;
          %let _uniqueCnt=0;
          proc sql noprint;
            create table work._cstunique as
            select distinct &_cstColumn1, &_cstColumn2, 0 as _checkError
              from &_cstDSName (keep=&_cstColumn1 &_cstColumn2)
              where missing(&_cstColumn1)=0 and missing(&_cstColumn2)=0
              order by &_cstColumn1, &_cstColumn2;
            select count(distinct &_cstColumn1) into :_col1Cnt
              from work._cstunique;
            select count(distinct &_cstColumn2) into :_col2Cnt
              from work._cstunique;
            select count(*) into :_uniqueCnt
              from work._cstunique;
          quit;
          %if (&sqlrc gt 0) %then
          %do;
            %* Check failed - SAS error  *;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Proc SQL derivation of work._cstunique;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstexit_error=1;
            %goto exit_subloop;
          %end;

          %if %length(&_cstCodeLogic)=0 %then
          %do;

            %***********************************************************************;
            %*  Function 3:  Does a combination of 2 columns have unique values?   *;
            %***********************************************************************;

            data work._cstunique;
              set work._cstunique;
                by &_cstColumn1 &_cstColumn2;
              if first.&_cstColumn1=0 or last.&_cstColumn1=0 then
                _checkError=1;
            run;
            %if (&syserr gt 4) %then
            %do;
              %* Check failed - SAS error  *;

              * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
              options nosyntaxcheck obs=max replace;

              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=Data step derivation of work._cstunique;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
              %let _cstexit_error=1;
              %goto exit_subloop;
            %end;

            proc sort data=work._cstunique;
              by &_cstColumn2 &_cstColumn1;
            run;
            data work._cstunique;
              set work._cstunique;
                by &_cstColumn2 &_cstColumn1;
              if first.&_cstColumn2=0 or last.&_cstColumn2=0 then
                _checkError=1;
            run;
            %if (&syserr gt 4) %then
            %do;
              %* Check failed - SAS error  *;

              * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
              options nosyntaxcheck obs=max replace;

              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=Data step derivation of work._cstunique;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
              %let _cstexit_error=1;
              %goto exit_subloop;
            %end;

            proc sql noprint;
              create table work._cstuniqueerrors as
              select &_cstSQLKeys, ds1.&_cstColumn1, ds1.&_cstColumn2, _checkError
                from &_cstDSName ds1
                     left join
                   work._cstunique ds2
                on ds1.&_cstColumn1 = ds2.&_cstColumn1 and ds1.&_cstColumn2 = ds2.&_cstColumn2
                where _checkError=1;
            quit;
            %if (&sqlrc gt 0) %then
            %do;
              %* Check failed - SAS error  *;
              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=Proc SQL derivation of work._cstuniqueerrors;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
              %let _cstexit_error=1;
              %goto exit_error;
            %end;

          %end;  %* end length(&_cstCodeLogic)=0 loop ;
          %else
          %do;

            %***********************************************************************;
            %*  Function 4:  Are the values in one column (Column2) consistent     *;
            %*     within each value of another column (Column1)?                  *;
            %***********************************************************************;

            * Create a temporary work data set available to codeLogic. *;
            data _null_;
              attrib _csttemp label="Text string field for file names"  format=$char12.;
              _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
              call symputx('_cstclds',_csttemp);
            run;

            &_cstCodeLogic;

            %if %sysfunc(exist(work.&_cstclds)) %then
            %do;
              proc datasets lib=work nolist;
                delete &_cstclds;
              quit;
            %end;

            %if %sysfunc(exist(&_cstDomainOnly)) %then
            %do;
              proc datasets lib=work nolist;
                delete &_cstDomainOnly;
              quit;
            %end;

            %if ^%sysfunc(exist(work._cstuniqueerrors)) %then
            %do;
              %* Check failed - SAS error  *;

              * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
              options nosyntaxcheck obs=max replace;

              %let _cst_MsgID=CST0050;
              %let _cst_MsgParm1=Codelogic derivation of work._cstuniqueerrors;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
              %let _cstexit_error=1;
              %goto exit_subloop;
            %end;
          %end;  %* end length(&_cstCodeLogic)>0 loop ;

          * Create a temporary results data set. *;
          data _null_;
            attrib _csttemp label="Text string field for file names"  format=$char12.;
            _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
            call symputx('_csttempds',_csttemp);
          run;

          * Add the record to the temporary results data set. *;
          data &_csttempds (label='Work error data set');
            %cstutil_resultsdskeep;
               set work._cstuniqueerrors (keep=&_cstDSKeys &_cstColumn1 &_cstColumn2 _checkError &_cstReportingColumns) end=last;

                attrib
                  _cstSeqNo format=8. label="Sequence counter for result column"
                  _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
                  _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
                  _cstDetails format=$char200. label="Message details"
                  _cstLastKeyValues format=$char2000. label="Last keyvalues"
                ;

                retain _cstSeqNo 0;
                if _n_=1 then _cstSeqNo=&_cstSeqCnt;

                keep _cstMsgParm1 _cstMsgParm2;

                * Set results data set attributes *;
                %cstutil_resultsdsattr;
                retain message resultseverity resultdetails '';
                retain _cstDetails _cstLastKeyValues;

                if _checkError=1 then
                do;
                  resultid="&_cstCheckID";
                  _cstMsgParm1='';
                  _cstMsgParm2='';
                  resultseq=&_cstResultSeq;
                  resultflag=1;
                  srcdata = "&_cstDSName";
                  _cst_rc=0;

                  * Calculate keyvalues column.  *;
                  %let _cstSubCnt=%SYSFUNC(countw(&_cstDSKeys,' '));
                  %do _currentKey = 1 %to &_cstSubCnt;
                    %let _cstKey=%SYSFUNC(kscan(&_cstDSKeys,&_currentKey,' '));
                    if vtype(&_cstKey)='C' then
                    do;
                      if keyvalues='' then
                        keyvalues = cats("&_cstKey","=",&_cstKey);
                      else
                        keyvalues = cats(keyvalues,",","&_cstKey","=",&_cstKey);
                    end;
                    else
                    do;
                      if keyvalues='' then
                        keyvalues = cats("&_cstKey","=",put(&_cstKey,8.));
                      else
                        keyvalues = cats(keyvalues,",","&_cstKey","=",put(&_cstKey,8.));
                    end;
                  %end;

                  * Calculate actual column.  *;
                  %if &_cstReportingColumns = %str() %then
                  %do;
                    actual = cats("&_cstColumn1","=",&_cstColumn1,",","&_cstColumn2","=",&_cstColumn2);
                  %end;
                  %else
                  %do;
                    actual = cats("&_cstColumn1","=",&_cstColumn1,",","&_cstColumn2","=",&_cstColumn2);
                    %let _cstSubCnt=%SYSFUNC(countw(&_cstReportingColumns,' '));
                    %do _currentCol = 1 %to &_cstSubCnt;
                      %let _cstRptCol=%SYSFUNC(kscan(&_cstReportingColumns,&_currentCol,' '));
                      if vtype(&_cstRptCol)='C' then
                      do;
                        if actual='' then
                          actual = cats("&_cstRptCol","=",&_cstRptCol);
                        else
                          actual = cats(actual,",","&_cstRptCol","=",&_cstRptCol);
                      end;
                      else
                      do;
                        if actual='' then
                          actual = cats("&_cstRptCol","=",put(&_cstRptCol,8.));
                        else
                          actual = cats(actual,",","&_cstRptCol","=",put(&_cstRptCol,8.));
                      end;
                    %end;
                  %end;

                  _cstDetails=actual;
                  _cstLastKeyValues=keyvalues;

                  _cstSeqNo+1;
                  seqno=_cstSeqNo;

                  checkid="&_cstCheckID";

                  output;
                end;

              if last then
              do;
                call symputx('_cstSeqCnt',_cstSeqNo);
                call symputx('_cstLastError',cats('%nrstr( ','Last invalid result:',_cstDetails,' )'));
                call symputx('_cstLastErrorKeys',cats('%nrstr( ',_cstLastKeyValues,' )'));
              end;
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
            %let _cstexit_error=1;
            %goto exit_error;
          %end;

          %* Write applicable metrics *;
          %if &_cstMetrics %then %do;

            %if &_cstMetricsNumSubj %then
              %cstutil_writemetric(
                              _cstMetricParameter=# of subjects
                             ,_cstResultID=&_cstCheckID
                             ,_cstResultSeqParm=&_cstResultSeq
                             ,_cstMetricCnt=&_cstMetricsCntNumSubj
                             ,_cstSrcDataParm=&_cstDSName
                            );
            %if &_cstMetricsNumRecs %then
              %cstutil_writemetric(
                              _cstMetricParameter=# of records tested
                             ,_cstResultID=&_cstCheckID
                             ,_cstResultSeqParm=&_cstResultSeq
                             ,_cstMetricCnt=&_cstMetricsCntNumRecs
                             ,_cstSrcDataParm=&_cstDSName
                            );
          %end;

        %end;  %* ends if _cstDSName exists loop ;
        %else
        %do;
          %* Check not run - source data set could not be found  *;
          %let _cst_MsgID=CST0003;
          %let _cst_MsgParm1=&_cstDSName;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstSrcData=&sysmacroname;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstCheckID
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
          %let _cstexit_error=0;
        %end;

        %if %length(&_csttempds)>0 %then
        %do;
          %let _cstErrorRecords=0;
          data _null_;
            if 0 then set &_csttempds nobs=_numobs;
            if _numobs > 0 then
            call symputx('_cstErrorRecords',_numobs);
            stop;
          run;

          %if &_cstErrorRecords %then
          %do;
            %* Write only one record to the results data set for the domain in error *;
            %if %upcase(&_cstReportAll)=N %then
            %do;

              %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
              %cstutil_writeresult(
                     _cstResultID=&_cstCheckID
                    ,_cstValCheckID=&_cstCheckID
                    ,_cstResultParm1=
                    ,_cstResultParm2=
                    ,_cstResultSeqParm=&_cstResultSeq
                    ,_cstSeqNoParm=&_cstSeqCnt
                    ,_cstSrcDataParm=&_cstDSName
                    ,_cstResultFlagParm=1
                    ,_cstActualParm=%str(&_cstLastError)
                    ,_cstKeyValuesParm=%str(&_cstLastErrorKeys)
                    ,_cstResultDetails=%str(All results may not be reported because reportAll=N)
                    ,_cstResultsDSParm=&_cstResultsDS
              );

              %let _cstexit_loop=0;
              %goto exit_subloop;
            %end;
            %else
            %do;
              %* Parameters passed are check-level -- not record-level -- values *;
              %cstutil_appendresultds(
                               _cstErrorDS=&_csttempds
                              ,_cstVersion=&_cstStandardVersion
                              ,_cstSource=&_cstCheckSource
                              ,_cstStdRef=&_cstStandardRef
                              );
            %end;

          %end;
          %else
          %do;
            %* No errors detected in source data set  *;
            %let _cst_MsgID=CST0100;
            %let _cst_MsgParm1=&_cstDSName;
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
                         ,_cstSrcDataParm=&_cstDSName
                         ,_cstResultFlagParm=0
                         ,_cstRCParm=&_cst_rc
                         ,_cstActualParm=
                         ,_cstKeyValuesParm=
                         ,_cstResultsDSParm=&_cstResultsDS
                         );
            %let _cstexit_error=0;
          %end;

        %end;  %* end if _csttempds (errors) exist loop ;

%exit_subloop:

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

        %if &_cstDebug=0 %then
        %do;
          %if %symexist(_csttempds) %then
          %do;
            %if %length(&_csttempds)>0 %then
            %do;
               %if %sysfunc(exist(work._cstunique)) %then
               %do;
                 proc datasets lib=work nolist;
                   delete &_csttempds;
                 quit;
                %end;
            %end;
          %end;
          %if %sysfunc(exist(work._cstunique)) %then
          %do;
            proc datasets lib=work nolist;
              delete _cstUnique;
            quit;
          %end;
          %if %sysfunc(exist(work._cstuniqueerrors)) %then
          %do;
            proc datasets lib=work nolist;
              delete _cstUniqueErrors;
            quit;
          %end;
        %end;

      %end;  %* end do i=1 to _cstSubCnt1 (processing sublist) loop  ;

      %if %sysfunc(exist(work._cstsublists)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstsublists;
        quit;
      %end;

    %end;  %* end %if &_cstColumnSublistCnt>1 loop *;
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
    %if %sysfunc(exist(work._cstcolumnmetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstcolumnmetadata;
      quit;
    %end;
    %if %sysfunc(exist(work._csttablemetadata)) %then
    %do;
      proc datasets lib=work nolist;
        delete _csttablemetadata;
      quit;
    %end;
  %end;
  %else
  %do;
    %put <<< cstcheck_notunique;
  %end;

%mend cstcheck_notunique;
