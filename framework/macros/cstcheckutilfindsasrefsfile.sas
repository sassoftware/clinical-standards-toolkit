%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutilfindsasrefsfile                                                    *;
%*                                                                                *;
%* Determines whether files in the referenced SASReferences data set exist.       *;
%*                                                                                *;
%* This macro determines whether the specified files in the referenced            *;
%* SASReferences data set exist.                                                  *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (for      *;
%*       example, a full DATA step or PROC SQL invocation) and is used within the *;
%*       cstcheckentitynotfound macro. It creates and populates work._cstproblems,*;
%*       which is returned to the calling check macro for reporting purposes.     *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstValidationStd Standard of _cstSASRefsFile                          *;
%* @macvar _cstValidationStdVer StandardVersion of _cstSASRefsFile                *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%*                                                                                *;
%* @param _cstSASRefsFile  - required - The SASReferences data set to evaluate.   *;
%*            Default: &_cstDSName (passed from calling check macro)              *;
%* @param _cstStdsDS  - optional - The list of supported standards to use for     *;
%*            this check. If no data set is specified, all records in the         *;
%*            glmeta.standards data set are used. This might result in false      *;
%*            positive errors, especially for SAS catalogs, because required      *;
%*            librefs might not have been allocated. The supported standards data *;
%*            set must include the Standard, StandardVersion, and RootPath        *;
%*            columns.                                                            *;
%*            Default: glmeta.standards                                           *;
%* @param _cstFTypes  - required - The set of SASReferences file types of         *;
%*            interest (uppercased values of sasreferences.filetype).             *;
%*            Default: FILE FOLDER CATALOG                                        *;
%*                     NOTE: Data sets and data views are not supported.          *;
%* @param _cstOverrideUnresolvedMacro  - optional - Do not report unresolved      *;
%*            macro variables in the entity path as a problem (Y).                *;
%*            Values:  N | Y                                                      *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutilfindsasrefsfile(
    _cstSASRefsFile=&_cstDSName,
    _cstStdsDS=glmeta.standards,
    _cstFTypes=FILE FOLDER CATALOG,
    _cstOverrideUnresolvedMacro=N
    ) / des="CST: Checks for existence of a sasreferences file";

  %local
    _cstDataRecords
    _cstexit_error
  ;
  
  %let _cstDataRecords=0;
  %let _cstexit_error=0;
  
  %if ^%sysfunc(exist(&_cstSASRefsFile)) %then
  %do;
    %let _cst_MsgID=CST008;
    %let _cst_MsgParm1=&_cstSASRefsFile;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstactual=;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;

  %if %length(&_cstStdsDS)=0 %then
  %do;
    %let _cstStdsDS=work._cstAllStds;
    %cst_getRegisteredStandards(_cstOutputDS=&_cstStdsDS);
  %end;
  %if ^%sysfunc(exist(&_cstStdsDS)) %then
  %do;
    %let _cst_MsgID=CST008;
    %let _cst_MsgParm1=&_cstStdsDS;
    %let _cst_MsgParm2=;
    %let _cst_rc=0;
    %let _cstResultFlag=-1;
    %let _cstactual=;
    %let _cstSrcData=&sysmacroname;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;


  filename cstCode CATALOG "work._cstcode.entitynotfound.source" &_cstLRECL;

  * Limit files to selected standards *;
  proc sql noprint;
    create table work._cstEntities as
      select ref.*
        from &_cstStdsDS (keep=standard standardversion rootpath studylibraryrootpath
                          where=(upcase(standard)=upcase("&_cstValidationStd") and
                             upcase(standardversion)=upcase("&_cstValidationStdVer"))) std
          left join
             &_cstSASRefsFile ref
        on std.standard=ref.standard and std.standardversion=ref.standardversion
        where ref.standard ne ''
      order by ref.standard, ref.standardversion, type, subtype;
      select count(*) into :_cstMetricsCntNumRecs from work._cstEntities;
  quit;
  
  data work._cstUnresolvedEntities (keep=standard standardversion srcdata entitytype entityname problem);
    set work._cstEntities end=last;
        file cstCode;
      attrib entitytype format=$8.
             entityname format=$500.
             srcdata format=$200.
             tempvar format=$200.
             tempvar2 format=$200.
             problem format=$80.
             studylibraryrootpath format=$200.
             rootpath format=$200.
             oldstandard format=$20.
             oldstandardversion format=$20.;
    retain oldstandard oldstandardversion;
    if _n_=1 then do;
      call missing(entitytype,entityname,srcdata);
      call missing(rootpath,studylibraryrootpath);
      declare hash std(dataset:"&_cstStdsDS");
      std.defineKey("standard","standardversion");
      std.defineData("rootpath","studylibraryrootpath");
      std.defineDone();
      put @1 '%macro _cstTemp;';
      put @3 'data work._cstproblems (keep=standard standardversion srcdata entitytype entityname);';
      put @5 "set &_cstSASRefsFile;";
      put @7 'attrib entitytype format=$8. entityname format=$500. srcdata format=$200.;';
      put @5 'stop;';
      put @5 'call missing(of _all_);';
      put @3 'run;';
    end;
    entitytype=upcase(filetype);
    call missing(problem);
  
    rc=std.find(); * Placed here instead of inside loop so rootpath and studylibraryrootpath are available  *;

    if _n_=1 then
    do;
      put;
      tempvar=cats('%let studyrootpath=',studylibraryrootpath,';');
      put @3 tempvar;
      tempvar=cats('%let studyoutputpath=',studylibraryrootpath,';');
      put @3 tempvar;
      tempvar=cats('%let trgstudyrootpath=',studylibraryrootpath,';');
      put @3 tempvar;
    end;

    *Look only at user-specified file types that have a non-missing path - otherwise ignore *;
    if indexw("&_cstFTypes",entitytype) and ^missing(path) then do;
      put @3 '%let _cst_rc=0;';
      
      * Note the following statements assume the presence and use of the SASReferences column *;
      *  relpathprefix to resolve relative paths.  This column and this macro are new to      *;
      *  Toolkit with v1.5 and apply only to versions 1.5 and later.                          *;
      if upcase(relpathprefix)='ROOTPATH' and upcase(resolve(path)) ^=: upcase(resolve(rootpath)) then
      do;
*        tempvar=resolve(catx('/',rootpath,path));
        tempvar=catx('/',rootpath,path);
        select(entitytype);
          when('FILE','CATALOG')
          do;
*            entityname=resolve(catx('/',rootpath,path,memname));
            entityname=catx('/',rootpath,path,memname);
            if entitytype='CATALOG' then
            do;
              if index(memname,'.') then memname=scan(memname,1,'.');
              entityname=catx('.',sasref,memname);
              memname=entityname;
            end;
          end;
*          when('FOLDER') entityname=resolve(catx('/',rootpath,path));
          when('FOLDER') entityname=catx('/',rootpath,path);
          otherwise;
        end;
      end;
      else if upcase(relpathprefix)='STUDYLIBRARYROOTPATH' and upcase(resolve(path)) ^=: upcase(resolve(studylibraryrootpath)) then
      do;
        if ^missing(studylibraryrootpath) then
        do;
*          tempvar=resolve(catx('/',studylibraryrootpath,path));
          tempvar=catx('/',studylibraryrootpath,path);
          select(entitytype);
            when('FILE','CATALOG')
            do;
*              entityname=resolve(catx('/',studylibraryrootpath,path,memname));
              entityname=catx('/',studylibraryrootpath,path,memname);
              if entitytype='CATALOG' then
              do;
                if index(memname,'.') then memname=scan(memname,1,'.');
                entityname=catx('.',sasref,memname);
                memname=entityname;
              end;
            end;
*            when('FOLDER') entityname=resolve(catx('/',studylibraryrootpath,path));
            when('FOLDER') entityname=catx('/',studylibraryrootpath,path);
            otherwise;
          end;
        end;
        else do;
          * Report that we cannot assess because of missing studylibraryrootpath *;
          problem='Studylibraryrootpath not defined for this standard';
*          entityname=resolve(catx('/',path,memname));
          entityname=catx('/',path,memname);
          output;
        end;
      end;
      else do;
*        tempvar=resolve(path);
        tempvar=path;
        select(entitytype);
          when('FILE','CATALOG')
          do;
*            entityname=resolve(catx('/',path,memname));
            entityname=catx('/',path,memname);
            if entitytype='CATALOG' then
            do;
              if index(memname,'.') then memname=scan(memname,1,'.');
              entityname=catx('.',sasref,memname);
              memname=entityname;
            end;
          end;
*          when('FOLDER') entityname=resolve(path);
          when('FOLDER') entityname=path;
          otherwise;
        end;
      end;

      * Identify record as incomplete and report that information later  *;
      if kindexc(resolve(entityname),'&') then
      do;
        if missing(problem) then
        do;
          problem='SASReferences record contains unresolved macro';
          output;
        end;
      end;
      else
      do;

        if (standard ne oldstandard or standardversion ne oldstandardversion) then
        do;
          if ^missing(studylibraryrootpath) then
          do;
            tempvar2=cats('%let studyrootpath=',studylibraryrootpath,';');
            put @3 tempvar2;
            tempvar2=cats('%let studyoutputpath=',studylibraryrootpath,';');
            put @3 tempvar2;
            tempvar2=cats('%let trgstudyrootpath=',studylibraryrootpath,';');
            put @3 tempvar2;
          end;
        end;
     
        tempvar=cats('%cstutilfindvalidfile(_cstfiletype=',entitytype,',_cstfilepath=',tempvar,
                     ',_cstfileref=',memname,');');
        put @3 tempvar;
        put @3 '%if &_cst_rc>0 %then %do;';
          tempvar=cats('%let _cstObsNum=',strip(put(_n_,8.)),';');
          put @5 tempvar;
          put @5 'data work._cstProblems (keep=standard standardversion srcdata entitytype entityname);';
          put @7 'set work._cstProblems &_cstSASRefsFile (in=new firstObs=&_cstObsNum obs=&_cstObsNum);';
          put @9 'srcdata="&_cstSASRefsFile";';
          put @9 'if new then do;';
            tempvar=cats("entitytype='",entitytype,"';");
            put @11 tempvar;
            tempvar=cats("entityname='",entityname,"';");
            put @11 tempvar;
          put @9 'end;';
          put @5 'run;';
        put @3 '%end;';
      end;
    end;
    
    oldstandard=standard;
    oldstandardversion=standardversion;
    
    if last then do;
      put @3 '%let _cst_rc=0;';
      put @1 '%mend;';
      put @1 '%_cstTemp;';
    end;
  run;

  %* User-set parameter determines reporting strategy *;
  %if &_cstOverrideUnresolvedMacro=N %then
  %do;
    data _null_;
      if 0 then set work._cstUnresolvedEntities nobs=_numobs;
      call symputx('_cstDataRecords',_numobs);
      stop;
    run;

    %if &_cstDataRecords %then
    %do;

      * Create a temporary results data set. *;
      data _null_;
        attrib _csttemp label="Text string field for file names"  format=$char12.;
        _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
        call symputx('_csttempds',_csttemp);
      run;

      * Add the record to the temporary results data set. *;
      data &_csttempds (label='Work error data set');
        %cstutil_resultsdskeep;
          set work._cstUnresolvedEntities end=last;

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
            retain message resultseverity resultdetails '';

            resultid="CST0201";
            _cstMsgParm1=cats(strip(problem),'-entity not evaluated');
            _cstMsgParm2='';
            resultseq=&_cstResultSeq;
            resultflag=1;
            srcdata = "&_cstDSName";
            _cst_rc=0;
            actual = cats('entitytype=',strip(entitytype),',entityname=',strip(entityname));
            keyvalues='';
            _cstSeqNo+1;
            seqno=_cstSeqNo;
            checkid="&_cstCheckID";

            if last then
            do;
              call symputx('_cstSeqCnt',_cstSeqNo);
            end;
      run;

      %cstutil_appendresultds(
                  _cstErrorDS=&_csttempds
                  ,_cstVersion=&_cstStandardVersion
                  ,_cstSource=&_cstCheckSource
                  ,_cstStdRef=&_cstStandardRef
                  );

      proc datasets lib=work nolist;
        delete &_csttempds;
      quit;
    %end;
  %end;
  
  %if &_cstDebug=0 %then
  %do;
    proc datasets lib=work nolist;
      delete _cstUnresolvedEntities;
    quit;
  %end;

  %include cstCode;

  %if %sysfunc(exist(work._cstAllStds)) %then
  %do;
    proc datasets lib=work nolist;
      delete _cstAllStds;
    quit;
  %end;

%exit_error:

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
                   ,_cstResultsDSParm=&_cstResultsDS
                   );

  %end;

  %if &_cstDebug=0 %then
  %do;
    %if %sysfunc(cexist("work._cstcode.entitynotfound.source")) %then
    %do;
      proc catalog cat=work._cstcode;
        delete entitynotfound.source;
      run;
    
      * Clear the filename;
      filename cstCode;
    %end;
    
  %end;

%mend cstcheckutilfindsasrefsfile;

