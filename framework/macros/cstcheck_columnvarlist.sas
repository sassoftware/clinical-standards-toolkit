%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_columnvarlist                                                         *;
%*                                                                                *;
%* Compares columns within the same data set or across multiple data sets.        *;
%*                                                                                *;
%* NOTE: As a general rule, this macro expects a check metadata columnScope       *;
%*       syntax of {_cstList:var1+var2+var3...varn} for within-data-set           *;
%*       assessments and {_cstList:var1...varn}{_cstList:var1...varn} for         *;
%*       multi-data-set assessments.                                              *;
%*                                                                                *;
%* NOTE: This macro requires use of _cstCodeLogic at a DATA step level (for       *;
%*       example, a full DATA step or PROC SQL invocation). _cstCodeLogic creates *;
%*       a Work file (_cstproblems) that contains the records in error.           *;
%*       _cstCodeLogic MUST handle any data set joins when multiple data sets are *;
%*       involved in the column comparisons.                                      *;
%*                                                                                *;
%* Example validation checks that use this macro:                                 *;
%*    ADAM0152 - (for BDS data sets) BASE is populated and BASE is not equal to   *;
%*       AVAL where ABLFL is equal to "Y" for a given value of PARAM and BASETYPE *;
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
%* @history 2016-03-18 Added file presence conditional checking (1.6.1 and 1.7.1) *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_columnvarlist(_cstControl=)
    / des='CST: Column varlist processing';

  %local
    _csttempds

    _cstColCnt
    _cstDomainOnly
    _cstDSName
    _cstDSKeys
    _cstFoundByPass
    _cstKey
    _cstDataRecords

    _cstCheckID
    _cstStandardVersion
    _cstCheckSource
    _cstCodeLogic
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstStandardRef
    _cstReportingColumns
    _cstReportAll

    _cstSubDSList
    _cstSubVarList
    _cstBypassExist
    _cstRptLevel
    _cstResultReported

    _cstexit_error
    _cstexit_loop

    _cstVarlistCnt
    _cstSubVarDriver
    _cstSubVarDriverCnt
    _cstDriverDSList
    _cstDriverSubDSList
    _cstSubVarWC
    _cstSubVarDriver1Pre
    _cstSubVarDriver1Suf
    _cstSubVarDriver1WCType
    _cstSubVarDriver1WCCnt
    _cstSubVarDriver2Pre
    _cstSubVarDriver2Suf
    _cstSubVarDriver2WCType
    _cstSubVarDriver2WCCnt
    _cstTCnt
    _cstDriverCol1
    _cstPairList1
    _cstPairList2

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
      put "reportingColumns=&_cstReportingColumns";
      put "reportAll=&_cstReportAll";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;

  %if %length(%superq(_cstCodeLogic))=0 %then
  %do;
    %* Required parameter not found  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=Codelogic must be specified;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if %length(&_cstColumnScope)=0 %then
  %do;

    %* Required parameter not found  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=ColumnScope must be specified;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %let _cstVarlistCnt=0;
  %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstDomSubOverride=Y,_cstColSubOverride=Y);
  %if &_cst_rc  or ^%sysfunc(exist(work._cstcolumnmetadata))  or ^%sysfunc(exist(work._csttablemetadata)) %then
  %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&_cstSrcData;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  data _null_;
    if 0 then set work._cstcolumnmetadata nobs=_numobs;
    call symputx('_cstColCnt',_numobs);
    stop;
  run;

  %* If parsing of tablescope and columnscope fail to return any referenceable columns,   *;
  %*  that will be reported now.  Later checks evaluate whether expected columns required *;
  %*  by each check can be found.                                                         *;
  %if &_cstColCnt=0 %then
  %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&_cstSrcData;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  %if &_cstVarlistCnt>2 %then
  %do;
      %let _cst_MsgID=CST0099;
      %let _cst_MsgParm1=More than two sublists;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&_cstSrcData;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  %let _cstSubVarDriverCnt=0;
  %let _cstSubVarWC=0;

  %* Define all local list macro variables we will need for the remainder of this module *;
  %do _sub_=1 %to &_cstVarlistCnt;
    proc sql noprint;
      select max(tsublist) into :_cstDSSublListCnt from work._cstalltablemetadata;
    quit;
    %if &_cstDSSublListCnt=1 %then
    %do;
      proc sql noprint;
        select max(tsublist) into :_cstDSSublListCnt from work._cstalltablemetadata;
        select distinct(catx('.',sasref,table)) into :_cstSubDSList  separated by ' '
        from work._cstalltablemetadata (where=(tsublist=&_cstDSSublListCnt));
        create table work._csttemp as
        select distinct column, varorder from (
        select col.sasref, col.table, col.column, col.sublist, col.varorder
        from work._cstalltablemetadata (keep=sasref table tsublist where=(tsublist=&_cstDSSublListCnt)) tab
          left join
         work._cstcolumnmetadata (where=(sublist=&_sub_)) col
        on col.sasref=tab.sasref and col.table=tab.table
        where col.sublist=&_sub_)
        order by varorder;
      quit;
    %end;
    %else
    %do;
      proc sql noprint;
        select max(tsublist) into :_cstDSSublListCnt from work._cstalltablemetadata;
        select distinct(catx('.',sasref,table)) into :_cstSubDSList  separated by ' '
        from work._cstalltablemetadata (where=(tsublist=&_sub_));
        create table work._csttemp as
        select distinct column, varorder from (
        select col.sasref, col.table, col.column, col.sublist, col.varorder
        from work._cstalltablemetadata (keep=sasref table tsublist where=(tsublist=&_sub_)) tab
          left join
         work._cstcolumnmetadata (where=(sublist=&_sub_)) col
        on col.sasref=tab.sasref and col.table=tab.table and col.sublist=tab.tsublist
        where col.sublist=&_sub_)
        order by varorder;
      quit;
    %end;
    %if (&sqlrc gt 0) %then
    %do;
      %* Check failed - SAS error  *;
      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=Proc SQL sublist derivation from work._cstcolumnmetadata;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstSrcData=&_cstSrcData;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %let _cstColCnt=0;
    data _null_;
      if 0 then set work._csttemp nobs=_numobs;
      call symputx('_cstColCnt',_numobs);
      stop;
    run;

    %if &_cstColCnt=0 %then
    %do;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstSrcData=&_cstSrcData;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %* _cstCSList is used to document the wildcarding used in columnScope, as well as    *;
    %*  to establish the minimum number of columns expected.                             *;
    %let _cstCSList = %upcase(%scan(&_cstColumnScope, &_sub_ , "}"));
    %let _cstCSList=%sysfunc(kcompress(%sysfunc(tranwrd(%sysfunc(ktrim(&_cstCSList)),%str(_CSTLIST:),%str()))));
    %let _cstCSList=%sysfunc(tranwrd(%sysfunc(ktrim(&_cstCSList)),%str({),%str()));

    %* Save the first list information for later use in sub-looping below *;
    %if &_cstVarlistCnt>1 %then
    %do;
      %if &_sub_=1 %then
      %do;
        data _null_;
          set work._csttemp end=last;
            attrib tempvar format=$500.;
            retain tempvar;
          tempvar = catx(' ',tempvar,column);
          if last then
          do;
            call symputx('_cstSubVarDriver',tempvar);
            call symputx('_cstSubVarDriverCnt',_n_);
            tempvar=symget('_cstCSList');

            do i = 1 to countw(tempvar,'+-');
              col=kscan(tempvar,i,'+-');
              wcIndex=kindexc(col,'#*');
              if wcIndex then
              do;
                call symputx("_cstSubVarDriver&_sub_.WCCnt",min(countc(col,'#*'),2));
                wcIndex=kindex(col,'##');
                if wcIndex then
                do;
                  call symputx("_cstSubVarDriver&_sub_.WCType",'POUND');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<(klength(col)-1) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+2));
                end;
                else if kindex(col,'#') then
                do;
                  wcIndex=kindex(col,'#');
                  call symputx("_cstSubVarDriver&_sub_.WCType",'POUND');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<klength(col) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+1));
                end;
                else if kindex(col,'**') then
                do;
                  wcIndex=kindex(col,'**');
                  call symputx("_cstSubVarDriver&_sub_.WCType",'ASTERISK');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<(klength(col)-1) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+2));
                end;
                leave;
              end;
            end;
          end;
        run;
      %end;
      %else
      %do;
        %if %sysfunc(kindexc(&_cstCSList,'#*')) %then
          %let _cstSubVarWC=1;

        data _null_;
          set work._csttemp end=last;
            attrib tempvar format=$500.;
            retain tempvar;
          tempvar = catx(' ',tempvar,column);
          if last then
          do;
            tempvar=symget('_cstCSList');

            do i = 1 to countw(tempvar,'+-');
              col=kscan(tempvar,i,'+-');
              wcIndex=kindexc(col,'#*');
              if wcIndex then
              do;
                call symputx("_cstSubVarDriver&_sub_.WCCnt",min(countc(col,'#*'),2));
                wcIndex=kindexc(col,'##');
                if wcIndex then
                do;
                  call symputx("_cstSubVarDriver&_sub_.WCType",'POUND');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<(klength(col)-1) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+2));
                end;
                else if kindexc(col,'#') then
                do;
                  wcIndex=kindexc(col,'#');
                  call symputx("_cstSubVarDriver&_sub_.WCType",'POUND');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<klength(col) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+1));
                end;
                else if kindexc(col,'**') then
                do;
                  wcIndex=kindexc(col,'**');
                  call symputx("_cstSubVarDriver&_sub_.WCType",'ASTERISK');
                  if wcIndex>1 then
                    call symputx("_cstSubVarDriver&_sub_.Pre",ksubstr(col,1,wcIndex-1));
                  if wcIndex<(klength(col)-1) then
                    call symputx("_cstSubVarDriver&_sub_.Suf",ksubstr(col,wcIndex+2));
                end;
                leave;
              end;
            end;
          end;
        run;
      %end;
    %end;

    data _null_;
      set work._cstalltablemetadata (where=(tsublist=&_sub_));
        call symputx(cats("_cstSub&_sub_.DS",kstrip(put(_n_,8.))),catx('.',sasref,table));
        call symputx(cats("_cstSub&_sub_.DSKeys",kstrip(put(_n_,8.))),keys);
    run;

    data _null_;
      set work._csttemp end=last;
        attrib cslist format=$500.
               newcolumn  format=$32.
               neworder  format=8.;
        if _n_=1 then
        do;
          declare hash invars(ordered: 'a');
          rc=invars.defineKey('neworder', 'newcolumn');
          rc=invars.defineDone();
          cslist=symget('_cstCSList');
          csvars=countw(cslist,' +');
          do i = 1 to csvars;
            neworder=i;
            newcolumn=kscan(cslist,i,' +');
            * Exclude wildcards  *;
            if kindexc(newcolumn,'#*')=0 then
              rc=invars.add();
          end;
        end;
        newcolumn=column;
        neworder=varorder;
        rc=invars.add();
        if last then
          invars.output (dataset: "work._csttemp2") ;
    run;
    data _null_;
      set work._csttemp2 (rename=(newcolumn=column neworder=varorder)) end=last;
        attrib tempvar format=$500.;
        retain tempvar;
      tempvar = catx(' ',tempvar,column);
      call symputx(cats("_cstSub&_sub_.Col",kstrip(put(_n_,8.))),column);
      if last then
      do;
        call symputx('_cstSubVarList',tempvar);
        call symputx('_cstSubVarListCnt',_n_);
        call symputx("_cstSubVarList&_sub_",tempvar);
        call symputx("_cstSubVarList&_sub_.Cnt",_n_);

        %if &_cstVarlistCnt=1 %then
        %do;
          call symputx('_cstSubVarDriver',tempvar);
          call symputx('_cstSubVarDriverCnt',1);
        %end;

      end;
    run;

    %if &_cstDebug %then
    %do;
      %put _cstSubVarList=&_cstSubVarList;
      %put _cstSubDSList=&_cstSubDSList;
    %end;
    %let _cstDriverSubDSList=&_cstSubDSList;

    %let _cstSubDSListCnt=%SYSFUNC(countw(&_cstSubDSList,' '));
    %**let _cstSubVarListCnt=%SYSFUNC(countw(&_cstSubVarList,' '));

    %****************************************************************************;
    %* This section attempts to confirm data set can be accessed and expected   *;
    %* columns for any given check can be found.  If any problems are found,    *;
    %* the check logic will not be submitted and a Warning: Check not run       *;
    %* message will typically be writen to the results data set.                *;
    %****************************************************************************;

    %do _ds_=1 %to &_cstSubDSListCnt;
      %let _cstDSName=%scan(&_cstSubDSList,&_ds_,' ');

      %let _cstTCnt=0;

      %* Specified data set does not exist  *;
      %if ^%sysfunc(exist(&_cstDSName)) %then
      %do;
        %let _cst_MsgID=CST0016;
        %let _cst_MsgParm1=&_cstDSName;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstSrcData=&_cstSrcData;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
      %else
      %do;
        %let _cstdsid = %sysfunc(open(&_cstDSName, i));
        %* Specified data set cannot be opened *;
        %if &_cstdsid = 0 %then
        %do;
          %let _cstexit_error=1;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %cstutil_writeresult(
                      _cstResultID=CST0111
                     ,_cstValCheckID=&_cstCheckID
                     ,_cstResultParm1=&_cstDSName
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstSeqNoParm=&_cstSeqCnt
                     ,_cstSrcDataParm=&_cstSrcData
                     ,_cstResultFlagParm=-1
                     ,_cstRCParm=0
                     ,_cstResultsDSParm=&_cstResultsDS
                     );
        %end;
        %else %do;

          %let _cstFoundByPass=0;
          data _null_;
            attrib _cstCL format=$2000.;
            _cstCL=symget('_cstCSList');
            if indexw(_cstCL,'_CSTBYPASSEXIST',' =')>0 then
              call symputx('_cstFoundByPass','1');
          run;
          %if &_cstFoundByPass=0 %then
          %do;

            * Initialize a working copy of the column metadata *;
            data work._csttemp3;
              set work._cstcolumnmetadata;
                stop;
            run;

            %* We wont bother if columnScope contains the keyword _ALL_  *;
            %if %sysfunc(indexw(&_cstCSList,'_ALL_','+-')) %then;
            %else %if %length(&_cstCSList)>0 %then
            %do;

              %let _cstTCnt = %SYSFUNC(countw(&_cstCSList,'+-'));
              %do _cstCSCnt_= 1 %to &_cstTCnt;
                %let _cstColumn = %scan(&_cstCSList, &_cstCSCnt_ , "+-");
                %let _cstTString=;
                %cstutil_parsescopesegment(_cstPart=&_cstColumn,_cstVarName=column);
                * Note hardcoding reference to work._cstsrccolumnmetadata with expectation      *;
                * that this operation has meaning only looking through source column metadata.  *;
                data work._csttemp3;
                  set work._csttemp3
                      work._cstsrccolumnmetadata (where=(upcase(sasref)=upcase(scan("&_cstDSName",1,'.')) and
                                      upcase(table)=upcase(scan("&_cstDSName",2,'.')) and &_cstTString));
                run;
              %end;
            %end;

            data _null_;
              if 0 then set work._csttemp3 nobs=_numobs;
                call symputx('_cstFoundVars',_numobs);
                stop;
            run;

            %if &_cstDebug=0 %then
            %do;
              %cstutil_deleteDataSet(_cstDataSetName=work._csttemp3);
            %end;

            %if &_cstFoundVars < &_cstTCnt %then
            %do;
              %* Table &_cstparm1 does not contain &_cstparm2 column(s) *;
              %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
              %let _cstSrcData=&sysmacroname;
              %cstutil_writeresult(
                         _cstResultID=CST0021
                         ,_cstValCheckID=&_cstCheckID
                         ,_cstResultParm1=&_cstDSName
                         ,_cstResultParm2=all &_cstCSList
                         ,_cstResultSeqParm=&_cstResultSeq
                         ,_cstSeqNoParm=&_cstSeqCnt
                         ,_cstSrcDataParm=&_cstSrcData
                         ,_cstResultFlagParm=-1
                         ,_cstRCParm=0
                         ,_cstResultsDSParm=&_cstResultsDS
                         );
              %* Remove data set from subsequent processing *;
              %let _cstDriverSubDSList=%sysfunc(tranwrd(%sysfunc(ktrim(&_cstDriverSubDSList)),%str(&_cstDSName),%str()));
              %let _cstexit_error=1;
            %end;

            %let _cstdsid = %sysfunc(close(&_cstdsid));

          %end;
        %end;
      %end;
    %end;

    %if &_sub_=1 %then
      %let _cstDriverDSList=&_cstDriverSubDSList;

    %if &_cstDebug=0 %then
    %do;
      %cstutil_deleteDataSet(_cstDataSetName=work._csttemp);
      %cstutil_deleteDataSet(_cstDataSetName=work._csttemp2);
      %cstutil_deleteDataSet(_cstDataSetName=work._csttemp3);
    %end;

  %end;

  %if &_cstexit_error %then
    %let _cstResultReported=1;

  %* Cycle through those data sets that remain (those having the targeted columns) *;
  %do _sub_=1 %to %SYSFUNC(countw(&_cstDriverDSList,' '));
    %let _cstexit_error=0;
    %let _cstDSName=%scan(&_cstDriverDSList,&_sub_,' ');
    %let _cstDomainOnly=&_cstDSName;
    %if %eval(%index(&_cstDSName,.)>0) %then %do;
      %let _cstDomainOnly=%scan(&_cstDSName,2,'.');
    %end;

    %if &_cstDebug %then
    %do;
      %put Start of driver sublist processing loop for &_cstDSName ...;
      %put _all_;
    %end;

    data _null_;
      if 0 then set &_cstDSName nobs=_numobs;
      call symputx('_cstMetricsCntNumRecs',_numobs);
      stop;
    run;

    data _null_;
      set work._cstalltablemetadata;
        attrib lib format=$8.
               tab format=$8.;
        lib=kscan("&_cstDSName",1,'.');
        tab=kscan("&_cstDSName",2,'.');
        if sasref=lib and table=tab then
          call symputx('_cstDSKeys',keys);
    run;
    %let _cstResultReported=0;


    %* Loop through columns in the driver (first) list.  If this is not the intended      *;
    %*  flow, and we should test all columns only once per record, then the check         *;
    %*  metadata codelogic should issue the statement: %let _subdv_=&_cstSubVarDriverCnt  *;
    %*  at the bottom of the code segment.                                                *;
    %do _subdv_=1 %to &_cstSubVarDriverCnt;
      %let _cstDriverCol1=%scan(&_cstSubVarDriver,&_subdv_,' ');

        %*************************************************************************;
        %*  _cstCodeLogic must be a self-contained data or proc sql step. The    *;
        %*  expected result is a work._cstproblems data set of records in error. *;
        %*  If there are no errors, the data set should have 0 observations.     *;
        %*                                                                       *;
        %* Macro variables available to codeLogic:                               *;
        %*  _cstSubnDSn       Example: _cstSub1DS1 is the first data set from    *;
        %*                                the first sublist.                     *;
        %*  _cstSubnDSKeysn   Example: keys from CST metadata for _cstSub1DS1    *;
        %*  _cstSubnColn      Example: _cstSub1Col2 is the second column         *;
        %*                                from the first sublist                 *;
        %*  _cstDSName        The current libref.dataset being evaluated         *;
        %*  _cstDomainOnly    The current data set being evaluated               *;
        %*                                                                       *;
        %*************************************************************************;

      data work._cstproblems;
        if _n_=1 then stop;
      run;

      &_cstCodeLogic;

      %if %symexist(sqlrc) %then %do;
        %if (&sqlrc gt 0) %then
        %do;
          %let _cstResultReported=1;
          %* Check failed - SAS error  *;
          %let _cst_MsgID=CST0050;
          %let _cst_MsgParm1=Codelogic processing failed;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;
      %end;
      %if (&syserr gt 4) %then
      %do;
        %* Check failed - SAS error  *;

        * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
        options nosyntaxcheck obs=max replace;

        %let _cstResultReported=1;
        %let _cst_MsgID=CST0050;
        %let _cst_MsgParm1=Codelogic processing failed;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      %if &_cstexit_loop=1 %then
        %goto exit_subloop;

      %let _cstDataRecords=0;

      %if %sysfunc(exist(work._cstproblems)) %then
      %do;
        data _null_;
          if 0 then set work._cstproblems nobs=_numobs;
          call symputx('_cstDataRecords',_numobs);
          stop;
        run;
      %end;

      * One or more errors were found*;
      %if &_cstDataRecords %then
      %do;
        * Create a temporary results data set. *;
        data _null_;
          attrib _csttemp label="Text string field for file names"  format=$char12.;
          _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
          call symputx('_csttempds',_csttemp);
        run;

        * Add the record to the temporary results data set. *;
        data &_csttempds (label='Work error data set');
          %cstutil_resultsdskeep;
            set work._cstproblems end=last;

              attrib
                _cstSeqNo format=8. label="Sequence counter for result column"
                _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
                _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
              ;

              retain _cstSeqNo 0;
              if _n_=1 then _cstSeqNo=&_cstSeqCnt;

              keep _cstMsgParm1 _cstMsgParm2;

              * Set results data set attributes *;
              %cstutil_resultsdsattr;
              retain message resultseverity resultdetails '';

              resultid="&_cstCheckID";
              _cstMsgParm1='';
              _cstMsgParm2='';
              resultseq=&_cstResultSeq;
              resultflag=1;
              srcdata = "&_cstDSName";
              _cst_rc=0;
              keyvalues='';
              actual='';

              %if %upcase(&_cstRptLevel) ne TABLE %then
              %do;
                * Calculate keyvalues column.  *;
                %do _currentKey = 1 %to %SYSFUNC(countw(&_cstDSKeys,' '));
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

                %* The string includes wildcards, so we need to match these up... *;
                %if &_cstSubVarDriver1WCType=POUND %then
                %do;
                  %if %length(&_cstSubVarDriver1WCType)>0 and %length(&_cstSubVarDriver2WCType)>0 %then
                  %do;
                    %let _cstSubVarList=&_cstDriverCol1;
                    %let _cstSubIterator=%SYSFUNC(ksubstr(&_cstSubVarList,%eval(%length(&_cstSubVarDriver1Pre)+1),&_cstSubVarDriver1WCCnt));
                    %let _cstSubVarList=&_cstDriverCol1 &_cstSubVarDriver2Pre.&_cstSubIterator.&_cstSubVarDriver2Suf;
                    %let _cstSubVarListCnt=2;
                  %end;
                  %else
                  %do;
                    %if ^%SYSFUNC(kindex(&_cstSubVarList,"&_cstDriverCol1")) %then
                    %do;
                      %let _cstSubVarList=&_cstDriverCol1 &_cstSubVarList;
                      %let _cstSubVarListCnt=%eval(&_cstSubVarListCnt+1);
                    %end;
                  %end;
                %end;
                %else %if &_cstSubVarDriver1WCType=ASTERISK %then
                %do;
                  %if %length(&_cstSubVarDriver1WCType)>0 and %length(&_cstSubVarDriver2WCType)>0 %then
                  %do;
                    %let _cstSubVarList=&_cstDriverCol1;
                    %let _cstSubIterator=%SYSFUNC(ksubstr(&_cstSubVarList,%eval(%length(&_cstSubVarDriver1Pre)+1),&_cstSubVarDriver1WCCnt));
                    %**let _cstSubVarList=&_cstDriverCol1 &_cstSubVarDriver2Pre.&_cstSubIterator.&_cstSubVarDriver2Suf;
                    %let _cstSubVarList=&_cstDriverCol1 %SYSFUNC(tranwrd(&_cstDriverCol1,&_cstSubVarDriver1Suf,&_cstSubVarDriver2Suf));;
                    %let _cstSubVarListCnt=2;
                  %end;
                  %else
                  %do;
                    %if ^%SYSFUNC(kindex(&_cstSubVarList,"&_cstDriverCol1")) %then
                    %do;
                      %let _cstSubVarList=&_cstDriverCol1 &_cstSubVarList;
                      %let _cstSubVarListCnt=%eval(&_cstSubVarListCnt+1);
                    %end;
                  %end;
                %end;
                %if %length(&_cstReportingColumns)>0 %then
                %do;
                  %do _rc_=1 %to %SYSFUNC(countw(&_cstReportingColumns,' '));
                    %if ^%SYSFUNC(kindex(&_cstSubVarList,%SYSFUNC(kscan(&_cstReportingColumns,&_rc_,' ')))) %then
                    %do;
                      %let _cstSubVarList=&_cstSubVarList %SYSFUNC(kscan(&_cstReportingColumns,&_rc_,' '));
                      %let _cstSubVarListCnt=%eval(&_cstSubVarListCnt+1);
                    %end;
                  %end;
                %end;
                %if &_cstSubVarDriver1WCType=BOTH %then
                %do;
                  actual=_cstColumnPair;
                %end;
                %else
                %do;
                  %do _currentKey = 1 %to &_cstSubVarListCnt;
                    %let _cstKey=%SYSFUNC(kscan(&_cstSubVarList,&_currentKey,' '));
                    if vtype(&_cstKey)='C' then
                    do;
                      if actual='' then
                        actual = cats("&_cstKey","=",&_cstKey);
                      else
                        actual = cats(actual,",","&_cstKey","=",&_cstKey);
                    end;
                    else
                    do;
                      if actual='' then
                        actual = cats("&_cstKey","=",put(&_cstKey,8.));
                      else
                        actual = cats(actual,",","&_cstKey","=",put(&_cstKey,8.));
                    end;
                  %end;
                %end;
              %end;

              _cstSeqNo+1;
              seqno=_cstSeqNo;

              checkid="&_cstCheckID";

          if last then
          do;
            call symputx('_cstSeqCnt',_cstSeqNo);
          end;
        run;
        %if (&syserr gt 4) %then
        %do;
          %* Check failed - SAS error  *;

          * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
          options nosyntaxcheck obs=max replace;

          %let _cstResultReported=1;
          %let _cst_MsgID=CST0050;
          %let _cst_MsgParm1=;
          %let _cst_MsgParm2=;
          %let _cst_rc=0;
          %let _cstResultFlag=-1;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;

        %let _cstResultReported=1;

        %* Write only one record to the results data set for the domain in error *;
        %if %upcase(&_cstReportAll)=N %then
        %do;

          %* Report that we are only reporting a single result  *;
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
                    ,_cstActualParm=
                    ,_cstKeyValuesParm=
                    ,_cstResultDetails=%str(All results may not be reported because reportAll=N)
                    ,_cstResultsDSParm=&_cstResultsDS
          );
          %let _cstexit_loop=1;
          %goto exit_subloop;

        %end;
        %else
        %do;
          %cstutil_appendresultds(
                     _cstErrorDS=&_csttempds
                    ,_cstVersion=&_cstStandardVersion
                    ,_cstSource=&_cstCheckSource
                    ,_cstStdRef=&_cstStandardRef
          );
        %end;

      %end;
      %else %if &_cstDataRecords=0 %then
      %do;
        %let _cstResultReported=1;
        %* No errors detected in source data  *;
        %let _cst_MsgID=CST0100;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_src=%upcase(&_cstDSName);
        %if &_cstRptLevel=COLUMN %then
          %let _cst_src=%upcase(&_cstDSName..&_cstDriverCol1);
        %let _cst_rc=0;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                    _cstResultID=&_cst_MsgID
                    ,_cstValCheckID=&_cstCheckID
                    ,_cstResultParm1=&_cst_MsgParm1
                    ,_cstResultParm2=&_cst_MsgParm2
                    ,_cstResultSeqParm=&_cstResultSeq
                    ,_cstSeqNoParm=&_cstSeqCnt
                    ,_cstSrcDataParm=&_cst_src
                    ,_cstResultFlagParm=0
                    ,_cstRCParm=&_cst_rc
                    ,_cstActualParm=
                    ,_cstKeyValuesParm=
                    ,_cstResultsDSParm=&_cstResultsDS
                    );
      %end;

%exit_subloop:

      %if &_cstDebug=0 %then
      %do;
        %if %symexist(_csttempds) %then
        %do;
          %if %length(&_csttempds)>0 %then
          %do;
            %cstutil_deleteDataSet(_cstDataSetName=&_csttempds);
          %end;
        %end;
        %if %sysfunc(exist(work._cstproblems)) %then
        %do;
          %cstutil_deleteDataSet(_cstDataSetName=work._cstproblems);
        %end;
      %end;

      %if &_subdv_<&_cstSubVarDriverCnt %then
      %do;
        %if %sysfunc(exist(work._cstproblems)) %then
        %do;
          %cstutil_deleteDataSet(_cstDataSetName=work._cstproblems);
        %end;
      %end;

      %if &_cstexit_loop=1 %then
        %let _cstexit_loop=0;

    %end;  %* end of _subdv_ loop  *;

    %if &_cstSubVarDriverCnt=0 %then
    %do;
      %* Report that no columns could be assessed...  *;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                   _cstResultID=CST0004
                   ,_cstValCheckID=&_cstCheckID
                   ,_cstResultParm1=
                   ,_cstResultParm2=
                   ,_cstResultSeqParm=&_cstResultSeq
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=%upcase(&_cstDSName)
                   ,_cstResultFlagParm=-1
                   ,_cstRCParm=0
                   ,_cstActualParm=%str(columnScope=&_cstColumnScope)
                   ,_cstResultsDSParm=&_cstResultsDS
                   );

    %end;
    %else
    %do;
      %if &_cstResultReported<1 %then
      %do;

        %* No errors detected in source data  *;
        %let _cst_MsgID=CST0100;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_src=%upcase(&_cstDSName);
        %let _cst_rc=0;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                   _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cst_src
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
      %end;

      %* Write applicable metrics *;
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
    %end;

  %end;  %* end of driverDS loop  *;

%exit_error:

  %if &_cstexit_error %then
  %do;
    %if &_cstResultReported<1 %then
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

  %end;

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(exist(work._cstcolumnmetadata)) %then
    %do;
      %cstutil_deleteDataSet(_cstDataSetName=work._cstcolumnmetadata);
    %end;
    %if %sysfunc(exist(work._csttablemetadata)) %then
    %do;
      %cstutil_deleteDataSet(_cstDataSetName=work._csttablemetadata);
    %end;
  %end;
  %else
  %do;
    %put <<< cstcheck_columnvarlist;
  %end;

%mend cstcheck_columnvarlist;
