%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_createTablesForDataStandard                                                *;
%*                                                                                *;
%* Creates tables from registered reference metadata.                             *;
%*                                                                                *;
%* This macro generates all of the table shells that are defined for a standard   *;
%* that is registered and that is a data standard. The table shells are stored in *;
%* a library specified by the caller.                                             *;
%*                                                                                *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*             Values: 1 | 0                                                      *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstStandard - required - The name of the registered standard.          *;
%* @param _cstStandardVersion - optional - The version of the standard from which *;
%*            the data set is created. If this parameter is omitted, the default  *;
%*            version for the standard is used. If a default version is not       *;
%*            defined, an  error is generated.                                    *;
%* @param _cstOutputLibrary - required - The libname in which the table shells    *;
%*            are created.                                                        *;
%* @param _cstWhereClause - optional - A valid SAS WHERE clause used in the PROC  *;
%*            sort to enable the creation of subset by table. By default, no      *;
%*            WHERE clause is submitted. This parameter relies on a syntactically *;
%*            valid WHERE statement.                                              *;
%*            Example:                                                            *;
%*              %nrstr(where upcase(tablecore) ne 'EXT')                          *;
%*            Default: <blank>                                                    *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            a Results data set to create. If this parameter is omitted, the     *;
%*            Results data set specified by &_cstResultsDS is used.               *;
%* @param _cstNumObs - optional - The number of records in the data sets to       *;
%*            create. By default, zero-observation data sets are created. If you  *;
%*            specify a value other than 0, the data sets to create contain one   *;
%*            observation with all fields missing.                                *;
%*            Default: 0                                                          *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_createTablesForDataStandard(
    _cstStandard=,
    _cstStandardVersion=,
    _cstOutputLibrary=,
    _cstWhereClause=,
    _cstResultsOverrideDS=,
    _cstNumObs=0
    ) / des = 'CST: Creates tables from registered referencemetadata.';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstDebugDS1
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstHasRefMDColumn
    _cstHasRefMDTable
    _cstIsDataStandard
    _cstLastSysErr
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstNextCode
    _cstParamInError
    _cstParm1
    _cstParm2
    _cstRandom
    _cstRefMDColumnMDMember
    _cstRefMDColumnMDPath
    _cstRefMDTableMDMember
    _cstRefMDTableMDPath
    _cstTypeRefMD
    _cstSavedResultsDSName
    _cstSavedSASRefsName
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstSubTypeRefColumn
    _cstSubTypeRefTable
    _cstTempColumnMD
    _cstTempDS1
    _cstTempLib1
    _cstTempLib2
    _cstTempTableMD
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
    ;

  %let _cstThisMacroRC=0;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);
  %cst_getStatic(_cstName=CST_SASREF_TYPE_REFMD,_cstVar=_cstTypeRefMD);
  %cst_getStatic(_cstName=CST_SASREF_SUBTYPE_TABLE,_cstVar=_cstSubTypeRefTable);
  %cst_getStatic(_cstName=CST_SASREF_SUBTYPE_COLUMN,_cstVar=_cstSubTypeRefColumn);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib1=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib2=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempTableMD=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempColumnMD=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);
  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  %* Pre-requisite: _cstStandard is not blank;
  %if (%length(&_cstStandard)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstStandard;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstOutputLibrary is not blank;
  %if (%length(&_cstOutputLibrary)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstOutputLibrary;
    %goto NULL_PARAMETER;
  %end;

  * Pre-requisite: Check that the output libref is assigned;
  %if (%sysfunc(libref(&_cstOutputLibrary))) %then %do;
    %let _cstParm1=&_cstOutputLibrary;
    %let _cstParm2=;
    %goto LIBREF_NOT_ASSIGNED;
  %end;

  * Pre-requisite: Check that the standard is valid and that it is a data standard;
  %let _cstError=Y;
  %let _cstIsDataStandard=MISSING;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDS
      (where=(upcase(standard)=%sysfunc(upcase("&_cstStandard"))));
    if (_n_=1) then do;
      call symputx('_cstError','N','L');
      call symputx('_cstIsDataStandard',upcase(isDataStandard),'L');
    end;
  run;

  %if (&_cstError=Y) %then %do;
    %goto INVALID_STD;
  %end;
  %else %if (&_cstIsDataStandard=N) %then %do;
    %goto NOT_DATA_STANDARD;
  %end;

  * Pre-requisite: Check that the version is valid (if provided) or a default exists if not;
  %if (%length(&_cstStandardVersion)>0) %then %do;
    %let _cstError=Y;
    * Check that the version is valid;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion"))));
      if (_n_=1) then call symputx('_cstError','N','L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %goto INVALID_VERSION;
    %end;
  %end;
  %else %do;
    %let _cstError=Y;
    * Check that there is a default version specified and retrieve it;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(isstandarddefault="Y"));
      if (_n_=1) then call symputx('_cstError','N','L');
      call symputx('_cstStandardVersion',standardVersion,'L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %let _cstParm1=&_cstStandardVersion;
      %let _cstParm2=&_cstStandard;
      %goto NO_DEFAULT_VERSION;
    %end;
  %end;

  * Pre-requisite: Check there is reference metadata for the standard-version;
  %let _cstHasRefMDTable=N;
  %let _cstHasRefMDColumn=N;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDS
      (where=(
        (upcase(standard)=%sysfunc(upcase("&_cstStandard"))) AND
        (upcase(standardVersion)=%sysfunc(upcase("&_cstStandardVersion"))) AND
        (upcase(type)=%sysfunc(upcase("&_cstTypeRefMD")))
      ));

    if (upcase(subType)=upcase("&_cstSubTypeRefTable")) then do;
      call symputx('_cstHasRefMDTable','Y','L');
      * save the name of the member;
      call symputx('_cstRefMDTableMDPath',path,'L');
      call symputx('_cstRefMDTableMDMember',scan(memname,1),'L');
      * do this in preparation for the next step;
      sasref="&_cstTempLib1";
    end;
    else if (upcase(subType)=upcase("&_cstSubTypeRefColumn")) then do;
      call symputx('_cstHasRefMDColumn','Y','L');
      * save the name of the member;
      call symputx('_cstRefMDColumnMDPath',path,'L');
      call symputx('_cstRefMDColumnMDMember',scan(memname,1),'L');
      * do this in preparation for the next step;
      sasref="&_cstTempLib2";
    end;
  run;

  %if (&_cstDebug) %then %do;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstDebugDS1=_cst&_cstRandom;

    %put "- Writing sasrefs data set to work.&_cstDebugDS1";
    data &_cstDebugDS1;
      set &_cstTempDS1;
    run;
  %end;

  %* process an error;
  %let _cstError=N;
  %let _cstParm1=&_cstStandard &_cstStandardVersion;
  %if (&_cstHasRefMDTable=N) %then %do;
    %let _cstParm2=&_cstSubTypeRefTable;
    %let _cstError=Y;
  %end;
  %if (&_cstHasRefMDColumn=N) %then %do;
    %if (&_cstError=Y) %then %do;
      %let _cstParm2=&_cstParm2./;
    %end;
    %let _cstParm2=&_cstParm2.&_cstSubTypeRefTable;

    %let _cstError=Y;
  %end;
  %if (&_cstError=Y) %then %do;
    %goto NO_REFMETADATA;
  %end;

  %* Assign the libnames to the reference metadata;
  %if (&_cstDebug) %then %do;
    %put - Assigning libnames to the reference metadata;
  %end;
  %let _cst_rc=0;
  %if %symexist(_cstSASRefs) %then %do;
    %let _cstSavedSASRefsName=&_cstSASRefs;
  %end;
  %if %symexist(_cstResultsDS) %then %do;
    %let _cstSavedResultsDSName=&_cstResultsDS;
  %end;
  %let _cstSASRefs=&_cstTempDS1;
  %let _cstResultsDS=&_cstThisResultsDS;
  %* The next 2 lines was a call to cstutil_allocatesasrefs - surrounding code left in, in case this goes back in;
  libname &_cstTempLib1 "%unquote(&_cstRefMDTableMDPath)";
  libname &_cstTempLib2 "%unquote(&_cstRefMDColumnMDPath)";

  %* reset the messages/sasrefs;
  %if (%length(&_cstSavedSASRefsName)>0) %then %do;
    %let _cstSASRefs=&_cstSavedSASRefsName;
  %end;
  %if (%length(&_cstSavedResultsDSName)>0) %then %do;
    %let _cstResultsDS=&_cstSavedResultsDSName;
  %end;

  %if (&_cst_rc) %then %do;
    %* Clear the metadata libraries;
    %if (%sysfunc(libref(&_cstTempLib1))=0) %then %do;
      libname &_cstTempLib1;
    %end;
    %if (%sysfunc(libref(&_cstTempLib1))=0) %then %do;
      libname &_cstTempLib2;
    %end;

    %goto ERROR_ASSIGNING_REFMD;
  %end;

  * Assign a filename for the code that will be generated;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source";

  * merge the reference table and column metadata;
  proc sort
    data=&_cstTempLib1..&_cstRefMDTableMDMember
    out=work.&_cstTempTableMD(keep=table label rename=(label=tableLabel));
    by table;
    &_cstWhereClause;
  run;

  proc sort
    data=&_cstTempLib1..&_cstRefMDColumnMDMember
    out=work.&_cstTempColumnMD;
    by table order column;
  run;

  data &_cstTempDS1;
    merge
      work.&_cstTempTableMD (in=x)
      work.&_cstTempColumnMD (in=y);
    by table;
    if (x and y);
  run;

  * create the code to run next;
  %let _cstError=0;
  data _null_;
    file &_cstNextCode;
    set &_cstTempDS1 end=eof;
    by table;

    if (first.table) then do;
       put @3 "data &_cstOutputLibrary.." table +(-1)"(label='" tableLabel +(-1) "');";
       put @5 "attrib";
    end;

    put @7 column;
    put @9 "label='" label +(-1) "'";
    if (upcase(type)='C') then do;
      put @9 "length=$" length;
    end;
    else do;
      put @9 "length=" length;
    end;

    if (displayformat ne '') then do;
      put @9 "format=" displayFormat;
    end;

    if (last.table) then do;
       put @5 ';';
%if &_cstNumObs=0 %then
%do;
       put @5 'stop;';
%end;
       put @5 'call missing(of _all_);';
       put @3 'run;' /;

       put '* Check the return code for the submitted code;';
       put '%let _cstLastSysErr=&sysErr;';
       put 'data _null_;';
       put @3 'syserr = input(symget("_cstLastSysErr"),8.);';
       put @3 'if (syserr > 0) then do;';
       put @5   'call symputx("_cstError",1,"L");';
       put @3 'end;' / 'run;' /;
    end;
  run;

  * Include the generated code;
  %include &_cstNextCode;

  %* Check the system return code.;
  %if (&_cstError) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0121
                ,_cstResultParm1=&_cstStandard &_cstStandardVersion
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %end;
  %else %do;
    %let _cstThisMacroRC=0;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0122
                ,_cstResultParm1=&_cstStandard &_cstStandardVersion
                ,_cstResultParm2=&_cstOutputLibrary
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %end;

  * Clear the filename;
  filename &_cstNextCode;

  %* Clear the metadata libraries;
  libname &_cstTempLib1;
  libname &_cstTempLib2;

  %goto CLEANUP;

%NULL_PARAMETER:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0081
                ,_cstResultParm1=&_cstParamInError
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%LIBREF_NOT_ASSIGNED:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0101
                ,_cstResultParm1=&_cstParm1
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_STD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0082
                ,_cstResultParm1=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%NOT_DATA_STANDARD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0118
                ,_cstResultParm1=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_VERSION:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstStandardVersion
                ,_cstResultParm2=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NO_DEFAULT_VERSION:
  %* ERROR: No version was supplied and there is no default for &_cstStandard.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstParm1
                ,_cstResultParm2=&_cstParm2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NO_REFMETADATA:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0119
                ,_cstResultParm1=&_cstParm1
                ,_cstResultParm2=&_cstParm2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%ERROR_ASSIGNING_REFMD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0120
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATETABLESFORDATASTANDARD
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * Clear the libname;
  libname &_cstGlobalMDLib;

  * Clean up temporary data sets if they exist;
  proc datasets nolist lib=work;
    delete &_cstTempDS1 &_cstTempTableMD &_cstTempColumnMD / mt=data;
    delete &_cstNextCode / mt=catalog;
    quit;
  run;

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

  %let _cst_rc=&_cstThisMacroRC;

%mend cst_createTablesForDataStandard;