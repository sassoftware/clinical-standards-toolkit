%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutildeletemetadatarecords.sas                                               *;
%*                                                                                *;
%* Deletes an observation from a SAS Clinical Standards Toolkit data set.         *;
%*                                                                                *;
%* This macro deletes a record/row from the specified data set. All actions that  *;
%* change the content of the data set are written to the specified log file.      *;
%*                                                                                *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc: Error detection return code (1 indicates an error)            *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstStd - required - The name of the data standard. For example,        *;
%*           CDISC-SDTM.                                                          *;
%* @param _cstStdVer - required - The version of the data standard. For example,  *;
%*           3.1.4.                                                               *;
%* @param _cstDS - required - The <Libname>.<DSname> two-part SAS data set        *;
%*           reference that contains the records to delete. Before invoking this  *;
%*           macro, the libname must be initialized.                              *;
%* @param _cstDSIfClause - required - A SAS subset clause used in an IF statement *;
%*           that identifies the records to delete. All records that match the    *;
%*           criteria of this clause are deleted. Clauses that are syntactically  *;
%*           incorrect or contain nonexistent column references generate errors   *;
%*           and cause the macro to exit without performing any actions. The      *;
%*           syntax can delete from 0 to all records. If all records are deleted, *;
%*           this macro aborts because it assumes that there is a problem with    *;
%*           the IF clause.                                                       *;
%*           Example:                                                             *;
%*           _cstDSIfClause=%str(checkid='SDTM0412' and standard='CDISC-SDTM'     *;
%*           and standardversion='***' and checksource='SAS' and                  *;
%*           uniqueid='SDTM004121CST150SDTM3132013-03-07T18:15:21CST')            *;
%*                                                                                *;
%* @param _cstTestMode - optional - Run the macro in test mode. In test mode,     *;
%*           a new library is created called _CSTTEST and a copy of the data set  *;
%*           (_cstDS parameter) is created so the user can review it to determine *;
%*           whether modifications are accurate before the final data set is      *;
%*           created. If this parameter is specified, the user you must run this  *;
%*           macro a final time to instantiate the changes.                       *;
%*           Values: Y | N                                                        *;
%*           Default: Y                                                           *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutildeletemetadatarecords(
       _cstStd=
       ,_cstStdVer=
       ,_cstDS=
       ,_cstDSIfClause=
       ,_cstTestMode=Y
       ) / des='CST: Delete an observation from a CST data set';

  %local _cstAttrString
         _cstCheckVal
         _cstDSIfClause_orig
         _cstDSKeys
         _cstDSLabel
         _cstDSLabelStatement
         _cstDSRecCnt
         _cstNeedToDeleteMsgs
         _cstNumObs1
         _cstNumObs2
         _cstOutDS
         _cstParm1
         _cstParm2       
         _cstRandom 
         _cstResultSeq
         _cstSASoption
         _cstSeqCnt
         _cstSrcMacro
         _cstTemp1
         _cstTempTable
         _cstTestMsg
         _cstTotalRec
         _cstTransCopyDS
         _cstZeroObs
         _cst_rcmsg_thismacro
         ;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstTestMsg=;
  
  %if (%symexist(_cstResultsDS)=1) %then 
  %do;
    %if (%klength(&_cstResultsDS)>0) and %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      %let _cstUseResultsDS=1;
      %******************************************************;
      %*  Create a temporary messages data set if required  *;
      %******************************************************;
      %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);
    %end;
  %end;
        
  %***************************************************;
  %*  Check for existence of _cst_rc macro variable  *;
  %***************************************************;
  %if ^%symexist(_cst_rc) %then 
  %do;
    %global _cst_rc _cst_rcmsg;
  %end;

  %let _cst_rc=;
  %let _cst_rcmsg=;

  %*********************************;
  %*  _cstTestMode must be Y or N  *;
  %*********************************;
  %if (%klength(&_cstTestMode)=0) %then %let _cstTestMode=Y;
  %if %upcase(&_cstTestMode) ne N and %upcase(&_cstTestMode) ne Y %then 
  %do;
    %let _cstMsgID=CST0202;
    %let _cst_rcmsg=The _cstTestMode macro parameter value [&_cstTestMode] is not Y or N.;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %let _cst_rc=1;
    %goto ABORT_PROCESS;
  %end;

  %if %upcase(&_cstTestMode)=Y %then
  %do;
    %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] *****  NOTE: RUNNING IN TEST MODE - Actual data set is not being updated  *****;
    %let _cstTestMsg=**Test Mode**;
  %end;
  
  %*******************************************************;
  %*  One or more missing parameter values for _cstStd,  *;
  %*  _cstStdVer, _cstDS, or _cstDSIfClause              *;
  %*******************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstDSIfClause)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstDSIfClause;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg One or more of the following parameters is missing _cstStd, _cstStdVer, _cstDS, or _cstDSIfClause.;
    %goto ABORT_PROCESS;
  %end;

  %****************************************************;
  %*  Verify _cstStd and _cstStdVer are valid values  *;
  %****************************************************;
  %let _cstDSRecCnt=0;
  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);

  data work._cstStandards;
    set work._cstStandards (where=(upcase(standard)=upcase("&_cstStd") and upcase(standardversion)=upcase("&_cstStdVer"))) nobs=_numobs;
    call symputx('_cstDSRecCnt',_numobs);
  run;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstStandards);

  %if &_cstDSRecCnt=0 %then
  %do;
    %let _cst_rc=1;
    %let _cstMsgID=CST0082;
    %let _cstParm1=&_cstStd &_cstStdVer;
    %let _cstParm2=;
    %let _cst_rcmsg=&_cstTestMsg The standard &_cstParm1 is not registered.;
    %goto ABORT_PROCESS;
  %end;
  
  %*****************************************************************;
  %*  Parameter _cstDS not in required form of <libname>.<dsname>  *;
  %*****************************************************************;
  %let _cstCheckVal=%sysfunc(countc("&_cstDS",'.'));
  %if &_cstCheckVal=1 %then
  %do;
    %********************************************;
    %*  Check for a leading or trailing period  *;
    %********************************************;
    %let _cstTemp1=%sysfunc(indexc(%str(&_cstDS),%str(.)));
    %if &_cstTemp1=1 or &_cstTemp1=%klength(&_cstDS) %then
    %do;
      %let _cstCheckVal=0;
    %end;
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg The data set [&_cstDS] macro parameter does not follow <libname>.<dsname> construct.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %**********************************;
  %*  Verify input data set exists  *;
  %**********************************;
  %let _cst_rc=;
  %if not %sysfunc(exist(&_cstDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg The data set [&_cstDS] specified in the _cstDS macro parameter does not exist.;
    %let _cstMsgID=CST0008;
    %let _cstParm1=&_cstDS;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %********************************;
  %*  Verify write access to the  *;
  %*  data set if not Test Mode.  *;
  %********************************;
  %if %upcase(&_cstTestMode) ^= Y %then
  %do;
    %cstutilcheckwriteaccess(_cstFileType=DATASET,_cstFileRef=&_cstDS);
    %if &_cst_rc %then
    %do;
      %let _cstMsgID=CST0111;
      %let _cstParm1=&_cstDS with write access;
      %let _cstParm2=;
      %let _cst_rcmsg=&_cstTestMsg Unable to open data set &_cstParm1.;
      %goto ABORT_PROCESS;
    %end;
  %end;

  %**************************************************************************;
  %*  Translate _cstDSIfClause to change any double quotes to single quotes *;
  %*  Report this in the log only if _cstDSIfClause is modified.            *;
  %**************************************************************************;
  %let _cstDSIfClause_orig=&_cstDSIfClause;
  %let _cstDSIfClause=%sysFunc(ktranslate(&_cstDSIfClause,%str(%'),%str(%")));
  %if "&_cstDSIfClause" ne "&_cstDSIfClause_orig" %then
    %put [CSTLOG%str(MESSAGE)] NOTE: Double quotes have been translated to single quotes for the _cstDSIfClause parameter; 

  %**************************************;
  %*  Remove observation from data set  *;
  %**************************************;
  
  %************************;
  %*  Is this TEST mode?  *;
  %************************;
  
  %if %upcase(&_cstTestMode) = Y %then 
  %do;
    %let _cstSASOption=%sysfunc(getoption(dlcreatedir));
    options dlcreatedir;
    %**********************************************************************;
    %*  Create a subdirectory in the WORK folder to ensure no user files  *;
    %*  are overwritten while in Test Mode and assign to _CSTTEST.        *;
    %**********************************************************************;
    libname _csttest "%sysfunc(pathname(work))/_csttest"; 
    options &_cstSASOption;

    %let _cstOutDS=_csttest%sysfunc(substr(&_cstDS,%sysfunc(kindexc(&_cstDS,'.'))));
  %end; 
  %else 
  %do;
    %let _cstOutDS=&_cstDS; 
  
    %if (^%symexist(_cstTransactionDS)=1) %then 
      %let _cstTransactionDS=;
    %***********************************************************;
    %*  Check Transaction data set to verify it is not locked  *:
    %*  by another user. If locked abort the process without   *;
    %*  making the change and notify user, otherwise proceed.  *;
    %***********************************************************;
    %cstutilgetdslock;
  
    %if &_cst_rc %then
    %do;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;
  %end;

  %let _cstNumObs1=%cstutilnobs(_cstDataSetName=&_cstDS);
  %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=SORTEDBY);
  %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=LABEL);
  %if %klength(&_cstDSLabel) gt 0 
    %then %let _cstDSLabelStatement=(label="&_cstDSLabel");
    %else %let _cstDSLabelStatement=;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempTable=work._cst&_cstRandom._app;
  
  %*****************************************************;
  %*  Check to make sure ALL records are not deleted.  *;
  %*  If so, warn the user and abort the process.      *;
  %*****************************************************;
  data &_cstTempTable;
    set &_cstDS;
    if %str(&_cstDSIfClause) then delete; 
  run;
  %let _cstZeroObs=%cstutilnobs(_cstDataSetName=&_cstTempTable); 

  %if &SYSERR %then 
  %do;
    %if %upcase(&_cstTestMode)=N %then 
    %do;
      lock &_cstTransactionDS clear;
    %end;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg There is a problem with the IF clause [%upcase(&_cstDSIfClause)] - check syntax and verify variable(s) exist. SEE LOG;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %if &_cstZeroObs eq 0 %then 
  %do;
    %if %upcase(&_cstTestMode)=N %then 
    %do;
      lock &_cstTransactionDS clear;
    %end;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg The IF Clause [IF %upcase(&_cstDSIfClause)] resulted in a 0 obs data set.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %*************************;
  %*  Proceed with delete  *;
  %*************************;
  data &_cstOutDS &_cstDSLabelStatement &_cstTempTable;
    set &_cstDS;
    if %str(&_cstDSIfClause) then 
    do;
      output &_cstTempTable;
      delete;
    end;
    output &_cstOutDS;
  run;
  
  %if %klength(&_cstDSkeys) gt 0 %then
  %do;
    proc sort data=&_cstOutDS;
      by &_cstDSKeys;
    run;
  %end;

  %let _cstNumObs2=%cstutilnobs(_cstDataSetName=&_cstOutDS);

  %**************************************************************************;
  %*  Check number of observations, if equal no records were deleted. Send  *;
  %*  NOTE to log or results data set and bypass transactiuon log since no  *;
  %*  changes occurred.                                                     *;
  %*  If unequal, changes occurred and transaction log is updated.          *;
  %**************************************************************************;
  %if &_cstNumObs1 ne &_cstNumObs2 %then
  %do;
    %let _cstTotalRec=%eval(&_cstNumObs1-&_cstNumObs2);
    %let _cst_rc=0;
    %let _cst_rcmsg_thismacro=&_cstTestMsg Deletion of &_cstTotalRec record(s) successful using where clause %UPCASE(&_cstDSIfClause);

    %if %upcase(&_cstTestMode)=N %then
    %do;
      %******************************************;
      %*  Create transaction template data set  *;
      %******************************************;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstTransCopyDS=work._cst&_cstRandom;
      %cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstStandardVersion=1.2,_cstType=logging, _cstSubType=transaction,_cstOutputDS=&_cstTransCopyDS);
    
      %if &_cst_rc %then
      %do;
        lock &_cstTransactionDS clear;
        %let _cstMsgID=CST0117;
        %let _cstParm1=LOGGING;
        %let _cstParm2=TRANSACTION;
        %let _cst_rcmsg=No template dataset found for type=&_cstParm1, subtype=&_cstParm2.;
        %goto ABORT_PROCESS;
      %end;
  
      %*********************************************************;
      %*  Populate values for transaction data set (1 record)  *;
      %*********************************************************;
      %let _cstAttrString=;
      %cstutilbuildattrfromds(_cstSourceDS=&_cstTransCopyDS,_cstAttrVar=_cstAttrString);

      data &_cstTransCopyDS (keep=cststandard cststandardversion cstuser cstmacro cstfilepath cstmessage cstcurdtm cstdataset cstcolumn cstactiontype cstentity);
        attrib &_cstAttrString;
        set &_cstTempTable;
        
        attrib _cstkeys format=$200. update_cnt format=8.;
        retain _cstkeys update_cnt;
            
        if _n_=1 then 
        do;
          _cstkeys=symget('_cstDSKeys');
          update_cnt=0;
        end;
        update_cnt+1;
      
        cststandard=ktrim("&_cstStd");
        cststandardversion=ktrim("&_cstStdVer");
        cstuser=ktrim("&SYSUSERID");
        cstmacro=ktrim("&_cstSrcMacro");
        cstfilepath=ktrim(pathname(ksubstr("&_cstDS",1,kindexc(ktrim("&_cstDS"),'.')-1)));
        cstcurdtm=datetime();
        cstdataset=ktrim("&_cstDS");
        cstcolumn="";
        cstactiontype="DELETE";
        cstentity="RECORD";

        %if %klength(&_cstDSkeys) gt 0 %then
        %do;
          if missing(cstmessage) then cstmessage="Record DELETED in &_cstDS for Key values";
          do k=1 to countw(_cstkeys,' ');
            if k=1 
              then cstmessage=catx(' ',cstmessage,catx(', ', cats(kscan("&_cstDSKeys",1,' '),'=',vvaluex(kscan(_cstkeys,k,' ')))));
              else cstmessage=catx(', ',cstmessage,cats(kscan("&_cstDSKeys",k,' '),'=',vvaluex(kscan(_cstkeys,k,' '))));
          end;
          output;
        %end;
        %else
        %do;
          if last then 
          do;
            cstmessage=ktrim(update_cnt)||" records were REMOVED from data set %upcase(&_cstDS).";
            output;
          end;
        %end;
      run;
     
      %***********************************;
      %*  Write to transaction data set  *;
      %***********************************;
      %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
      %cstutil_deletedataset(_cstDataSetName=&_cstTransCopyDS);
    %end;
    %let _cst_rc=0;
    %let _cst_rcmsg=&_cst_rcmsg_thismacro;
  %end;
  %else
  %do;
    %if %upcase(&_cstTestMode)=N %then 
    %do;
      lock &_cstTransactionDS clear;
    %end;
    %let _cst_rc=0;
    %let _cst_rcmsg_thismacro=&_cstTestMsg The record specified in the if clause [%upcase(&_cstDSIfClause)] does not exist. No action performed.;
    %let _cst_rcmsg=&_cst_rcmsg_thismacro;
  %end;

  %UPDATE_RESULTS:
  %*****************************;
  %*  Update Results data set  *;
  %*****************************;
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstThisMacroRC=0;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(_cstResultId=CST0200
                ,_cstResultParm1=&_cst_rcmsg
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstResultsDS
                );
  %end;
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cst_rcmsg_thismacro;
  %goto EXIT_MACRO;
 
  %****************************;
  %*  Handle any errors here  *;
  %****************************;
  %ABORT_PROCESS:
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstThisMacroRC=1;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=&_cstMsgID
                ,_cstResultParm1=&_cstParm1
                ,_cstResultParm2=&_cstParm2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cst_rc
                ,_cstRCParm=&_cst_rc
                );
  %end;
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cst_RCmsg;
  %goto EXIT_MACRO;

  %EXIT_MACRO:

  %if %klength(&_cstTempTable) and %sysfunc(exist(&_cstTempTable)) gt 0 %then %cstutil_deletedataset(_cstDataSetName=&_cstTempTable);

%mend cstutildeletemetadatarecords;