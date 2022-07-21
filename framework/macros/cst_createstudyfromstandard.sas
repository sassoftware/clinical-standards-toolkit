%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_createStudyFromStandard                                                    *;
%*                                                                                *;
%* Creates a study from the selected model and version.                           *;
%*                                                                                *;
%* @macvar _cst_MsgID Results: Result or validation check ID.                     *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1.                                   *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2.                                   *;
%* @macvar _cst_rc Task error status.                                             *;
%* @macvar _cstDebug Turns debugging on or off for the session.                   *;
%*             Values: 1 | 0                                                      *;
%* @macvar _cstResultsDS Results data set.                                        *;
%* @macvar _cstResultSeq Results: Unique invocation of check.                     *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq.              *;
%* @macvar _cstMessages Cross-standard work messages data set.                    *;
%*                                                                                *;
%* @param _cstModel - required - The name of the data model to use for this study.*;
%* @param _cstVersion - required - The version of the data model to use for this  *;
%*             study.                                                             *;
%* @param _cstStudyRootPath -required - The physical path location in which to    *;
%*             create the study.                                                  *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cst_createStudyFromStandard(
    _cstModel=,
    _cstVersion=,
    _cstStudyRootPath=
    ) / des='CST: Create a Study from the specified Standard/Version.';

%cstutil_setcstgroot;

%local
    _cstCheckID
    _cstDomCnt
    _cstDataRecords
    _cstErrorIndicator
    _cstExit_Error
    _cstRandom
    _cstResDS
    _cstResultFlag
    _cstSourceData
    _cstSrcData
    _cstStdDS
    _cstSysMsg
    _cstTableScope
    _cstUseSourceModel
    _dir
    _dirCreate
    _libCreate
    _results
    _stdvalid
    _stdyvalid
    did
    f
    rc
    stddir
    tempMsgDataSetWasCreated
    ;

  %let _cstErrorIndicator=0;
  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstDomCnt=0;
  %let _cstSrcData=;
  %let _cstSourceData=;
  %let _cstSeqCnt=0;
  %let _cstResultFlag=-1;
  %let rc=0;
  %let did=0;
  %let _stdvalid=N;
  %let _stdyvalid=N;
  %let _dirCreate=N;
  %let _results=&_cstResultsDS;

  %if &_cstDebug %then
  %do;
    %put >>> createStudyFromStandard;
    %put **************************************************** ;
    %put Model=&_cstModel;
    %put Version=&_cstVersion;
    %put StudyRootPath =&_cstStudyRootPath;
    %put ****************************************************;
  %end;

%cstUtil_createTempMessages(_cstCreationFlag=tempMsgDataSetWasCreated);

%if ("&_cstModel"="") or ("&_cstVersion"="") or ("&_cstStudyRootPath"="") %then
%do;
  %cstutil_writeresult(
             _cstResultID=CST0005
             ,_cstValCheckID=CST0005
             ,_cstResultParm1=createStudyFromStandard
             ,_cstResultParm2=
             ,_cstResultSeqParm=1
             ,_cstSeqNoParm=1
             ,_cstSrcdataParm=createStudyFromStandard
             ,_cstResultFlagParm=-1
             ,_cstRCParm=1
             ,_cstActualParm=
             ,_cstKeyValuesParm=
             ,_cstResultsDSParm=&_results
             );
  %goto exit;
%end;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);

%let _cstStdDS=work._cstStdDS&_cstRandom;
%let _cstResDS=work._cstResDS&_cstRandom;

%cst_getRegisteredStandards(_cstOutputDS=&_cstStdDS,  _cstResultsDS=&_cstResDS );

%if %sysfunc(exist(&_cstStdDS)) %then
%do;
  * search registered standards for selected standard*;
  %let _cstDataRecords=0;
  data &_cstStdDS;
    set &_cstStdDS(where=(upcase(Standard)=upcase("&_cstModel"))) nobs=_numobs;
    call symputx('_cstDataRecords',_numobs);
    output;
  run;
  %IF &_cstDataRecords>0 %THEN
  %do;
    * search registered standards for selected version, get the rootpath for the standard*;
    %let stddir=;
    data &_cstStdDS;
      set &_cstStdDS (where=(upcase(Standard)=upcase("&_cstModel") and
                             upcase(standardversion)=upcase("&_cstVersion") and
                             isdatastandard="Y"));
      call symput ('stddir',rootpath);
    run;
    %if "&stddir"="" %then
    %do;
      %cstutil_writeresult(
              _cstResultID=CST0083
              ,_cstValCheckID=CST0083
              ,_cstResultParm1=&_cstVersion
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcdataParm=createStudyFromStandard
              ,_cstResultFlagParm=-1
              ,_cstRCParm=1
              ,_cstActualParm=
              ,_cstKeyValuesParm=
              ,_cstResultsDSParm=&_results
              );
      %goto exit;
    %end;
  %end;
  %else
  %do;
    %cstutil_writeresult(
              _cstResultID=CST0082
              ,_cstValCheckID=CST0082
              ,_cstResultParm1=&_cstModel
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcdataParm=createStudyFromStandard
              ,_cstResultFlagParm=-1
              ,_cstRCParm=1
              ,_cstActualParm=
              ,_cstKeyValuesParm=
              ,_cstResultsDSParm=&_results
              );
    %goto exit;
  %end;
%end;

data _null_  ;
  rcstudy=filename("stdydir",kstrip("&_cstStudyRootPath"));
  _cstsysmsg=sysmsg();
  if rcstudy=0 then did=dopen("stdydir");
  if rcstudy ne 0 or did le 0 then do;
    dir=ktranslate(kstrip("&_cstStudyRootPath"),'/','\');
    call symput('_cst_MsgID','CST0070');
    call symput('_cst_MsgParm1',dir);
    call symput('_cst_MsgParm2','');
    call symput('_cstSrcData','createStudyFromStandard');
    call symput('_cst_rc','1');
    call symput('_cstResultFlag','-1');
    call symput('_cstExit_Error','1');
    call symput('_stdyvalid','N');
    %if &_cstDebug %then
    %do;
      put _cstsysmsg;
    %end;
  end;
  else call symput('_stdyvalid','Y');
run;

%if &_cst_rc %then
%do;
  %goto exit_error;
%end;

data _null_  ;
  rcstd=filename("stddir",kstrip("&stddir"));
  _cstsysmsg=sysmsg();
  dir=ktranslate(kstrip("&stddir")||'/'||dirname,'/','\');
  if rcstd=0 then did=dopen("stddir");
  if rcstd ne 0 or did le 0 then do;
    dir=ktranslate(kstrip("&stddir"),'/','\');
    call symput('_cst_MsgID','CST0071');
    call symput('_cst_MsgParm1',dir);
    call symput('_cst_MsgParm2','');
    call symput('_cstSrcData','createStudyFromStandard');
    call symput('_cst_rc','1');
    call symput('_cstResultFlag','-1');
    call symput('_cstExit_Error','1');
    call symput('_stdvalid','N');
    %if &_cstDebug %then
    %do;
      put _cstsysmsg;
    %end;
  end;
  else call symput('_stdvalid','Y');
run;

%if &_cst_rc %then
%do;
  %goto exit_error;
%end;

%if ("&_stdvalid"="Y" and "&_stdyvalid"="Y") %then %do;
  %* create the dirs for this study. This is specific to sdtm model;
  data _null_;
    length dirname $200 newdir $200 newdir2 $200;
    newdir="";
    newdir2="";
    do dirname="validation","control","data" ,"macros","messages","metadata","programs","results";
      newDir=dcreate(dirname,kstrip("&_cstStudyRootPath"));
      rc=sysrc();
      _cstSysMsg=sysmsg();
      if dirname="validation" and newdir ne '' and rc le 0 then do;
        newDir2=dcreate('control',kstrip("&_cstStudyRootPath")||"/validation");
        %if &_cstDebug %then
        %do;
          rc2=sysrc();
          _cstSysMsg2=sysmsg();
          put newdir2= _cstsysmsg2=;
        %end;
        if newdir2 eq '' and rc2>0 then do;
          dir=ktranslate(kstrip("&_cstStudyRootPath")||'/validation/control','/','\');
          call symput('_cst_MsgID','CST0072');
          call symput('_cst_MsgParm1',dir);
          call symput('_cst_MsgParm2','');
          call symput('_cstSrcData','createStudyFromStandard');
          call symput('_cst_rc','1');
          call symput('_cstResultFlag','-1');
          call symput('_cstExit_Error','1');
          call symput('_dirCreate','N');
          %if &_cstDebug %then
          %do;
            put _cstsysmsg2;
          %end;
        end;
      end;
      if newdir eq '' and rc gt 0 then do;
        dir=ktranslate(kstrip("&_cstStudyRootPath")||'/'||dirname,'/','\');
        call symput('_cst_MsgID','CST0072');
        call symput('_cst_MsgParm1',dir);
        call symput('_cst_MsgParm2','');
        call symput('_cstSrcData','createStudyFromStandard');
        call symput('_cst_rc','1');
        call symput('_cstResultFlag','-1');
        call symput('_cstExit_Error','1');
        call symput('_dirCreate','N');
        %if &_cstDebug %then
        %do;
          put _cstsysmsg;
        %end;
      end;
      else call symput('_dirCreate','Y');
    end;
  run;
%end;

%if &_cst_rc %then
%do;
  %goto exit_error;
%end;

%* directories created starting creating datasets *;
%if "&_dirCreate" = "Y" %then %do;

  %let _dir=%unquote(%sysfunc(ktranslate(%sysfunc(kstrip(&_cstStudyRootPath)),'/','\')));
  %cstutil_writeresult(
                  _cstResultID=CST0073
                  ,_cstValCheckID=CST0073
                  ,_cstResultParm1=&_DIR
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcdataParm=
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );

  %PUT "NOTE: Study directories created successfully in " &_dir;
  %let _libCreate=Y;

  %* check to see if we can assign libnames;
  data work._cstDS&_cstRandom;
    %cstutil_resultsdskeep;
      attrib  _cstSeqNoParm format=8. label="Sequence counter for result column";
      length dir $200 ;
      keep _cstResultParm1 _cstResultParm2;
      retain _cstSeqNoParm 0 _cstResultID _cstValCheckID _cstResultSeqParm _cstResultFlagParm _cstRCParm;
      * Set results data set attributes *;
      %cstutil_resultsdsattr;
      if _n_=1 then
      do;
        _cst_cstSeqNoParm=&_cstSeqCnt;
        _cstResultID="CST0075";
        _cstValCheckID="CST0075";
        _cstResultSeqParm=&_cstResultSeq;
        _cstResultFlagParm=1;
        _cstRCParm=0;
        _cstResultParm1='';
        _cstSrcdataParm = '';
        _cstActualParm='';
      end;

      dir=ktranslate(kstrip("&_cstStudyRootPath")||"/validation/control",'/','\');
      rc=libname("sdyval",dir);
      msg=sysmsg();
      link chk_lib;
      dir=ktranslate(kstrip("&_cstStudyRootPath")||"/metadata", '/','\');
      rc=libname("sdymeta",dir);
      msg=sysmsg();
      link CHK_LIB;
      dir=ktranslate(kstrip("&stddir")||"/validation/control",'/','\');
      rc=libname("stdval",dir,'','access=readonly');
      msg=sysmsg();
      link CHK_LIB;
      dir=ktranslate(kstrip("&stddir")||"/metadata",'/','\');
      rc=libname("stmeta",dir,'','access=readonly');
      msg=sysmsg();
      link CHK_LIB;
      call symputx('_cstSeqCnt',_cstSeqNoParm);
    chk_lib:
      if (rc ne 0 and rc ne -70004 ) then do;
        _cstResultParm2= dir;
        put msg;
        OUTPUT;
        _cstSeqNoParm+1;
        %* seqno=_cstSeqNo;
      end;
    return;
  run;

  %if %sysfunc(exist( work._cstDS&_cstRandom)) %then
  %do;
    data _null_;
      if 0 then set  work._cstDS&_cstRandom nobs=_numobs;
      call symputx('_cstDataRecords',_numobs);
      stop;
    run;
    %IF &_cstDataRecords %THEN %do;
      %let _libcreate=N;
      %cstutil_appendresultds(
                   _cstErrorDS=work._cstDS&_cstRandom
                  ,_cstResultID=CST0075
                  ,_cstVersion=&_cstVersion
                  ,_cstSource=CST
                  ,_cstStdRef=
                  );
    %end;
  %end;
  %if "&_libCreate" = "Y" %then %do;
    proc copy in=stdval out=sdyval;
      select validation_master;
    run;
    data sdymeta.source_columns;
      set stmeta.reference_columns;
      stop;
    run;
    data sdymeta.source_tables;
      set stmeta.reference_tables;
      stop;
    run;
    data sdyval.sasreferences (label="SAS File and Library References");
      attrib
        standard format=$char20.  label="Name of Standard"
        standardversion format=$char20.  label="Version of Standard"
        type format=$char40.  label="CST input/output data or metadata"
        subtype format=$char40.  label="Data or metadata subtype within type"
        SASref format=$char8. label="SAS libref or fileref"
        reftype format=$char8. label="Reference type (libref or fileref)"
        path format=$char200. label="Relative path"
        order format=8. label="Order within type (autocall,fmtseach)"
        memname format=$char48. label="Filename (null for libraries)"
        comment format=$char200. label="Explanatory comments"
       ;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      subtype="";
      type="sourcedata";
      SASref="srcdata";
      reftype="libref";
      path="&_cstStudyRootPath/data";
      memname="";
      order=.;
      comment="Path to study-specific SDTM domain data sets";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="sourcemetadata";
      subtype="table";
      SASref="srcmeta";
      reftype="libref";
      path="&_cstStudyRootPath/metadata";
      memname="source_tables.sas7bdat";
      order=.;
      comment="Source of study-specific SDTM table metadata";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="sourcemetadata";
      subtype="column";
      SASref="srcmeta";
      reftype="libref";
      path="&_cstStudyRootPath/metadata";
      memname="source_columns.sas7bdat";
      order=.;
      comment="Source of study-specific SDTM column metadata";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="referencecontrol";
      subtype="validation";
      SASref="refcntl";
      reftype="libref";
      path="";
      memname="validation_master.sas7bdat";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="control";
      subtype="validation";
      SASref="control";
      reftype="libref";
      path="&_cstStudyRootPath/control";
      memname="validation_control.sas7bdat";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="control";
      subtype="reference";
      SASref="control";
      reftype="libref";
      path="&_cstStudyRootPath/control";
      memname="sasreferences.sas7bdat";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="results";
      subtype="validationresults";
      SASref="results";
      reftype="libref";
      path="&_cstStudyRootPath/results";
      memname="validation_results.sas7bdat";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="results";
      subtype="validationmetrics";
      SASref="results";
      reftype="libref";
      path="&_cstStudyRootPath/results";
      memname="validation_metrics.sas7bdat";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="resultspackage";
      subtype="xml";
      SASref="package";
      reftype="fileref";
      path="&_cstStudyRootPath/results";
      memname="resultspackage.xml";
      order=.;
      comment="";
    output;
      standard="&_cstModel";
      standardversion="&_cstVersion";
      type="resultspackage";
      subtype="log";
      SASref="saslog";
      reftype="fileref";
      path="&_cstStudyRootPath/results";
      memname="CSTprocess.log";
      order=.;
      comment="";
    output;
    run;

   %let _dir=%unquote(%sysfunc(ktranslate(%sysfunc(kstrip(&_cstStudyRootPath)),'/','\')));
   %cstutil_writeresult(
              _cstResultID=CST0074
              ,_cstValCheckID=CST0074
              ,_cstResultParm1=&_DIR
              ,_cstResultParm2=
              ,_cstResultSeqParm=1
              ,_cstSeqNoParm=1
              ,_cstSrcdataParm=
              ,_cstResultFlagParm=0
              ,_cstRCParm=0
              ,_cstActualParm=
              ,_cstKeyValuesParm=
              ,_cstResultsDSParm=&_results
              );
  %end; %* _libcreate=Y loop *;
%end; %* _dircreate=Y loop *;
%goto CLEANUP;

%EXIT_ERROR:

  %* This is a catch-all for singly-occurring errors (only one of which can occur   *;
  %*  within this code module because of placement within non-overlapping else      *;
  %*  code blocks).                                                                 *;
  %if &_cstExit_Error %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %GOTO WRITE_RESULT;
  %end;
  %goto CLEANUP;
  %RETURN;

%WRITE_RESULT:
  %cstutil_writeresult(
              _cstResultID=&_cst_MsgID
              ,_cstValCheckID=&_cstCheckID
              ,_cstResultParm1=&_cst_MsgParm1
              ,_cstResultParm2=&_cst_MsgParm2
              ,_cstResultSeqParm=&_cstResultSeq
              ,_cstSeqNoParm=&_cstSeqCnt
              ,_cstSrcdataParm=&_cstSrcData
              ,_cstResultFlagParm=&_cstResultFlag
              ,_cstRCParm=&_cst_rc
              ,_cstActualParm=
              ,_cstKeyValuesParm=
              ,_cstResultsDSParm=&_results
              );
  %goto CLEANUP;
%RETURN;

%CLEANUP:

  %let f=stddir;
  %LET RC=%SYSFUNC(filename(f));
  %let f=stdydir;
  %LET RC=%SYSFUNC(filename(f));
  %if %sysfunc(exist( work._cstDS&_cstRandom)) %then %do;
    proc datasets nolist; delete %sysfunc(scan(work._cstDS&_cstRandom,2)); quit;
  %end;
  %if tempMsgDataSetWasCreated=1 %then %do;
    proc datasets nolist; delete %sysfunc(scan(work._cstMessages,2)); quit;
  %end;
  %if %sysfunc(exist(&_cstStdDS)) %then
  %do;
    proc datasets nolist; delete %sysfunc(scan(&_cstStdDS,2)); quit; run;
  %end;
  %if &tempMsgDataSetWasCreated=1 %then %do;
    proc datasets nolist; delete %sysfunc(scan(&_cstMessages,2)); quit; run;
  %end;
  %if %sysfunc(libref(sdyval))=0 %then %do;
    libname sdyval clear;
  %end;
  %if %sysfunc(libref(sdymeta))=0 %then %do;
    libname sdymeta clear;
  %end;
  %if %sysfunc(libref(stmeta))=0 %then %do;
    libname stmeta clear;
  %end;
  %if %sysfunc(libref(stdval))=0 %then %do;
    libname stdval clear;
  %end;

%RETURN;

%EXIT:
%GOTO CLEANUP;

%mend cst_createStudyFromStandard;




