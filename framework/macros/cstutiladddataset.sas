%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutiladddataset.sas                                                          *;
%*                                                                                *;
%* Adds a data set to the global standards library or the sample library.         *;
%*                                                                                *;
%* This macro adds a SAS Clinical Standards Toolkit data set to the global        *;
%* standards library or the sample library. The change is written to the global   *;
%* standards library transaction log.                                             *;
%*                                                                                *;
%* Example usage:                                                                 *;
%*    %cstutiladddataset(_cstStd=CDISC-SEND,_cstStdVer=3.0,                       *;
%*       _cstDS=srcmeta.source_values,_cstInputDS=work.source_values,             *;
%*       _cstDSLabel=%str(Source Value Metadata),                                 *;
%*       _cstDSKeys=%str(sasref table column value),_cstOverwrite=Y)              *;
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
%* @param _cstDS - required - The name of the data set (in the form               *;
%*           <Libname>.<DSname>) as it to be known in the global standards        *;
%*           library or the sample library. Before invoking this macro, the       *;
%*           libname must be initialized.                                         *;
%* @param _cstInputDS - required - The name of the source data set (in the form   *;
%*           <Libname>.<DSname>)to write to the _cstDS destination. Before        *;
%*           invoking this macro, the libname must be initialized.                *;
%* @param _cstDSLabel - optional - The data set label. Best practices recommend   *;
%*           that every global standards library or sample library data set have  *;
%*           a label.                                                             *;
%* @param _cstDSKeys - optional - The data set keys. Best practices recommend     *;
%*           that every global standards library or sample library data set have  *;
%*           keys that uniquely identify records in the data set.                 *;
%* @param _cstOverwrite - optional - Overwrite _cstDS if it exists.               *;
%*           Values: Y | N                                                        *;
%*           Default: N                                                           *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutiladddataset(
       _cstStd=
       ,_cstStdVer=
       ,_cstDS=
       ,_cstInputDS=
       ,_cstDSLabel=
       ,_cstDSKeys=
       ,_cstOverwrite=N
       ) / des='CST: Add a data set';

  %local _cstAttrString
         _cstBadKey
         _cstCheckVal
         _cstDSKeysCnt
         _cstDSRecCnt
         _cstKey
         _cstKeyStr
         _cstNeedToDeleteMsgs
         _cstParm1
         _cstParm2   
         _cstRandom
         _cstRDir
         _cstResultSeq
         _cstSeqCnt
         _cstSrcMacro
         _cstTemp1
         _cstThisMacroRC
         _cstThisMacroRCmsg
         _cstTransCopyDS
         _cstUseResultsDS
         ;
  
  %*****************************************;
  %*  Set any optional parameter defaults  *;
  %*****************************************;
  %if %length(&_cstOverwrite)=0 %then
    %let _cstOverwrite=N;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstThisMacroRC=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  
  %if (%symexist(_cstResultsDS)=1) %then 
  %do;
    %if (%klength(&_cstResultsDS)>0) and %sysfunc(exist(&_cstResultsDS)) %then %do;  
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

  %let _cst_rc=0;
  %let _cst_rcmsg=;

  %********************************************************;
  %*  One or more missing parameter values for _cstSTD,   *;
  %*  _cstStdVer, _cstDS, or _cstInputDS                  *;
  %********************************************************;
  %if (%length(&_cstStd)=0) or (%length(&_cstStdVer)=0) or (%length(&_cstDS)=0) or (%length(&_cstInputDS)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstInputDS;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=One or more of the following REQUIRED parameters is missing _cstStd, _cstStdVer, _cstDS, or _cstInputDS.;
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
    %if &_cstTemp1=1 or &_cstTemp1=%length(&_cstDS) %then
      %let _cstCheckVal=0;
    %else
      %let _cstRDir=%scan(&_cstDS,1,.);
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set macro parameter value [&_cstDS] does not follow <libname>.<dsname> construct.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %**********************************************************************;
  %*  Parameter _cstInputDS not in required form of <libname>.<dsname>  *;
  %**********************************************************************;
  %let _cstCheckVal=%sysfunc(countc("&_cstInputDS",'.'));
  %if &_cstCheckVal=1 %then
  %do;
    %********************************************;
    %*  Check for a leading or trailing period  *;
    %********************************************;
    %let _cstTemp1=%sysfunc(indexc(%str(&_cstInputDS),%str(.)));
    %if &_cstTemp1=1 or &_cstTemp1=%length(&_cstInputDS) %then
    %do;
      %let _cstCheckVal=0;
    %end;
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The source data set macro parameter value [&_cstInputDS] does not follow <libname>.<dsname> construct.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %****************************************************;
  %*  Verify _cstStd and _cstStdVer are valid values  *;
  %****************************************************;
  %let _cstDSRecCnt=0;
  %cst_getRegisteredStandards(_cstOutputDS=work._cstStandards);

  data work._cstStandards;
    set work._cstStandards (where=(upcase(standard)=upcase("&_cstStd") and upcase(standardversion)=upcase("&_cstStdVer")));
  run;
  data _null_;
    set work._cstStandards nobs=_numobs;
    call symputx('_cstDSRecCnt',_numobs);
  run;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstStandards);

  %if &_cstDSRecCnt=0 %then
  %do;
    %let _cst_rc=1;
    %let _cstMsgID=CST0082;
    %let _cstParm1=&_cstStd &_cstStdVer;
    %let _cstParm2=;
    %let _cst_rcmsg=The standard &_cstParm1 is not registered.;
    %goto ABORT_PROCESS;
  %end;

  %***********************************;
  %*  Verify input data set exists   *;
  %***********************************;
  %if not %sysfunc(exist(&_cstInputDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstInputDS] specified in the _cstInputDS macro parameter does not exist.;
    %let _cstMsgID=CST0008;
    %let _cstParm1=&_cstInputDS;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %**************************************************************;
  %*  Verify output data set exists but _cstOverwrite specified *;
  %*  In this case, the request cannot be completed.            *;
  %**************************************************************;
  %if %sysfunc(exist(&_cstDS)) and %upcase(&_cstOverwrite)=N %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Operation cannot be completed because &_cstDS already exists and the _cstOverwrite parameter has been set to N.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cstInputDS;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %***********************************************;
  %*  Verify write access to the target library  *;
  %***********************************************;
  %cstutilcheckwriteaccess(_cstFileType=LIBNAME,_cstFileRef=&_cstRDir);
  %if &_cst_rc %then
  %do;
    %let _cstMsgID=CST0113;
    %let _cstParm1=&_cstDS because %upcase(&_cstRDir) is read-only;
    %let _cstParm2=;
    %let _cst_rcmsg=Unable to create data set &_cstParm1.;
    %goto ABORT_PROCESS;
  %end;

  %if %length(&_cstDSKeys)>0 %then
  %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=;
    %let _cstKeyStr=;
    %let _cstBadKey=0;
    %*******************************;
    %*  Verify each column exists  *;
    %*******************************;
    %do _cstDSKeysCnt=1 %to %SYSFUNC(countw(&_cstDSKeys,' '));
      %let _cstKey = %SYSFUNC(scan(&_cstDSKeys,&_cstDSKeysCnt,' '));
      %if %cstutilgetattribute(_cstDataSetName=&_cstInputDS,_cstVarName=&_cstKey,_cstAttribute=VARNUM) lt 1 %then
      %do;
        %let _cstKeyStr=&_cstKeyStr &_cstKey;
        %let _cstBadKey=1;
      %end;
    %end;
    %if &_cstBadKey=1 %then
    %do;
       %let _cst_rc=1;
       %let _cstMsgID=CST0008;
       %let _cstParm1=These keys (%upcase(&_cstKeyStr)) specified in the _cstDSKeys parameter;
       %let _cstParm2=;
       %let _cst_rcmsg=&_cstParm1 could not be found.;
       %goto ABORT_PROCESS;
    %end;
  %end;

  %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);
 
  %***********************************************;
  %*  Prepare to add observation(s) to data set  *;
  %***********************************************;
  %if (^%symexist(_cstTransactionDS)=1) %then 
    %let _cstTransactionDS=;

  %***********************************************************;
  %*  Check Transaction data set to verify it is not locked  *;
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

  %if %length(&_cstDSKeys)>0 %then
  %do;
    %if %length(&_cstDSLabel)>0 %then %do;
      proc sort data=&_cstInputDS out=&_cstDS (label="%quote(&_cstDSLabel)");
    %end;
    %else %do;
      proc sort data=&_cstInputDS out=&_cstDS;
    %end;
        by &_cstDSKeys;
      run;
  %end;
  %else %do;
    %if %length(&_cstDSLabel)>0 %then %do;
      data &_cstDS (label="%quote(&_cstDSLabel)");
    %end;
    %else %do;
      data &_cstDS;
    %end;
        set &_cstInputDS;
      run;
  %end;
  %if &SYSERR %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Unable to successfully add &_cstDS.. SEE LOG;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  %else %do;
    %let _cst_rc=0;
    %let _cst_rcmsg=&_cstDS successfully added.;
  %end;

  %* Capture successful outcome of request (_cst_rc will be reset in call to cstutillogevent() below). *;
  %let _cstThisMacroRC=&_cst_rc;
  %let _cstThisMacroRCmsg=&_cst_rcmsg;

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
  
  %**********************************************;
  %*  Populate values for transaction data set  *;
  %**********************************************;
  %let _cstAttrString=;
  %cstutilbuildattrfromds(_cstSourceDS=&_cstTransCopyDS,_cstAttrVar=_cstAttrString);

  data &_cstTransCopyDS;
    attrib &_cstAttrString;
    
    cststandard=ktrim("&_cstStd");
    cststandardversion=ktrim("&_cstStdVer");
    cstuser=ktrim("&SYSUSERID");
    cstmacro=ktrim("&_cstSrcMacro");
    cstfilepath=ktrim(pathname(ksubstr("&_cstDS",1,kindexc(ktrim("&_cstDS"),'.')-1)));
    cstmessage=ktrim("&_cstThisMacroRCmsg");
    cstcurdtm=datetime();
    cstdataset=ktrim("&_cstDS");
    cstcolumn="";
    cstactiontype="ADD";
    cstentity="DATASET";
  run;
  %if &SYSERR %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Unable to create a working copy of the transaction log;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %**************************************************;
  %*  Write to transaction data set                 *;
  %*  cstutillogevent unlocks transaction data set  *;
  %**************************************************;
  %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
    
  %if &_cst_rc %then
  %do;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg=;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
    
  %let _cst_rc=&_cstThisMacroRC;
  %let _cst_rcmsg=&_cstThisMacroRCmsg;


%UPDATE_RESULTS:
  %*****************************;
  %*  Update Results data set  *;
  %*****************************;
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(_cstResultId=CST0200
                ,_cstResultParm1=&_cst_rcmsg
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&_cstSrcMacro
                ,_cstResultFlagParm=&_cst_rc
                ,_cstRCParm=&_cst_rc
                );
  %end;
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cst_rcmsg;
  %goto EXIT_MACRO;
 
  %****************************;
  %*  Handle any errors here  *;
  %****************************;
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
 
%mend cstutiladddataset;