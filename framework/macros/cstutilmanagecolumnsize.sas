%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilmanagecolumnsize                                                        *;
%*                                                                                *;
%* Provides options to alter column size to observed or expected lengths          *;
%*                                                                                *;
%* Notes:                                                                         *;
%*   1. Any librefs referenced in macro parameters must be pre-allocated.         *;
%*   2. Every source data set is written to the output location, even if no       *;
%*      column lengths are modified. Only modifications are reported. Data sets   *;
%*      that existin the output location are overwritten.                         *;
%*   3. No column trimming is performed for any data set with 0 obserations.      *;
%*      Doing so results in all character column lengths of 1, which would serve  *;
%*      no data set size reduction value.                                         *;
%*   4. If column trimming would result in truncation of one or more values, this *;
%*      is reported as a warning and no column trimming occurw.                   *;
%*   5. To evaluate lengths relative to a codelist associated with a column,      *;
%*      the codelists must be defined as SAS formats reachable via the SAS        *;
%*      format search path as defined in the SAS FMTSEARCH option.                *;
%*   6. Column trimming can never result in a length less than 1. Any columns     *;
%*      having only missing values will be set to a length of 1 unless            *;
%*      _cstTrimAlgorithm values dictate otherwise.                               *;
%*   7. Certain parameter values might be ignored if other parameter settings take*;
%*      precedence. For example, _cstMaxExpected is ignored if _cstTrimAlgorithm  *;
%*      is not set to MAXEXPECTED.                                                *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session. Set _cstDebug=1   *;
%*             before this macro call to retain work files created in this macro. *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstResultSeq Results: Unique invocation of macro                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstTransactionDS Identifies logging data set can be set before        *;
%*             calling this macro to override the default)                        *;
%* @macvar _cstStandard Name of the registered standard added to the logging      *;
%*             data set (if desired, set before calling this macro)               *;
%* @macvar _cstStandardVersion Version of the registered standard added to the    *;
%*             logging data set (if desired, set before calling this macro)       *;
%*                                                                                *;
%* @param _cstSourceDataSet - optional - The (libref.)dataset of the source data  *;
%*            set to modify.                                                      *;
%* @param _cstOutputDataSet - optional - The (libref.)dataset of the output data  *;
%*            set that contains the minimized lengths. Required if                *;
%*            _cstSourceDataSet is specified.                                     *;
%* @param _cstSourceLibrary - optional - The libref of the source data folder/    *;
%*            library to modify.                                                  *;
%* @param _cstOutputLibrary - optional - The libref of the output data folder/    *;
%*            library that contains the data sets with modified column lengths.   *;
%*            Required if _cstSourceLibrary is specified and output to the WORK   *;
%*            library is not needed.                                              *;
%*            Default: WORK                                                       *;
%* @param _cstColumnList - optional - The list of blank-delimited variables to    *;
%*            be minimize.                                                        *;
%*            Values: _ALL_ | (Example) AETERM AEDECOD AEBODSYS                   *;
%*                    _ALL_: Include all character variables.                     *;
%*                    AETERM AEDECOD AEBODSYS: Trim only this list of variables.  *;
%*            Default: _ALL_                                                      *;
%* @param _cstTrimAlgorithm - optional - The algorithm to apply to all columns    *;
%*            when calculating the modified maximum column size.                  *;
%*            Values: MAXOBSERVED | MAXEXPECTED | MAXCODELIST | MAXCOLMETA        *;
%*                    MAXOBSERVED: Use the maximum observed length across all     *;
%*                                 records.                                       *;
%*                    MAXEXPECTED: Use length n, as defined in _cstMaxExpected,   *;
%*                                 across all records. For example, n might be    *;
%*                                 set to 2 for flag variables. Or, n might be    *;
%*                                 set to 17 for datetime columns that may        *;
%*                                 support the ISO8601 yyyy-mm-ddThh:mm format    *;
%*                                 even though only dates have been collected so  *;
%*                                 far. Typically used with _cstColumnList.       *;
%*                                 Requires a _cstMaxExpected integer value > 0.  *;
%*                                 (Subject to truncation limitation noted above) *;
%*                    MAXCODELIST: Apply the codelist (SAS format) length for the *;
%*                                 associated column.                             *;
%*                                 Requires that the _cstSourceMetadataDataSet    *;
%*                                 parameter be specified.                        *;
%*                                 (Subject to truncation limitation noted above) *;
%*                    MAXCOLMETA: Use the EXPORTLENGTH value specified in the     *;
%*                                 _cstSourceMetadataDataSet data set as the      *;
%*                                 pre-determined length of each column.          *;
%*                                 (Subject to truncation limitation noted above.)*;
%*            Default: MAXOBSERVED                                                *;
%* @param _cstMaxExpected - optional - A positive integer that represents the     *;
%*            maximum value expected. Required if _cstTrimAlgorithm is set to     *;
%*            MAXEXPECTED. Note this value applies to all implied or specified    *;
%*            columns. (Subject to truncation limitation noted above.)            *;
%* @param _cstSourceMetadataDataSet - optional - The libref.dataset of a          *;
%*            metadata file that contains column metadata such as column name and *;
%*            type. In the SAS Clinical Standards Toolkit, such a file can be     *;
%*            found in a location such as:                                        *;
%*            <Sample Library>/cdisc-sdtm-3.2-1.7/sascstdemodata/metadata/        *;
%*            source_columns.sas7bdat.                                            *;
%*            At a minimun, this data set must contain the variables TABLE (table *;
%*            name), COLUMN (column name), TYPE (column type) and XMLCODELIST     *;
%*            (SAS format name). EXPORTLENGTH can optionally be included to signal*;
%*            the desired trimmed length for each column that will be used when   *;
%*            _cstTrimAlgorithm=MAXCOLMETA.                                       *;
%* @param _cstResizeStrategy - optional - Action to take when any change in       *;
%*            column size is indicated from what is currently defined.            *;
%*            Values: DECREASE | INCREASE | BOTH                                  *;
%*                    DECREASE: Only minimize column size, if possible.           *;
%*                    INCREASE: Only increase column size, if indicated.          *;
%*                    BOTH: Reset the column size larger or smaller, if indicated.*;
%*            Default: DECREASE                                                   *;
%* @param _cstRptType - optional - How modifications are to be reported.          *;
%*            Values: LOG | CSTRESULTSDS | TRANSACTIONLOG                         *;
%*                    LOG: Modifications are reported in the SAS log file.        *;
%*                    _CSTRESULTSDS: Modifications are reported in the  Results   *;
%*                                   data set that is specified by the            *;
%*                                   _cstResultsDS global macro variable.         *;
%*                    TRANSACTIONLOG: Modifications are tdocumented using the     *;
%*                                    the SAS Clinical Standards Toolkit Metadata *;
%*                                    Management tools and recorded in the        *;
%*                                    transactionlog data set.                    *;
%*            Default: LOG                                                        *;
%*                                                                                *;
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;

%macro cstutilmanagecolumnsize(
    _cstSourceDataSet=,
    _cstOutputDataSet=,
    _cstSourceLibrary=,
    _cstOutputLibrary=WORK,
    _cstColumnList=_ALL_,
    _cstTrimAlgorithm=MAXOBSERVED,
    _cstMaxExpected=,
    _cstSourceMetadataDataSet=,
    _cstResizeStrategy=DECREASE,
    _cstRptType=LOG
    ) / des="CST: Minimize character variable length";


  %local _cstAllDSVars
         _cstAllTableCnt
         _cstAllTableLastDS
         _cstAllTableList
         _cstColCnt
         _cstColIter
         _cstColList
         _cstColumnListQuoted
         _cstDefLen
         _cstDefLenList
         _cstDir
         _cstDontAllowUpdate
         _cstDSKeys
         _cstDSLabel
         _cstfid
         _cstFmtIter
         _cstFmts
         _cstFmtsCnt
         _cstLengthStmt
         _cstLogAttrString
         _cstLogMessage
         _cstMaxColMeta
         _cstMaxObserved
         _cstMsgDir
         _cstMsgMem
         _cstMissingVars
         _cstNeedToDeleteMsgs
         _cstNewLen
         _cstNewLenList
         _cstObsLen
         _cstObsLenList
         _cstOutLibref
         _cstOutputDS
         _cstRandom 
         _cstResultsOverrideDS
         _cstReturnCode
         _cstSaveOpt
         _cstSrcLibref
         _cstSrcMacro
         _cstTabIter
         _cstTable
         _cstTableCnt
         _cstTableList
         _cstTempLib
         _cstTempPath
         _cstTransCopyDS
  ;

  %let _cstMaxColMeta=0;
  %let _cstResultSeq=1;
  %let _cstSaveOpt=WARN;
  %let _cstSeqCnt=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstTableCnt=0;
  %let _cstAllTableCnt=0;
  %let _cstFmtsCnt=0;
  %let _cstResultsOverrideDS=;
  %let _cstDontAllowUpdate=0;
  %let _cstLogMessage=1;
  
  %***************************************************;
  %*  Check for existence of global macro variables  *;
  %***************************************************;
  %if ^%symexist(_cst_rc) %then 
  %do;
    %global _cst_rc _cst_rcmsg;
    %let _cst_rc=0;
  %end;
  %if ^%symexist(_cstDeBug) %then 
  %do;
    %global _cstDeBug;
    %let _cstDebug=0;
  %end;


  %************************;
  %* Set parameter values *;
  %************************;

  %* Rule:  If _cstColumnList is blank, set to _ALL_ *;
  %if %klength(&_cstColumnList) < 1 %then
    %let _cstColumnList=_ALL_;
  %else %let _cstColumnList=%upcase(&_cstColumnList);  

  %* Rule:  If _cstTrimAlgorithm is blank, set to MAXOBSERVED *;
  %if %klength(&_cstTrimAlgorithm) < 1 %then
    %let _cstTrimAlgorithm=MAXOBSERVED;  
  %else %let _cstTrimAlgorithm=%upcase(&_cstTrimAlgorithm);  
    
  %* Rule:  If _cstRptType is blank, set to LOG *;
  %if %klength(&_cstRptType) < 1 %then
    %let _cstRptType=LOG; 
  %else %let _cstRptType=%upcase(&_cstRptType);
  
  %* Rule:  If _cstResizeStrategy is blank, set to DECREASE *;
  %if %klength(&_cstResizeStrategy) < 1 %then
    %let _cstResizeStrategy=DECREASE; 
  %else %let _cstResizeStrategy=%upcase(&_cstResizeStrategy);
  

  %*********************;
  %*  Reporting setup  *;
  %*********************;

  %if &_cstRptType=CSTRESULTSDS %then 
  %do;
    %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK, _cstSubType=initialize);
    
    %* Create a temporary messages data set if required;
    %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %end;
  %else %if &_cstRptType=TRANSACTIONLOG %then 
  %do;
    %if (^%symexist(_cstTransactionDS)=1) %then 
      %let _cstTransactionDS=;

    %***********************************************************;
    %*  Check Transaction data set to verify it is not locked  *:
    %*  by another user. If locked abort the process without   *;
    %*  making the change and notify user, otherwise proceed.  *;
    %***********************************************************;
    %cstutilgetdslock;
  
    %if &_cst_rc %then
      %goto exit_error;

    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTransCopyDS=work._cst&_cstRandom;

    %let _cstLogAttrString=;
    %cstutilbuildattrfromds(_cstSourceDS=&_cstTransactionDS,_cstAttrVar=_cstLogAttrString);
    
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstDir=_cst&_cstRandom;
    %let _cstReturnCode=%sysfunc(filename(_cstDir,%sysfunc(pathname(work))/logrecs.txt));

  %end;


  %************************;
  %* Parameter checking   *;
  %************************;

  %if %klength(&_cstSourceDataSet)<1 and %klength(&_cstSourceLibrary)<1 %then
  %do;
    %* Rule:  Either _cstSourceDataSet or _cstSourceLibrary must be specified  *;
    %let _cst_rcmsg=Either _cstSourceDataSet or _cstSourceLibrary must be specified.;
    %goto exit_error;
  %end;
  %if %klength(&_cstSourceDataSet)>0 %then
  %do;
    %if %klength(&_cstOutputDataSet) < 1 %then
    %do;
      %* Rule:  If _cstSourceDataSet>0, _cstOutputDataSet must be specified  *;
      %let _cst_rcmsg=If _cstSourceDataSet is specified, _cstOutputDataSet must also be specified.;
      %goto exit_error;
    %end;
    %else 
    %do;
      %cstutilcheckwriteaccess(_cstfiletype=DATASET,_cstfileref=&_cstOutputDataSet);
      %if &_cst_rc %then
      %do;
        %* Rule:  If _cstOutputDataSet>0, it is not write-protected *;
        %let _cst_rcmsg=Unable to write output to &_cstOutputDataSet.;
        %goto exit_error;
      %end;

    %end;
    %if %klength(&_cstSourceLibrary)>0 %then
    %do;
      %* Rule:  Only _cstSourceDataSet or _cstSourceLibrary should be specified, but not both   *;
      %let _cst_rcmsg=Only _cstSourceDataSet or _cstSourceLibrary should be specified, but not both.;
      %goto exit_error;
    %end;


    %if %sysfunc(exist(&_cstSourceDataSet))=0 %then 
    %do;
      %* Rule:  If _cstSourceDataSet>0, it must exist  *;
      %let _cst_rcmsg=&_cstSourceDataSet does not exist.;
      %goto exit_error;
    %end;
    %if %klength(&_cstColumnList)>0 %then
    %do;
      %if &_cstColumnList ^= _ALL_ %then
      %do;
        %let _cstMissingVars=;
        %if %cstutilcheckvarsexist(_cstDataSetName=&_cstSourceDataSet,_cstVarList=&_cstColumnList,
             _cstNotExistVarList=_cstMissingVars)=0 %then
        %do;
          %* Rule:  If _cstSourceDataSet>0, confirm all _cstColumnList exist   *;
          %let _cst_rcmsg=The column(s) &_cstMissingVars could not be found in &_cstSourceDataSet.;
          %goto exit_error;
        %end;
      %end;
    %end;
  %end;
  %if %klength(&_cstSourceLibrary)>0 %then
  %do;
    %if (%sysfunc(libref(&_cstSourceLibrary))) %then
    %do;
      %* Rule:  If _cstSourceLibrary>0, it must exist  *;
      %let _cst_rcmsg=The libref &_cstSourceLibrary has not been pre-allocated.;
      %goto exit_error;
    %end;
    %if %klength(&_cstOutputLibrary) < 1 %then
    %do;
      %* Rule:  If _cstSourceLibrary>0 and no _cstOutputLibrary, set _cstOutputLibrary to WORK  *;
      %let _cstOutputLibrary=WORK;
      %put NOTE: [CSTLOG%str(MESSAGE)] Any modified data sets will be written to the WORK directory.;
    %end;
    %else %if %upcase(&_cstOutputLibrary) ^= WORK %then
    %do;
      %* Rule:  If _cstOutputLibrary ne WORK, folder is writable  *;
      %let _cstTempPath=%sysfunc(pathname(&_cstOutputLibrary));
      %cstutilcheckwriteaccess(_cstfiletype=FOLDER,_cstfilepath=&_cstTempPath);
      %if &_cst_rc %then
      %do;
        %let _cst_rcmsg=Unable to write output to &_cstOutputLibrary.;
        %goto exit_error;
      %end;
    %end;
  %end;

  %if %klength(&_cstTrimAlgorithm)>0 %then
  %do;
    %if &_cstTrimAlgorithm ^= MAXOBSERVED and &_cstTrimAlgorithm ^= MAXEXPECTED and &_cstTrimAlgorithm ^= MAXCODELIST and &_cstTrimAlgorithm ^= MAXCOLMETA %then
    %do;
      %* Rule:  If _cstTrimAlgorithm>0, must be set to MAXOBSERVED | MAXEXPECTED | MAXCODELIST | MAXCOLMETA  *;
      %let _cst_rcmsg=_cstTrimAlgorithm must be set to MAXOBSERVED, MAXEXPECTED, MAXCODELIST or MAXCOLMETA.;
      %goto exit_error;
    %end;
    %if &_cstTrimAlgorithm=MAXEXPECTED %then
    %do;
      %if %kverify(&_cstMaxExpected,0123456789)>0 %then
      %do;
        %* Rule:  If _cstTrimAlgorithm=MAXEXPECTED, _cstMaxExpected must be integer   *;
        %let _cst_rcmsg=_cstMaxExpected must be set to an integer.;
        %goto exit_error;
      %end;
      %if %eval(&_cstMaxExpected<1) %then
      %do;
        %* Rule:  If _cstTrimAlgorithm=MAXEXPECTED, _cstMaxExpected must be integer>0   *;
        %let _cst_rcmsg=_cstMaxExpected must be set to an integer > 0.;
        %goto exit_error;
      %end;
    %end;
    %if &_cstTrimAlgorithm=MAXCODELIST %then
    %do;
      %if %klength(&_cstSourceMetadataDataSet)<1 %then
      %do;
        %* Rule:  If _cstTrimAlgorithm=MAXCODELIST, _cstSourceMetadataDataSet must be specified   *;
        %let _cst_rcmsg=If _cstTrimAlgorithm is set to MAXCODELIST, _cstSourceMetadataDataSet must be provided.;
        %goto exit_error;
      %end;
    %end;
    %if &_cstTrimAlgorithm=MAXCOLMETA %then
    %do;
      %if %klength(&_cstSourceMetadataDataSet)<1 %then
      %do;
        %* Rule:  If _cstTrimAlgorithm=MAXCOLMETA, _cstSourceMetadataDataSet must be specified   *;
        %let _cst_rcmsg=If _cstTrimAlgorithm is set to MAXCOLMETA, _cstSourceMetadataDataSet must be provided.;
        %goto exit_error;
      %end;
      %let _cstMissingVars=;
      %if %cstutilcheckvarsexist(_cstDataSetName=&_cstSourceMetadataDataSet,_cstVarList=EXPORTLENGTH,
           _cstNotExistVarList=_cstMissingVars)=0 %then
      %do;
        %* Rule:  If _cstTrimAlgorithm=MAXCOLMETA, _cstSourceMetadataDataSet must include the EXPORTLENGTH column  *;
        %let _cst_rcmsg=If _cstTrimAlgorithm is set to MAXCOLMETA, &_cstSourceMetadataDataSet must contain EXPORTLENGTH.;
        %goto exit_error;
      %end;
      %else %let _cstMaxColMeta=1;
    %end;
  %end;

  %if %klength(&_cstSourceMetadataDataSet)>0 %then
  %do;
    %if %sysfunc(exist(&_cstSourceMetadataDataSet))=0 %then 
    %do;
      %* Rule:  If _cstSourceMetadataDataSet>0, it must exist  *;
      %let _cst_rcmsg=&_cstSourceMetadataDataSet does not exist.;
      %goto exit_error;
    %end;
    %let _cstMissingVars=;
    %if %cstutilcheckvarsexist(_cstDataSetName=&_cstSourceMetadataDataSet,_cstVarList=TABLE COLUMN TYPE XMLCODELIST,
         _cstNotExistVarList=_cstMissingVars)=0 %then
    %do;
      %* Rule:  If _cstSourceMetadataDataSet>0, it must contain TABLE COLUMN TYPE XMLCODELIST  *;
      %let _cst_rcmsg=The column(s) &_cstMissingVars could not be found in &_cstSourceMetadataDataSet.;
      %goto exit_error;
    %end;
  %end;

  %if &_cstRptType ^= LOG and &_cstRptType ^= CSTRESULTSDS and &_cstRptType ^= TRANSACTIONLOG %then 
  %do;
    %* Rule:  If _cstRptType>0, must be set to LOG | CSTRESULTSDS | TRANSACTIONLOG  *;
    %let _cst_rcmsg=_cstRptType value must be LOG, CSTRESULTSDS or TRANSACTIONLOG.;
    %goto exit_error;
  %end;

  %if &_cstResizeStrategy ^= INCREASE and &_cstResizeStrategy ^= DECREASE and &_cstResizeStrategy ^= BOTH %then 
  %do;
    %* Rule:  If _cstResizeStrategy>0, must be set to INCREASE | DECREASE | BOTH  *;
    %let _cst_rcmsg=_cstResizeStrategy value must be INCREASE, DECREASE or BOTH.;
    %goto exit_error;
  %end;


  %************************;
  %* Begin macro logic    *;
  %************************;

  %*****************************************************;
  %* This section creates column subset of interest    *;
  %*****************************************************;
  
  %if &_cstColumnList ^= _ALL_ %then
  %do;
    data _null_;
      newList=cats("'",tranwrd(strip(symget('_cstColumnList'))," ","' '"),"'");
      call symputx('_cstColumnListQuoted',newList);
    run;
  %end;
 
  %if %klength(&_cstSourceDataSet)>0 %then
  %do;
    %if %sysfunc(indexc("&_cstSourceDataSet",'.'))>0 %then
      %let _cstSrcLibref=%upcase(%scan(&_cstSourceDataSet,1,'.'));
    %else
      %let _cstSrcLibref=WORK;
    proc contents data=&_cstSourceDataSet
  %end;
  %if %klength(&_cstSourceLibrary)>0 %then
  %do;
    %let _cstSrcLibref=%upcase(&_cstSourceLibrary);
    proc contents data=&_cstSourceLibrary.._ALL_
  %end;
 
      out=work._cstColumns (keep=libname memname name length type nobs
            rename=(memname=table name=column)) noprint;
    run;
 
  * This step is needed to get full set of tables so that all can be copied to the output location *;
  proc sql noprint;
    select distinct catx('.',libname,table)  into :_cstAllTableList separated by ' '  
    from work._cstColumns ;
    select count(distinct catx('.',libname,table))  into :_cstAllTableCnt  
    from work._cstColumns ;
  quit; 
  
  %if &_cstAllTableCnt=0 %then
    %goto exit_macro;

  %let _cstAllTableLastDS=%scan(&_cstAllTableList,&_cstAllTableCnt,' ');
  
  data work._cstColumns (drop=libname type);
    set work._cstColumns (
    
  %* At this point, _cstColumnList will either be _ALL_ or a list of columns  *;
  %if &_cstColumnList ^= _ALL_ %then
  %do;
      where=(type=2 and column in(&_cstColumnListQuoted))
  %end;
  %else %do;
      where=(type=2)
  %end;
 
      );
  run;
 
  %* Now check to see if we have independent column metadata available  *;
  %if %klength(&_cstSourceMetadataDataSet)>0 %then
  %do;
    proc sort data=&_cstSourceMetadataDataSet out=work._cstColumnMetadata;
      by table column;
    run;
    
    data work._cstColumns;
      attrib table  format=$32.
             column format=$32.
             ;
      merge work._cstColumns (in=source)
            work._cstColumnMetadata;
        by table column;
      if source; * Only keep extra metadata for column subset previously identified *;
    run;

    %***********************************************************************;
    %* Parameter choice indicates desire to use any codelists that have    *;
    %* been associated with columns as our target column lengths.          *;
    %* We will look in the SAS format search path for this information.    *;
    %***********************************************************************;
  
    %if &_cstTrimAlgorithm=MAXCODELIST %then
    %do;
      data _null_;
        attrib _cstfmts_rev format=$500.;
        _cstfmts = translate(getoption('FMTSEARCH'),'','()');
        do i = 1 to countw(_cstfmts,' ');
          _cstCatalog=scan(_cstfmts,i,' ');
          if indexc(_cstCatalog,'.')=0 then
            _cstCatalog=catx('.',_cstCatalog,'FORMATS');
          _cstfmts_rev=catx(' ',_cstfmts_rev,_cstCatalog);
        end;
        call symputx('_cstFmts',_cstfmts_rev);
        call symputx('_cstFmtsCnt',countw(_cstfmts,' '));
      run;
      * Example _cstFmts:  _CSTFMTS=S1.CTERMS S2.FORMATS WORK.FORMATS  *;
      
      %do _cstFmtIter=1 %to &_cstFmtsCnt;
        %let _cstCatalog=%scan(&_cstFmts,&_cstFmtIter,' ');
        proc format lib=&_cstCatalog cntlout=work._cstCat&_cstFmtIter (keep=fmtname type length where=(type='C'));
        run; 
        data _null_;
          set work._cstCat&_cstFmtIter end=last;
            by fmtname;
          if _n_=1 then do;
  %if &_cstFmtIter=1 %then %do;
      declare hash ht(ordered: 'a');
  %end;
  %else %do;
      declare hash ht(dataset:"work._cstFmts", ordered: 'a');
  %end;
      ht.defineKey("fmtname");
      ht.defineData("fmtname","length");
      ht.defineDone();
    end;
    if first.fmtname then
            rc=ht.add();
          if last then
            ht.output (dataset:"work._cstFmts") ;
        run;
        
        * Put max value length for each codelist into work._cstColumnMetadata as _cstCTMax *;
        proc sql noprint;
          create table work._cstColumnMetadata as
          select col.*, ct.fmtname as _cstCTFmtname, ct.length as _cstCTMax length=8 format=8.
          from work._cstColumns col
                 left join
               work._cstFmts ct
               on col.xmlcodelist = ct.fmtname
          order by table, order;
        quit;
        
      %end;
    
      %if &_cstDeBug<1 %then
      %do;
        * Clean up temporary data sets if they exist;
        proc datasets nolist lib=work;
          delete _cstCat1-_cstCat&_cstFmtsCnt _cstFmts / mt=data;
          quit;
        run;
      %end;    
    %end;
    %else %do;
      proc sql noprint;
        create table work._cstColumnMetadata as
        select col.*, '' as _cstCTFmtname format=$32., . as _cstCTMax format=8.
        from work._cstColumns col
        order by table, column;
      quit;
    %end;
  %end;
  %else %do;
    proc sql noprint;
      create table work._cstColumnMetadata as
      select col.*, '' as _cstCTFmtname format=$32., . as _cstCTMax format=8.
      from work._cstColumns col
      order by table, column;
    quit;
  %end;

  * Create _cstTableList macro with list of just those source data sets to-be-modified  *;
  data _null_;
    set work._cstColumnMetadata end=last;
      by table;
    attrib tempvar format=$41. alltables format=$2000.;
    retain alltables '' tabcnt 0;
    if first.table then 
    do;
      if nobs > 0 then
      do;
        tabcnt+1;
        tempvar=catx('.',"&_cstSrcLibref",table);
        alltables=catx(' ',alltables,tempvar);
      end;
    end;
    if last then
    do;
      call symputx('_cstTableList',alltables);
      call symputx('_cstTableCnt',tabcnt);
    end;
  run;
        
  %if %klength(&_cstOutputLibrary)>0 %then
  %do;
    %let _cstOutLibref=&_cstOutputLibrary;
  %end;
  %if %klength(&_cstOutputDataSet)>0 %then
  %do;
    %if %sysfunc(indexc(&_cstOutputDataSet,'.'))>0 %then
      %let _cstOutLibref=%scan(&_cstOutputDataSet,1,'.');
    %else
      %let _cstOutLibref=WORK;
  %end;

  %if &_cstRptType=TRANSACTIONLOG %then 
  %do;
    %let _cstfid=%sysfunc(fopen(&_cstdir,a,0,e));
  %end;

  %**********************************************************************;
  %* Now cycle through each source data set and modify column lengths   *;
  %**********************************************************************;

  %do _cstTabIter=1 %to &_cstTableCnt;
    %let _cstTable=%scan(&_cstTableList,&_cstTabIter,' ');
    %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstTable,_cstAttribute=SORTEDBY);
    %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstTable,_cstAttribute=LABEL);
    %let _cstOutputDS=&_cstTable;
    %if %sysfunc(indexc("&_cstOutputDS",'.'))>0 %then
    %do;
      %let _cstOutputDS=%sysfunc(tranwrd(%scan(&_cstOutputDS,1,'.'),&_cstSrcLibref,&_cstOutLibref)).%scan(&_cstOutputDS,2,'.');
    %end;

    %if &_cstAllTableCnt ^= &_cstTableCnt %then
    %do;
      %let indx=%sysfunc(findw(&_cstAllTableList,&_cstTable,' '));
      %if &indx>1 %then
      %do;
        %if &_cstTable=&_cstAllTableLastDS %then
          %let _cstAllTableList=%sysfunc(ksubstr(&_cstAllTableList,1,&indx-2));
        %else
          %let _cstAllTableList=%sysfunc(ksubstr(&_cstAllTableList,1,&indx-2))%sysfunc(ksubstr(&_cstAllTableList,&indx+%sysfunc(length(&_cstTable))));
      %end;
      %else %if &indx=1 %then
        %let _cstAllTableList=%sysfunc(ksubstr(&_cstAllTableList,%sysfunc(length(&_cstTable))+1));
    %end;

    * Need to capture all data set columns in varnum order to  *;
    *  perserve column order in generated output data set.     *;
    proc contents data=&_cstTable out=work._cstColumns (keep=name varnum) noprint;
    run;
    proc sort data=work._cstColumns;
      by varnum;
    run;
    data _null_;
      set work._cstColumns end=last;
        attrib _cstColStr format=$5000.;
        retain _cstColStr;
        _cstColStr=catx(' ',_cstColStr,name);
        if last then
          call symputx('_cstAllDSVars',_cstColStr);
    run;
    
    * work._cstColumnMetadata contains one record for each column to be assessed  *;
    data _null_;
      set work._cstColumnMetadata (where=(table=scan("&_cstTable",2,'.'))) end=last;
        attrib collist format=$5000. newlengths curlengths format=$1000.;
        retain collist newlengths curlengths;
        collist=catx(' ',collist,column);
    %* User has specifically declared an exportlength using _cstTrimAlgorithm=MAXCOLMETA  *;
    %if &_cstMaxColMeta=1 %then
    %do;
        newlengths=catx(' ',newlengths,put(exportlength,8.));
    %end;
    %else %if &_cstTrimAlgorithm=MAXCODELIST %then
    %do;
        newlengths=catx(' ',newlengths,put(_cstCTMax,8.));
    %end;
    %else %if &_cstTrimAlgorithm=MAXEXPECTED %then
    %do;
        newlengths=catx(' ',newlengths,put(&_cstMaxExpected,8.));
    %end;
        curlengths=catx(' ',curlengths,put(length,8.));
    
        if last then do;
          call symputx('_cstColCnt',_n_);
          call symputx('_cstColList',collist);
          call symputx('_cstNewLenList',newlengths);
          call symputx('_cstDefLenList',curlengths);
        end;
    run;

    %let _cstObsLenList=;  %* Reset for each table  *;
    %do _cstColIter=1 %to &_cstColCnt;
      %let _cstColumn=%scan(&_cstColList,&_cstColIter,' ');
      proc sql noprint;
        select max(length(&_cstColumn)) into: _cstMaxObserved
        from &_csttable;
      quit;
      %let _cstMaxObserved=%sysfunc(max(&_cstMaxObserved,1));
      %let _cstObsLenList=&_cstObsLenList &_cstMaxObserved;
    %end;

    %***************************************************************;
    %* This is the code segment where the trim decision is made.   *;
    %* Changes (and instances of being unable to make desired      *;
    %*  changes) are reported here.                                *;
    %*                                                             *;
    %* At this point we have available:                            *;
    %* _cstColList - columns of interest in this data set          *;
    %* _cstNewLenList - derived alternative lengths based on       *;
    %*               _cstTrimAlgorithm parameter setting           *;
    %* _cstDefLenList - pre-defined lengths for column subset      *;
    %* _cstColCnt - number of columns in _cstColList               *;
    %* _cstObsLenList - maximum observed lengths in this data set  *;
    %***************************************************************;

    %let _cstLengthStmt=length ;
    %do _cstColIter=1 %to &_cstColCnt;
      %let _cst_rcmsg=;
      %let _cstDontAllowUpdate=0;
      %let _cstColumn=%scan(&_cstColList,&_cstColIter,' ');
      %let _cstNewLen=%scan(&_cstNewLenList,&_cstColIter,' ');
      %let _cstDefLen=%scan(&_cstDefLenList,&_cstColIter,' ');
      %let _cstObsLen=%scan(&_cstObsLenList,&_cstColIter,' ');

      %if &_cstDeBug=1 %then
      %do;
        %put Column:                       &=_cstColumn;
        %put Column count:                 &=_cstColCnt;
        %put List of columns:              &=_cstColList;
        %put &=_cstNewLenList;
        %put Candidate revised length:     &=_cstNewLen;
        %put &=_cstDefLenList;
        %put Current defined length:       &=_cstDefLen;
        %put &=_cstObsLenList;
        %put Current maximum length found: &=_cstObsLen;
      %end;
      
      %let _cstLogMessage=1;
      
      %if &_cstTrimAlgorithm=MAXOBSERVED %then
      %do; 
        %* Observed can never be larger than the defined lengths  *;
        %if &_cstResizeStrategy=INCREASE %then
        %do;
          %put NOTE: [CSTLOG%str(MESSAGE).&_cstSrcMacro] Specification of _cstResizeStrategy=INCREASE will have no effect when _cstTrimAlgorithm=MAXOBSERVED.;
          %goto exit_macro;
        %end;
        %if &_cstObsLen<&_cstDefLen %then 
        %do;
          %let _cst_rcmsg=&_cstTable..&_cstColumn length has been changed from $&_cstDefLen to $&_cstObsLen in &_cstOutputDS;
          %let _cstLengthStmt=&_cstLengthStmt &_cstColumn $&_cstObsLen;
        %end;
      %end;
      %else %if &_cstTrimAlgorithm=MAXCODELIST %then
      %do; 
        %if &_cstNewLen=. %then 
        %do;
          %if _cstDeBug=1 %then
          %do;
            %let _cst_rcmsg=&_cstTable..&_cstColumn length will not be modified - no associated codelist found in FMTSEARCH;
            %let _cstLogMessage=0;
          %end;
        %end;
        %if &_cstResizeStrategy=DECREASE or &_cstResizeStrategy=BOTH %then
        %do;
          %if &_cstNewLen ^= . and &_cstNewLen<&_cstDefLen %then 
          %do;
            %if &_cstNewLen<&_cstObsLen %then 
            %do;
              %let _cstDontAllowUpdate=1;
              %let _cstLogMessage=0;
              %let _cst_rcmsg=&_cstTable..&_cstColumn length was not modified because it would cause value truncation;
            %end;
            %else %do;
              %let _cst_rcmsg=&_cstTable..&_cstColumn length has been changed from $&_cstDefLen to $&_cstNewLen in &_cstOutputDS;
              %let _cstLengthStmt=&_cstLengthStmt &_cstColumn $&_cstNewLen;
            %end;
          %end;
        %end;
        %if &_cstResizeStrategy=INCREASE or &_cstResizeStrategy=BOTH %then
        %do;
          %if &_cstNewLen>&_cstDefLen %then 
          %do;
            %let _cst_rcmsg=&_cstTable..&_cstColumn length has been changed from $&_cstDefLen to $&_cstNewLen in &_cstOutputDS;
            %let _cstLengthStmt=&_cstLengthStmt &_cstColumn $&_cstNewLen;
          %end;
        %end;
      %end;
      %else %if &_cstTrimAlgorithm=MAXCOLMETA or &_cstTrimAlgorithm=MAXEXPECTED %then
      %do; 
        %if &_cstResizeStrategy=DECREASE or &_cstResizeStrategy=BOTH %then
        %do;
          %if &_cstNewLen ^= . and &_cstNewLen<&_cstDefLen %then 
          %do;
            %if &_cstNewLen<&_cstObsLen %then 
            %do;
              %let _cstDontAllowUpdate=1;
              %let _cstLogMessage=0;
              %let _cst_rcmsg=&_cstTable..&_cstColumn length was not modified because it would cause value truncation;
            %end;
            %else %do;
              %let _cst_rcmsg=&_cstTable..&_cstColumn length has been changed from $&_cstDefLen to $&_cstNewLen in &_cstOutputDS;
              %let _cstLengthStmt=&_cstLengthStmt &_cstColumn $&_cstNewLen;
            %end;
          %end;
        %end;
        %if &_cstResizeStrategy=INCREASE or &_cstResizeStrategy=BOTH %then
        %do;
          %if &_cstNewLen>&_cstDefLen %then 
          %do;
            %let _cst_rcmsg=&_cstTable..&_cstColumn length has been changed from $&_cstDefLen to $&_cstNewLen in &_cstOutputDS;
            %let _cstLengthStmt=&_cstLengthStmt &_cstColumn $&_cstNewLen;
          %end;
        %end;
      %end;
      
      %if %length(&_cst_rcmsg)>0 %then
      %do;
        %if &_cstRptType=LOG %then 
        %do;
          %if &_cstDontAllowUpdate=1 %then
            %put WAR%STR(NING): [CSTLOG%str(MESSAGE).&_cstSrcMacro]: &_cst_rcmsg;
          %else
            %put [CSTLOG%str(MESSAGE).&_cstSrcMacro]: &_cst_rcmsg;
        %end;
        %else %if &_cstRptType=CSTRESULTSDS %then 
        %do;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %if &_cstDontAllowUpdate=1 %then
          %do;
            %cstutil_writeresult(
                   _cstResultId=CST0201
                  ,_cstResultParm1=&_cst_rcmsg
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcMacro
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  );    
          %end;
          %else %do;
            %cstutil_writeresult(
                   _cstResultId=CST0200
                  ,_cstResultParm1=&_cst_rcmsg
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcMacro
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  );    
          %end;
        %end;
        %else %if &_cstRptType=TRANSACTIONLOG %then
        %do;
          %if &_cstDontAllowUpdate=1 %then
            %put WAR%STR(NING): [CSTLOG%str(MESSAGE).&_cstSrcMacro]: &_cst_rcmsg;
          %else %if &_cstLogMessage=1 %then
          %do;
            %let _cstReturnCode=%sysfunc(fput(&_cstfid,&_cstTable|&_cstColumn|&_cst_rcmsg));
            %let _cstReturnCode=%sysfunc(fwrite(&_cstfid));
          %end;
        %end;
      %end;
      %let _cst_rcmsg=;
      %let _cst_rc=0;
    %end;

    %*************************;
    %* Apply length updates  *;
    %*************************;

    %let _cstSaveOpt=%sysfunc(getoption(varlenchk));
    options varlenchk=nowarn; 
    
    data &_cstOutputDS
    %if %length(&_cstDSLabel)>0 %then
    %do;
      (label="&_cstDSLabel")
    %end;
      ;
      retain &_cstAllDSVars;
      &_cstLengthStmt;
        set &_cstTable;
    run;
    %if (&syserr gt 4) %then
    %do;
      %let _cst_rcmsg=Updates to &_cstTable failed.;
      %goto exit_error;
    %end;
    
    %if %length(&_cstDSKeys)>0 %then
    %do;
      proc sort data=&_cstOutputDS
      %if %length(&_cstDSLabel)>0 %then
      %do;
        (label="&_cstDSLabel")
      %end;
      ;
        by &_cstDSKeys;
      run;
      %if (&syserr gt 4) %then
      %do;
        %let _cst_rcmsg=Updates to &_cstTable failed.;
        %goto exit_error;
      %end;
    %end;

  %end;
  
  %if &_cstRptType=TRANSACTIONLOG %then 
  %do;
  
    %let _cstReturnCode=%sysfunc(fclose(&_cstfid));

    data &_cstTransCopyDS (keep=cststandard cststandardversion cstuser cstmacro cstfilepath cstmessage cstcurdtm cstdataset cstcolumn cstactiontype cstentity);
      attrib &_cstLogAttrString;
      infile &_cstDir length=reclen pad missover recfm=v lrecl=255; 
      input line $varying255. reclen;

    %if %symexist(_cstStandard) %then 
    %do;
        cststandard=ktrim("&_cstStandard");
    %end;
    %else %do;
        cststandard="";
    %end;
    %if %symexist(_cstStandardVersion) %then 
    %do;
        cststandardversion=ktrim("&_cstStandardVersion");
    %end;
    %else %do;
        cststandardversion="";
    %end;
        cstuser=ktrim("&SYSUSERID");
        cstmacro=ktrim("&_cstSrcMacro");
        cstfilepath=ktrim(pathname(ksubstr("&_cstTable",1,kindexc(ktrim("&_cstTable"),'.')-1)));
        cstcurdtm=datetime();
        cstdataset=scan(line,1,'|');
        cstcolumn=scan(line,2,'|');
        cstmessage=scan(line,3,'|');
        cstactiontype="UPDATE";
        cstentity="COLUMN";
    run;
      
    %let _cstReturnCode=%sysfunc(fdelete(&_cstdir));
    %let _cstReturnCode=%sysfunc(filename(_cstdir));    
      
    %***********************************;
    %*  Write to transaction data set  *;
    %***********************************;
    %* Following call to cstutillogevent also unlocks the transaction data set  *;
    %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
    %cstutil_deletedataset(_cstDataSetName=&_cstTransCopyDS);
  %end;

  %******************************;
  %* Copy any unmodified files  *;
  %******************************;

  %if &_cstAllTableCnt ^= &_cstTableCnt %then
  %do;
    %let _cstAllTableList=%sysfunc(tranwrd(&_cstAllTableList,&_cstSrcLibref,%str()));
    %let _cstAllTableList=%sysfunc(compbl(%sysfunc(tranwrd(&_cstAllTableList,%str(.),%str()))));

    proc copy in=&_cstSrcLibref out=&_cstOutLibref;
      select &_cstAllTableList;
    run;
    %if (&syserr gt 4) %then
    %do;
      %let _cst_rcmsg=Copy of unmodified data sets failed.;
      %goto exit_error;
    %end;
    
    %do i=1 %to %sysfunc(countw(&_cstAllTableList,' '));
      %let _cstTable=%sysfunc(scan(&_cstAllTableList,&i,' '));
      %let _cst_rcmsg=&_cstSrcLibref..&_cstTable copied unmodified to &_cstOutLibref..&_cstTable;

      %if &_cstRptType=CSTRESULTSDS %then 
      %do;
        %let _cst_rc=0;
        %let _cstSeqCnt=&i;
        %cstutil_writeresult(
                _cstResultId=CST0200
                ,_cstResultParm1=&_cst_rcmsg
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cst_rc
                ,_cstRCParm=&_cst_rc
                );
      %end;
      %else %if &_cstRptType=LOG %then
        %put NOTE: [CSTLOG%str(MESSAGE).&_cstSrcMacro] &_cst_rcmsg;

    %end;
    %let _cst_rcmsg=;
  %end;

  %goto exit_macro;

  %****************************;
  %*  Handle any errors here  *;
  %****************************;
%exit_error:
  
  %let _cst_rc=1;
  %if &_cstRptType=CSTRESULTSDS %then 
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0202
                ,_cstResultParm1=&_cst_rcmsg
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cst_rc
                ,_cstRCParm=&_cst_rc
                );
  %end;
  %else %if %length(&_cst_rcmsg)>0 %then
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&_cstSrcMacro] &_cst_rcmsg;
  %goto exit_macro;

%exit_macro:

  options varlenchk=&_cstSaveOpt;
  
  %if &_cstAllTableCnt=0 %then
    %put NOTE: [CSTLOG%str(MESSAGE).&_cstSrcMacro] No tables/columns found based on current source parameter settings.;
  %else %if &_cstTableCnt=0 %then
    %put NOTE: [CSTLOG%str(MESSAGE).&_cstSrcMacro] No tables/columns have been modified based on current parameter settings.;

  %* Delete the temporary messages data set if it was created here;
  %if (&_cstNeedToDeleteMsgs=1) %then %do;
    %if %eval(%index(&_cstMessages,.)>0) %then %do;
      %let _cstMsgDir=%scan(&_cstMessages,1,.);
      %let _cstMsgMem=%scan(&_cstMessages,2,.);
    %end;
    %else %do;
      %let _cstMsgDir=work;
      %let _cstMsgMem=&_cstMessages;
    %end;
    proc datasets nolist lib=&_cstMsgDir;
      delete &_cstMsgMem / mt=data;
      quit;
    run;
  %end;

  %if &_cstDeBug<1 %then
  %do;
    * Clean up temporary data sets if they exist;
    %cstutil_deletedataset(_cstDataSetName=work._cstColumns);
    %cstutil_deletedataset(_cstDataSetName=work._cstColumnMetadata);
  %end;    

%mend cstutilmanagecolumnsize;

