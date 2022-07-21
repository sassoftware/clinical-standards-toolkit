%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheck_notincodelist                                                         *;
%*                                                                                *;
%* Identifies column values inconsistent with controlled terminologies.           *;
%*                                                                                *;
%* An example of an inconsistency is a **STAT value other than 'NOT DONE'.        *;
%*                                                                                *;
%* NOTE:  This macro requires reference to the SAS format search path built       *;
%*        based on type=FMTSEARCH records in the SASReferences control file.      *;
%*                                                                                *;
%* Processing is based on the value of the check metadata LOOKUPTYPE field:       *;
%*                                                                                *;
%* FORMAT:   The code compares column values against a SAS format in the format   *;
%*           search path. codeLogic is optional. (That is, if you do not specify  *;
%*           any codeLogic, cstcheck_notincodelist uses default logic, which is   *;
%*           PROC SQL code that creates work._cstproblems if one or more errors   *;
%*           are detected). The SAS format is specified in the check metadata     *;
%*           LOOKUPSOURCE field.                                                  *;
%*                                                                                *;
%* DATASET:  The code requires the use of codeLogic to create the data set        *;
%*           work._cstproblems. LOOKUPSOURCE must contain the reference data set  *;
%*           (for example, MedDRA for AE preferred term lookups) used in          *;
%*           codeLogic.Given that any reference dictionary with any given         *;
%*           structure can be used, it is incumbent on you to code correct joins  *;
%*           and lookup logic within codeLogic.                                   *;
%*                                                                                *;
%* CODELIST: This functionality is deferred.                                      *;
%*                                                                                *;
%* LOOKUP:   The code compares column values against a standardlookup data set.   *;
%*           CodeLogic is required, and should create work._cstproblems if one    *;
%*           or more errors are detected.                                         *;
%*                                                                                *;
%* METADATA: The code compares column values against a SAS format in the format   *;
%*           search path. codeLogic is optional. (That is, if you do not specify  *;
%*           any codeLogic, cstcheck_notincodelist uses default logic, which is   *;
%*           PROC SQL code that creates work._cstproblems if one or more errors   *;
%*           are detected). The SAS format is specified in the source column      *;
%*           metadata XMLCODELIST field.                                          *;
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
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cstcheck_notincodelist(_cstControl=)
    / des = 'CST: Identify invalid controlled terms';


  %local
    _cstCheckID
    _cstCodeLogic
    _cstexit_error
    _cstexit_loop
    _cstUniqueDomains
    _cstDataRecords
    _cstCatCnt
    _cstBadCatCnt
    _cstCatalog
    _cstXMLCodeList
    _cstFMTValCnt
    _cstSASrefLibs

    _cstLookupType
    _cstLookupSource
    _cstTableScope
    _cstColumnScope
    _cstUseSourceMetadata
    _cstReportingColumns
    _cstStandardVersion
    _cstCheckSource
    _cstStandardRef

    _cstLibCnt
    _cstLibrary
    _cstInitLookupSource
    _cstFoundLookupSource
    _cstDSName
    _cstColumn
    _cstDSRowCt
    _cstDomainOnly
    _cstCol2Value
  ;

  %let _cstexit_error=0;
  %let _cstexit_loop=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstDomCnt=0;
  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;
  %let _cstactual=;

  %*****************************************************************;
  %*  Read Control data set to retrieve information for the check. *;
  %*****************************************************************;

  %cstutil_readcontrol;

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
      put "lookupType=&_cstLookupType";
      put "lookupSource=&_cstLookupSource";
      put "useSourceMetadata=&_cstUseSourceMetadata";
      put "standardref=&_cstStandardRef";
      put "ReportingColumns=&_cstReportingColumns";
      put '****************************************************';
    run;
    options &_cstRestoreQuoteLenMax;
  %end;

  %* Call to cstutil_buildcollist interprets both tableScope and columnScope   *;
  %if %upcase(&_cstLookupType)=METADATA %then
  %do;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver,_cstColWhere=%str(xmlcodelist ne ''));
  %end;
  %else
  %do;
    %cstutil_buildcollist(_cstStd=&_cstrunstd,_cstStdVer=&_cstrunstdver);
  %end;
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
    %* This check requires reference to source metadata  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=USESOURCEMETADATA;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %if %length(&_cstLookupType)=0 %then
  %do;
    %* This check requires a lookupType value  *;
    %let _cst_MsgID=CST0026;
    %let _cst_MsgParm1=a LOOKUPTYPE value is required;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
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

  %let _cstSrcData=&sysmacroname;
  %if &_cstColCnt <= 0 %then
  %do;
    %* No columns evaluated - check validation_master specification  *;
    %let _cst_MsgID=CST0004;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
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
    %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %******************************************;
  %* Begin conditional code...              *;
  %* Which lookup type does the check use?  *;
  %******************************************;

  %if %upcase(&_cstLookupType)=METADATA or %upcase(&_cstLookupType)=FORMAT %then
  %do;

    %let _cst_rc=0;
    data _null_;
      attrib _cstCatalog format=$char17.
             _cstfmts format=$char200.
             _cstCatalogs format=$char200.
             _cstCatCnt format=8.;

      _cstfmts = ktranslate(getoption('FMTSEARCH'),'','()');
      * Example _cstfmts="WORK SDTMFMT.FORMATS CSTFMT.CTERMS" *;

      if _cstfmts='' then
          call symputx('_cst_rc',1);

      _cstCatCnt=0;
      do i = 1 to countw(_cstfmts,' ');
        _cstCatalog=kscan(_cstfmts,i,' ');
        if kindex(_cstCatalog,'.') = 0
          then _cstCatalog = catx('.',_cstCatalog,'FORMATS');
        _cstCatalogs = catx(' ',_cstCatalogs,_cstCatalog);
        _cstCatCnt+1;
      end;

      call symput('_cstCatalogs',_cstCatalogs);
      call symputx('_cstCatCnt',_cstCatCnt);
    run;

    %if &_cst_rc or %length(&_cstCatalogs)=0 %then
    %do;
      %* Format search path has not been set  *;
      %let _cst_MsgID=CST0028;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %let _cstBadCatCnt=0;
    %do i=1 %to &_cstCatCnt;
      %let _cstCatalog=%SYSFUNC(kscan(&_cstCatalogs,&i,' '));
      %if ^%sysfunc(cexist(&_cstCatalog)) %then
      %do;
        %let _cstBadCatCnt=%eval(&_cstBadCatCnt+1);

        %* Format catalog in fmtsearch cannot be found  *;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(
                  _cstResultID=CST0029
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cstCatalog
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );

      %end;
    %end;
    %if &_cstCatCnt=&_cstBadCatCnt %then
    %do;
      %* No catalogs found in fmtsearch  *;
      %let _cst_MsgID=CST0030;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
    %else
    %do;
      %* Format catalog in fmtsearch cannot be found  *;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0033
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cstCatalogs
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

    catname _cstfmts ( &_cstCatalogs ) ;
    %if &_cstDebug %then
    %do;
      catname _cstfmts list ;
    %end;

    %if %upcase(&_cstLookupType)=FORMAT %then
    %do;

      %****************************************************;
      %* Rely on the check metadata column lookupsource   *;
      %* to identify the SAS format of interest.          *;
      %****************************************************;

      %if %length(&_cstLookupSource)=0 %then
      %do;
        %let _cst_MsgID=CST0026;
        %let _cst_MsgParm1=a LOOKUPSOURCE value is required;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      proc format library=work._cstfmts cntlout=work._cstformats (keep=fmtname label rename=(label=_uvlabel));
        select &_cstLookupSource;
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
      %let _cstXMLCodeList=&_cstLookupSource;

      %if ^%sysfunc(exist(work._cstformats)) %then
      %do;
        %*************************************************;
        %*  Check not run - Format data set not created  *;
        %*************************************************;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=WORK._CSTFORMATS;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;

    %***************************;
    %*  Cycle through columns  *;
    %***************************;
    %if &_cstColCnt > 0 %then
    %do;
      %do i=1 %to &_cstColCnt;

        data _null_;
          attrib _csttemp format=$41. label="Temp variable";
          set work._cstcolumnmetadata (keep=sasref table column type xmlcodelist firstObs=&i);
            _csttemp = catx('.',sasref,table);
            call symputx('_cstDSName',kstrip(_csttemp));
            call symputx('_cstRefOnly',sasref);
            call symputx('_cstDomainOnly',table);
            call symputx('_cstColumn',column);
            if type='C' then
              call symputx('_cstXMLCodeList',cats('$',xmlcodelist));
            else
              call symputx('_cstXMLCodeList',xmlcodelist);
          stop;
        run;

        %if %upcase(&_cstLookupType)=METADATA %then
        %do;

          %*******************************************************************************;
          %* Rely on the column metadata field xmlcodelist to signal lookup candidates   *;
          %* and to identify the SAS format of interest.                                 *;
          %*******************************************************************************;

          *Note _cstXMLCodeList has no leading $ for character formats... *;
          proc format library=work._cstfmts cntlout=work._cstformats (keep=fmtname label rename=(label=_uvlabel));
            select &_cstXMLCodeList;
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

          %if ^%sysfunc(exist(work._cstformats)) %then
          %do;
            %*************************************************;
            %*  Check not run - Format data set not created  *;
            %*************************************************;
            %let _cst_MsgID=CST0003;
            %let _cst_MsgParm1=WORK._CSTFORMATS;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;

        %end;

        %if ^%SYSFUNC(kindex(&_cstUniqueDomains,%str(&_cstDSName))) %then
        %do;
          %if &_cstUniqueDomains= %then
            %let _cstUniqueDomains=%SYSFUNC(catx(%str( ),&_cstDSName));
          %else
            %let _cstUniqueDomains=%SYSFUNC(catx(%str( ),&_cstUniqueDomains,&_cstDSName));

          %let _cstSrcData=&_cstDSName;

          %if %sysfunc(exist(&_cstDSName)) %then
          %do;
            data _null_;
              set work._csttablemetadata (keep=sasref table keys where=(upcase(sasref)=upcase("&_cstRefOnly") and upcase(table)=upcase("&_cstDomainOnly")));

                attrib _csttemp format=$char200. label="Text string field"
                       _cstkey format=$char8. label="Key name";

                _csttemp ='';
                do i=1 to countw(keys,' ');
                  _cstkey = kscan(keys,i,' ');
                  if _csttemp ne '' then
                    _csttemp = catx(",",_csttemp,_cstkey);
                  else
                    _csttemp = _cstkey;
                end;

                call symputx('_cstDSKeys',keys);
                call symputx('_cstKeyCnt',countw(keys,' '));
              stop;
            run;

            %* Note _cstSQLKeys will exclude the target columns ;
            %let _cstSQLKeys=;
            %if &_cstKeyCnt > 0 %then
            %do;
              %do scnt=1 %to &_cstKeyCnt;
                %let _cstKeyColumn = %SYSFUNC(kscan(&_cstDSKeys,&scnt,' '));
                %if %upcase(&_cstKeyColumn) ne %upcase(&_cstColumn) %then
                %do;
                  %if &_cstSQLKeys= %then
                    %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstKeyColumn));
                  %else
                    %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstSQLKeys,&_cstKeyColumn));
                %end;
              %end;
            %end;

            data _null_;
              if 0 then set &_cstDSName nobs=_numobs;
              call symputx('_cstMetricsCntNumRecs',_numobs);
              stop;
            run;

            %* Write applicable metrics *;
            %if &_cstMetrics %then %do;
              %if &_cstMetricsNumRecs %then
                %cstutil_writemetric(
                     _cstMetricParameter=# of records tested
                     ,_cstResultID=&_cstCheckID
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstMetricCnt=&_cstMetricsCntNumRecs
                     ,_cstSrcDataParm=&_cstSrcData
                );
            %end;
          %end;
          %else
          %do;
            %****************************************************;
            %*  Check not run - &_cstDSName could not be found  *;
            %****************************************************;
            %let _cst_MsgID=CST0003;
            %let _cst_MsgParm1=&_cstDSname;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstSrcData=&sysmacroname;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;

        %end;

        data _null_;
          if 0 then set work._cstformats nobs=_numobs;
          call symputx('_cstFMTValCnt',_numobs);
          stop;
        run;

        %if &_cstFMTValCnt <= 0 %then
        %do;
          %* No formatted values identified  *;
          %let _cst_MsgID=CST0034;
          %let _cst_MsgParm1=WORK._CSTFORMATS;
          %let _cst_MsgParm2=&_cstXMLCodeList;
          %let _cstResultFlag=-1;
          %let _cstSrcData=&_cstDSName..&_cstColumn;
          %let _cst_rc=0;
          %let _cstexit_loop=1;
          %goto exit_loop;
        %end;

        %let dsid = %sysfunc(open(&_cstDSName));
        %if &dsid ne 0 %then %do;
          %if %sysfunc(varnum(&dsid,&_cstColumn))=0 %then
          %do;
            %let dsid = %sysfunc(close(&dsid));
            %****************************************************;
            %*  Check not run - &_cstColumn could not be found  *;
            %****************************************************;
            %let _cst_MsgID=CST0003;
            %let _cst_MsgParm1=&_cstDSname &_cstColumn;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstSrcData=&sysmacroname;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;
          %let dsid = %sysfunc(close(&dsid));
        %end;
        %if %sysfunc(exist(&_cstDSName)) %then
        %do;

          %if %sysevalf(%superq(_cstCodeLogic)=,boolean) %then
          %do;

            proc sql noprint;
              create table work._cstproblems /* (drop=_uv) */ as
              select &_cstDomainOnly..*, _uv
              from &_cstDSName &_cstDomainOnly
                left join
                  (select _uv, _uvlabel from
                      (select distinct &_cstColumn as _uv from &_cstDSName)
                    left join work._cstformats
                      on _uv = _uvlabel
                        where _uvlabel = '')
                  on _uv = &_cstColumn
                    where _uv ne '';
            quit;
          %end;
          %else
          %do;

            &_cstCodeLogic;

          %end;

          %if %symexist(sqlrc) %then %do;
            %if (&sqlrc gt 0) %then
            %do;
              %* Check failed - SAS error  *;
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
            %* Check failed - SAS error  *;

            * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
            options nosyntaxcheck obs=max replace;

            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Codelogic processing failed;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;
        %end;
        %else %do;
          %let _cstexit_loop=0;
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

        %****************************************;
        %* One or more errors were found  *;
        %****************************************;

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
            srcdata =catx('.',"&_cstDSName","&_cstColumn");
            _cstSeqNo+1;
            seqno=_cstSeqNo;
            keyvalues='';

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

            * Calculate actual column.  *;
            %if &_cstReportingColumns = %str() %then
            %do;
              actual = cats("&_cstColumn","=",&_cstColumn);
            %end;
            %else
            %do;
              actual = cats("&_cstColumn","=",&_cstColumn);
              %let _cstSubCnt=%SYSFUNC(countw(&_cstReportingColumns,' '));
              %do _currentCol = 1 %to &_cstSubCnt;
                %let _cstCol=%SYSFUNC(kscan(&_cstReportingColumns,&_currentCol,' '));
                %if %upcase("&_cstColumn") ^= %upcase("&_cstCol") %then
                %do;
                  if vtype(&_cstCol)='C' then
                  do;
                    if actual='' then
                      actual = cats("&_cstCol","=",&_cstCol);
                    else
                      actual = cats(actual,",","&_cstCol","=",&_cstCol);
                  end;
                  else
                  do;
                    if actual='' then
                      actual = cats("&_cstCol","=",put(&_cstCol,8.));
                    else
                      actual = cats(actual,",","&_cstCol","=",put(&_cstCol,8.));
                  end;
                %end;
              %end;
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
            %let _cstexit_loop=1;
            %goto exit_loop;
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
          %if &_cstDSRowCt=0 %then
          %do;
            %*****************************************************************;
            %* Value for check not found                                     *;
            %* _cstDSRowCT is initialized in cstutilcheck_formatlookup macro *;
            %* This macro is used in codelogic field of validation_control   *;
            %*****************************************************************;
            %let _cst_MsgID=CST0016;
            %let _cst_MsgParm1=&_cstCol2Value;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstResultFlag=0;
            %let _cstSrcData=&_cstDSName..&_cstColumn;
            %let _cstexit_loop=1;
            %goto exit_loop;
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
            %let _cstResultFlag=0;
            %let _cstSrcData=&_cstDSName..&_cstColumn;
            %let _cstexit_loop=1;
            %goto exit_loop;
          %end;
        %end;

%exit_loop:

        %if &_cstDebug=0 %then
        %do;
          %if %sysfunc(exist(work._cstproblems)) %then
          %do;
            proc datasets lib=work nolist;
              delete _cstproblems;
            run;
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
      %end;  /* do i=1 to _cstColCnt loop  */
    %end;  /* _cstColCnt > 0 loop  */
    %else
    %do;
      %******************************************;
      %*  Check not run - No columns evaluated  *;
      %******************************************;
      %let _cst_MsgID=CST0004;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstactual=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope);
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
  %end;

  %else %if %upcase(&_cstLookupType)=CODELIST %then
  %do;
    %* Functionality not yet supported  *;
    %let _cst_MsgID=CST0099;
    %let _cst_MsgParm1=Codelist lookup functionality;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;

    **********************************************************
    *  Assume lookupSOURCE = a\b\c\yesno.txt (or xml???)...  *
    *  Also be thinking about odm or crtdds validation       *
    *  against internal codelist                             *
    *********************************************************************************************
    *  Sample ODM excerpt:
    *
    * <CodeList OID="ACTION" Name="ACTION" DataType="text">
    *  <CodeListItem CodedValue="1">
    *    <Decode> <TranslatedText xml:lang="EN">none</TranslatedText> </Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="2">
    *    <Decode> <TranslatedText xml:lang="EN">study drug reduced</TranslatedText> </Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="3">
    *    <Decode> <TranslatedText xml:lang="EN">study drug discontinued</TranslatedText> </Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="4">
    *    <Decode> <TranslatedText xml:lang="EN">concomitant medication</TranslatedText> </Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="5">
    *    <Decode> <TranslatedText xml:lang="EN">hospitalization (required or prolonged)</TranslatedText> </Decode>
    *  </CodeListItem>
    * </CodeList>
    *
    * Sample Pilot excerpt:
    *
    * <CodeList OID="CODELISTC19" Name="SEX" DataType="text" SASFormatName="SEX">
    *  <CodeListItem CodedValue="F" Rank="4">
    *    <Decode> <TranslatedText xml:lang="en">Female  </TranslatedText></Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="M" Rank="5">
    *    <Decode> <TranslatedText xml:lang="en">Male  </TranslatedText></Decode>
    *  </CodeListItem>
    *  <CodeListItem CodedValue="U" Rank="6">
    *    <Decode> <TranslatedText xml:lang="en">Unknown  </TranslatedText></Decode>
    *  </CodeListItem>
    * </CodeList>
    *********************************************************************************************;
  %end;
  %else %if %upcase(&_cstLookupType)=DATASET %then
  %do;

    %****************************************************;
    %* Rely on the check metadata column lookupsource   *;
    %* to identify the SAS data set of interest.        *;
    %****************************************************;

    %if %length(&_cstLookupSource)=0 %then
    %do;
      %let _cst_MsgID=CST0026;
      %let _cst_MsgParm1=a LOOKUPSOURCE value is required;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if %sysevalf(%superq(_cstCodeLogic)=,boolean) %then
    %do;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=CODELOGIC;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %**************************************************************************************;
    %* Assumption is that lookupsource contains the full libref.member reference          *;
    %* to the data set of interest.  If the libref is not provided, it must be            *;
    %* obtained from a type=referencecterm entry in the sasreferences control data set.   *;
    %**************************************************************************************;

    %let _cstFoundLookupSource=0;

    %if ^%SYSFUNC(kindexc(&_cstLookupSource,'.')) %then
    %do;

      %let _cstSASrefLibs=;
      %* Return all referencecterm librefs defined in sasreferences                         *;
      %* Note absence of standard and standardversion.  These are assumed to be irrelevant  *;
      %*  for type=referencecterm records, as these may cross or be independent of any      *;
      %*  given standard.                                                                   *;
      %cstutil_getsasreference(_cstSASRefType=referencecterm,_cstSASRefsasref=_cstSASrefLibs,_cstConcatenate=1);
      %let _cstSrcData=&sysmacroname;
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=&_cstLookupSource data set;
        %let _cst_MsgParm2=;
        %let _cst_rc=0;
        %let _cstResultFlag=-1;
        %let _cstactual=%str(lookupType=&_cstLookupType,lookupSource=&_cstLookupSource);
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      %* Determine how many referencecterm librefs there are.  Note users may concatenate multiple  *;
      %* libraries within a single libref or have multiple distinct referencecterm librefs.         *;
      %let _cstLibCnt = %SYSFUNC(countw(&_cstSASrefLibs,' '));
      %let _cstInitLookupSource=&_cstLookupSource;
      %let i=0;
      %do %while (&i < &_cstLibCnt and &_cstFoundLookupSource=0);
        %let i=%eval(&i+1);
        %let _cstLibrary = %scan(&_cstSASrefLibs, &i , " ");
        %let _cstLookupSource=&_cstLibrary..&_cstInitLookupSource;

        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %* Report (informational) each attempted libref.dataset we will look for  *;
        %cstutil_writeresult(
                  _cstResultID=CST0032
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=&_cstInitLookupSource
                  ,_cstResultParm2=&_cstLookupSource
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=%str(&_cstactual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );

        %* Once we find the first occurrence of _cstLookupSource (from the check metadata), use it  *;
        %* This mimics library concatenation when we encounter multiple librefs                     *;
        %if %sysfunc(exist(&_cstLookupSource)) %then
          %let _cstFoundLookupSource=1;
      %end;

    %end;
    %else 
    %do;
      %if %sysfunc(exist(&_cstLookupSource)) %then
        %let _cstFoundLookupSource=1;
      %else
        %let _cstInitLookupSource=&_cstLookupSource;
    %end;

    %if &_cstFoundLookupSource=0 %then
    %do;
      %* reference terminology data set &_cstLookupSource not found *;
      %let _cst_MsgID=CST0031;
      %let _cst_MsgParm1=data set &_cstInitLookupSource;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
    %else
    %do;

      %***************************;
      %*  Cycle through columns  *;
      %***************************;
      %if &_cstColCnt > 0 %then
      %do;
        %do i=1 %to &_cstColCnt;

          data _null_;
            set work._cstcolumnmetadata (keep=sasref table column type xmlcodelist firstObs=&i);
              _csttemp = catx('.',sasref,table);
              call symputx('_cstDSName',kstrip(_csttemp));
              call symputx('_cstRefOnly',sasref);
              call symputx('_cstDomainOnly',table);
              call symputx('_cstColumn',column);
            stop;
          run;

          %if ^%SYSFUNC(kindex(&_cstUniqueDomains,%str(&_cstDSName))) %then
          %do;
            %if &_cstUniqueDomains= %then
              %let _cstUniqueDomains=%SYSFUNC(catx(%str( ),&_cstDSName));
            %else
              %let _cstUniqueDomains=%SYSFUNC(catx(%str( ),&_cstUniqueDomains,&_cstDSName));

            %let _cstSrcData=&_cstDSName;

            %if %sysfunc(exist(&_cstDSName)) %then
            %do;
              data _null_;
                set work._csttablemetadata (keep=sasref table keys where=(upcase(sasref)=upcase("&_cstRefOnly") and upcase(table)=upcase("&_cstDomainOnly")));

                  attrib _csttemp format=$char200. label="Text string field"
                         _cstkey format=$char8. label="Key name";

                  _csttemp ='';
                  do i=1 to countw(keys,' ');
                    _cstkey = kscan(keys,i,' ');
                    if _csttemp ne '' then
                      _csttemp = catx(",",_csttemp,_cstkey);
                    else
                      _csttemp = _cstkey;
                  end;

                  call symputx('_cstDSKeys',keys);
                  call symputx('_cstKeyCnt',countw(keys,' '));
                stop;
              run;

              %* Note _cstSQLKeys will exclude the target columns ;
              %let _cstSQLKeys=;
              %if &_cstKeyCnt > 0 %then
              %do;
                %do scnt=1 %to &_cstKeyCnt;
                  %let _cstKeyColumn = %SYSFUNC(kscan(&_cstDSKeys,&scnt,' '));
                  %if %upcase(&_cstKeyColumn) ne %upcase(&_cstColumn) %then
                  %do;
                    %if &_cstSQLKeys= %then
                      %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstKeyColumn));
                    %else
                      %let _cstSQLKeys=%SYSFUNC(catx(%str(,),&_cstSQLKeys,&_cstKeyColumn));
                  %end;
                %end;
              %end;

              data _null_;
                if 0 then set &_cstDSName nobs=_numobs;
                call symputx('_cstMetricsCntNumRecs',_numobs);
                stop;
              run;

              %* Write applicable metrics *;
              %if &_cstMetrics %then %do;
                %if &_cstMetricsNumRecs %then
                  %cstutil_writemetric(
                     _cstMetricParameter=# of records tested
                     ,_cstResultID=&_cstCheckID
                     ,_cstResultSeqParm=&_cstResultSeq
                     ,_cstMetricCnt=&_cstMetricsCntNumRecs
                     ,_cstSrcDataParm=&_cstSrcData
                  );
              %end;
            %end;
            %else
            %do;
              %****************************************************;
              %*  Check not run - &_cstDSName could not be found  *;
              %****************************************************;
              %let _cst_MsgID=CST0003;
              %let _cst_MsgParm1=&_cstDSname;
              %let _cst_MsgParm2=;
              %let _cst_rc=0;
              %let _cstResultFlag=-1;
              %let _cstSrcData=&sysmacroname;
              %let _cstexit_loop=1;
              %goto exit_dbloop;
            %end;

          %end;

          %let dsid = %sysfunc(open(&_cstDSName));
          %if %sysfunc(varnum(&dsid,&_cstColumn))=0 %then
          %do;
            %let dsid = %sysfunc(close(&dsid));
            %****************************************************;
            %*  Check not run - &_cstColumn could not be found  *;
            %****************************************************;
            %let _cst_MsgID=CST0003;
            %let _cst_MsgParm1=&_cstDSname &_cstColumn;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstSrcData=&sysmacroname;
            %let _cstResultFlag=-1;
            %let _cstexit_loop=1;
            %goto exit_dbloop;
          %end;
          %let dsid = %sysfunc(close(&dsid));

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
              %let _cstexit_loop=1;
              %goto exit_dbloop;
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
            %let _cstexit_loop=1;
            %goto exit_dbloop;
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

          %****************************************;
          %* One or more errors were found  *;
          %****************************************;

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

              attrib _cstSeqNo format=8. label="Sequence counter for result column";

              keep _cstMsgParm1 _cstMsgParm2;

              retain _cstSeqNo 0 resultid checkid resultseq resultflag _cst_rc;

              %***********************************;
              %* Set results data set attributes *;
              %***********************************;
              %cstutil_resultsdsattr;
              retain message resultseverity resultdetails '';

              if _n_=1 then
              do;
                _cstSeqNo=&_cstSeqCnt;
                resultid="&_cstCheckID";
                checkid="&_cstCheckID";
                resultseq=&_cstResultSeq;
                resultflag=1;
                _cst_rc=0;
              end;

              _cstMsgParm1='';
              _cstMsgParm2='';
              srcdata =catx('.',"&_cstDSName","&_cstColumn");
              _cstSeqNo+1;
              seqno=_cstSeqNo;

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

              * Calculate actual column.  *;
              %if &_cstReportingColumns = %str() %then
              %do;
                actual = cats("&_cstColumn","=",&_cstColumn);
              %end;
              %else
              %do;
                actual = cats("&_cstColumn","=",&_cstColumn);
                %let _cstSubCnt=%SYSFUNC(countw(&_cstReportingColumns,' '));
                %do _currentCol = 1 %to &_cstSubCnt;
                  %let _cstCol=%SYSFUNC(kscan(&_cstReportingColumns,&_currentCol,' '));
                  %if %upcase("&_cstColumn") ^= %upcase("&_cstCol") %then
                  %do;
                    if vtype(&_cstCol)='C' then
                    do;
                      if actual='' then
                        actual = cats("&_cstCol","=",&_cstCol);
                      else
                        actual = cats(actual,",","&_cstCol","=",&_cstCol);
                    end;
                    else
                    do;
                      if actual='' then
                        actual = cats("&_cstCol","=",put(&_cstCol,8.));
                      else
                        actual = cats(actual,",","&_cstCol","=",put(&_cstCol,8.));
                    end;
                  %end;
                %end;
              %end;

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
              %let _cstexit_loop=1;
              %goto exit_dbloop;
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
            %let _cstResultFlag=0;
            %let _cstSrcData=&_cstDSName..&_cstColumn;
            %let _cstexit_loop=1;
            %goto exit_dbloop;
          %end;

%exit_dbloop:

          %if &_cstDebug=0 %then
          %do;
            %if %sysfunc(exist(work._cstproblems)) %then
            %do;
              proc datasets lib=work nolist;
                delete _cstproblems;
              run;
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
        %end;
      %end;
    %end;
  %end;
      
      
  %else %if %upcase(&_cstLookupType)=LOOKUP %then
  %do;

    %****************************************************;
    %* Rely on the check metadata column lookupsource   *;
    %* to identify the SAS data set of interest.        *;
    %****************************************************;

    %if %length(&_cstLookupSource)=0 %then
    %do;
      %let _cst_MsgID=CST0026;
      %let _cst_MsgParm1=a LOOKUPSOURCE value is required;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %if %sysevalf(%superq(_cstCodeLogic)=,boolean) %then
    %do;
      %let _cst_MsgID=CST0003;
      %let _cst_MsgParm1=CODELOGIC;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %**************************************************************************************;
    %* Assumption is that lookupsource contains the full libref.member reference          *;
    %* to the data set of interest and that the lookup data set exists.                   *;
    %**************************************************************************************;

    %if ^%sysfunc(exist(&_cstLookupSource)) %then
    %do;
      %* lookup data set &_cstLookupSource not found *;
      %let _cst_MsgID=CST0031;
      %let _cst_MsgParm1=data set &_cstLookupSource;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
    %else
    %do;

      %**************************************************************************;
      %*  _cstCodeLogic must be a self-contained data or proc sql step. The     *;
      %*  expected result is a work._cstProblems data set.  If this data set    *;
      %*  has > 0 observations, this will be interpreted as an error condition. *;
      %**************************************************************************;

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
          %let _cstexit_loop=1;
          %goto exit_lkloop;
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
        %let _cstexit_loop=1;
        %goto exit_lkloop;
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

      %****************************************;
      %* One or more errors were found  *;
      %****************************************;

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
            * Expected content:  work._cstproblems (keep=sasref table column value) *;
            attrib _cstSeqNo format=8. label="Sequence counter for result column";

            keep _cstMsgParm1 _cstMsgParm2;

            retain _cstSeqNo 0 resultid checkid resultseq resultflag _cst_rc;

            %***********************************;
            %* Set results data set attributes *;
            %***********************************;
            %cstutil_resultsdsattr;
            retain message resultseverity resultdetails '';

            if _n_=1 then
            do;
              _cstSeqNo=&_cstSeqCnt;
              resultid="&_cstCheckID";
              checkid="&_cstCheckID";
              resultseq=&_cstResultSeq;
              resultflag=1;
              _cst_rc=0;
            end;

            _cstMsgParm1='';
            _cstMsgParm2='';
            srcdata=upcase(catx('.',strip(sasref),strip(table),strip(column)));
            _cstSeqNo+1;
            seqno=_cstSeqNo;

            * Calculate actual column.  *;
            actual=_value_;

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
            %let _cstexit_loop=1;
            %goto exit_lkloop;
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
        %let _cstResultFlag=0;
        %let _cstSrcData=WORK._CSTTABLEMETADATA;
        %let _cstexit_loop=1;
        %goto exit_lkloop;
      %end;

%exit_lkloop:

      %if &_cstDebug=0 %then
      %do;
        %if %sysfunc(exist(work._cstproblems)) %then
        %do;
          proc datasets lib=work nolist;
            delete _cstproblems;
          run;
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
    %end;
  %end;
  %else
  %do;
    %* Functionality not yet supported  *;
    %let _cst_MsgID=CST0099;
    %let _cst_MsgParm1=&_cstLookupType lookup functionality;
    %let _cst_MsgParm2=;
    %let _cstResultFlag=-1;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %exit_error:
  %**********************************************************************************;
  %* This is a catch-all for singly-occurring errors (only one of which can occur   *;
  %*  within this code module because of placement within non-overlapping else      *;
  %*  code blocks).                                                                 *;
  %**********************************************************************************;
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

  %if %sysfunc(cexist(_cstfmts)) %then
  %do;
     catname _cstfmts clear;
  %end;

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(exist(work._cstformats)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstformats;
      run;
    %end;
    %if %sysfunc(exist(work._cstfmts)) %then
    %do;
      proc datasets lib=work nolist;
        delete _cstfmts;
      run;
    %end;
  %end;
  %else
    %put <<< cstcheck_notincodeList;

%mend cstcheck_notincodeList;