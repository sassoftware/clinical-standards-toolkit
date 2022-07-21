%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstupdateStandardSASRefs                                                       *;
%*                                                                                *;
%* Expands all relative paths to full paths in a SASReferences file.              *;
%*                                                                                *;
%* By default, a StandardSASReferences data set provides file paths that are      *;
%* relative to the rootpath as defined in the global standards library data sets. *;
%* Relative paths must resolve to full paths.                                     *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSASRefsLoc SASReferences file location                             *;
%* @macvar _cstSASRefsName SASReferences file name                                *;
%*                                                                                *;
%* @param _cstSASReferences - optional - The(libname.)member that points to a     *;
%*            SASReferences file to update. If this parameter is not specified,   *;
%*            specify the SASReferences file information by using the global      *;
%*            macro variables _cstSASRefsLoc and _cstSASRefsName. If neither of   *;
%*            these methods is used, _cstSASRefs is used.                         *;
%* @param _cstOutputDS - required - The output data set to create that contains   *;
%*            the updated information.                                            *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstupdatestandardsasrefs(
    _cstSASReferences=,
    _cstOutputDS=
    ) / des="CST: Updates relative paths with full paths";

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstRandom
    _cstTempLib0
    _cstDeallocateTempLib0

    _cstStd
    _cstStdVer

    _cstThisMacroRC
    _cstParamInError
    ;

  %let _cstThisMacroRC=0;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib0=_cst&_cstRandom;

  %let _cstDeallocateTempLib0=N;

  %* Pre-requisite: _cstOutputDS is not blank;
  %if (%length(&_cstOutputDS)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstOutputDS;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstSASReferences must be passed in (or provided as global macro variables);
  %if (%length(&_cstSASReferences)=0) %then %do;
    %* try to use global macro variables;
    %if ((%symexist(_cstSASRefsLoc)=1) AND (%symexist(_cstSASRefsName)=1)) %then %do;
      %* check that the macro vars specifying path/data set have values;
      %if ((%length(&_cstSASRefsLoc)>0) and (%length(&_cstSASRefsName)>0)) %then %do;
        libname &_cstTempLib0 "%unquote(&_cstSASRefsLoc)";
        %let _cstDeallocateTempLib0=Y;
        %* check that the data set exists;
        %if (%sysfunc(exist(&_cstTempLib0..&_cstSASRefsName))) %then %do;
           %let _cstSASReferences=&_cstTempLib0..&_cstSASRefsName;
        %end;
        %else %do;
          * Clear the libname;
          libname &_cstTempLib0 ;
          %let _cstDeallocateTempLib0=N;

          %* SAS References does not exist using the global macro variables;
          %goto NO_SASREFS;
        %end;

      %end;
      %* check that the macro vars specifying path/data set have values;
      %else %do;
        %if ((%symexist(_cstSASRefs)=1) and (%length(&_cstSASRefs)>0)) %then %do;
          %let _cstSASReferences=&_cstSASRefs;
        %end;
        %else %do;
          %* SAS References not passed in and no global macro variables supplied;
          %goto NO_SASREFS;
        %end;
      %end;

    %end;
    %* macro vars specifying path/data set do not exist so use the cstSASRefs;
    %else %if ((%symexist(_cstSASRefs)=1) and (%length(&_cstSASRefs)>0)) %then %do;
      %let _cstSASReferences=&_cstSASRefs;
    %end;
    %else %do;
      %* SAS References not passed in and no global macro variables supplied;
      %goto NO_SASREFS;
    %end;
  %end;

  %* First call to CSTUTILVALIDATESASREFERENCES, checking:                          *;
  %*   - Is the data set structurally correct?  (CHK01)                             *;
  %*   - Unknown standard/standardversion  (CHK02)                                  *;
  %*   - Are all discrete character field values found in standardlookup?  (CHK05)  *;
  %*   - Multiple fmtsearch records but valid ordering is not provided  (CHK07)     *;
  %*   - Multiple autocall records but valid ordering is not provided  (CHK08)      *;
  %cstutilvalidatesasreferences (_cstDSName=&_cstSASReferences,_cstallowoverride=CHK03 CHK04 CHK06,
     _cstResultsType=RESULTS);

  %if (&_cst_rc) %then %do;
    %let _cstThisMacroRC=1;
    %goto CLEANUP;
  %end;

  data _null_;
    set &_cstSASReferences;
      call symputx('_cstStd',standard);
      call symputx('_cstStdVer',standardversion);
    if _n_=1 then stop;
  run;

  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandardsforUpdate);

  * Create the data set that was requested;
  data &_cstOutputDS (drop=rootpath studylibraryrootpath rc);
    set &_cstSASReferences;
      attrib rootpath format=$200.
             studylibraryrootpath format=$200.;
    if _n_=1 then do;
      call missing(rootpath,studylibraryrootpath);
      declare hash ht(dataset:"work._cstStandardsforUpdate");
      ht.defineKey("standard","standardversion");
      ht.defineData("rootpath","studylibraryrootpath");
      ht.defineDone();
    end;
    rc=ht.find();
    if (path ne '') then
    do;
      if upcase(relpathprefix)='ROOTPATH' then
        path=catx('/',rootpath,path);
      else if upcase(relpathprefix)='STUDYLIBRARYROOTPATH' then
        path=catx('/',studylibraryrootpath,path);
      else if not missing(relpathprefix) then
        path=catx('/',relpathprefix,path);
    end;
  run;
  proc datasets lib=work nolist;
    delete _cstStandardsforUpdate;
  quit;

  %* Second call to CSTUTILVALIDATESASREFERENCES, checking:                  *;
  %*   - Given context, are path/memname macro variables resolved?  (CHK06)  *;
  %cstutilvalidatesasreferences (_cstDSName=&_cstOutputDS,_cstallowoverride=CHK01 CHK02 CHK03 CHK04 CHK05 CHK07 CHK08,
     _cstResultsType=RESULTS);

  %if (&_cst_rc) %then %do;
    %let _cstThisMacroRC=1;
    %goto CLEANUP;
  %end;
  %else %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
               _cstResultID=CST0200
               ,_cstResultParm1=SASReferences data set was successfully validated
               ,_cstResultSeqParm=1
               ,_cstSeqNoParm=&_cstSeqCnt
               ,_cstSrcDataParm=CSTUPDATESTANDARDSASREFS
               ,_cstResultFlagParm=0
               ,_cstRCParm=0
               );
   %end;


  %goto CLEANUP;

%NULL_PARAMETER:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0081
                ,_cstResultParm1=&_cstParamInError
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CSTUPDATESTANDARDSASREFS
                ,_cstResultFlagParm=0
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NO_SASREFS:
  %* ERROR: A SASReferences file was not passed as a parameter and one is not specified using global environment variables.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0103
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CSTUPDATESTANDARDSASREFS
                ,_cstResultFlagParm=0
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CLEANUP:

  %if (&_cstDeallocateTempLib0=Y) %then %do;
    * de-allocate the temporary libname to SASRefs;
    libname &_cstTempLib0;
  %end;

  %* Set the global return code;
  %let _cst_rc=&_cstThisMacroRC;

%mend cstupdatestandardsasrefs;
