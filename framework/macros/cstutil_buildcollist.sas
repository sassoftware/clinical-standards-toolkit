%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_buildcollist                                                           *;
%*                                                                                *;
%* Builds columns based on the value from validation_control.columnscope.         *;
%*                                                                                *;
%* This macro builds a set of columns (in either list format or data set format)  *;
%* based on the value from the validation check control file                      *;
%* validation_control.columnscope.                                                *;
%*                                                                                *;
%* The expected result is that the work._csttablemetadata and                     *;
%* work._cstcolumnmetadata data sets are created and are in synchronization. This *;
%* means that they are consistent with regard to the tables based on resolving    *;
%* the tableScope and columnScope check macro fields.                             *;
%*                                                                                *;
%* The rules used to interpret columnScope values (using mostly CDISC SDTM        *;
%* examples):                                                                     *;
%*   - validation_control.columnscope can be null.                                *;
%*   - Blanks are converted to "+" (for example, LBDTC LBENDTC becomes            *;
%*     LBDTC+LBENDTC).                                                            *;
%*   - The value must not begin with "+" or "-".                                  *;
%*   - If the blank conversion results in multiple "+" characters, all but one of *;
%*     these characters are removed (for example, AE1 +DM1 becomes AE1++DM1,      *;
%*     which becomes AE1+DM1).                                                    *;
%*   - No attempt is made to assess the validity of the columnScope value (for    *;
%*     example, **TEST-AE1 is allowed, although no change to the resolved set of  *;
%*     **TEST columns occurs).                                                    *;
%*   - The derived set of columns is built by parsing columnScope from left to    *;
%*     right (for example, ALL-**TEST builds a set of all columns removing all    *;
%*     **TEST columns).                                                           *;
%*   - If <libref> is included, it must be listed in the SASReferences.SASRef     *;
%*     column.                                                                    *;
%*   - Wildcard conventions:                                                      *;
%*        - Must use the string **                                                *;
%*        - Can appear as a suffix (for example, SUPP**, for all columns that     *;
%*          start with SUPP)                                                      *;
%*        - Can appear as a prefix (for example, **DTC, for all columns that end  *;
%*          with DTC)                                                             *;
%*        - Can appear alone (for example, **), which is equivalent to _ALL_      *;
%*        - Use <table>.** for all columns in the specified data set              *;
%*        - Use **.USUBJID for all USUBJID columns across referenced data sets    *;
%*   - Sublists are delimited by brackets, and resolved lengths (that is,         *;
%*     # columns) must be the same unless _cst*SubOverride is set to Y. Sublists  *;
%*     must conform to the non-sublist rules stated above.                        *;
%*   - A special naming convention of <column>:<value>, such as                   *;
%*     QUALIFIERS:DATETIME, enables you to specify to subset columns a            *;
%*     _cstColumnMetadata column and column value. In this example, all           *;
%*     _cstColumnMetadata.QUALIFIERS='DATETIME' columns are returned.             *;
%*                                                                                *;
%* Sample columnscope values:                                                     *;
%*   _ALL_                    (all columns)                                       *;
%*   AESEQ                    (a single column)                                   *;
%*   LBDTC+LBENDTC            (multiple columns)                                  *;
%*   QUALIFIERS:DATETIME      (_cstColumnMetadata.QUALIFIERS='DATETIME')          *;
%*   **TEST                   (all columns ending in "TEST")                      *;
%*   DM**                     (all columns beginning with "DM")                   *;
%*   **TEST+**TESTCD          (all columns ending in "TEST" or "TESTCD")          *;
%*   [AESTDY+CMSTDY+EXSTDY][AEENDY+CMENDY+EXENDY]     (two paired sublists)       *;
%*   SRCDATA1.AE.AESTDY+SRCDATA2.AE.AESTDY  (AESTDY column from AE data sets in   *;
%*                              two different libraries)                          *;
%*   AE.**                    (all columns in the AE table)                       *;
%*   **.USUBJID               (all USUBJID columns from all tables)               *;
%*                                                                                *;
%* Required global macro variables (beyond reporting and debugging variables):    *;
%*   _cstTableMetadata                                                            *;
%*   _cstColumnMetadata                                                           *;
%*                                                                                *;
%* Required file inputs:                                                          *;
%*   work._cstcolumnmetadata                                                      *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstMsgID Results: Result or validation check ID                       *;
%* @macvar _cstMsgParm1 Messages: Parameter 1                                     *;
%* @macvar _cstMsgParm2 Messages: Parameter 2                                     *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstColumnScope Column scope as defined in validation check metadata   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstColumnMetadata Table that contains column metadata referenced in   *;
%*             _cstStandard                                                       *;
%* @macvar _cstTableMetadata Table that contains table metadata referenced in     *;
%*             _cstStandard                                                       *;
%* @macvar _cstTableScope Table scope as defined in validation check metadata     *;
%*                                                                                *;
%* @param _cstFormatType - required - The format type:                            *;
%*            LIST:    Sets macro variables of # tables and space-delimited list  *;
%*                     of tables.                                                 *;
%*            DATASET: Returns a data set of tables that match the tableScope     *;
%*                     specification.                                             *;
%*            Values: LIST | DATASET                                              *;
%*            Fefault: DATASET                                                    *;
%* @param _cstColWhere - optional - The WHERE clause to subset the returned set   *;
%*            of columns. The WHERE clause is applied as the last step.           *;
%* @param _cstDomWhere - optional - The WHERE clause to subset the returned set   *;
%*            of tables. The WHERE clause is applied as the last step.            *;
%* @param _cstStd - required - The name of the registered standard. Typically     *;
%*            used only with a validation that involves multiple standards.       *;
%*            Default: &_cstStandard                                              *;
%* @param _cstStdVer - required - The version of _cstStd. Typically used only     *;
%*            with validation that involves multiple standards.                   *;
%*            Default: &_cstStandardVersion                                       *;
%* @param _cstColDSName - conditional - The name of the data set with column      *;
%*            metadata returned when _cstFormatType=DATASET.                      *;
%*            Default: &_cstColumnMetadata                                        *;
%* @param _cstDomDSName - conditional - The name of the data set with table       *;
%*            metadata returned when _cstFormatType=DATASET.                      *;
%*            Default: &_cstTableMetadata                                         *;
%* @param _cstColSubOverride - required - Override sublist processing to allow    *;
%*            sublists of different lengths (such as                              *;
%*            columnScope=[**DTC][RFSTDTC] ).                                     *;
%*            Values: N | Y                                                       *;
%*            Default: N                                                          *;
%* @param _cstDomSubOverride - required - Override sublist processing to allow    *;
%*            sublists of different lengths (such as tableScope=[_ALL_-DM][DM] ). *;
%*            Values: N | Y                                                       *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @history 2016-03-18 Added sublist discrepancy reporting (1.6.1 and 1.7.1)      *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_buildcollist(
    _cstFormatType=DATASET,
    _cstColWhere=,
    _cstDomWhere=,
    _cstStd=&_cstStandard,
    _cstStdVer=&_cstStandardVersion,
    _cstColDSName=&_cstColumnMetadata,
    _cstDomDSName=&_cstTableMetadata,
    _cstColSubOverride=N,
    _cstDomSubOverride=N
    )  / des ='CST: Build column list from columnscope';

  %cstutil_setcstgroot;

  %local
    _cstDomain
    _cstexit_error
    _cstModifiedSubList
    _cstProblem
    _cstSubList
    _cstSublistCnt
    _cstTCnt
    _cstDomSubListCnt
    _cstMultiStd
    _cstVarList1
    _cstVarList2
  ;

  %if &_cstDebug %then
  %do;
    %put cstutil_buildcollist >>>;
    %put *********************************************************;
    %put _cstFormatType = &_cstFormatType;
    %put _cstColWhere = &_cstColWhere;
    %put _cstDomWhere = &_cstDomWhere;
    %put _cstDomDSName = &_cstDomDSName;
    %put _cstColDSName = &_cstColDSName;
    %put _cstColSubOverride = &_cstColSubOverride;
    %put _cstDomSubOverride = &_cstDomSubOverride;
    %put TableScope = &_cstTableScope;
    %put ColumnScope = &_cstColumnScope;
    %put *********************************************************;
  %end;

  %let _cstTCnt=0;
  %let _cstDomain=;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstActual=;
  %let _cstSrcData=&sysmacroname;
  %let _cst_rc=0;
  %let _cstexit_error=0;
  %let _cstProblem=0;
  %let _cstColumnSublistCnt=1;
  %let _cstSublistCnt=1;
  %let _cstVarlistCnt=0;
  %let _cstDomSubListCnt=0;
  %let _cstMultiStd=;

  %cstutil_builddomlist(_cstFormatType=DATASET,_cstStd=&_cstStd,_cstStdVer=&_cstStdVer,_cstDomDSName=&_cstDomDSName,
                        _cstSubOverride=&_cstDomSubOverride);

  %if &_cst_rc  or ^%sysfunc(exist(&_cstDomDSName)) %then
  %do;
      %let _cst_MsgID=CST0002;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;
  
  * Populate _cstMultiStd when a single table metadata data set references         *;
  *  multiple standards.  This is expected to happen only with Internal Validation *;
  *  that compares data sets across standards.                                     *;
  proc sql noprint;
    select count(*) as _cstCnt into :_cstMultiStd
    from (select distinct standard,standardversion from &_cstDomDSName) having _cstCnt>1;
  quit;

  %***************************************************;
  %* We have a valid work._csttablemetadata data set *;
  %***************************************************;

  %if %upcase(&_cstFormatType)=DATASET or %upcase(&_cstFormatType)=LIST %then
  %do;

    %*******************************************************************************;
    %* Evaluate _cstColumnScope global macro and handle any discrepancy conditions *;
    %*******************************************************************************;

    proc sort data=&_cstColumnMetadata out=work._cstcolumnmetadata;
      by SASref table order;
    run;

    %*****************************************************************;
    %* At this point, assume we have a valid work._cstcolumnmetadata *;
    %* data set that points either to source or reference metadata,  *;
    %* and if source metadata, multiple source data SASRefs may be   *;
    %* available in the data set.                                    *;
    %*****************************************************************;

    %if %length(&_cstColumnScope)=0 %then
    %do;

      * Keep a copy of the target tables for use by any checks that loop through *;
      *  domains regardless of whether there are any valid columns.              *;
      * Example:  cstcheck_columnexists macro                                    *;
      data work._cstalltablemetadata;
        set work._csttablemetadata;
      run;

      %* We will interpret this as wanting all columns in the tableScope subset of tables. *;
      data work._cstcolumnmetadata;
        merge
          %if %length(&_cstColWhere)=0 %then
          %do;
              work._cstcolumnmetadata (in=_col)
          %end;
          %else
          %do;
              work._cstcolumnmetadata (in=_col where=(&_cstColWhere))
          %end;

          %if %length(&_cstDomWhere)=0 %then
          %do;
              work._csttablemetadata (in=_tab keep=SASref table);
          %end;
          %else
          %do;
              work._csttablemetadata (in=_tab keep=SASref table where=(&_cstDomWhere));
          %end;

          by SASref table;
        if _tab and _col;
        sublist=1;
        suborder=1;
      run;
    %end;
    %else
    %do;

      %if %SYSFUNC(indexc(&_cstColumnScope,' ')) %then
      %do;
         %* Translate any blanks to + signs;
         %let _cstColumnScope=%sysfunc(tranwrd(%sysfunc(trim(&_cstColumnScope)),%str( ),%str(+)));
      %end;
      %if %SYSFUNC(indexc(&_cstColumnScope,'++')) %then
      %do;
         %* Translate multiple + signs to single + signs;
         %let _cstColumnScope=%sysfunc(tranwrd(%sysfunc(trim(&_cstColumnScope)),%str(++),%str(+)));
      %end;

      data work._csttempcolumnmetadata (label="Temporary work file");
        set work._cstcolumnmetadata;
        sublist=.;
        suborder=.;
        varorder=.;
        stop;
      run;

      %*******************************************************;
      %* _cstColumnScope contains sublists, like:            *;
      %*   [AESTDY+CMSTDY+EXSTDY][AEENDY+CMENDY+EXENDY]      *;
      %*                                                     *;
      %* Processing of multiple sublists is self-contained   *;
      %* within this loop given their unique nature.         *;
      %*******************************************************;

      %let _cstSublistCnt = %SYSFUNC(countw(&_cstColumnScope,'['));

      %* By default, countw will return a 1 if the delimiter is not found ;
      %if &_cstSublistCnt > 1 %then
      %do;

        %let _cstColumnSublistCnt=&_cstSublistCnt;

        %do i= 1 %to &_cstSublistCnt;

          %let _cstSubList = %scan(&_cstColumnScope, &i , "]");
          %let _cstSubList=%sysfunc(tranwrd(%sysfunc(trim(&_cstSubList)),%str([),%str()));
          %let _cstModifiedSubList=&_cstSubList;

          %cstutil_parsecolumnscope(_cstscopestr=&_cstSubList,_cstopsource=&_cstModifiedSubList,_cstsublistnum=&i);
          %if &_cst_rc %then
          %do;
            %let _cstexit_error=0;
            %goto exit_error;
          %end;

        %end;  %* end of do=1 to n sublists loop;

        %****************************************************************;
        %* work._csttempcolumnmetadata has been created, now check for  *;
        %* equivalent sublist lengths.  If not equivalent, report error *;
        %****************************************************************;

        proc sort data=work._csttempcolumnmetadata out=work._cstcolumnmetadata;
          by SASref table order;
        run;

        * Keep a copy of the target tables for use by any checks that loop through *;
        *  domains regardless of whether there are any valid columns.              *;
        * Example:  cstcheck_columnexists macro                                    *;
        data work._cstalltablemetadata;
          set work._csttablemetadata;
        run;

        * Rebuild table metadata to reflect column processing *;
        data work._csttablemetadata;
          merge work._cstcolumnmetadata (keep=sasref table in=col)
                work._csttablemetadata (in=tab);
            by sasref table;
          if col and tab and first.table;
        run;

        * Rebuild column metadata to reflect table processing *;
        data work._cstcolumnmetadata;
          merge work._cstcolumnmetadata (in=col)
                work._csttablemetadata (keep=sasref table in=tab);
            by sasref table;
          if col and tab;
        run;

        proc sort data=work._cstcolumnmetadata;
          by sublist suborder;
        run;

        data work._cstcolumnmetadata;
          set work._cstcolumnmetadata (drop=suborder);
            by sublist;
          if first.sublist then suborder=1;
          else suborder+1;
        run;

        %if %upcase(&_cstColSubOverride)=N %then
        %do;

          proc sql noprint;
            select count(distinct listcnt) into :_cstProblem
              from (select sublist, count(*) as listCnt
                from work._cstcolumnmetadata
                  group by sublist);
          quit;
          %if (&sqlrc gt 0) %then
          %do;
            %* Check failed - SAS error  *;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Proc SQL sublist length assessment;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstexit_error=1;
            %goto exit_error;
          %end;

          %if &_cstProblem>1 %then
          %do;
            proc sql noprint;
              select column into :_cstVarList1 separated by ' '
                from work._cstcolumnmetadata where sublist=1;
              select column into :_cstVarList2 separated by ' '
                from work._cstcolumnmetadata where sublist=2;
            quit;
            %put [CSTLOG%str(MESSAGE)] The following incompatible sublist lengths were found for checkId=&_cstCheckID and resultSeq=&_cstResultSeq;
            %put [CSTLOG%str(MESSAGE)] Sublist1: &_cstVarList1;
            %put [CSTLOG%str(MESSAGE)] Sublist2: &_cstVarList2;
            %let _cst_MsgID=CST0023;
            %let _cst_MsgParm1=columnscope;
            %let _cst_MsgParm2=;
            %let _cstactual=%str(Sublist1=&_cstVarList1,Sublist2=&_cstVarList2);
            %if %eval(%klength(&_cstactual)>240) %then 
            %do;
              %let _cstactual=%substr(&_cstactual,1,237)...;
              %let _cstResultDetails=The actual column value has been truncated. See the log for the complete sublist values.;
            %end;
            %let _cst_rc=0;
            %let _cstexit_error=1;
            %goto exit_error;
          %end;
        %end;  %* End of _cstColSubOverride loop  *;

        %let _cstexit_error=0;
        %goto exit_error;
      %end; %* end of >1 sublist processing ;


      %*******************************************************;
      %* _cstColumnScope contains one or more sublists like: *;
      %*   {_cstList:AESTDY+CMSTDY+EXSTDY}                   *;
      %*                                                     *;
      %* This is a special syntax supporting multi-column    *;
      %* processing                                          *;
      %*******************************************************;

      %else %if %SYSFUNC(indexc(&_cstColumnScope,'{')) %then
      %do;

        %let _cstVarlistCnt = %SYSFUNC(countw(&_cstColumnScope,'{'));

        %do i= 1 %to &_cstVarlistCnt;

          %let _cstSubList = %scan(&_cstColumnScope, &i , "}");
          %let _cstSubList=%sysfunc(tranwrd(%sysfunc(trim(&_cstSubList)),%str({),%str()));
          %let _cstModifiedSubList=&_cstSubList;

          %cstutil_parsecolumnscope(_cstscopestr=&_cstSubList,_cstopsource=&_cstModifiedSubList,_cstsublistnum=&i);
          %if &_cst_rc %then
          %do;
            %let _cstexit_error=0;
            %goto exit_error;
          %end;

        %end;  %* end of do=1 to n sublists loop;

        %****************************************************************;
        %* work._csttempcolumnmetadata has been created, now check for  *;
        %* equivalent sublist lengths.  If not equivalent, report error *;
        %****************************************************************;

        proc sort data=work._csttempcolumnmetadata out=work._cstcolumnmetadata;
          by SASref table order;
        run;

        * Keep a copy of the target tables for use by any checks that loop through *;
        *  domains regardless of whether there are any valid columns.              *;
        * Example:  cstcheck_columnexists macro                                    *;
        data work._cstalltablemetadata;
          set work._csttablemetadata;
        run;

        data work._csttablemetadata;
          set work._csttablemetadata;
            by SASref table;
          if first.table;
        run;

        * Rebuild table metadata to reflect column processing *;
        data work._csttablemetadata;
          merge work._cstcolumnmetadata (keep=sasref table in=col)
                work._csttablemetadata (in=tab);
            by sasref table;
          if col and tab and first.table;
        run;

        * Rebuild column metadata to reflect table processing *;
        data work._cstcolumnmetadata;
          merge work._cstcolumnmetadata (drop=suborder in=col)
                work._csttablemetadata (keep=sasref table in=tab);
            by sasref table;
          if col and tab;
          retain suborder 0;
          if first.table then suborder+1;
        run;

        %if %upcase(&_cstColSubOverride)=N %then
        %do;

          proc sql noprint;
            select count(distinct listcnt) into :_cstProblem
              from (select sublist, count(*) as listCnt
                from work._cstcolumnmetadata
                  group by sublist);
          quit;
          %if (&sqlrc gt 0) %then
          %do;
            %* Check failed - SAS error  *;
            %let _cst_MsgID=CST0050;
            %let _cst_MsgParm1=Proc SQL sublist length assessment;
            %let _cst_MsgParm2=;
            %let _cst_rc=0;
            %let _cstexit_error=1;
            %goto exit_error;
          %end;

          %if &_cstProblem>1 %then
          %do;
            proc sql noprint;
              select column into :_cstVarList1 separated by ' '
                  from work._cstcolumnmetadata where sublist=1;
              select column into :_cstVarList2 separated by ' '
                  from work._cstcolumnmetadata where sublist=2;
            quit;
            %put [CSTLOG%str(MESSAGE)] The following incompatible sublist lengths were found for checkId=&_cstCheckID and resultSeq=&_cstResultSeq;
            %put [CSTLOG%str(MESSAGE)] Sublist1: &_cstVarList1;
            %put [CSTLOG%str(MESSAGE)] Sublist2: &_cstVarList2;
            %let _cst_MsgID=CST0023;
            %let _cst_MsgParm1=columnscope;
            %let _cst_MsgParm2=;
            %let _cstactual=%str(Sublist1=&_cstVarList1,Sublist2=&_cstVarList2);
            %if %eval(%klength(&_cstactual)>240) %then 
            %do;
              %let _cstactual=%substr(&_cstactual,1,237)...;
              %let _cstResultDetails=The actual column value has been truncated. See the log for the complete sublist values.;
            %end;
            %let _cst_rc=0;
            %let _cstexit_error=1;
            %goto exit_error;
          %end;
        %end;  %* End of _cstColSubOverride loop  *;

        %let _cstexit_error=0;
        %goto exit_error;
      %end; %* end of >1 sublist processing ;

      %else
      %do;
        %******************************************************;
        %* Everything else except multiple sublists:          *;
        %*   AESEV  _ALL_  QUALIFIERS:DATETIME-**DTC          *;
        %*   SRCDATA1.AE.AESEV+SRCDATA2.AE.AESEV              *;
        %*   SUPP**    **DTC    AE.**                         *;
        %*   [RFSTDTC+RFENDTC]                                *;
        %******************************************************;

        %let _cstColumnScope=%SYSFUNC(compress(&_cstColumnScope,']['));

        %* _cstDomSubListCnt indicates the number of tablescope sublists as set in cstutil_builddomlist().  *;
        %* This loop adds duplicate records to work._csttempcolumnmetadata for each columnscope column,     *;
        %*  one per tablescope sublist.  This supports Internal Validation of like-named tables across      *;
        %*  multiple standards defined in tablescope.                                                       *;
        %if %length(&_cstMultiStd)<1 %then
          %let _cstDomSubListCnt=1;
        %do domj=1 %to &_cstDomSubListCnt;
          %cstutil_parsecolumnscope(_cstscopestr=&_cstColumnScope,_cstopsource=&_cstColumnScope,_cstsublistnum=&domj);
          %if &_cst_rc %then
          %do;
            %let _cstexit_error=0;
            %goto exit_error;
          %end;
        %end;

        proc sort data=work._csttempcolumnmetadata out=work._cstcolumnmetadata;
          by SASref table;
        run;

        data work._cstcolumnmetadata;
          merge
            %if %length(&_cstColWhere)=0 %then
            %do;
                work._cstcolumnmetadata (in=_col)
            %end;
            %else
            %do;
                work._cstcolumnmetadata (in=_col where=(&_cstColWhere))
            %end;

            %if %length(&_cstDomWhere)=0 %then
            %do;
                work._csttablemetadata (in=_tab keep=SASref table);
            %end;
            %else
            %do;
              work._csttablemetadata (in=_tab keep=SASref table where=(&_cstDomWhere));
            %end;

            by SASref table;
              if _tab and _col;
        run;

        %if %length(&_cstMultiStd)>0 %then
        %do;
          proc sort data=work._cstcolumnmetadata;
            by sasref table column;
          run;
          proc sort data=work._csttablemetadata;
            by sasref table;
          run;
          data work._cstcolumnmetadata;
            merge work._cstcolumnmetadata (in=col)
                  work._csttablemetadata (keep=sasref table tsublist in=tab);
              by sasref table;
            if tab;
          run;
          data work._cstcolumnmetadata;
            set work._cstcolumnmetadata;
              by sasref table column;
            if first.column;
          run;
        %end;

        * Reset suborder value *;
        data work._cstcolumnmetadata;
         set work._cstcolumnmetadata (drop=suborder);
            by SASref table;
           retain suborder 0;
           if first.table then suborder=1;
           else suborder+1;
        run;

        * Keep a copy of the target tables for use by any checks that loop through *;
        *  domains regardless of whether there are any valid columns.              *;
        * Example:  cstcheck_columnexists macro                                    *;
        data work._cstalltablemetadata;
          set work._csttablemetadata;
        run;

        * Rebuild table metadata to reflect above column processing *;
        data work._csttablemetadata;
          merge work._cstcolumnmetadata (keep=sasref table in=col)
                work._csttablemetadata (in=tab);
            by sasref table;
          if col and tab and first.table;
        run;
      %end;
    %end;  %* end of non-missing columnScope loop *;
  %end;
  %else
  %do;
    %let _cst_MsgID=CST0015;
    %let _cst_MsgParm1=Type;
    %let _cst_MsgParm2=cstutil_buildcollist;
    %let _cst_rc=0;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

 %exit_error:

  %if &_cstexit_error %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %let _cstSrcData=&sysmacroname;
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
                  ,_cstActualParm=&_cstActual
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );

  %end;
  %else
  %do;
    %*****************************************************************;
    %* This section does any reformatting of results to conform to   *;
    %*  the input parameters.  If DATASET format, return the data    *;
    %*  specified or implied in the _cstDomDSName parameter.  If     *;
    %*  LIST format, populate the necessary macro variables.         *;
    %*****************************************************************;
/*
    %* Set work data set name to calling input parameter data set name *;
    %if %length(&_cstDomDSName)<1 %then
      %let _cstDomDSName=work._csttablemetadata;
    %if %length(&_cstColDSName)<1 %then
      %let _cstColDSName=work._cstcolumnmetadata;
*/
    %if %upcase(&_cstFormatType)=LIST %then
    %do;
      %let _cstColumnSublistCnt=&_cstSublistCnt;

      proc sql noprint;
        select sasref into :_cstSASRefList separated by ' '
          from work._cstcolumnmetadata;
        select table into :_cstDomList separated by ' '
          from work._cstcolumnmetadata;
        select column into :_cstColList separated by ' '
          from work._cstcolumnmetadata;
        select count(*) into :_cstColCnt
          from work._cstcolumnmetadata;
        select count(*) into :_cstDomCnt
          from work._csttablemetadata;
      quit;
    %end;
  %end;

  proc sort data=work._csttablemetadata
    %if %upcase(&_cstDomDSName) ne WORK._CSTTABLEMETADATA %then
    %do;
      out=&_cstDomDSName
    %end;
       ;by sasref table;
  run;

  proc sort data=work._cstcolumnmetadata
    %if %upcase(&_cstColDSName) ne WORK._CSTCOLUMNMETADATA %then
    %do;
      out=&_cstColDSName
    %end;
       ;by sasref table;
  run;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_buildcollist;
  %end;
  %else %if %sysfunc(exist(work._csttempcolumnmetadata)) %then
  %do;
    proc datasets lib=work nolist;
      delete _csttempcolumnmetadata;
    quit;
  %end;

%mend cstutil_buildcollist;