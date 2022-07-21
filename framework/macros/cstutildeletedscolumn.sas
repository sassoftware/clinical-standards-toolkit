%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutildeletedscolumn.sas                                                      *;
%*                                                                                *;
%* Deletes a column from a SAS Clinical Standards Toolkit data set.               *;
%*                                                                                *;
%* All actions that change the content of the data set are written to the         *;
%* specified log file.                                                            *;
%*                                                                                *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc: Error detection return code (1 indicates an error)            *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstStd - required - The name of the data standard. For example,        *;
%*             CDISC-SDTM.                                                        *;
%* @param _cstStdVer - required - The version of the data standard. For example,  *;
%*             3.1.4.                                                             *;
%* @param _cstDS - required - The <Libname>.<DSname> two-part SAS data set        *;
%*             reference that contains the column to delete. Before invoking this *;
%*             macro, the libname must be initialized.                            *;
%* @param _cstColumn - required - The column in _cstDS to delete. Only one column *;
%*             can be deleted at a time.                                          *;
%* @param _cstMustBeEmpty - required - Determine whether all column values are    *;
%*             empty before deleting a column. If Y or missing, delete the column *;
%*             only if all the values are empty. If N, delete the column without  *;
%*             regard to the values.                                              *;
%*             Values Y | N                                                       *;
%*             Default: Y                                                         *;
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

%macro cstutildeletedscolumn(
       _cstStd=,
       _cstStdVer=,
       _cstDS=,
       _cstColumn=,
       _cstMustBeEmpty=Y,
       _cstTestMode=Y
       ) / des='CST: Delete an existing column from any CST data set';

  %local _cstApplyAction
         _cstAttrString
         _cstCheckVal
         _cstDSKeys
         _cstDSLabel
         _cstDSLabelStatement
         _cstNeedToDeleteMsgs
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
         _cstTransCopyDS
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

  %************************************************;
  %*  One or more missing parameter values for    *;
  %*  _cstStd, _cstStdVer, _cstDS, or _cstColumn  *;
  %************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstColumn)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstColumn;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg One or more of the following parameters is missing _cstStd, _cstStdVer, _cstDS, or _cstColumn.;
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

  %********************************************************************;
  %*  Parameter _cstMustBeEmpty valid values are Y, N, and <missing>  *;
  %********************************************************************;
  %if "%upcase(&_cstMustBeEmpty)" ne "Y" and "%upcase(&_cstMustBeEmpty)" ne "N" and "%upcase(&_cstMustBeEmpty)" ne "" %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg Invalid _cstMustBeEmpty macro parameter (&_cstMustBeEmpty).;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstMsgID=CST0202;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %*****************************************************;
  %*  Verify input data set and column variable exist  *;
  %*****************************************************;
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
  %else
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=;
    %let _cstCheckVal=%sysfunc(countc("&_cstColumn",' '));
    %if &_cstCheckVal gt 0 %then
    %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=&_cstTestMsg The column value [&_cstColumn] specified in the _cstColumn macro parameter contains more than one column.;
       %let _cstMsgID=CST0202;
       %let _cstParm1=&_cst_rcmsg;
       %let _cstParm2=;
       %goto ABORT_PROCESS;
    %end;

    %***********************************;
    %*  Verify selected column exists  *;
    %***********************************;
    %if %cstutilgetattribute(_cstDataSetName=&_cstDS,_cstVarName=&_cstColumn,_cstAttribute=VARNUM) lt 1 %then
    %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=&_cstTestMsg The column [&_cstColumn] specified in the _cstColumn macro parameter does not exist.;
       %let _cstMsgID=CST0202;
       %let _cstParm1=&_cst_rcmsg;
       %let _cstParm2=;
       %goto ABORT_PROCESS;
    %end;

    %************************************************************************;
    %*  Retrieve key variables if they exist for sorting later              *;
    %*  Check to make sure user is not attempting to delete a KEY variable  *;
    %************************************************************************;
    %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=SORTEDBY);
    %if %sysfunc(indexw(%upcase(%str(&_cstDSKeys)),%upcase(%str(&_cstColumn))))>0 %then
    %do;
       %let _cst_rc_=1;
       %let _cst_rcmsg=&_cstTestMsg The column [&_cstColumn] specified in the _cstColumn macro parameter is a key in &_cstDS and cannot be deleted.;
       %let _cstMsgID=CST0202;
       %let _cstParm1=&_cst_rcmsg;
       %let _cstParm2=;
       %goto ABORT_PROCESS;
    %end; 
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
 
  %****************************************************;
  %*  Verify that all values for the column are null  *; 
  %*  if _cstMustBeEmpty flag is set to Y or Missing  *;
  %****************************************************;
  %if "%upcase(&_cstMustBeEmpty)"="Y" or %klength(&_cstMustBeEmpty)=0 %then 
  %do;
    %let _cstNumObs=%cstutilnobs(_cstDataSetName=&_cstDS);
    %let _cstApplyAction=0;

    %*****************************************************************;
    %*  If 0 obs data set then no need to verify if column is empty  *;
    %*****************************************************************;
    %if &_cstNumObs ne 0 %then 
    %do;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstTempTable=_cst&_cstRandom;
    
      proc freq data=&_cstDS;
        tables &_cstColumn / out=work.&_cstTempTable noprint;
      run;

      data _null_;
        set work.&_cstTempTable;
        if count=%eval(&_cstNumObs) and percent=. then 
        do;
          call symputx('_cstApplyAction',1);
        end;
      run;

      %cstutil_deletedataset(_cstDataSetName=work.&_cstTempTable);
    
      %if &_cstApplyAction=0 %then
      %do;
        %let _cst_rc_=1;
        %let _cst_rcmsg=&_cstTestMsg Column must be empty parameter is set and column values are present - no action performed.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;
    %end;
  %end;

  %*********************************;
  %*  Remove column from data set  *;
  %*********************************;
  
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
      %let _cst_rcmsg=&_cstTestMsg No template dataset found for type=&_cstParm1, subtype=&_cstParm2.;
      %goto ABORT_PROCESS;
    %end;
  %end;
  
  %***************************************************************************;
  %*  Perform deletion of column                                             *;
  %*  If keys exist use proc sort to maintain LABEL and SORTEDBY attributes  *;
  %*  If keys do not exist use data step and retrieve LABEL attribute        *;
  %***************************************************************************;
  %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=LABEL);
  %let _cstDSLabelStatement=label="%nrbquote(&_cstDSLabel)";
  
  %if %klength(&_cstDSkeys) gt 0 %then
  %do;
    data &_cstOutDS (drop=&_cstColumn &_cstDSLabelStatement);
      set &_cstDS;
    run;
    proc sort data=&_cstOutDS;
      by &_cstDSKeys;
    run;
  %end;
  %else
  %do;
    %if %klength(&_cstDSLabel)=0 %then %let _cstDSLabelStatement=;

    %let _cstAttrString=;
    %cstutilbuildattrfromds(_cstSourceDS=&_cstDS,_cstAttrVar=_cstAttrString);

    data &_cstOutDS (drop=&_cstColumn &_cstDSLabelStatement);
      attrib &_cstAttrString;
      set &_cstDS;
    run;
  %end;
    
  %let _cst_rc=0;
  %let _cst_rcmsg_thismacro=&_cstTestMsg Deletion of column [%upcase(&_cstColumn)] successful;

  %if %upcase(&_cstTestMode)=N %then
  %do;
    %*********************************************************;
    %*  Populate values for transaction data set (1 record)  *;
    %*********************************************************;
    %let _cstAttrString=;
    %cstutilbuildattrfromds(_cstSourceDS=&_cstTransCopyDS,_cstAttrVar=_cstAttrString);

    data &_cstTransCopyDS;
      attrib &_cstAttrString;
    
      cststandard=ktrim("&_cstStd");
      cststandardversion=ktrim("&_cstStdVer");
      cstuser=ktrim("&SYSUSERID");
      cstmacro=ktrim("&_cstSrcMacro");
      cstfilepath=ktrim(pathname(ksubstr("&_cstDS",1,kindexc(ktrim("&_cstDS"),'.')-1)));
      cstmessage=ktrim("&_cst_rcmsg_thismacro");
      cstcurdtm=datetime();
      cstdataset=ktrim("&_cstDS");
      cstcolumn=ktrim("&_cstcolumn");
      cstactiontype="DELETE";
      cstentity="COLUMN";
      output;
    run;
   
    %***********************************;
    %*  Write to transaction data set  *;
    %***********************************;
    %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
    %cstutil_deletedataset(_cstDataSetName=&_cstTransCopyDS);

  %end;

  %let _cst_rc=0;
  %let _cst_rcmsg=&_cst_rcmsg_thismacro;
  
  %UPDATE_RESULT:
  %*****************************;
  %*  Update Results data set  *;
  %*****************************;
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstThisMacroRC=0;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(_cstResultId=CST0200
                ,_cstResultParm1=&_cst_rcmsg_thismacro
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
 
  %ABORT_PROCESS:
  %if (&_cstUseResultsDS=1) %then 
  %do;
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
%mend cstutildeletedscolumn;