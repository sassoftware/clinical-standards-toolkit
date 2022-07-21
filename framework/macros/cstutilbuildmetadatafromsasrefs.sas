%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilbuildmetadatafromsasrefs                                                *;
%*                                                                                *;
%* Builds the framework reference_tables and reference_columns data sets.         *;
%*                                                                                *;
%* This macro builds the framework reference_tables and reference_columns data    *;
%* sets from a SASReferences data set (where filetype=DATASET).                   *;
%*                                                                                *;
%* NOTE: Libraries must be allocated before invoking this macro.                  *;
%*                                                                                *;
%* @macvar _cst_rc  Task error status                                             *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%*                                                                                *;
%* @param cstSRefsDS - required - The SASReference data set. The value must use   *;
%*            the format (libname.)member.                                        *;
%*            Default: &_cstsasrefs                                               *;
%* @param cstRefTabDS - required - The reference metadata table metadata data set.*;
%*            The value must use the format (libname.)member.                     *;
%*            Default: work.reference_tables                                      *;
%* @param cstRefColDS - required - The reference metadata column metadata data    *;
%*            set. The value must use the format (libname.)member.                *;
%*            Default: work.reference_columns                                     *;
%* @param cstSrcTabDS - optional - The source metadata table metadata data set.   *;
%*            The value must use the format (libname.)member. If this parameter   *;
%*            is not specified, no source metadata is created. By default, this   *;
%*            is a copy of cstRefTabDS.                                           *;
%* @param cstSrcColDS - optional - The source metadata column metadata data set.  *;
%*            The value must use the format (libname.)member. If this parameter   *;
%*            is not specified, no source metadata is created. By default, this   *;
%*            is a copy of cstRefColDS.                                           *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstutilbuildmetadatafromsasrefs(
    cstSRefsDS=&_cstsasrefs,
    cstRefTabDS=work.reference_tables,
    cstRefColDS=work.reference_columns,
    cstSrcTabDS=,
    cstSrcColDS=
    ) / des='CST: Build metadata from SASRefs';

  %* Declare local variables used in the macro  *;
  %local
    _cstErrorDetected
    _cstexit_error
  ;

  %let _cstErrorDetected=0;
  %let _cstexit_error=0;

  %* If there is any problem entering this method, abort and do not run  *;
  %if (&_cst_rc) %then %do;
    %goto exit_abort;
  %end;

  %if (%length(&cstSRefsDS)=0) %then %do;
    %let _cst_MsgID=CST0103;
    %let _cstexit_error=1;
    %goto exit_error;
  %end;
  %else %do;
    %if (^%sysfunc(exist(&cstSRefsDS))) %then
    %do;
      %let _cst_MsgID=CST0103;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;
  %end;

%**********************************************************************;
%* Internal helper macro                                              *;
%* (convenience macros supporting repetitive calls throughout module) *;
%**********************************************************************;

%macro _cstCommonCode(_cstDSName=);
  %cstutilfindvalidfile(_cstfiletype=DATASET,_cstfileref=&_cstDSName);
  %if (&_cst_rc) %then %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultID=CST0202
               ,_cstResultParm1=%str(&_cst_rcmsg)
               ,_cstResultSeqParm=1
               ,_cstSeqNoParm=&_cstSeqCnt
               ,_cstSrcDataParm=%upcase(&_cstDSName)
               ,_cstResultFlagParm=1
               ,_cstRCParm=&_cst_rc
               );
     %let _cst_rc=0;
     %let _cst_rcmsg=;
     %return;
  %end;

  proc contents data=&_cstDSName out=work._cstContents
      (keep=libname memname memlabel name type length label varnum sorted sortedby)  noprint;
  run;

  proc sort data=work._cstContents;
    by libname memname sortedby;
  run;

  ********************;
  * Table metadata   *;
  ********************;

  data work.tables (keep=sasref table label keys);
    set work._cstcontents (keep=libname memname memlabel name sorted sortedby);
      by libname memname;
    attrib
      sasref format=$8. label="SASreferences libref"
      table format=$32. label="Table Name"
      label format=$40. label="Table Label"
      keys format=$200. label="Table Keys"
    ;

    retain keys;
    if first.memname then
      keys='';

    * First look to see if the data set is sorted, and if so assume the sort columns as keys *;
    if sorted=1 then
    do;
      if sortedby ne . then
        keys = catx(' ',keys,name);
    end;
    if last.memname then
    do;
      sasref=libname;
      table=memname;
      label=memlabel;
      output;
    end;
  run;

  proc append base=work._cstTables data=work.tables;
  run;
  proc datasets nolist lib=work;
    delete tables;
  quit;

  ********************;
  * Column metadata  *;
  ********************;

  proc sort data=work._cstContents;
    by libname memname varnum;
  run;

  data work.columns (keep=sasref table column label order type length core);
    set work._cstcontents (drop=memlabel sorted sortedby rename=(label=clabel length=clength type=ctype));
    attrib
      sasref format=$8. label="SAS libref or fileref"
      table format=$32. label="Table Name"
      column format=$32. label="Column Name"
      label format=$200. label="Column Description"
      order format=8. label="Column Order"
      type format=$1. label="Column Type"
      length format=8. label="Column Length"
      core format=$10. label="Column Required or Optional"
      comment format=$200. label="Comment"
    ;

    sasref=libname;
    table=memname;
    column=name;
    label=clabel;
    order=varnum;
    select(ctype);
      when(1) type='N';
      otherwise type='C';
    end;
    length=clength;
    core='Req';
    call missing(comment);
  run;

  proc append base=work._cstColumns data=work.columns;
  run;

  proc datasets nolist lib=work;
    delete columns _cstContents;
  quit;

%mend;

  filename cstCode CATALOG "work._cstInc.buildrefmeta.source" &_cstLRECL;

  * Our interest here is only the distinct SASReferences input data sets, excluding catalogs, files and folders  *;
  data work._cstSASRefsTables;
    set &cstSRefsDS (where=(upcase(reftype)='LIBREF' and upcase(filetype)='DATASET' and
                             upcase(iotype) in ('INPUT' 'BOTH') and upcase(path) ne '&WORKPATH'));
    attrib table format=$32. label="Table Name"
           datetime format=$20. label="Derivation Datetime";

    datetime=put(datetime(),E8601DT20.);
    table=scan(memname,1,'.');
  run;

  proc sort data=work._cstSASRefsTables;
    by sasref table;
  run;
  
  data work._cstSASRefsTables (keep=standard standardversion type subtype sasref table iotype allowoverwrite 
                                    relpathprefix path datetime comment);
    set work._cstSASRefsTables;
      by sasref table;
      
    file cstCode;
    attrib tempvar format=$200.;

    if first.table then
    do;
      tempvar=catx(' ','%_cstCommonCode(_cstDSName=',catx('.',sasref,table),');');
      put tempvar;
    end;
  run;

  %include cstCode /source2;
  %* clear the filename;
  filename cstCode;

  proc sql noprint;
    create table &cstRefTabDS as
    select upcase(sasrefs.sasref) as sasref,
           upcase(sasrefs.table) as table,
           contents.label,
           sasrefs.path,
           contents.keys,
           sasrefs.type,
           sasrefs.subtype,
           sasrefs.iotype,
           sasrefs.allowoverwrite,
           sasrefs.relpathprefix,
           sasrefs.standard,
           sasrefs.standardversion,
           sasrefs.datetime,
           sasrefs.comment
    from work._cstSASRefsTables sasrefs
           left join
         work._cstTables contents
    on upcase(sasrefs.sasref)=contents.sasref and upcase(sasrefs.table)=contents.table
    order by sasref,table;
  quit;
  %if (&sqlrc gt 0) %then
  %do;
      %let _cst_MsgID=CST0077;
      %let _cst_MsgParm1=&cstRefTabDS;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  proc sql noprint;
    create table &cstRefColDS as
    select contents.*,
           sasrefs.standard,
           sasrefs.standardversion
    from work._cstSASRefsTables sasrefs
           left join
         work._cstColumns contents
    on upcase(sasrefs.sasref)=contents.sasref and upcase(sasrefs.table)=contents.table
    order by sasref,table,order;
  quit;
  %if (&sqlrc gt 0) %then
  %do;
      %let _cst_MsgID=CST0077;
      %let _cst_MsgParm1=&cstRefColDS;
      %let _cstexit_error=1;
      %goto exit_error;
  %end;

  proc datasets nolist lib=work;
    delete _cstInc / mt=catalog;
    delete _cstTables _cstColumns _cstSASRefsTables;
  quit;

  %* Conditionally create source metadata if data set names provided as parameter values *;
  %if (%length(&cstSrcTabDS)>0) %then %do;
    data &cstSrcTabDS;
      set &cstRefTabDS;
    run;
  %end;

  %if (%length(&cstSrcColDS)>0) %then %do;
    data &cstSrcColDS;
      set &cstRefColDS;
    run;
  %end;

%exit_error:

  %if &_cstexit_error %then
  %do;
    %let _cst_rc=1;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                   _cstResultID=&_cst_MsgID
                   ,_cstResultParm1=&_cst_MsgParm1
                   ,_cstResultParm2=&_cst_MsgParm2
                   ,_cstResultSeqParm=1
                   ,_cstSeqNoParm=&_cstSeqCnt
                   ,_cstSrcDataParm=CSTUTILBUILDMETADATAFROMSASREFS
                   ,_cstResultFlagParm=-1
                   ,_cstRCParm=&_cst_rc
                   );
  %end;
  %else %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
               _cstResultID=CST0200
               ,_cstResultParm1=Reference metadata was successfully derived from &cstSRefsDS
               ,_cstResultSeqParm=1
               ,_cstSeqNoParm=&_cstSeqCnt
               ,_cstSrcDataParm=CSTUTILBUILDMETADATAFROMSASREFS
               ,_cstResultFlagParm=0
               ,_cstRCParm=0
               );
   %end;

%exit_abort:

%mend cstutilbuildmetadatafromsasrefs;

