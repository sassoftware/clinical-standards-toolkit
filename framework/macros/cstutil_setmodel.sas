%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_setmodel                                                               *;
%*                                                                                *;
%* Establishes the comparison reference metadata for a validation check.          *;
%*                                                                                *;
%* This macro creates a copy of metadata for reference tables, source tables, and *;
%* columns in the SAS Work library. The metadata is based on library references   *;
%* and file references that are specified in the SASReferences data set.          *;
%*                                                                                *;
%* Comparison metadata for each check is based on the                             *;
%* validation_control.usesourcemetadata flag. If this flag is Y, sourcemetadata.* *;
%* is the comparison metadata. Otherwise, referencemetadata.* is the comparison   *;
%* metadata.                                                                      *;
%*                                                                                *;
%* This macro is called for each validation check, typically by either the        *;
%* builddomlist macro or by multi-standard comparison check macros.               *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. In general, there should be only a single source of referencemetadata.*   *;
%*      that is specified in the SASReferences control data set. However, this    *;
%*      macro permits multiple sources. These sources are concatenated by this    *;
%*      macro during the derivation of the work._cstTableMetadata data set and    *;
%*      the work._cstColumnMetadata data set.                                     *;
%*   2. There can be multiple sources of sourcemetadata.* that are specified in   *;
%*      the SASReferences control data set. These sources are concatenated by     *;
%*      this macro during the derivation of the work._cstTableMetadata data set   *;
%*      and the work._cstColumnMetadata data set.                                 *;
%*                                                                                *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstUseSourceMetadata Use source table and column metadata (Y/N)       *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstStd - required - The name of the registered standard. This          *;
%*            parameter is typically used only with a validation that involves    *;
%*            multiple standards.                                                 *;
%*            Default: &_cstStandard                                              *;
%* @param _cstStdVer - required - The version of _cstStd. This parameter is       *;
%*            typically used only with a validation that involves multiple        *;
%*            standards.                                                          *;
%*            Default: &_cstStandardVersion                                       *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_setmodel(
    _cstStd=&_cstStandard,
    _cstStdVer=&_cstStandardVersion
    ) / des="CST: Set Which Model Definition to Use";

  %cstutil_setcstgroot;

  %if &_cstDebug %then
  %do;
    %put cstutil_setmodel >>>;
    %put _cstUseSourceMetadata=&_cstUseSourceMetadata;
  %end;

  %local
    i
    _cstExitError
    _cstLibCnt
    _cstLibrary
    _cstMember
    _cstModel
    _cstSASrefLibs
    _cstSASrefMembers
  ;

  %let _cstModel=;
  %let _cstSASrefLibs=;
  %let _cstSASrefMembers=;
  %let _cstLibCnt=0;
  %let _cstLibrary=;
  %let _cstMember=;
  %let _cst_rc=0;
  %let _cstExitError=0;

  %************************************************************************;
  %* Lookup to sasreferences for sourcemetadata and referencemetadata     *;
  %************************************************************************;

  %cstutil_getsasreference(_cstStandard=&_cstStd,_cstStandardVersion=&_cstStdVer,_cstSASRefType=sourcemetadata,
                           _cstSASRefSubtype=column,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers,_cstConcatenate=1);
  %if &_cst_rc %then
  %do;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  %let _cstLibCnt = %SYSFUNC(countw(&_cstSASrefLibs,' '));

  data work._cstSrcColumnMetadata (label="Contains source column-level metadata");
    set

  %do i= 1 %to &_cstLibCnt;
      %let _cstLibrary = %scan(&_cstSASrefLibs, &i , " ");
      %let _cstMember = %scan(&_cstSASrefMembers, &i , " ");

      &_cstLibrary..&_cstMember
  %end;

  ;run;
  %if &_cstLibCnt>1 %then
  %do;
    proc sort data=work._cstSrcColumnMetadata;
      by SASref table order;
    run;
  %end;

  %cstutil_getsasreference(_cstStandard=&_cstStd,_cstStandardVersion=&_cstStdVer,_cstSASRefType=sourcemetadata,
                           _cstSASRefSubtype=table,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers,_cstConcatenate=1);
  %if &_cst_rc %then
  %do;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  %let _cstLibCnt = %SYSFUNC(countw(&_cstSASrefLibs,' '));

  data work._cstSrcTableMetadata (label="Contains source table-level metadata");
    set

  %do i= 1 %to &_cstLibCnt;
      %let _cstLibrary = %scan(&_cstSASrefLibs, &i , " ");
      %let _cstMember = %scan(&_cstSASrefMembers, &i , " ");

      &_cstLibrary..&_cstMember
  %end;

  ;run;
  %if &_cstLibCnt>1 %then
  %do;
    proc sort data=work._cstSrcTableMetadata;
      by SASref table;
    run;
  %end;

  %cstutil_getsasreference(_cstStandard=&_cstStd,_cstStandardVersion=&_cstStdVer,_cstSASRefType=referencemetadata,
                           _cstSASRefSubtype=column,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers,_cstConcatenate=1);
  %if &_cst_rc %then
  %do;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  %let _cstLibCnt = %SYSFUNC(countw(&_cstSASrefLibs,' '));

  data work._cstRefColumnMetadata (label="Contains reference column-level metadata");
    set

  %do i= 1 %to &_cstLibCnt;
      %let _cstLibrary = %scan(&_cstSASrefLibs, &i , " ");
      %let _cstMember = %scan(&_cstSASrefMembers, &i , " ");

      &_cstLibrary..&_cstMember
  %end;

  ;run;
  %if &_cstLibCnt>1 %then
  %do;
    proc sort data=work._cstRefColumnMetadata;
      by SASref table order;
    run;
  %end;

  %cstutil_getsasreference(_cstStandard=&_cstStd,_cstStandardVersion=&_cstStdVer,_cstSASRefType=referencemetadata,
                           _cstSASRefSubtype=table,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers,_cstConcatenate=1);
  %if &_cst_rc %then
  %do;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  %let _cstLibCnt = %SYSFUNC(countw(&_cstSASrefLibs,' '));

  data work._cstRefTableMetadata (label="Contains reference table-level metadata");
    set

  %do i= 1 %to &_cstLibCnt;
      %let _cstLibrary = %scan(&_cstSASrefLibs, &i , " ");
      %let _cstMember = %scan(&_cstSASrefMembers, &i , " ");

      &_cstLibrary..&_cstMember
  %end;

  ;run;
  %if &_cstLibCnt>1 %then
  %do;
    proc sort data=work._cstRefTableMetadata;
      by SASref table;
    run;
  %end;

  %************************************************************************;
  %* Set macro variables to support looping methodology in macro modules  *;
  %*  to loop through specified tables and columns.                       *;
  %************************************************************************;

  %if %upcase(&_cstUseSourceMetadata)=Y %then
  %do;
    data work._cstTableMetadata;
      set work._cstSrcTableMetadata;
    run;
    data work._cstColumnMetadata;
      set work._cstSrcColumnMetadata;
    run;
    %**let _cstTableMetadata=work._cstSrcTableMetadata;
    %**let _cstColumnMetadata=work._cstSrcColumnMetadata;
  %end;
  %else
  %do;
    data work._cstTableMetadata;
      set work._cstRefTableMetadata;
    run;
    data work._cstColumnMetadata;
      set work._cstRefColumnMetadata;
    run;
    %**let _cstTableMetadata=work._cstRefTableMetadata;
    %**let _cstColumnMetadata=work._cstRefColumnMetadata;
  %end;


%exit_error:

    %if &_cstExitError %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=CST0006
                  ,_cstValCheckID=&_cstCheckID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&sysmacroname
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_setmodel;
  %end;


%mend cstutil_setmodel;


