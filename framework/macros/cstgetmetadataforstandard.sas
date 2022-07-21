%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstgetmetadataforstandard                                                      *;
%*                                                                                *;
%* Retrieves standard metadata for a standard and version.                        *;
%*                                                                                *;
%* A valid SASReferences data set is passed into this macro. A row must exist for *;
%* each metadata table to retrieve. The row must identify the standard,           *;
%* standardversion, type, and subtype of each metadata entity. The row SASRef and *;
%* the memname columns must specify the libname.memberName of each output data    *;
%* set. Only filetype=DATASET rows are processed.                                 *;
%*                                                                                *;
%* For example, to retrieve SDTM 3.1.3 reference metadata about tables into the   *;
%* WORK library data set named REFTABLEMD, the SASReferences data set must        *;
%* include a row with the following column values:                                *;
%*   standard=CDISC-SDTM                                                          *;
%*   standardversion=3.1.3                                                        *;
%*   type=referencemetadata                                                       *;
%*   subtype=table                                                                *;
%*   SASRef=WORK                                                                  *;
%*   memname=REFTABLEMD                                                           *;
%*   filetype=dataset                                                             *;
%*                                                                                *;
%* NOTE: The SASReferences data set must include records for only a single        *;
%* registered standard and version.                                               *;
%*                                                                                *;
%* @macvar _cstMsgID Results: Result ID                                           *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*             Values 1 | 0                                                       *;
%* @macvar _cstMessages Cross-standard work Messages data set                     *;
%*                                                                                *;
%* @param _cstSASReferences - required - The (libname.)member that refers to a    *;
%*            valid SASReferences file.                                           *;
%* @param _cstResultsOverrideDS - optional - The (libname.)member that refers     *;
%*            to the Results data set to create. If omitted, the Results data set *;
%*            that is specified by &_cstResultsDS is used.                        *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstgetmetadataforstandard(
    _cstSASReferences=,
    _cstResultsOverrideDS=
    ) / des='CST: Retrieves standard metadata';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstBadSASRefs
    _cstCopyDS
    _cstCopyDSCnt
    _cstError
    _cstGlobalMDLib
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdSASRefsDS
    _cstMsgDir
    _cstMsgMem
    _cstMultipleStds
    _cstNeedToDeleteMsgs
    _cstNextCode
    _cstParam1
    _cstParam2
    _cstRandom
    _cstSaveResultSeq
    _cstSrcMacro
    _cstTempDS1
    _cstTempDS2
    _cstTempResultsDS
    _cstThisMacroRC
    _cstThisMacroRCmsg
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstUsingResultsOverride
    ;

  %let _cstBadSASRefs=;
  %let _cstCopyDSCnt=0;
  %let _cstError=N;
  %let _cstMultipleStds=N;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstThisMacroRC=0;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS2=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempResultsDS=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  * Assign a filename for the code that will be generated;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source";

  %* decide where the results should be written to;
  %cstutil_internalManageResults(_cstAction=SAVE);

  %* incremement the results sequence number for this macro iteration;
  %let _cstResultSeq=1;

  %***************************;
  %* Check parameters        *;
  %***************************;

  %* Pre-requisite: _cstSASReferences is not blank;
  %if (%length(&_cstSASReferences)=0) %then %do;
    %let _cstError=Y;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=The required parameter _cstSASReferences is missing.;
    %let _cstMsgID=CST0081;
    %let _cstParam1=_cstSASReferences;
    %let _cstParam2=;
    %goto ABORT_PROCESS;
  %end;

  %* Pre-requisite: _cstSASReferences exists;
  %if (^%sysfunc(exist(&_cstSASReferences))) %then
  %do;
    %let _cstError=Y;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=The data set [&_cstSASReferences] specified in the _cstSASReferences macro parameter does not exist.;
    %let _cstMsgID=CST0008;
    %let _cstParam1=&_cstSASReferences;
    %let _cstParam2=;
    %goto ABORT_PROCESS;
  %end;

  %********************************;
  %* Verify SASReferences content *;
  %********************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstCopyDS=_cst&_cstRandom;
  
  * Look only at filetype=DATASET records.  Identify any problems. *;
  data &_cstCopyDS (drop=_cstStd _cstStdVer _cstBadSASRefList);
    set &_cstSASReferences (where=(upcase(filetype)='DATASET')) end=last;
      attrib _cstStd format=$20.
             _cstStdVer format=$20.
             _cstBadSASRefList format=$200.;
      retain _cstStd _cstStdVer _cstBadSASRefList;
      if _n_=1 then 
      do;
        _cstStd=upcase(standard);
        _cstStdVer=upcase(standardversion);
        call symputx('_cstCopyDSCnt',1);
      end;
      else do;
        if upcase(standard) ne _cstStd or upcase(standardversion) ne _cstStdVer then
          call symputx('_cstMultipleStds','Y');
      end;
      if missing(sasref) or missing(memname) then 
        call symputx('_cstError','Y');
      if (libref(sasref) >0) then 
        _cstBadSASRefList=catx(' ',_cstBadSASRefList,sasref);

      if last and ^missing(_cstBadSASRefList) then
        call symputx('_cstBadSASRefs',_cstBadSASRefList);
  run;

  %if (&_cstCopyDSCnt=0) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=The data set [&_cstSASReferences] contains no FILETYPE=DATASET records.;
    %let _cstMsgID=CST0202;
    %let _cstParam1=&_cstThisMacroRCmsg;
    %let _cstParam2=;
    %goto ABORT_PROCESS;
  %end;

  %if (&_cstError=Y) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=The data set [&_cstSASReferences] contains missing SASREF or MEMNAME column values.;
    %let _cstMsgID=CST0088;
    %let _cstParam1=SASReferences;
    %let _cstParam2=SASRef memname;
    %goto ABORT_PROCESS;
  %end;

  %* Pre-requisite: Check that all librefs are assigned;
  %if (%length(&_cstBadSASRefs)>0) %then %do;
    %let _cstError=Y;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=One or more SASREF column values in &_cstSASReferences has not been allocated.;
    %let _cstMsgID=CST0101;
    %let _cstParam1=&_cstBadSASRefs;
    %let _cstParam2=;
    %goto ABORT_PROCESS;
  %end;

  %* Create a complete SASReferences template *;
  %cst_createdsfromtemplate(
    _cstStandard=CST-FRAMEWORK,
    _cstType=control,
    _cstSubType=reference,
    _cstOutputDS=&_cstTempDS1,
    _cstResultsOverrideDS=&_cstTempResultsDS);

  %* check for an error;
  %if (&_cst_rc=1) %then %do;
    %let _cstError=Y;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=Unable to successfully create &_cstTempDS1 using cst_createdsfromtemplate().;
    %let _cstMsgID=CST0077;
    %let _cstParam1=&_cstTempDS1;
    %let _cstParam2=%str(call to cst_createdsfromtemplate failed);
    %goto ABORT_PROCESS;
  %end;

  * Create a data set with just the basic information in it;
  data work._cstSASReferences_updated;
    set &_cstTempDS1
        &_cstCopyDS (keep=standard standardVersion type subType refType iotype filetype allowoverwrite
                          relpathprefix /* engine reftypeoptions */ );
  run;

  %* insert the standard sas references;
  %cst_insertStandardSASRefs(
    _cstSASReferences=work._cstSASReferences_updated,
    _cstOutputDS=work._cstSASReferences_updated,
    _cstResultsOverrideDS=&_cstTempResultsDS);

  %* check for an error;
  %if (&_cst_rc=1) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=Call to cst_insertStandardSASRefs failed;
    %let _cstMsgID=CST0202;
    %let _cstParam1=&_cstThisMacroRCmsg;
    %let _cstParam2=;
    %goto ABORT_PROCESS;
  %end;

  * Check that all data sets were found and valid paths exist;
  %let _cstError=N;
  data _null_;
    set work._cstSASReferences_updated;
      if (path='') then
      do;
        call symputx('_cstError','Y');
        stop;
      end;
  run;

  %if (&_cstError=Y) %then %do;
    %let _cstThisMacroRC=1;
    %let _cstThisMacroRCmsg=One or more paths are missing in work._cstSASReferences_updated.;
    %let _cstMsgID=CST0088;
    %let _cstParam1=work._cstSASReferences_updated;
    %let _cstParam2=path;
    %goto ABORT_PROCESS;
  %end;

  %********************************;
  %* Start retrieval process      *;
  %********************************;

  * merge the orginal/resolved sasreferences;
  proc sort data=&_cstCopyDS out=&_cstTempDS2;
    by standard standardversion type subtype;
  run;

  proc sort data=work._cstSASReferences_updated;
    by standard standardversion type subtype;
  run;

  data work._cstSASReferences_updated;
    merge
      work._cstSASReferences_updated(in=y)
      &_cstTempDS2(in=x
        keep=standard standardVersion type subType sasref memname
        rename=(SASRef=toSASRef memName=ToMemName)) ;
    by standard standardversion type subtype;
  run;

  %if (&_cstDebug=1) %then %do;
    * DEBUG - print out the temp data set;
    proc print data=work._cstSASReferences_updated;
    run;
  %end;

  * create the copy code;
  data _null_;
   file &_cstNextCode;
    set work._cstSASReferences_updated;

    memname=scan(memname,1);

    put @1 'libname &_cstNextCode "' %unquote(path) +(-1)'";';
    put @1 "data " toSASRef +(-1) "." toMemName ";";
    put @3   "set &_cstNextCode.." memName +(-1)";";
    put @1 "run;";
    put @1 "libname &_cstNextCode;";
    put;
    put @1 '%let _cstSeqCnt=%eval(&_cstSeqCnt+1);';
    put @1 '%cstutil_writeresult(';
    put @3 "_cstResultId=CST0102";
    put @3 ",_cstResultParm1=" toSASRef +(-1) "." toMemName;
    put @3 ",_cstResultSeqParm=&_cstResultSeq";
    put @3 ',_cstSeqNoParm=&_cstSeqCnt';
    put @3 ",_cstSrcDataParm=&_cstSrcMacro";
    put @3 ",_cstResultFlagParm=0";
    put @3 ",_cstRCParm=&_cstThisMacroRC";
    put @3 ",_cstResultsDSParm=&_cstTempResultsDS";
    put @3 ");";
    put ;
  run;

  %include &_cstNextCode;

  %* Success;
  %let _cstThisMacroRC=0;

  %* send the results data set back;
  data &_cstThisResultsDS;
    set &_cstTempResultsDS;
  run;

  %goto CLEANUP;

  %****************************;
  %*  Handle any errors here  *;
  %****************************;
%ABORT_PROCESS:
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
              _cstResultId=&_cstMsgID
              ,_cstResultParm1=&_cstParam1
              ,_cstResultParm2=&_cstParam2
              ,_cstResultSeqParm=&_cstResultSeq
              ,_cstSeqNoParm=&_cstSeqCnt
              ,_cstSrcDataParm=&_cstSrcMacro
              ,_cstResultFlagParm=&_cstThisMacroRC
              ,_cstRCParm=&_cstThisMacroRC
              );
  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * clear the libname to the global metadata library;
  libname &_cstGlobalMDLib;

  * clear the filename to the temporary catalog;
  filename &_cstNextCode;

  * Clean up temporary data sets/catalogs if they exist;
  %if (&_cstDebug=0) %then %do;
    proc datasets nolist lib=work;
      delete _cstSASReferences_updated &_cstCopyDS &_cstTempDS1 &_cstTempDS2  / mt=data;
      delete &_cstNextCode  / mt=catalog;
      delete &_cstTempResultsDS  / mt=data;
    quit;
  %end;

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

  %* set the return code of this macro;
  %let _cst_rc=&_cstThisMacroRC;

%mend cstgetmetadataforstandard;