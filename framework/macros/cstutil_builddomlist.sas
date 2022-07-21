%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_builddomlist                                                           *;
%*                                                                                *;
%* Builds a tables based on the value from validation_control.tablescope.         *;
%*                                                                                *;
%* This macro builds a set of tables (in either list format or data set format)   *;
%* based on the value from the validation check control file                      *;
%* validation_control.tablescope.                                                 *;
%*                                                                                *;
%* These are the rules used to interpret tableScope values (using mostly CDISC    *;
%* SDTM examples):                                                                *;
%*   -  validation_control.tablescope cannot be null.                             *;
%*   -  Blanks are converted to "+" (for example, AE DM becomes AE+DM).           *;
%*   -  The value must not begin with  '+' or '-'.                                *;
%*   -  If the blank conversion results in multiple '+' characters, all but one   *;
%*      of the '+' characters are removed (for example, AE +DM becomes AE++DM,    *;
%*      which becomes AE+DM).                                                     *;
%*   -  No attempt is made to assess the validity of the tableScope value (for    *;
%*      example, CLASS:FINDINGS-AE is allowed, although no change to the resolved *;
%*      set of CLASS:FINDINGS tables occurs).                                     *;
%*   -  The derived set of tables is built by parsing tableScope from left to     *;
%*      right (for example, _ALL_-CLASS:RELATES builds a set of all tables        *;
%*      removing RELREC and SUPP**).                                              *;
%*   -  If <libref> is included, it must be listed in the                         *;
%*      SASReferences.SASRef column.                                              *;
%*   -  Wildcard conventions:                                                     *;
%*        - must use the string **                                                *;
%*        - can appear as a suffix (for example, SUPP** for all tables that start *;
%*          with SUPP)                                                            *;
%*        - can appear as a prefix (for example, **DM for all tables that end     *;
%*          with DM)                                                              *;
%*        - can appear alone (for example, **), equivalent to _ALL_               *;
%*        - <libref>.** for all tables in the specified library                   *;
%*        - **.AE for all AE tables across referenced libraries                   *;
%*   -  Sublists are delimited by brackets, and resolved lengths (that is, #      *;
%*      columns) must be the same unless _cst*SubOverride is set to Y, and they   *;
%*      must conform to non-sublist rules stated above.                           *;
%*   -  A special naming convention of <column>:<value>, such as CLASS:EVENTS,    *;
%*       allows you to specify a _cstTableMetadata column and column value to     *;
%*       subset tables. In this example, all CLASS='EVENTS' tables are returned.  *;
%*                                                                                *;
%* Sample tablescope values:                                                      *;
%*   _ALL_                    (all tables)                                        *;
%*   AE                       (a single table)                                    *;
%*   DM+DS                    (multiple tables)                                   *;
%*   CLASS:EVENTS             (_cstTableMetadata.CLASS='EVENTS')                  *;
%*   SUPP**                   (all Supplemental Qualifier tables)                 *;
%*   _ALL_-SUPP**             (all tables except Supplemental Qualifier tables)   *;
%*   [DM][EX]                 (two sublists comparing DM with EX)                 *;
%*   SRCDATA1.AE+SRCDATA2.AE  (AE table from two different libraries)             *;
%*   SRCDATA.**               (all tables from the SRCDATA library)               *;
%*   **.AE                    (all AE tables from all sourcedata libraries)       *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstMsgID Results: Result or validation check ID                       *;
%* @macvar _cstMsgParm1 Messages: Parameter 1                                     *;
%* @macvar _cstMsgParm2 Messages: Parameter 2                                     *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstTableMetadata Table that contains table metadata referenced in     *;
%*             _cstStandard                                                       *;
%* @macvar _cstTableScope Table scope as defined in validation check metadata     *;
%*                                                                                *;
%* @param _cstFormatType - required - The format type:                            *;
%*            LIST:    Sets macro variables of # tables and space-delimited list  *;
%*                     of tables.                                                 *;
%*            DATASET: Returns a data set of tables matching tableScope           *;
%*                     specification.                                             *;
%*            Values: LIST | DATASET                                              *;
%*            Default: DATASET                                                    *;
%* @param _cstDomWhere - optional - The WHERE clause to subset returned set of    *;
%*            tables. A WHERE clause is applied as the last step.                 *;
%*            Any WHERE clause is applied as the last step.                       *;
%* @param _cstStd - required - The name of the registered standard. Typically used*;
%*            only with a validation that involves multiple standards.            *;
%*            Default: &_cstStandard                                              *;
%* @param _cstStdVer - required - The version of _cstStd. Typically used only with*;
%*            validation involving multiple standards.                            *;
%*            Default: &_cstStandardVersion                                       *;
%* @param _cstDomDSName - conditional - The name of the data set that is returned *;
%*            when _cstFormatType=DATASET.                                        *;
%*            Default: &_cstTableMetadata                                         *;
%* @param _cstSubOverride -required - Override sublist processing to allow        *;
%*            sublists of different lengths (such as tableScope=[_ALL_-DM][DM] ). *;
%*            Values: N | Y                                                       *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @history 2016-03-18 Added sublist discrepancy reporting (1.6.1 and 1.7.1)      *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_builddomlist(
    _cstFormatType=DATASET,
    _cstDomWhere=,
    _cstStd=&_cstStandard,
    _cstStdVer=&_cstStandardVersion,
    _cstDomDSName=&_cstTableMetadata,
    _cstSubOverride=N
    )  / des ='CST: Build table list from tablescope';

  %cstutil_setcstgroot;

  %local
    _cstexit_error
    _cstModifiedSubList
    _cstSASRefCnt
    _cstSubList
    _cstSublistCnt
    _cstProblem
    ;

  %if &_cstDebug %then
  %do;
    %put cstutil_builddomlist >>>;
    %put "*********************************************************";
    %put "_cstFormatType = &_cstFormatType";
    %put "_cstDomWhere = &_cstDomWhere";
    %put "_cstDomDSName = &_cstDomDSName";
    %put "_cstSubOverride = &_cstSubOverride";
    %put "_cstTableScope = &_cstTableScope";
    %put "*********************************************************";
  %end;

  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstSrcData=&sysmacroname;
  %let _cst_rc=0;
  %let _cstexit_error=0;
  %let _cstProblem=0;
  %let _cstSublistCnt=1;
  %let _cstTableSublistCnt=1;

  *******************************************************************************;
  * Evaluate _cstTableScope global macro and handle any discrepancy conditions  *;
  *******************************************************************************;

  %if %length(&_cstTableScope)=0 %then
  %do;
      %let _cst_MsgID=CST0014;
      %let _cst_MsgParm1=_cstTableScope;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  %if %upcase(&_cstFormatType)=DATASET or %upcase(&_cstFormatType)=LIST %then
  %do;

    %****************************************************************;
    %* cstutil_setmodel builds table and column work data sets and  *;
    %* populates the critical macro variables _cstTableMetadata     *;
    %* and _cstColumnMetadata                                       *;
    %****************************************************************;

    %cstutil_setmodel(_cstStd=&_cstStd,_cstStdVer=&_cstStdVer);
    %if &_cst_rc %then
    %do;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %****************************************************************;
    %* At this point, work._csttablemetadata points either to       *;
    %* srcmodel or refmodel, and if srcmodel, multiple srcdata      *;
    %* SASRefs are available in the data set.                       *;
    %****************************************************************;

    %if %SYSFUNC(indexc(&_cstTableScope,' ')) %then
    %do;
       %* Translate any blanks to + signs  *;
       %let _cstTableScope=%sysfunc(tranwrd(%sysfunc(trim(&_cstTableScope)),%str( ),%str(+)));
    %end;
    %if %SYSFUNC(indexc(&_cstTableScope,'++')) %then
    %do;
       %* Translate multiple + signs to single + signs  *;
       %let _cstTableScope=%sysfunc(tranwrd(%sysfunc(trim(&_cstTableScope)),%str(++),%str(+)));
    %end;

    data work._csttemptablemetadata (label="Temporary work file");
      set work._csttablemetadata;
      tsublist=1;
      stop;
    run;

    %*******************************************************;
    %* _cstTableScope contains sublists, like:             *;
    %*   [DM][AE]   [_ALL_-SV][SV]                         *;
    %*                                                     *;
    %* Processing of multiple sublists is self-contained   *;
    %* within this loop given their unique nature.         *;
    %*******************************************************;

    %let _cstSublistCnt = %SYSFUNC(countw(&_cstTableScope,'['));

    %* By default, countw will return a 1 if the delimiter is not found ;
    %if &_cstSublistCnt > 1 %then
    %do;

      %let _cstTableSublistCnt=&_cstSublistCnt;

      %do i= 1 %to &_cstSublistCnt;

        %let _cstSubList = %scan(&_cstTableScope, &i , "]");
        %let _cstSubList=%sysfunc(tranwrd(%sysfunc(trim(&_cstSubList)),%str([),%str()));
        %let _cstModifiedSubList=&_cstSubList;

        %cstutil_parsetablescope(_cstscopestr=&_cstSubList,_cstopsource=&_cstModifiedSubList,_cstsublistnum=&i);
        %if &_cst_rc %then
        %do;
          %let _cstexit_error=1;
          %goto exit_error;
        %end;

      %end;  %* end of do=1 to n sublists loop  *;

      %****************************************************************;
      %* work._csttemptablemetadata has been created, now check for   *;
      %* equivalent sublist lengths.  If not equivalent, report error *;
      %****************************************************************;

      proc sort data=work._csttemptablemetadata out=work._csttablemetadata;
        by sasref table;
      run;

      %if %upcase(&_cstSubOverride)=N %then
      %do;

        proc sql noprint;
          select count(distinct listcnt) into :_cstProblem
            from (select tsublist, count(*) as listCnt
              from work._csttemptablemetadata
                group by tsublist);
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
            select table into :_cstVarList1 separated by ' '
              from work._csttemptablemetadata where tsublist=1;
            select table into :_cstVarList2 separated by ' '
              from work._csttemptablemetadata where tsublist=2;
          quit;
          %put [CSTLOG%str(MESSAGE)] The following incompatible sublist lengths were found for checkId=&_cstCheckID and resultSeq=&_cstResultSeq;
          %put [CSTLOG%str(MESSAGE)] Sublist1: &_cstVarList1;
          %put [CSTLOG%str(MESSAGE)] Sublist2: &_cstVarList2;
          %let _cst_MsgID=CST0023;
          %let _cst_MsgParm1=tablescope;
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
      %end;  %* End of _cstSubOverride=N loop  *;
    %end; %* end of >1 sublist processing ;
    %else
    %do;

      %******************************************************;
      %* Everything else except multiple sublists:          *;
      %*   AE+DM  _ALL_-EX  CLASS:EVENTS+CLASS:FINDINGS-AE  *;
      %*   SRCDATA1.AE+SRCDATA2.AE                          *;
      %*   SUPP**    **.DM    SRCDATA.**                    *;
      %*   AE _ALL_ SRCDATA.EX                              *;
      %*   [DM+AE]                                          *;
      %******************************************************;

      %let _cstTableScope=%SYSFUNC(compress(&_cstTableScope,']['));

      %* Hardcode the sublist number to 1 *;
      %cstutil_parsetablescope(_cstscopestr=&_cstTableScope,_cstopsource=&_cstTableScope,_cstsublistnum=1);
      %if &_cst_rc %then
      %do;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      data work._csttablemetadata;
        set work._csttemptablemetadata;
      run;

    %end;

  %end;
  %else
  %do;
      %* Invalid _cstparm1 input parameter, _cstparm2 macro cannot run  *;
      %let _cst_MsgID=CST0015;
      %let _cst_MsgParm1=Type;
      %let _cst_MsgParm2=cstutil_builddomlist;
      %let _cst_rc=0;
      %let _cstexit_error=1;
  %end;

 %exit_error:

  %if &_cst_rc=0 and %sysfunc(exist(work._csttablemetadata)) %then
  %do;
  
    %if %sysfunc(exist(work._csttemptablemetadata)) %then
    %do;
      data work._csttablemetadata;
        set work._csttemptablemetadata;
      run;
    %end;
    
    %***************************;
    %* Apply any where clause  *;
    %***************************;

    %if %length(&_cstDomWhere)=0 %then
    %do;
      proc sort data=work._csttablemetadata;
        by sasref table;
      run;
    %end;
    %else
    %do;
      proc sort data=work._csttablemetadata (where=(&_cstDomWhere));
        by sasref table;
      run;
    %end;

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
*/
    %if %upcase(&_cstFormatType)=LIST %then
    %do;
      %let _cstTableSublistCnt=&_cstSublistCnt;

      proc sql noprint;
        select count(distinct sasref) into :_cstSASRefCnt
          from work._csttablemetadata;
        select count(*) into :_cstDomCnt
          from work._csttablemetadata;
      quit;

      proc sql noprint;
        %if &_cstSASRefCnt>1 %then
        %do;
          select catx('.',sasref,table) into :_cstDomList separated by ' '
        %end;
        %else
        %do;
          select table into :_cstDomList separated by ' '
        %end;
          from work._csttablemetadata;
      quit;

    %end;

    %if %upcase(&_cstDomDSName) ne WORK._CSTTABLEMETADATA %then
    %do;
      proc sort data=work._csttablemetadata out=&_cstDomDSName;
        by sasref table;
      run;
    %end;

  %end;

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
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_builddomlist;
  %end;
  %else %if %sysfunc(exist(work._csttemptablemetadata)) %then
  %do;
    proc datasets lib=work nolist;
      delete _csttemptablemetadata;
    quit;
  %end;
  
  %* Set _cstDomSubListCnt to be a count of the number of tablescope sublists  *;
  %let _cstDomSubListCnt=&_cstSublistCnt;
  
%mend cstutil_builddomlist;