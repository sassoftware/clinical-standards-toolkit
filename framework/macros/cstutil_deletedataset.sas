%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_deleteDataSet                                                          *;
%*                                                                                *;
%* Deletes a data set, if it exists.                                              *;
%*                                                                                *;
%* Clinical Standards Toolkit utility macro designed to delete a data set. The    *;
%* macro optionally logs the event in the global library transaction log.         *;
%*                                                                                *;
%* @param _cstDataSetName - required - The (libname.)memname of the data set to   *;
%*             delete.                                                            *;
%* @param _cstLogging - optional - Boolean to signal whether deletion of the      *;
%*             data set should be logged in the global library transaction log.   *;
%*             Values: 0 (No) | 1 (Yes)                                           *;
%*             Default: 0                                                         *;
%* @param _cstLoggingDS - optional - User-defined data set to be used to log      *;
%*             data set deletions.  Ignored if _cstLogging=0.  If _cstLogging=1,  *;
%*             and _cstLoggingDS is not provided, the default data set used is    *;
%*             derived from the CST_LOGGING_PATH and CST_LOGGING_DS static        *;
%*             variables.  If provided, must follow <libref.dset> convention.     *;
%*                                                                                *;
%* @history 2013-10-09 Added logging parameters (1.6)                             *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_deleteDataSet(
    _cstDataSetName=,
    _cstLogging=0,
    _cstLoggingDS=
    ) / des='CST: Delete a SAS data set';

  %local
    _cstRandom1
    _cstRDir
    _cstRMem
    _cstSrcMacro
    _cstThisMacroRC
    _cstThisMacroRCmsg    
  ;

  %if &_cstLogging=1 %then
  %do;
  
    %* _cstLoggingDS file existence is confirmed in call to cstutilgetdslock() below *;

    %let _cstSrcMacro=&SYSMACRONAME;

    %if %length(&_cstDataSetName)=0 %then
    %do;
      %let _cstThisMacroRC=1;
      %let _cstThisMacroRCmsg=%str(_cstDataSetName parameter value must be provided);
      %goto ABORT_PROCESS;
    %end;

    %if (^%sysfunc(exist(&_cstDataSetName))) %then
    %do;
      %let _cstThisMacroRC=1;
      %let _cstThisMacroRCmsg=%str(&_cstDataSetName does not exist.);
      %goto ABORT_PROCESS;
    %end;

    %if (^%symexist(_cstTransactionDS)=1) %then 
      %let _cstTransactionDS=;
    %if %length(&_cstLoggingDS)>0 %then
      %let _cstTransactionDS=&_cstLoggingDS;

    %***********************************************************;
    %*  Check Transaction data set to verify it is not locked  *:
    %*  by another user. If locked abort the process without   *;
    %*  making the change and notify user, otherwise proceed.  *;
    %***********************************************************;
    %cstutilgetdslock(_cstLockDS=&_cstLoggingDS);
  
    %if &_cst_rc %then
    %do;
      %let _cstThisMacroRC=&_cst_rc;
      %let _cstThisMacroRCmsg=&_cst_rcmsg;
      %goto ABORT_PROCESS;
    %end;

    %******************************************;
    %*  Create transaction template data set  *;
    %******************************************;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom1);
    %let _cstTransCopyDS=_cst&_cstRandom1;
    %cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstStandardVersion=1.2,_cstType=logging, _cstSubType=transaction,_cstOutputDS=&_cstTransCopyDS);
    
    %if &_cst_rc %then
    %do;
      lock &_cstTransactionDS clear;
      %let _cstThisMacroRC=&_cst_rc;
      %let _cstThisMacroRCmsg=No template dataset found for type=LOGGING, subtype=TRANSACTION.;
      %goto ABORT_PROCESS;
    %end;

  %end;

  %**************************************;
  %*  Attempt to make requested change  *:
  %**************************************;

  %if (%length(&_cstDataSetName)>0) %then 
  %do;
    %if (%sysfunc(exist(&_cstDataSetName))) %then
    %do;
      %if %eval(%index(&_cstDataSetName,.)>0) %then
      %do;
        %let _cstRDir=%scan(&_cstDataSetName,1,.);
        %let _cstRMem=%scan(&_cstDataSetName,2,.);
      %end;
      %else
      %do;
        %let _cstRDir=work;
        %let _cstRMem=&_cstDataSetName;
      %end;

      proc datasets nolist lib=&_cstRDir;
        delete &_cstRMem / mt=data;
        quit;
      run;

      %let _cstThisMacroRC=0;
      %let _cstThisMacroRCmsg=%str(&_cstDataSetName successfully deleted.);

    %end;
    %else %do;
      %* Not setting _cstThisMacroRC to 1 as this is not a fatal error. *;
      %let _cstThisMacroRC=0;
      %let _cstThisMacroRCmsg=%str(&_cstDataSetName does not exist.);
      %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: %str(&_cstDataSetName does not exist.);
    %end;
  %end;
  %else
    %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): _cstDataSetName parameter value must be provided;

  %if &_cstLogging=1 %then
  %do;
    %**********************************************;
    %*  Populate values for transaction data set  *;
    %**********************************************;
    %let _cstAttrString=;
    %cstutilbuildattrfromds(_cstSourceDS=&_cstTransCopyDS,_cstAttrVar=_cstAttrString);

    data &_cstTransCopyDS;
      attrib &_cstAttrString;

      %if (^%symexist(_cstStandard)=1) %then
        %let _cstStandard=;
      cststandard=ktrim("&_cstStandard");
      %if (^%symexist(_cstStandardVersion)=1) %then
        %let _cstStandardVersion=;
      cststandardversion=ktrim("&_cstStandardVersion");
      cstuser=ktrim("&SYSUSERID");
      cstmacro=ktrim("&_cstSrcMacro");
      cstfilepath=ktrim(pathname(ksubstr("&_cstDataSetName",1,kindexc(ktrim("&_cstDataSetName"),'.')-1)));
      cstmessage=ktrim("&_cstThisMacroRCmsg");
      cstcurdtm=datetime();
      cstdataset=ktrim("&_cstDataSetName");
      cstcolumn='';
      cstactiontype="DELETE";
      cstentity="DATASET";
      output;
    run;

    %**************************************************;
    %*  Write to transaction data set                 *;
    %*  cstutillogevent unlocks transaction data set  *;
    %**************************************************;
    %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
    
    %if &_cst_rc %then
    %do;
      %let _cstThisMacroRC=&_cst_rc;
      %let _cstThisMacroRCmsg=&_cst_rcmsg;
      %goto ABORT_PROCESS;
    %end;
    
    %* Clean up work files *;
    proc datasets lib=work nolist;
      delete &_cstTransCopyDS;
    quit;
    %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cstDataSetName successfully deleted.;
    %goto EXIT_MACRO;
  %end;
  %else
    %goto EXIT_MACRO;

%ABORT_PROCESS:
  %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cstThisMacroRCmsg;
  %goto EXIT_MACRO;

%EXIT_MACRO:

  %* Action deferred post-CST 1.6 *;
  %*let _cst_rc=&_cstThisMacroRC;
  %*let _cst_rcmsg=&_cstThisMacroRCmsg;

%mend cstutil_deleteDataSet;
