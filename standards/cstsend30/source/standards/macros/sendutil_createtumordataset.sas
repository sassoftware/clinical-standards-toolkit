%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sendutil_createtumordataset                                                    *;
%*                                                                                *;
%* Creates a SEND TUMOR.XPT file and data set.                                    *;
%*                                                                                *;
%* This macro creates a TUMOR.XPT file and data set as specified for FDA          *;
%* submission in the SEND Version 3.0 Implementation Guide, Appendix C.           *;
%*                                                                                *;
%* NOTE: The following source domains are required: DM, TX, EX, DS, MI, and TF.   *;
%*                                                                                *;
%* @macvar studyRootPath Root path to the sample source study                     *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param _cstSENDInputLibrary - required - The libname that points to the SEND   *;
%*            domains.                                                            *;
%* @param _cstSENDOutputDSFile - required - The libname.SAS data set name         *;
%*            (for example, study1.tumor) combination that specifies the data set *;
%*            name and library in which the content is written.                   *;
%* @param _cstSENDCreateXPT - optional - Generate a transport file.               *;
%*            Default: 1                                                          *;
%* @param _cstSENDOutputXPTFile - conditional - The full path and filename of the *;
%*            transport file to generate. If _cstSENDCreateXPT=1, a value is      *;
%*            required.                                                           *;
%*            Example:  c:\protocol_abc\study123\fda\tumor\rat.xpt                *;
%* @param _cstSENDExtendedVars - optional - Include additional SEND domain        *;
%*            variables in the tumor data set and XPT file. Variables should be   *;
%*            specified in the form of domain.variable (e.g. TX.SET DM.ARM) and   *;
%*            be space-delimited. Columns may only come from the set of required  *;
%*            domains itemized above. If any problems are detected parsing or     *;
%*            finding variables itemized in this parameter, warning messages will *;
%*            be reported and the process will not abort. Warning messages may be *;
%*            generated if the column already is included in the work file.       *;
%* @param _cstAbortIfDataIssue - optional - If a data issue is detected in the    *;
%*            source SEND domains, should the macro processing be aborted?  Y/N   *;
%*            Default: N                                                          *;
%*            Note that macro parameter errors will cause the process to abort    *;
%*            regardless of this parameter value.                                 *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%*                                                                                *;
%* @history 27September2017 Addresses Technical Support Defect S1360970           *;
%*                                                                                *;
%* @exposure external                                                             *;

%macro sendutil_createtumordataset(
    _cstSENDInputLibrary=,
    _cstSENDOutputDSFile=,
    _cstSENDCreateXPT=1,
    _cstSENDOutputXPTFile=,
    _cstSENDExtendedVars=,
    _cstAbortIfDataIssue=N
    ) / des='CST: Create FDA TUMOR.XPT from SEND Data';

  %local
    dm_vars
    ds_vars
    ex_vars
    mi_vars
    mi_vars_sql
    tf_vars
    tf_vars_sql
    tx_vars
    _cstMsg
    _cstPreLS
    _cstRCPrefix
    _cstReqDS
    _cstRN
    _cstrundt
    _cstwarning_rc
    _dropcolumn
    _droplist
  ;

  %* Set linesize to handle longer Log messages;
  %let _cstPreLS=%sysfunc(getoption(LINESIZE));
  %put &=_cstPreLS;
  options ls=200;

  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;


  %* Write information about this process to the results data set  *;
  %if %symexist(_cstResultsDS) %then
  %do;
    data _null_;
      call symputx('_cstrundt',put(datetime(),is8601dt.));
    run;

    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstStandard,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStandardVersion,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: CREATE_TUMORDATASET,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: METADATA DERIVATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstsasrefs,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
    %if %symexist(studyRootPath) %then
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %else
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=9;
  %end;

  %if &_cstDebug=1 %then
  %do;
    %put ************  ENTERING MACRO SENDUTIL_CREATETUMORDATASET  ************;
    %put _cstSENDInputLibrary =&_cstSENDInputLibrary;
    %put _cstSENDOutputDSFile =&_cstSENDOutputDSFile;
    %put _cstSENDCreateXPT    =&_cstSENDCreateXPT;
    %put _cstSENDOutputXPTFile=&_cstSENDOutputXPTFile;
    %put _cstSENDExtendedVars=&_cstSENDExtendedVars;
    %put _cstAbortIfDataIssue =&_cstAbortIfDataIssue ;
    %put **********************************************************************;
  %end;

  %let _cst_rc=0;
  %let _cstMsg=;
  %let _cstwarning_rc=0;
  %*************************************************************;
  %*  Check for existence of needed parameters and data sets   *;
  %*************************************************************;
  %if &_cstSENDInputLibrary= %then
  %do;
    %let _cstMsg=The SEND input LIBRARY is required;
    %put %str(ERR%str(OR):) &_cstMsg;
    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=TUMOR data set/xpt program cannot run - &_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
    %let _cst_rc=1;
  %end;
  %if &_cstSENDOutputDSFile= %then
  %do;
    %let _cstMsg=The SEND data set output LIBRARY.<SASDATASET name> is required;
    %put %str(ERR%str(OR):) &_cstMsg;
    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=TUMOR data set/xpt program cannot run - &_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
    %let _cst_rc=1;
  %end;
  %if %length(&_cstSENDOutputXPTFile)=0 and &_cstSENDCreateXPT eq 1 %then
  %do;
    %let _cstMsg=The SEND transport output path and filename is required;
    %put %str(ERR%str(OR):) &_cstMsg;
    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=TUMOR data set/xpt program cannot run - &_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
    %let _cst_rc=1;
  %end;
  %if &_cst_rc > 0 %then %goto exit_macro;

  %*******************************************;
  %*  Check existence of required data sets  *;
  %*  DM TX EX DS MI TF                      *;
  %*******************************************;
  %let _requiredDomains=DM TX EX DS MI TF;
  %do j=1 %to %sysfunc(countw(&_requiredDomains,' '));
    %let _cstReqDS=&_cstSENDInputLibrary..%scan(&_requiredDomains,&j,' ');
    %let %scan(&_requiredDomains,&j,' ')_vars=;
    %if not %sysfunc(exist(&_cstReqDS)) %then
    %do;
      %let _cstMsg=The SEND data set &_cstReqDS does not exist;
      %put %str(ERR%str(OR):) &_cstMsg;
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=&_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
      %let _cst_rc=1;
    %end;
  %end;

  %let _cstSENDExtendedVars=%upcase(&_cstSENDExtendedVars);
  %do i=1 %to %sysfunc(countw(&_cstSENDExtendedVars,' '));
    %let _extendedVar=%scan(&_cstSENDExtendedVars,&i,' ');
    %let _extendedVarDomain=%scan(&_extendedVar,1,'.');
    %let _extendedDomainColumn=%scan(&_extendedVar,2,'.');
    %if %length(&_extendedVarDomain)=0 or %length(&_extendedDomainColumn)=0 %then
    %do;
      %let _cstMsg=An invalid value for the _cstSENDExtendedVars parameter was found. The variable is ignored.;
      %put %str(WARN%str(ING)): &_cstMsg;
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=&_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
      %let _cst_rc=0;
    %end;
    %else %do;
      %let _validDomain=0;
      %do j=1 %to %sysfunc(countw(&_requiredDomains,' '));
        %if &_extendedVarDomain=%scan(&_requiredDomains,&j,' ') %then
          %let _validDomain=1;
      %end;
      %if ^&_validDomain %then
      %do;
        %let _cstMsg=The &_extendedVarDomain..&_extendedDomainColumn column referenced in the _cstSENDExtendedVars parameter cannot be added because &_extendedVarDomain is an unsupported domain;
        %put %str(WARN%str(ING)): &_cstMsg;
        %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=&_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
        %let _cst_rc=0;
      %end;
      %else %do;
        %let dsid = %sysfunc(open(&_cstSENDInputLibrary..&_extendedVarDomain));
        %if (&dsid) %then %do;
          %if ^%sysfunc(varnum(&dsid,&_extendedDomainColumn)) %then
          %do;
            %let _cstMsg=The &_extendedVarDomain..&_extendedDomainColumn column referenced in the _cstSENDExtendedVars  parameter cannot be added because it cannot be found;
            %put %str(WARN%str(ING)): &_cstMsg;
            %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=&_cstMsg,_cstSeqNoParm=1,_cstSrcDataParm=SENDUTIL_CREATETUMORDATASET);
           %let _cst_rc=0;
          %end;
          %else
          %do;
            %let &_extendedVarDomain._vars=&&&_extendedVarDomain._vars &_extendedDomainColumn;
            %if &_extendedVarDomain=TF or &_extendedVarDomain=MI %then
            %do;
              %let &_extendedVarDomain._vars_sql=&&&_extendedVarDomain._vars_sql &_extendedVar;
            %end;
          %end;
          %let rc = %sysfunc(close(&dsid));
        %end;
      %end;
    %end;
  %end;
  %let mi_vars_sql=%sysfunc(tranwrd(%cmpres(&mi_vars_sql),%str(MI.),%str(,MI.)));
  %let tf_vars_sql=%sysfunc(tranwrd(%cmpres(&tf_vars_sql),%str(TF.),%str(,TF.)));

  %let _cstAbortIfDataIssue=%upcase(&_cstAbortIfDataIssue);
  %if "&_cstAbortIfDataIssue"^="Y" and "&_cstAbortIfDataIssue"^="N" %then
  %do;
    %let _cstAbortIfDataIssue=N;
    %let _cstMsg=An invalid value for the _cstAbortIfDataIssue parameter was found. _cstAbortIfDataIssue=N is used.;
    %put %str(NOTE): &_cstMsg;
    %let _cst_rc=0;
  %end;
  %if &_cstAbortIfDataIssue=N %then
    %let _cstRCPrefix=-;

  
  %****************************************************;
  %*  Required information is missing - Exit program  *;
  %****************************************************;
  %if &_cst_rc > 0 %then %goto exit_macro;

  %***************************************************************************************;
  %*  Generate random number for data set names to reduce filename conflicts during run  *;
  %***************************************************************************************;
  %cstutil_getRandomNumber(_cstVarname=_cstRN);
  %*******************************************************************************;
  %*  Prepare the DM and TX data to retrieve study and dosing group information  *;
  %*  Sort data for later merge to create the tumor data set                     *;
  %*******************************************************************************;
  proc sort data=&_cstSENDInputLibrary..dm out=work.dm&_cstRN(keep=studyid usubjid species sex setcd &dm_vars);
    by setcd;
  run;

  proc sort data=&_cstSENDInputLibrary..tx out=work.tx&_cstRN(keep=setcd txval &tx_vars);
    by setcd;
    where upcase(txparmcd)='SPGRPCD';
  run;

  data work.dg&_cstRN (keep=studyid dosegp usubjid species sex &dm_vars &tx_vars);
    merge work.dm&_cstRN 
          work.tx&_cstRN end=last;
      by setcd;
    length dosegp 8.;
    dosegp=input(put(txval,8.),8.);
    if last and symget('tx_vars') ne '' then     
      put "NOTE: Values for the added TX domain variable(s) &tx_vars come from the txparmcd='SPGRPCD' record";
  run;

  proc sort data=work.dg&_cstRN;
    by studyid usubjid;
  run;

  %**************************************************************;
  %*  Prepare the EX and DS data to retrieve death information  *;
  %*  Sort data for later merge to create the tumor data set    *;
  %**************************************************************;
  proc sort data=&_cstSENDInputLibrary..ex out=work.ex&_cstRN(keep=studyid usubjid exstdtc &ex_vars);
    by studyid usubjid exstdtc;
    where exstdtc ne '';
  run;

  proc sort data=&_cstSENDInputLibrary..ds out=work.ds&_cstRN(keep=studyid usubjid dsstdtc dsdecod &ds_vars);
    by studyid usubjid;
  run;

  data work.di&_cstRN(keep=studyid usubjid dthsactm dthsacst &ex_vars &ds_vars);
    merge work.ex&_cstRN (in=ex)
          work.ds&_cstRN (in=ds);
      by studyid usubjid;
        * Keep first chronological record in EX as start date of treatment *;
        * Multiple DS records are not expected, but if present, only the first is used *;
        if first.usubjid;
    attrib _cstMsg format=$200.
           dthsactm dthsacst length=8;
             
    dthsacst=input(put(dsdecod, $DTHCAT.),8.);
    if not ex then
    do;
      _cstMsg = catx(' ','WARNING: No valid EX (Exposure) record found for', cats('USUBJID="',usubjid,'".'), 'This violates an FDA Study Data Specification assumption.');
      put _cstMsg;
      call symputx('_cstwarning_rc',&_cstRCPrefix.9);
    end;
    else do;
      * Date handling assumes the use of ISO8601 in SEND source domains *;
      if indexc(dsstdtc,'T:') and indexc(exstdtc,'T:') then
      do;
        *  Convert from seconds to days  *;
        dsdt=floor(input(strip(dsstdtc),?? e8601dt.)/86400);
        exdt=floor(input(strip(exstdtc),?? e8601dt.)/86400);
      end;
      else do;
        * If both dates do not appear to have datetime values, process just the date portion *;
        dsdt = input(strip(dsstdtc),?? e8601da.);
        exdt = input(strip(exstdtc),?? e8601da.);
      end;
      if missing(dsdt) then 
      do;
        _cstMsg = catx(' ','WARNING: An invalid ISO8601 datetime value was found for DS.DSSTDTC:', cats('USUBJID="',usubjid,'",'), cats('DSSTDTC="',dsstdtc,'"'));
        put _cstMsg;
        call symputx('_cstwarning_rc',&_cstRCPrefix.9);
      end;
      if missing(exdt) then 
      do;
        _cstMsg = catx(' ','WARNING: An invalid ISO8601 datetime value was found for EX.EXSTDTC:', cats('USUBJID="',usubjid,'",'), cats('EXSTDTC="',exstdtc,'"'));
        put _cstMsg;
        call symputx('_cstwarning_rc',&_cstRCPrefix.9);
      end;
    end;
    if missing(_cstMsg) then
      dthsactm=(dsdt-exdt)+1;
  run;

  %********************************************************************************;
  %*  Prepare the MI and TF data to retrieve organ and tumor related information  *;
  %*  Sort data for later merge to create the tumor data set                      *;
  %********************************************************************************;
  proc sort data=&_cstSENDInputLibrary..mi out=work.mi&_cstRN(keep=studyid usubjid mistat mispcufl mispid &mi_vars);
    by studyid usubjid;
  run;

  data work.ae&_cstRN(keep=studyid usubjid animlexm) 
       work.m&_cstRN(keep=studyid usubjid mispid organexm &mi_vars);
    set work.mi&_cstRN;
      by studyid usubjid;
    length animlexm organexm 8.;
    retain animlexm;

    if first.usubjid then animlexm=0;
    if upcase(mistat) ne 'NOT DONE' then animlexm=1;

    if strip(mistat)='' and strip(mispcufl)='' then organexm=1;
      else if upcase(mispcufl)='N' then organexm=2;
      else if upcase(mistat)='NOT DONE' and strip(mispcufl)='' then organexm=3;

    output work.m&_cstRN;
    if last.usubjid then 
      output work.ae&_cstRN;
  run;

  data work.mi&_cstRN;
    merge work.ae&_cstRN 
          work.m&_cstRN;
      by studyid usubjid;
  run;

  %*********************************************************;
  %*  Reduce size of data set to reflect multiple records  *;
  %*  for animals with tumor and single records for those  *;
  %*  without tumor                                        *;
  %*********************************************************;
  proc sort data=work.mi&_cstRN nodupkey;
    by studyid usubjid organexm mispid;
  run;

  * Find and report MI records that would normally be expected to be included in TF but are not *;
  proc sql;
    create table work.mismatch&_cstRN as 
    select mi.studyid, mi.usubjid, "MI" as domain, mi.mispid as tumor
    from work.mi&_cstRN as mi 
            LEFT JOIN 
         &_cstSENDInputLibrary..tf as tf
    on mi.studyid=tf.studyid and mi.usubjid=tf.usubjid and mi.mispid=tf.tfspid
    where mi.mispid is NOT NULL and tf.tfspid is NULL;
  quit;
  data _null_;
    set work.mismatch&_cstRN;
    attrib _cstMsg format=$200.;
             
    _cstMsg = catx(' ','WARNING: MI tumor', cats('(',tumor,')'), 'found for', cats('USUBJID="',usubjid,'"'), 
       'but no corresponding tumor found in TF.');
    put _cstMsg;
    call symputx('_cstwarning_rc',&_cstRCPrefix.9);
  run;
  proc datasets lib=work nolist;
    delete mismatch&_cstRN/memtype=data;
  quit;
  * Find and report any TF records that cannot be found in MI *;
  proc sql;
    create table work.mismatch&_cstRN as 
    select a.studyid, a.usubjid, "TF" as domain, a.tfspid as tumor
    from &_cstSENDInputLibrary..tf as a
            LEFT JOIN 
         work.mi&_cstRN as b 
    on a.studyid=b.studyid and a.usubjid=b.usubjid and a.tfspid=b.mispid
    where a.tfspid is NOT NULL and b.mispid is NULL;
  quit;
  data _null_;
    set work.mismatch&_cstRN;
    attrib _cstMsg format=$200.;
             
    _cstMsg = catx(' ','WARNING: TF tumor', cats('(',tumor,')'), 'found for', cats('USUBJID="',usubjid,'"'), 
       'but no corresponding tumor found in MI.');
    put _cstMsg;
    call symputx('_cstwarning_rc',&_cstRCPrefix.9);
    call symputx('_cstMsg',_cstMsg);
  run;
    
  data work.mi&_cstRN;
    set work.mi&_cstRN;
      by studyid usubjid;
    if not(first.usubjid and last.usubjid) and mispid="" then delete;
  run; 

  proc sql;
    create table work.ms&_cstRN as 
    select mi.studyid, mi.usubjid, animlexm, organexm, tfstresc, tfspec, tfdetect, tfrescat, tfdthrel 
      &mi_vars_sql &tf_vars_sql
    from work.mi&_cstRN as mi 
            LEFT JOIN 
         &_cstSENDInputLibrary..tf as tf
    on mi.studyid=tf.studyid and mi.usubjid=tf.usubjid and mi.mispid=tf.tfspid;
  quit;

  %* TF source variables typically dropped from final tumor data set and XPT file *;
  %let _droplist = TFDTHREL TFRESCAT TFSTRESC TFSPEC TFDETECT;
  %do col = 1 %to %sysfunc(countw(&tf_vars,' '));
    %let _dropcolumn=%upcase(%scan(&tf_vars,&col,' '));
  %if %sysfunc(indexw(&_droplist,&_dropcolumn)) %then
    %let _droplist = %cmpres(%sysfunc(tranwrd(%sysfunc(trim(&_droplist)),%str(&_dropcolumn),%str())));
  %end;
  
  data work.ms&_cstRN(drop=&_droplist);
    set work.ms&_cstRN;
    length deathcau malignst 8.;
    deathcau=input(put(tfdthrel,$DTHCAU.),8.);
    malignst=input(put(tfrescat,$MALIG.),8.);
    tumornam=tfstresc;
    organnam=tfspec;
    detecttm=tfdetect;
  run;

  %****************************************************************************;
  %*  Create working copy tumor data set by merging files created previously  *;
  %*  Sort data for later merge to create the tumor data set                  *;
  %****************************************************************************;

  %let _droplist=STUDYID USUBJID;
  %do col = 1 %to %sysfunc(countw(&_cstSENDExtendedVars,' '));
    %let _dropcolumn=%upcase(%scan(&_cstSENDExtendedVars,&col,' '));
    %let _dropcolumn=%scan(&_dropcolumn,2,'.');
  %if %sysfunc(indexw(&_droplist,&_dropcolumn)) %then
    %let _droplist = %cmpres(%sysfunc(tranwrd(%sysfunc(trim(&_droplist)),%str(&_dropcolumn),%str())));
  %end;

  data work.tu&_cstRN (drop=&_droplist _cstMsg missingdomains);
    attrib
      studynum label='Study number'
      animlnum label='Animal number'
      species label='Animal species'
      sex label='Sex'
      dosegp format=8. label='Dose group'
      dthsactm label='Time in days to death or sacrifice'
      dthsacst label='Death or sacrifice status'
      animlexm format=8. label='Animal microscopic examination code'
      tumorcod format=$8. label='Tumor type code'
      tumornam label='Tumor name'
      organcod format=$8. label='Organ/tissue code'
      organnam label='Organ/tissue name'
      detecttm format=8. label='Time in days to detection of tumor'
      malignst format=8. label='Malignancy status'
      deathcau format=8. label='Cause of death'
      organexm format=8. label='Organ/tissue microscopic examination code';

    merge work.ms&_cstRN (in=ms)
          work.di&_cstRN (in=di)
          work.dg&_cstRN (in=dg);
      by studyid usubjid;
      
    attrib missingdomains format=$20.;
 
    studynum=studyid;
    animlnum=usubjid;
    if ms=0 or di=0 or dg=0 then
    do;
      if ms=0 then missingdomains='MI/TF';
      if di=0 and not missing(missingdomains) then
        missingdomains=catx('/',strip(missingdomains),'EX/DS');
      else if di=0 then
        missingdomains='EX/DS';
      if dg=0 and not missing(missingdomains) then
        missingdomains=catx('/',strip(missingdomains),'DM/TX');
      else if dg=0 then
        missingdomains='DM/TX';
      _cstMsg = catx(' ','WARNING: Not all expected source domains contributed records for:', cats('ANIMLNUM="',animlnum,'".'),
                catx(' ', 'Please review the', strip(missingdomains), 'domains for this animal.'));
      put _cstMsg;
      call symputx('_cstwarning_rc',&_cstRCPrefix.9);
    end;
      
    organcod=put(organnam,$ORGANCD.);
    tumorcod=put(tumornam,$TUMORCD.);
    species=put(species,$SPECIES.);
    if organexm in (2,3) then
    do;
      malignst=.;
      deathcau=.;
      tumornam='';
      tumorcod='';
    end;
      
    if not missing(dthsactm) and (dthsactm < detecttm) then 
    do;
      _cstMsg = catx(' ','WARNING: Time in days to death or sacrifice cannot be before time in days to detection of tumor:  ', cats('USUBJID="',usubjid,'",'), cats('DTHSACTM=',dthsactm,','), cats('DETECTTM=',detecttm));
      put _cstMsg;
      call symputx('_cstwarning_rc',&_cstRCPrefix.9);
    end;
  run;

  %* _cstwarning_rc will have a value > 0 if 1+ data problems were found and the _cstAbortIfDataIssue parameter = Y ;
  %if &_cstwarning_rc > 0 %then %goto exit_macro;

  %**********************************;
  %*  Produce final tumor data set  *;
  %**********************************;
  proc sort data=work.tu&_cstRN out=&_cstSENDOutputDSFile;
    by studynum animlnum tumorcod;
  run;

  %if (&syserr le 4 and %symexist(_cstResultsDS)) %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
          _cstResultID=CST0102,
          _cstResultParm1=&_cstSENDOutputDSFile,
          _cstSeqNoParm=&_cstSeqCnt,
          _cstSrcdataParm=&_cstSrcData,
          _cstActualParm=
    );
  %end;

  %**************************************;
  %*  Produce final tumor data set XPT  *;
  %**************************************;
  %if &_cstSENDCreateXPT eq 1 %then
  %do;
    filename tf&_cstRN "&_cstSENDOutputXPTFile";
    proc cport data=work.tu&_cstRN file=tf&_cstRN;
    run;
    %if (&syserr le 4 and %symexist(_cstResultsDS)) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
            _cstResultID=CST0102,
            _cstResultParm1=&_cstSENDOutputXPTFile,
            _cstSeqNoParm=&_cstSeqCnt,
            _cstSrcdataParm=&_cstSrcData,
            _cstActualParm=
      );
    %end;
    filename tf&_cstRN;
  %end;

  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  %if &_cstDebug ne 1 %then
  %do;
    proc datasets lib=work nolist;
      delete dm&_cstRN/memtype=data;
      delete tx&_cstRN/memtype=data;
      delete dg&_cstRN/memtype=data;
      delete ex&_cstRN/memtype=data;
      delete ds&_cstRN/memtype=data;
      delete di&_cstRN/memtype=data;
      delete mi&_cstRN/memtype=data;
      delete ae&_cstRN/memtype=data;
      delete m&_cstRN/memtype=data;
      delete ms&_cstRN/memtype=data;
      delete tu&_cstRN/memtype=data;
      delete mismatch&_cstRN/memtype=data;
    quit;
  %end;

%exit_macro:

  %if &_cstDebug=1 %then
  %do;
    %put ************  LEAVING MACRO SENDUTIL_CREATETUMORDATASET  ************;
    %put _cstSENDInputLibrary =&_cstSENDInputLibrary;
    %put _cstSENDOutputDSFile =&_cstSENDOutputDSFile;
    %put _cstSENDCreateXPT    =&_cstSENDCreateXPT;
    %put _cstSENDOutputXPTFile=&_cstSENDOutputXPTFile;
    %put _cstSENDExtendedVars =&_cstSENDExtendedVars;
    %put _cstAbortIfDataIssue =&_cstAbortIfDataIssue;
    %put _cst_rc              =&_cst_rc;
    %put _cstwarning_rc       =&_cstwarning_rc;
    %put _cstMsg              =&_cstMsg;
    %put *********************************************************************;
  %end;

  %if &_cst_rc > 0 or &_cstwarning_rc > 0 %then
    %put %str(ERR%str(OR):) Macro processing aborted;

  %if %symexist(_cstResultsDS) %then
  %do;
    %******************************************************;
    %* Persist the results if specified in sasreferences  *;
    %******************************************************;
    %cstutil_saveresults();
  %end;

  %* Reset linesize to prior length;
  options ls=&_cstPreLS;

%mend sendutil_createtumordataset;
