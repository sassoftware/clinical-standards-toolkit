%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_insertStandardSASRefs                                                      *;
%*                                                                                *;
%* Inserts missing standards information into a SASReferences file.               *;
%*                                                                                *;
%* Where a SASReferences file uses a standard, it is possible to specify only the *;
%* standard, standardVersion, type, and subType for information that has been     *;
%* registered by the standard. Calling this macro supplies the missing            *;
%* information. If a standardVersion is not specified, the information for the    *;
%* default version of that standard is used.                                      *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSASRefsLoc SASReferences file location                             *;
%* @macvar _cstSASRefsName SASReferences file name                                *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstSASReferences - optional - The(libname.)member that points to a     *;
%*            SASReferences file to complete. If this parameter is not specified, *;
%*            _cstSASRefsLoc and _cstSASRefsName can be used to specify the       *;
%*            SASReferences file information. If none of the other mechanisms are *;
%*            specified or available, _cstSASRefs is used.                        *;
%* @param _cstOutputDS - required - The output data set to create that contains   *;
%*            the completed information.                                          *;
%* @param _cstAddRequiredCSTRefs - optional - Add a default framework messages    *;
%*            data set record, if needed. 0 = no, 1 = yes.                        *;
%*            Values: 0 | 1                                                       *;
%*            Default: 0                                                          *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers to  *;
%*            the Results data set to create. If this parameter is omitted, the   *;
%*            Results data set that is specified by &_cstResultsDS is used.       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro cst_insertStandardSASRefs(
    _cstSASReferences=,
    _cstOutputDS=,
    _cstAddRequiredCSTRefs=0,
    _cstResultsOverrideDS=
    ) / des='CST: Inserts missing standards information into a SASReferences file';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstDeallocateTempLib0
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstMessagesMemname
    _cstMsgDir
    _cstMsgMem
    _cstNumRecs
    _cstParam1
    _cstParam2
    _cstParamInError
    _cstRandom
    _cstSavedOrigResultsName
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstTempDSNoVersion
    _cstTempDSVersion
    _cstTempGSASRefs
    _cstTempLib0
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstTStd
    _cstTStdVer
    _cstUsingResultsOverride
    _cstNeedToDeleteMsgs
    ;

  %let _cstThisMacroRC=0;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib0=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempGSASRefs=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDSVersion=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDSNoVersion=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  %* decide where the results should be written to;
  %cstutil_internalManageResults(_cstAction=SAVE);

  %let _cstResultSeq=1;
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

  * Create a sorted version in work;
  proc sort data=&_cstGlobalMDLib..&_cstGlobalStdSASRefsDS
    out=&_cstTempGSASRefs;
    by standard standardVersion type subtype sasref;
  run;

  * This data reduction step is to remove duplicates that may exist to handle CSTMETA and CONTROL  *;
  *  SASRefs pointing to the same files in support of backward compatibility  *;
  data &_cstTempGSASRefs;
    set &_cstTempGSASRefs;
      by standard standardVersion type subtype;
    attrib everoutput evercntl format=8.;
    retain everoutput evercntl 0;
    if upcase(standard)='CST-FRAMEWORK' then
    do;
      if first.subtype then
      do;
        everoutput=0;
        evercntl=0;
        if upcase(sasref) ne 'CONTROL' then
        do;
          output;
          everoutput=1;
        end;
        else if last.subtype and upcase(sasref)='CONTROL' then 
        do;
          output;
          everoutput=1;
          evercntl=1;
        end;
      end;
      else if everoutput=0 then
      do;
        if upcase(sasref) ne 'CONTROL' then
        do;
          output;
          everoutput=1;
        end;
        else  
        do;
          if last.subtype=0 then 
            evercntl=1;
        end;
      end;
      if last.subtype and everoutput=0 then
      do;
        if upcase(sasref) ne 'CONTROL' then
        do;
          output;
          everoutput=1;
        end;
        else output;
      end;
    end;
    else output;
  run;
  
  %* Pre-Process: Make sure there is a CST-FRAMEWORK messages record in the data set;
  proc sql noprint;
     select count(standard) into :_cstNumRecs
       from &_cstSASReferences
       where standard='CST-FRAMEWORK' and type='messages';
     quit;
  run;

  * Split the input SASRefs into those with version specified and those without;
  * Also add a default framework messages data set record if needed;
  data &_cstTempDSVersion &_cstTempDSNoVersion(drop=standardVersion);
    set &_cstSASReferences end=eof;
    if (compress(standardVersion)='') then do;
      output &_cstTempDSNoVersion;
    end;
    else do;
      output &_cstTempDSVersion;
    end;
  %if (&_cstAddRequiredCSTRefs) %then %do;
    if (eof AND (&_cstNumRecs=0)) then do;
      standard='CST-FRAMEWORK';
      standardVersion='';
      type='messages';
      subtype='';
      order=0;
      refType='libref';
      sasref='';
      path='';
      memname='';
      comment='Required record added by cst_insertStandardSASRefs';
      output &_cstTempDSNoVersion;
    end;
  %end;
  run;

  * Process the records with the version;
  proc sort data=&_cstTempDSVersion;
    by standard standardVersion type subtype;
  run;

  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandardsforUpdate);

  data &_cstTempDSVersion(drop=gSASRef gRefType gPath gOrder gMemname rootpath studylibraryrootpath rc);
    merge &_cstTempDSVersion(in=x)
      &_cstTempGSASRefs(in=y
        keep=standard standardVersion type subtype SASRef reftype path order memname
        rename=(SASRef=gSASRef reftype=greftype path=gpath order=gorder memname=gmemname));
    by standard standardVersion type subtype;

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

    if (x);
    
    * fill in the missing values;
    if (lengthn(SASRef)=0) then SASRef=gSASRef;
    if (lengthn(refType)=0) then refType=gRefType;
    if (lengthn(path)=0) then 
      path=gPath;
    else
    do;
      if upcase(relpathprefix)='ROOTPATH' then
        path=catx('/',rootpath,path);
      else if upcase(relpathprefix)='STUDYLIBRARYROOTPATH' then
        path=catx('/',studylibraryrootpath,path);
      else if not missing(relpathprefix) then
        path=catx('/',relpathprefix,path);
    end;
    if (lengthn(memname)=0) then memname=gMemname;
    * note: order is not copied over;
  run;

  * Process the records WITHOUT the version - we want to use the default;
  * Only get the default versions for the standards;
  data &_cstTempGSASRefs(drop=isStandardDefault);
    merge &_cstTempGSASRefs(in=x)
          &_cstGlobalMDLib..&_cstGlobalStdDS(in=y keep=standard standardVersion isStandardDefault);
    by standard standardVersion;
    if ((x) and (isStandardDefault='Y'));
    call symputx('_cstTStd',standard);
    call symputx('_cstTStdVer',standardversion);
  run;

  * Sort the data with no version by the required variables;
  proc sort data=&_cstTempDSNoVersion;
    by standard type subtype;
  run;
  
  proc sort data=&_cstTempGSASRefs (where=(upcase(standard)="&_cstTStd" and upcase(standardversion)="&_cstTStdVer"));
    by standard type subtype;
  run;

  * Merge in the default version information;
  data &_cstTempDSNoVersion(drop=gSASRef gRefType gPath gOrder gMemname rootpath studylibraryrootpath rc);
    merge &_cstTempDSNoVersion(in=x)
      &_cstTempGSASRefs(in=y
        keep=standard standardVersion type subtype SASRef reftype path order memname
        rename=(SASRef=gSASRef reftype=greftype path=gpath order=gorder memname=gmemname));
    by standard type subtype;

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

    if (x);

    * fill in the missing values;
    if (lengthn(SASRef)=0) then SASRef=gSASRef;
    if (lengthn(refType)=0) then refType=gRefType;
    if (lengthn(path)=0) then 
      path=gPath;
    else
    do;
      if upcase(relpathprefix)='ROOTPATH' then
        path=catx('/',rootpath,path);
      else if upcase(relpathprefix)='STUDYLIBRARYROOTPATH' then
        path=catx('/',studylibraryrootpath,path);
      else if not missing(relpathprefix) then
        path=catx('/',relpathprefix,path);
    end;
    if (lengthn(memname)=0) then memname=gMemname;
    * note: order is not copied over;
  run;

  * Concatenate the two temporary data sets - append confirms the structure;
  proc append base=&_cstTempDSNoVersion
    data=&_cstTempDSVersion;
  run;

  * Create the data set that was requested;
  data &_cstOutputDS;
    set &_cstTempDSNoVersion;
  run;

  proc datasets lib=work nolist;
    delete _cstStandardsforUpdate;
  quit;

  %* Second call to CSTUTILVALIDATESASREFERENCES, checking:                  *;
  %*   - Given context, are path/memname macro variables resolved?  (CHK06)  *;
  %cstutilvalidatesasreferences (_cstDSName=&_cstSASReferences,_cstallowoverride=CHK01 CHK02 CHK03 CHK04 CHK05 CHK07 CHK08,
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
               ,_cstSrcDataParm=CST_INSERTSTANDARDSASREFS
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
                ,_cstSrcDataParm=CST_INSERTSTANDARDSASREFS
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
                ,_cstSrcDataParm=CST_INSERTSTANDARDSASREFS
                ,_cstResultFlagParm=0
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * Clear the global metadata library;
  libname &_cstGlobalMDLib;

  %if (&_cstDeallocateTempLib0=Y) %then %do;
    * de-allocate the temporary libname to SASRefs;
    libname &_cstTempLib0;
  %end;

  * Delete the temporary data sets;
  proc datasets nolist lib=work;
    delete
      &_cstTempDSVersion
      &_cstTempDSNoVersion
      &_cstTempGSASRefs/ mt=data;
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

  %* Set the global return code;
  %let _cst_rc=&_cstThisMacroRC;

%mend cst_insertStandardSASRefs;