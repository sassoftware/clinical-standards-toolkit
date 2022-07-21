%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_allocatesasreferences                                                  *;
%*                                                                                *;
%* Allocates the librefs and filerefs in the SASReferences data set.              *;
%*                                                                                *;
%* This macro also sets the autocall, format search, and compiled library paths   *;
%* based on the SASReferences settings.                                           *;
%*                                                                                *;
%* This macro must be called outside the context of a DATA step, typically as an  *;
%* initial step in any SAS Clinical Standards Toolkit driver program (for example,*;
%* cst_validate).                                                                 *;
%*                                                                                *;
%* NOTE: Multiple calls to cstutilvalidatesasreferences are made before           *;
%*       invoking cstutil_allocatesasreferences and within                        *;
%*       cstutil_allocatesasreferences. These invocations validate the structure  *;
%*       and content of the SASReferences data set.                               *;
%*                                                                                *;
%* @macvar _cstDeBug Turns debugging on or off for the session                    *;
%* @macvar _cstFMTLibraries Modify format search path with..                      *;
%* @macvar _cstMessageOrder Merge or append message data sets                     *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cst_MsgID Results: Result or validation check ID                      *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1                                    *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2                                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstReallocateSASRefs Reallocate SAS librefs and filerefs              *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstCheckID Check ID from the run-time check metadata                  *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%*                                                                                *;
%* @param _cstSASRefsType - optional - The initial type of SASReferences data set *;
%*            on which to base the set up:                                        *;
%*               SASREFERENCES: Lookthrough to standardsasreferences for any      *;
%*                    incomplete path/memname records by using                    *;
%*                    cst_insertstandardsasrefs.                                  *;
%*               STANDARDSASREFERENCES: Resolve relative paths using              *;
%*                    cstupdatestandardsasrefs.                                   *;
%*            Values: SASREFERENCES | STANDARDSASREFERENCES                       *;
%*            Default: SASREFERENCES                                              *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_allocatesasreferences(
    _cstSASRefsType=SASREFERENCES
    ) / des='CST: Allocate sasreferences';

  %cstutil_setcstgroot;

  %local
    _cstCSTVersion
    _cstEType
    _cstexit_error
    _cstNeedToDeleteMsgs
    _cstNextCode
    _cstRandom
    _cstResultFlag
    _cstSASRefCnt
    _csttemp
    _csttempds
    workpath
  ;

  %let _cstexit_error=0;
  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;

  data _null_;
    set sashelp.vslib(where=(libname="WORK"));
       call symputx('workpath',path);
  run;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;
  * Assign a filename for the code that will be generated;
  filename &_cstNextCode "&workpath./_csttemptemp.txt" &_cstLRECL;


  %******************************************************************************;
  %* Call to cst_insertStandardSASRefs checks, and completes based on defaults, *;
  %*  the contents of the sasreferences data set.  This "fills-in" default      *;
  %*  paths and memnames if these have not been pre-defined.                    *;
  %* Call to cstupdatestandardsasrefs resolves any relative paths found in the  *;
  %*  input standardsasreferences data set.                                     *;
  %* The absence of the _cstSASReferences named parameter in these calls forces *;
  %*  the two macro modules to look in the global macro variables               *
  %*  _cstSASRefsLoc and _cstSASRefsName to find the file.  These are derived   *;
  %*  from the init properties file identified prior to the call to this        *;
  %*  module in the primary driver file.                                        *;
  %******************************************************************************;

  %if &_cstSASRefsType=STANDARDSASREFERENCES %then
  %do;
    %cstupdatestandardsasrefs(_cstOutputDS=&_cstSASRefs);
  %end;
  %else
  %do;
    %cst_insertstandardsasrefs(_cstOutputDS=&_cstSASRefs);
  %end;

  %* Create a temporary messages data set                             *;
  %* We will not delete it later, as a "permanent" work._cstmessages  *;
  %*  that includes all referenced standards is created later in this *;
  %*  macro and will overwrite this temporary copy.                   *;
  %cstutil_createTempMessages;

  %if &_cst_rc or ^%sysfunc(exist(&_cstSASRefs))%then
  %do;
    %* If we have a failure in this call we will abort the process.;
    %let _cst_MsgID=CST0090;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    attrib _csttemp label="Text string field for file names"  format=$char12.;
     _csttemp = "_cs1" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_csttemp',_csttemp);
  run;

  %* Go get the Framework default version *;
  %cst_getRegisteredStandards(_cstOutputDS=&_csttemp);

  data _null_;
    set &_csttemp (where=(upcase(standard)="CST-FRAMEWORK" and upcase(isstandarddefault)="Y"));
    call symputx('_cstCSTVersion',standardversion);
  run;

  proc datasets lib=work nolist;
    delete &_csttemp;
  quit;

  %******************************************************************************;
  %* Check to see whether any paths contain undefined or null macro variables.  *;
  %* This prevents allocation to an unexpected library.  If any problems are    *;
  %* detected, we will exit and report the problems.                            *;
  %******************************************************************************;

  %let _cstSASRefCnt=0;

  data work._cstproblems (drop=i newpath);
    set &_cstSASRefs;
      attrib macrovar format=$32.
             newpath format=$500.;

      * path contains one or more macro references  *;
      if kindexc(path,'&') then do;
        newpath=path;
        * compress extra '&' characters out *;
        do until (kindex(newpath,'&&')=0);
          newpath=tranwrd(newpath,'&&','&');
        end;
        do i=1 to countc(newpath,'&');
          newpath=ksubstr(newpath,kindexc(newpath,'&'));
          if kindexc(newpath,'./\& ') then
            macrovar=ksubstr(newpath,1,kindexc(newpath,'./\ ')-1);
          else
            macrovar=newpath;
          if countc(macrovar,'&') > 1 then
            macrovar=ksubstr(macrovar,1,kindexc(ksubstr(macrovar,2),'&'));
          if symexist(kcompress(macrovar,'&')) then
          do;
            if resolve(macrovar)='' then output;  * macro variable is blank *;
          end;
          else
            output;   * macro variable does not exist *;
          newpath=ksubstr(newpath,kindexc(newpath,'&')+1);
        end;
      end;
  run;

  data _null_;
    if 0 then set work._cstproblems nobs=_numobs;
    call symputx('_cstSASRefCnt',_numobs);
    stop;
  run;

  %if &_cstSASRefCnt > 0 %then
  %do;

    * Create a temporary results data set. *;
    data _null_;
      attrib _csttemp label="Text string field for file names"  format=$char12.;
      _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_csttempds',_csttemp);
    run;

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
          retain message resultseverity resultdetails keyvalues '';

          resultid="CST0009";
          checkid="";
          _cstMsgParm1=macrovar;
          _cstMsgParm2='';
          resultseq=&_cstResultSeq;
          resultflag=1;
          srcdata = upcase("&_cstSASRefs");
          _cst_rc=1;
          actual=catx(', ',catx('=','type',type),catx('=','path',path));

          _cstSeqNo+1;
          seqno=_cstSeqNo;

      if last then
      do;
        call symputx('_cstSeqCnt',_cstSeqNo);
      end;
    run;
    %if (&syserr gt 4) %then
    %do;
      %* Check failed - SAS error  *;
      %let _cst_MsgID=CST0051;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=1;
      %let _cstResultFlag=-1;
     %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %cstutil_appendresultds(
                  _cstErrorDS=&_csttempds
                  ,_cstVersion=%str(&_cstCSTVersion)
                  ,_cstSource=CST
                  ,_cstStdRef=
                 );

    %if %symexist(_csttempds) %then
    %do;
      %if %length(&_csttempds)>0 %then
      %do;
        %if %sysfunc(exist(&_csttempds)) %then
        %do;
          proc datasets lib=work nolist;
            delete &_csttempds _cstproblems;
          quit;
        %end;
      %end;
    %end;

    %let _cstexit_error=0;
    %goto exit_error;
  %end;

  %let _cstSASRefCnt=0;

  *Default sort order allows us to honor order within type in processing that follows  *;
  proc sort data=&_cstSASRefs;
    by standard standardversion type order sasref path;
  run;

  %* Create a temporary results data set *;

  %******************************;
  %* Step 1:  Process librefs   *;
  %******************************;

  data _null_;
    attrib _csttemp label="Text string field for file names"  format=$char12.;
     _csttemp = "_cs2" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_csttemp',_csttemp);
  run;

  data &_csttemp (label='Work error data set');
    %cstutil_resultsdskeep;
    set &_cstSASRefs (keep=standard standardversion type order subtype sasref path reftype memname
                      where=(upcase(reftype)="LIBREF")) end=last;
      by standard standardversion type;
        attrib _cstCurrentPath format=$char2048. label="Current Libname or Filename path"
               _cstPath format=$char2048. label="Libname or Filename path"
               _cstOldPath format=$char2048. label="Previous Libname or Filename path"
               _cstoldSASRef format=$char8. label="Previous sasref"
               _csttemp format=$char2048. label="Work string variable"
               _cstOKtoAllocate format=8. label="Set to 1 if we should allocate"
               _cstOldOKtoAllocate format=8. label="Set to 1 if we should allocate"
               _cstDidNotAllocate format=8. label="Set to 1 if allocation not attempted"
               _cstSeqNo format=8. label="Sequence counter for result column"
               _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
               _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
        ;
        retain _cstSeqNo _cstPath _cstOldSASRef _cstOldPath _cstOldOKtoAllocate _csttemp;

        if _n_=1 then
          _cstSeqNo=&_cstSeqCnt;

        keep _cstMsgParm1 _cstMsgParm2;
        _cst_rc=0;

        * Set results data set attributes *;
        %cstutil_resultsdsattr;
        retain message resultseverity resultdetails keyvalues '';
        resultid='';

        _cstOKtoAllocate=0;
        _cstDidNotAllocate=0;

        _cstCurrentPath = pathname(SASref,'L');
        if _cstCurrentPath='' then
          _cstOKtoAllocate=1;  * SASref is not already allocated *;
        else if input(symget('_cstReallocateSASRefs'),8.) then
          _cstOKtoAllocate=1;  * SASref is allocated and we can reallocate based on property *;

        if first.type then
        do;
          _cstOldSASRef='';
          _cstOldPath='';
          _cstOldOKtoAllocate=0;
          _csttemp='';
          if last.type then
          do;
            * Single type, go ahead and allocate *;
            if _cstOKtoAllocate then
               call execute('libname ' || SASref || ' "' ||  kstrip(path) || '";');
            else
              _cstDidNotAllocate=1;
          end;
          else do;
            * More records for this type to come... *;
            _csttemp=catx(' ','libname',sasref,cats('"',path,'";'));
            _cstPath=cats('"',path,'"');
            _cstOldSasRef=sasref;
            _cstOldPath=kstrip(path);
            _cstOldOKtoAllocate=_cstOKtoAllocate;

          end;
        end;
        else
        do;
          if last.type then
          do;
            * Same libref *;
            if upcase(sasref)=upcase(_cstOldSASRef) then do;
              * Same path, allocate path from previous record *;


              if upcase(path)=upcase(_cstOldPath) then
              do;
                if _cstOKtoAllocate then
                  call execute(kstrip(_csttemp));
                else
                  _cstDidNotAllocate=1;
              end;
              else do;
                * Same libref but different path:  Concatenation required *;

                _cstPath=catx(' ',_cstPath,cats('"',path,'"'));
                if _cstOKtoAllocate then
                  call execute('libname ' || SASref || ' (' ||  kstrip(_cstPath) || ');');
                else
                  _cstDidNotAllocate=1;
              end;
            end;
            else do;

              * New sasref, allocate old and new ones *;
              if _cstOldOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
              _csttemp=catx(' ','libname',sasref,cats('"',path,'";'));
              if _cstOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
            end;
          end;
          else do;
            * Multiple (>2) records per type *;
            * Same libref *;
            if upcase(sasref)=upcase(_cstOldSASRef) then do;
              * Same libref but different path:  Concatenation required *;
              if upcase(kstrip(_cstOldPath)) ^= upcase(kstrip(path)) then
              do;
                _cstPath=catx(' ',_cstPath,cats('"',path,'"'));
                _csttemp=catx(' ','libname',sasref,cats('(',_cstPath,');'));
                _cstOldSasRef=sasref;
                _cstOldPath=kstrip(path);
              end;
            end;
            else do;
              * New sasref, allocate previous one *;
              if _cstOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
              _csttemp=catx(' ','libname',sasref,cats('"',path,'";'));
              _cstOldSasRef=sasref;
              _cstOldPath=kstrip(path);
            end;
          end;
        end;

        if _cstDidNotAllocate then
        do;
          resultid="CST0076";
          checkid="";
          _cstMsgParm1='libref';
          _cstMsgParm2=sasref;
          resultseq=&_cstResultSeq;
          resultflag=0;
          srcdata = upcase("&_cstSASRefs");
          _cst_rc=0;
          actual = 'type=' || strip(type) || ',SASref=' || strip(SASref) || ',reftype=' || strip(reftype) || ',path=' || kstrip(path) ;
          _cstSeqNo+1;
          seqno=_cstSeqNo;
          output;

          %if &_cstDebug %then
          %do;
            put 'Allocations Problem:';
            put _all_;
          %end;
        end;

      if last then
      do;
        call symputx('_cstSeqCnt',_cstSeqNo);
        call symputx('_cst_rc',_cst_rc);
        call symputx('_cst_MsgID',resultid);
      end;
  run;
  %if (&syserr gt 4) %then
  %do;
    %* Check failed - SAS error  *;
    %let _cst_MsgID=CST0051;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    if 0 then set &_csttemp nobs=_numobs;
    call symputx('_cstSASRefCnt',_numobs);
    stop;
  run;

  %if &_cstSASRefCnt > 0 %then
  %do;

    %cstutil_appendresultds(
                  _cstErrorDS=&_csttemp
                  ,_cstVersion=%str(&_cstCSTVersion)
                  ,_cstSource=CST
                  ,_cstStdRef=
                 );
  %end;

  %if %symexist(_csttemp) %then
  %do;
    %if %length(&_csttemp)>0 %then
    %do;
      %if %sysfunc(exist(&_csttemp)) %then
      %do;
        proc datasets lib=work nolist;
          delete &_csttemp;
        quit;
      %end;
    %end;
  %end;

  %******************************;
  %* Step 2:  Process filerefs  *;
  %******************************;

  *Default sort order allows us to honor order within type in processing that follows  *;
  proc sort data=&_cstSASRefs;
    by type order;
  run;

  %let _cstSASRefCnt=0;

  data _null_;
    attrib _csttemp label="Text string field for file names"  format=$char12.;
     _csttemp = "_cs3" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_csttemp',_csttemp);
  run;

  data &_csttemp (label='Work error data set');
    %cstutil_resultsdskeep;
    set &_cstSASRefs (keep=type order subtype sasref path reftype memname
                      where=(upcase(reftype)="FILEREF")) end=last;
      by type;
        attrib _cstCurrentPath format=$char2048. label="Current Libname or Filename path"
               _cstPath format=$2048. label="Libname or Filename path"
               _cstOldPath format=$2048. label="Previous Libname or Filename path"
               _cstoldSASRef format=$8. label="Previous sasref"
               _csttemp format=$2048. label="Work string variable"
               _cstOKtoAllocate format=8. label="Set to 1 if we should allocate"
               _cstDidNotAllocate format=8. label="Set to 1 if allocation not attempted"
               _cstFullPath format=$2048. label="Work full path"
               _cstSeqNo format=8. label="Sequence counter for result column"
               _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
               _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
        ;

        retain _cstSeqNo _cstPath _cstOldSASRef _cstOldPath _csttemp _cstFullPath;

        if _n_=1 then _cstSeqNo=&_cstSeqCnt;

        keep _cstMsgParm1 _cstMsgParm2;
        _cst_rc=0;

        * Set results data set attributes *;
        %cstutil_resultsdsattr;
        retain message resultseverity resultdetails keyvalues '';
        resultid='';

        _cstOKtoAllocate=0;
        _cstDidNotAllocate=0;

        _cstCurrentPath = pathname(SASref,'F');
        if _cstCurrentPath='' then
          _cstOKtoAllocate=1;
        else if input(symget('_cstReallocateSASRefs'),8.) then
          _cstOKtoAllocate=1;

        if first.type then
        do;
          _cstOldSASRef='';
          _cstOldPath='';
          _csttemp='';
          if memname ne '' then
            _cstFullPath=cats(path,'/',memname);
          else
            _cstFullPath=kstrip(path);

          if last.type then
          do;
            * Single type, go ahead and allocate *;
            if _cstOKtoAllocate then
              call execute('filename ' || SASref || ' "' ||  kstrip(_cstFullPath) || '";');
            else
              _cstDidNotAllocate=1;
          end;
          else do;
            * More records for this type to come... *;
            _csttemp=catx(' ','filename',sasref,cats('"',_cstFullPath,'";'));
            _cstPath=cats('"',_cstFullPath,'"');
            _cstOldSasRef=sasref;
            _cstOldPath=_cstFullPath;
          end;
        end;
        else
        do;
          if memname ne '' then
            _cstFullPath=cats(path,'/',memname);
          else
            _cstFullPath=kstrip(path);
          if last.type then
          do;
            * Same fileref *;
            if upcase(sasref)=upcase(_cstOldSASRef) then do;
              * Same path, allocate path from previous record *;
              if upcase(_cstFullPath)=upcase(_cstOldPath) then
                if _cstOKtoAllocate then
                  call execute(kstrip(_csttemp));
                else
                  _cstDidNotAllocate=1;
              else do;
                * Same fileref but different path:  Concatenation required *;
                if upcase(kstrip(_cstOldPath)) ^= upcase(kstrip(_cstFullPath)) then
                  _cstPath=catx(' ',_cstPath,cats('"',_cstFullPath,'"'));
                if _cstOKtoAllocate then
                  call execute('filename ' || SASref || ' (' ||  kstrip(_cstPath) || ');');
                else
                  _cstDidNotAllocate=1;
              end;
            end;
            else do;
              * New sasref, allocate old and new ones *;
              if _cstOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
              _csttemp=catx(' ','filename',sasref,cats('"',_cstFullPath,'";'));
              if _cstOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
            end;
          end;
          else do;
            * Multiple (>2) records per type *;

            * Same fileref *;
            if upcase(sasref)=upcase(_cstOldSASRef) then do;
              * Same fileref but different path:  Concatenation required *;
              if upcase(kstrip(_cstOldPath)) ^= upcase(kstrip(_cstFullPath)) then
              do;
                _cstPath=catx(' ',_cstPath,cats('"',_cstFullPath,'"'));
                _csttemp=catx(' ','filename',sasref,cats('(',_cstPath,');'));
              end;
            end;
            else do;
              * New sasref, allocate previous one *;
              if _cstOKtoAllocate then
                call execute(kstrip(_csttemp));
              else
                _cstDidNotAllocate=1;
              _csttemp=catx(' ','filename',sasref,cats('"',_cstFullPath,'";'));
              _cstOldSasRef=sasref;
              _cstOldPath=_cstFullPath;
            end;
          end;
        end;

        if _cstDidNotAllocate then
        do;
          resultid="CST0076";
          checkid="";
          _cstMsgParm1='fileref';
          _cstMsgParm2=sasref;
          resultseq=&_cstResultSeq;
          resultflag=0;
          srcdata = upcase("&_cstSASRefs");
          _cst_rc=0;
          actual = 'type=' || strip(type) || ',SASref=' || strip(SASref) || ',reftype=' || strip(reftype) || ',path=' || kstrip(path) || ',memname=' || strip(memname);
          _cstSeqNo+1;
          seqno=_cstSeqNo;
          output;

          %if &_cstDebug %then
          %do;
            put 'Allocations Problem:';
            put _all_;
          %end;
        end;

      if last then
      do;
        call symputx('_cstSeqCnt',_cstSeqNo);
        call symputx('_cst_rc',_cst_rc);
        call symputx('_cst_MsgID',resultid);
      end;
  run;
  %if (&syserr gt 4) %then
  %do;
    %* Check failed - SAS error  *;
    %let _cst_MsgID=CST0051;
    %let _cst_MsgParm1=;
    %let _cst_MsgParm2=;
    %let _cst_rc=1;
    %let _cstResultFlag=-1;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  data _null_;
    if 0 then set &_csttemp nobs=_numobs;
    call symputx('_cstSASRefCnt',_numobs);
    stop;
  run;

  %if &_cstSASRefCnt > 0 %then
  %do;
    %cstutil_appendresultds(
                  _cstErrorDS=&_csttemp
                  ,_cstVersion=%str(&_cstCSTVersion)
                  ,_cstSource=CST
                  ,_cstStdRef=
                 );
  %end;

  %if %sysfunc(exist(&_csttemp)) %then
  %do;
    proc datasets lib=work nolist;
      delete &_csttemp;
    quit;
  %end;

  data work._cstallocproblems (label='Work error data set');
    %cstutil_resultsdskeep;
    set &_cstSASRefs end=last;
      attrib
        _cstSeqNo format=8. label="Sequence counter for result column"
        _cstMsgParm1 format=$char40. label="Message parameter value 1 (temp)"
        _cstMsgParm2 format=$char40. label="Message parameter value 2 (temp)"
      ;

      keep _cstmsgParm1 _cstmsgParm2;

      * Set results data set attributes *;
      %cstutil_resultsdsattr;
      retain _cstSeqNo 0 message resultseverity resultdetails keyvalues '';
      if _n_=1 then
        _cstSeqNo=&_cstSeqCnt;

      _cst_rc=0;
      resultid="CST0075";
      checkid="";
      _cstMsgParm2=upcase(sasref);
      resultseq=&_cstResultSeq;
      resultflag=-1;
      srcdata = upcase("&_cstSASRefs");

      select(upcase(reftype));
        when("LIBREF")
        do;
          if libref(sasref) then
          do;
            _cstMsgParm1='libref';
            actual = 'type=' || strip(type) || ',SASref=' || strip(SASref) || ',reftype=' || strip(reftype) || ',path=' || kstrip(path);
            _cstSeqNo+1;
            seqno=_cstSeqNo;
            call symputx('_cst_MsgID',resultid);
            output;
          end;
        end;
        when("FILEREF")
        do;
          if fileref(sasref) and upcase(iotype) ne "OUTPUT" then
          do;
            _cstMsgParm1='fileref';
            actual = 'type=' || strip(type) || ',SASref=' || strip(SASref) || ',reftype=' || strip(reftype) || ',path=' || kstrip(path) || ',memname=' || strip(memname);
            _cstSeqNo+1;
            seqno=_cstSeqNo;
            call symputx('_cst_MsgID',resultid);
            output;
          end;
        end;
        otherwise;
      end;

    if last then
    do;
      call symputx('_cstSeqCnt',_cstSeqNo);
      call symputx('_cst_rc',_cst_rc);
    end;
  run;

  %let _cstSASRefCnt=0;
  data _null_;
    if 0 then set work._cstallocproblems nobs=_numobs;
    call symputx('_cstSASRefCnt',_numobs);
    stop;
  run;

  %if &_cstSASRefCnt > 0 %then
  %do;

    %cstutil_appendresultds(
                  _cstErrorDS=work._cstallocproblems
                  ,_cstVersion=%str(&_cstCSTVersion)
                  ,_cstSource=CST
                  ,_cstStdRef=
                 );
  %end;

  %if %sysfunc(exist(work._cstallocproblems)) %then
  %do;
    proc datasets lib=work nolist;
      delete _cstallocproblems;
    quit;
  %end;

  %* Third call to CSTUTILVALIDATESASREFERENCES, checking:                          *;
  %*   - Can the referenced input and output files and folders be reached? (CHK03)  *;
  %*   - Do all required look-thrus to Global Library defaults work?  (CHK04)       *;
  %cstutilvalidatesasreferences (_cstDSName=&_cstSASRefs,_cstallowoverride=CHK01 CHK02 CHK05 CHK06 CHK07 CHK08,
     _cstResultsType=RESULTS);

  %if (&_cst_rc) %then %do;
    %let _cstexit_error=1;
    %let _cst_MsgID=CST0090;
    %goto exit_error;
  %end;
  %else %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
               _cstResultID=CST0200
               ,_cstResultParm1=SASReferences data set was successfully validated
               ,_cstResultSeqParm=1
               ,_cstSeqNoParm=&_cstSeqCnt
               ,_cstSrcDataParm=CSTUTIL_ALLOCATESASREFERENCES
               ,_cstResultFlagParm=0
               ,_cstRCParm=0
               );
   %end;

  %***************************************************;
  %* Step 3:  Handle non-allocation actions:         *;
  %*                                                 *;
  %*  Set autocall path                              *;
  %*  Set format search path                         *;
  %*  Create work file of all messages               *;
  %*  Create global macro variables from properties  *;
  %***************************************************;

  %if (%symexist(_cstMessages)) %then
  %do;
    %if %length(&_cstMessages)=0 %then
      %let _cstMessages=work._cstmessages;
  %end;
  %else
  %do;
    data _null_;
        call symputx('_cstMessages','work._cstmessages', 'G');
    run;
  %end;

  data _null_;
    set &_cstSASRefs end=last;
    
      attrib _cstCurrentSASautos format=$200.
             _cstCurrentCmpLib format=$200.;
      retain _cstCurrentSASautos _cstCurrentCmpLib;
      
      if _n_=1 then
      do;
        _cstCurrentSASautos=getoption('sasautos');
        _cstCurrentCmpLib=getoption('cmplib');
      end;
      
      file &_cstNextCode mod;

      retain _cstautotext _cstfmttext _cstcmptext _cstmsgtext;
      attrib _cstautotext format=$char200. label="ordered autocall libref string";
      attrib _cstfmttext format=$200. label="ordered fmtsearch libref string";
      attrib _cstcmptext format=$200. label="ordered complib libref string";
      attrib _cstfmtcat format=$char20. label="<libref.>catalog reference";
      attrib _cstcmpds format=$char20. label="<libref.>dataset reference";
      attrib _cstmsgtext format=$char200. label="ordered messages libref.memname string";
      attrib _cstmsgtext2 format=$char200. label="ordered messages libref.memname string";
      attrib _csttemp format=$2000. label="temporary string variable";
      attrib _cstcount format=8. label="temporary counter variable";

      select(upcase(type));
        * Set the macro autocall path to include any user customized macros.             *;
        * SAS-supplied macros are referenced based on the SASAUTOS environment variable  *;
        *  defined in the SAS config file.                                               *;

        when ('AUTOCALL')
        do;
          if upcase(SASRef) ne "SASAUTOS" then
          do;
            if _cstautotext ne ''
              then _cstautotext = catx(" ",_cstautotext,SASRef);
            else _cstautotext = SASRef;
          end;
        end;

        * Set the format search path to include any user-written and user-referenced     *;
        *  formats.  SAS searches the format catalogs in the order listed, until the     *;
        *  desired member is found. The value of catalog-specification can be either     *;
        *  catalog or libref.catalog.                                                    *;

        when ('FMTSEARCH')
        do;
          if (memname ne '') then
          do;
            _csttemp = memname;
            if indexc(memname,'.') then
              _csttemp = scan(memname,1,'.');
            if SASRef ne '' then
              _cstfmtcat = catx(".",SASRef,_csttemp);
            else
              _cstfmtcat = _csttemp;
            if _cstfmttext ne ''
              then _cstfmttext = catx(" ",_cstfmttext,_cstfmtcat);
            else _cstfmttext = _cstfmtcat;
          end;
        end;

        * Set the compiled library path to include any user-written and user-referenced  *;
        *  functions.  SAS searches the libraries in the order listed, until the         *;
        *  desired data set is found.                                                    *;

        when ('CMPLIB')
        do;
          if (memname ne '') then
          do;
            _csttemp = memname;
            if indexc(memname,'.') then
              _csttemp = scan(memname,1,'.');
            if SASRef ne '' then
              _cstcmpds = catx(".",SASRef,_csttemp);
            else
              _cstcmpds = _csttemp;
            if _cstcmptext ne ''
              then _cstcmptext = catx(" ",_cstcmptext,_cstcmpds);
            else _cstcmptext = _cstcmpds;
          end;
        end;

        when ('PROPERTIES')
        do;

          * We assume that the fileref has been assigned above or errors have been documented.  *;
          if (SASRef ne '' and pathname(SASRef,'F') ne '') then
          do;
            if path ne '' and memname ne '' and indexc(memname,'.') then
              _csttemp = '%cst_setProperties(_cstPropertiesLocation=' || catx('/',path,memname) || ',_cstLocationType=PATH);';
            else
              _csttemp = '%cst_setProperties(_cstPropertiesLocation=' || strip(upcase(SASRef)) || ',_cstLocationType=FILENAME);';
            put _csttemp;
          end;
        end;

        when ('MESSAGES')
        do;

          * We assume that the file exists or errors have been documented above.  *;
          if (memname ne '' and SASRef ne '') then
          do;
            if indexc(memname,'.') then
              _csttemp = catx(".",SASRef,scan(memname,1,'.'));
            else
            _csttemp = catx(".",SASRef,memname);
          end;
          else
          do;
            * We assume any problems have been documented above.  *;
          end;
          if _cstmsgtext ne '' then
            _cstmsgtext = catx(" ",_cstmsgtext,_csttemp);
          else
            _cstmsgtext = _csttemp;

        end;
        otherwise;
      end;

      if last then
      do;
        _cstmsgtext2='';

        ***********************;
        *      SASAUTOS       *;
        ***********************;
        if (^missing(kcompress(_cstautotext))) then
          call execute('options append=(SASautos =('|| kstrip(_cstautotext) || ')) MautoSource;');

        ***********************;
        *      FMTSEARCH      *;
        ***********************;
        %if (%symexist(_cstFMTLibraries)) %then
        %do;
          * (Re)set fmtsearch based upon properties or sasreferences records ;
          * If these are missing, we do nothing to fmtsearch ;
          _csttemp='';
          %if %klength(&_cstFMTLibraries)>0 %then
          %do;
            _csttemp = symget('_cstFMTLibraries');
          %end;
          if _csttemp =: '**' then
          do;
            _csttemp = kcompress(_csttemp,'*');
            call execute('options fmtsearch = (' ||  kstrip(_cstfmttext) || ' ' || kstrip(_csttemp) || ');');
          end;
          else if (^missing(kcompress(_csttemp)) or ^missing(kcompress(_cstfmttext))) then
            call execute('options fmtsearch = (' || kstrip(_csttemp) ||  kstrip(_cstfmttext) || ');');
        %end;
        %else
        %do;
          if (^missing(kcompress(_cstfmttext))) then
            call execute('options fmtsearch = (' ||  kstrip(_cstfmttext) || ');');
        %end;

        ***********************;
        *       CMPLIB        *;
        ***********************;
        if (^missing(kcompress(_cstcmptext))) then
          call execute('options append=(cmplib =('|| kstrip(_cstcmptext) || '));');

        ***********************;
        *      MESSAGES       *;
        ***********************;
        if (_cstmsgtext ne '') then
        do;
          _cstcount=countw(_cstmsgtext,' ');
          %if (%symexist(_cstMessageOrder)) %then
          %do;
            %* By setting this property, user indicates intent to use look-through of      *;
            %* messaging based upon the order of the data sets specified in sasreferences: *;
            %* first file containing the messageID is used.                                *;

            %if %SYSFUNC(upcase(&_cstMessageOrder))=MERGE %then
            %do;
              if _cstcount>1 then
              do;
                do i = 1 to _cstcount;
                  _csttemp = scan(_cstmsgtext,i,' ');
                  _cstmsgtext2 = catx(" ",_cstmsgtext2,cats('_cstmsgds',i));
                  call execute('proc sort data=' || strip(_csttemp) || ' out=' || cats('_cstmsgds',i) || '; by resultid standardversion checksource; run;');
                end;
                call execute('data &_cstMessages; merge ' ||  strip(_cstmsgtext2) || '; by resultid standardversion checksource; run;');
                call execute('proc datasets lib=work nolist; delete ' || strip(_cstmsgtext2) || ';quit;');
              end;
              else
                call execute('data &_cstMessages; set ' ||  strip(_cstmsgtext) || '; run;');
            %end;
            %else
            %do;
              %* Default behavior:  APPEND;
              call execute('data &_cstMessages; set ' ||  strip(_cstmsgtext) || '; run;');
            %end;
          %end;
          %else
          %do;
            %* Default behavior:  APPEND;
            call execute('data &_cstMessages; set ' ||  strip(_cstmsgtext) || '; run;');
          %end;
        end;
        else
        do;
          _csttemp = '%cstutil_createTempMessages;';
          put _csttemp;
        end;
      end;

  run;

  %include &_cstNextCode;

  %******************************;
  %* Step 4:  Cleanup           *;
  %******************************;

  *Default sort order   *;
  proc sort data=&_cstSASRefs;
    by standard standardversion type order sasref path;
  run;

%exit_error:

    %if &_cstexit_error %then
    %do;
      %if &_cstSeqCnt<0 %then
         %let _cstSeqCnt=0;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %if %symexist(_cstCheckID) %then
         %let _cstEType=&_cstCheckID;
      %else
         %let _cstEType=&_cst_MsgID;

      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstEType
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

    * Delete the derived source code  *;
    data _null_;
      fname="&_cstNextCode";
      if fexist(fname) then
         rc=fdelete(fname);
    run;

    * clear the filename to the temporary catalog;
    filename &_cstNextCode;

    %if &_cstDebug=1 %then
    %do;
      %put <<< cstutil_allocatesasreferences;
    %end;

%mend cstutil_allocatesasreferences;