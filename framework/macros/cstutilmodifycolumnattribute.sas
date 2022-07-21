%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilmodifycolumnattribute.sas                                               *;
%*                                                                                *;
%* Modifies column attributes of a SAS Clinical Standards Toolkit data set.       *;
%*                                                                                *;
%* All actions that change the content of the data set are written to a           *;
%* transaction file as specified by the SAS Clinical Standards Toolkit.           *;
%* The macro will NOT allow a change in length of a numeric column.               *;
%* When changing character lengths this utility will check the actual data in the *;
%* data set to determine if any data will be truncated. If truncation will result *;
%* from this operation the utilty will inform the user and %* will not continue.  *;
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
%*             reference for the column modification. Before invoking this macro, *;
%*             the libname must be initialized.                                   *;
%* @param _cstColumn - required - The column to modify in _cstDS.                 *;
%* @param _cstAttr - required - The attribute to modify.                          *;
%*             Values: FORMAT | INFORMAT | LENGTH | LABEL | TRANSCODE             *;
%* @param _cstAttrValue - required - The valid value for the attribute specified  *;
%*             in _cstATTR. NOTE: Do not encase the parameter value in quotation  *;
%*             marks.                                                             *;
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

%macro cstutilmodifycolumnattribute(
         _cstStd=
         ,_cstStdVer=
         ,_cstDS=
         ,_cstColumn=
         ,_cstAttr=
         ,_cstAttrValue=
         ,_cstTestMode=Y
         ) / des='CST: Modify a column attribute of any CST data set';

  %local _cstAttrStatement
         _cstAttrString
         _cstCheckVal
         _cstColumnLength
         _cstDSKeys
         _cstDSLabel
         _cstMaxLength
         _cstNeedToDeleteMsgs
         _cstOutDS
         _cstParm1
         _cstParm2       
         _cstRandom 
         _cstResultSeq
         _cstSASOption
         _cstSeqCnt
         _cstSrcMacro
         _cstTemp1
         _cstTempTable
         _cstTestMsg
         _cstTransCopyDS
         _cstVarType
         _cstWarningText
         _cst_rcmsg_thismacro
         ;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstWarningText=;
  %let _cstTestMsg=;
  %let _cstMaxLength=;
  %let _cstAttrString=;

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

  %let _cst_rc=0;
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
    %let _cstTestMsg=**TEST MODE**;
  %end;

  %************************************************;
  %*  One or more missing parameter values for    *;
  %*  _cstStd, _cstStdVer, _cstDS, or _cstColumn  *;
  %************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstColumn)=0) or 
      (%klength(&_cstAttr)=0) or (%klength(&_cstAttrValue)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstColumn _cstAttr _cstAttrValue;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg One or more of the following parameters is missing _cstStd, _cstStdVer, _cstDS, _cstColumn, _cstAttr, or _cstAttrValue.;
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
  
  %*********************************************;
  %*  Verify input data set and column exists  *;
  %*********************************************;
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
    
    %**************************************************;
    %*  Verify a valid SAS column name is being used  *;
    %**************************************************;
    %if %sysfunc(nvalid(&_cstColumn))=0 %then
    %do;
      %let _cst_rc_=1;
      %let _cst_rcmsg=&_cstTestMsg Column [&_cstColumn] is an invalid SAS column name - no action performed.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;

    %************************************;
    %*  Verify specified column exists  *;
    %************************************;
    %if %cstutilgetattribute(_cstDataSetName=&_cstDS,_cstVarName=&_cstColumn,_cstAttribute=VARNUM)=0 %then
    %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=&_cstTestMsg The column [&_cstColumn] specified in the _cstColumn macro parameter does not exist. No action taken.;
       %let _cstMsgID=CST0202;
       %let _cstParm1=&_cst_rcmsg;
       %let _cstParm2=;
       %goto ABORT_PROCESS;
    %end;

    %************************************************************;
    %*  Retrieve key variables if they exist for sorting later  *;
    %*  Retrive column type N or C for checking later           *;
    %************************************************************;
    %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=SORTEDBY);
    %let _cstVarType=%cstutilgetattribute(_cstDataSetName=&_cstDS, _cstVarName=&_cstColumn,_cstAttribute=VARTYPE);
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

  %**********************************************;
  %*  Invalid attribute for _cstAttr parameter  *;
  %**********************************************;
  %if %upcase(&_cstAttr) ne FORMAT and %upcase(&_cstAttr) ne INFORMAT and %upcase(&_cstAttr) ne LENGTH and 
      %upcase(&_cstAttr) ne LABEL and %upcase(&_cstAttr) ne TRANSCODE %then
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=with a valid attribute. _cstAttr has invalid value [%upcase(&_cstAttr)] - no action taken.;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg A required parameter was not supplied with a valid attribute. _cstAttr has invalid value [%upcase(&_cstAttr)] - no action taken.;
    %goto ABORT_PROCESS;
  %end;

  %******************************************************************************;
  %*  Pre-pend ($) on length, format, and informat values for character column  *;
  %******************************************************************************;
  %if %upcase(&_cstVarType)=C %then  
  %do;
    %if %upcase(&_cstAttr)=LENGTH or %upcase(&_cstAttr)=FORMAT or %upcase(&_cstAttr)=INFORMAT %then
    %do;
      %let _cstCheckVal=%sysfunc(indexc(&_cstAttrValue,'$'));
      %if &_cstCheckVal=0 %then %let _cstAttrValue=$%ktrim(&_cstAttrValue);
    %end;
  %end;

  %*********************************;
  %*  Initialize ATTRIB statement  *;
  %*********************************;
  %if %upcase(&_cstAttr)=LABEL %then
  %do;
     %********************************************;
     %*  Remove any double quotes if they exist  *;
     %********************************************;
     %let _cstAttrValue=%sysFunc(ktranslate(%nrbquote(&_cstAttrValue),%str( ),%str(%")));
     %let _cstAttrStatement=&_cstColumn &_cstAttr="%nrbquote(&_cstAttrValue)";
  %end;
  %else %let _cstAttrStatement=&_cstColumn &_cstAttr=&_cstAttrValue;

  %**************************************;
  %*  Check for valid ATTRIB statement  *;
  %**************************************;
  %let _cst_rc=0;
  
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempTable=%sysfunc(pathname(work))/_cst&_cstRandom._log.log;
  
  filename _csttest "&_cstTempTable";
  
  proc printto log=_csttest;
  run;
  
  data _null_;
    attrib &_cstAttrStatement;
    set &_cstDS;
    if _n_=1;
  run;
  
  %let _cst_rc=&SYSERR;
  
  proc printto;
  run;
  
  %if &_cst_rc=4 %then %let _cstWarningText=&SYSWARNINGTEXT;
  
  %let _cstTemp1=%sysfunc(fdelete(_csttest));

  %if &_cst_rc and &_cst_rc ne 4 %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg &SYSERRORTEXT - Invalid Attribute statement [ATTRIB %upcase(&_cstAttrStatement)] for column %upcase(&_cstColumn) column type = %upcase(&_cstVarType) - no action performed.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cstTestMsg Invalid Attribute statement [ATTRIB %upcase(&_cstAttrStatement)] for column %upcase(&_cstColumn) column type = %upcase(&_cstVarType) - no action performed.;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %******************************;
  %*  Update column attributes  *;
  %******************************;
  
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
    
    data &_cstOutDS;
      set &_cstDS;
    run;
    
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
      %let _cst_rcmsg=No template dataset found for type=&_cstParm1, subtype=&_cstParm2.;
      %goto ABORT_PROCESS;
    %end;
  %end;
  
  %**********************************************************;
  %*  Do not accept a reduction in LENGTH for numeric data  *;
  %*********************************************************************;
  %if %upcase(&_cstAttr) eq LENGTH %then 
  %do;
    %let _cstColumnLength=%cstutilgetattribute(_cstDataSetName=&_cstDS, _cstVarName=&_cstColumn,_cstAttribute=VARLEN);
    %if %upcase(&_cstVarType)=N %then 
    %do;
      %let _cst_rc=1;
      %let _cst_rcmsg=&_cstTestMsg This utility will not allow a change in the LENGTH of a numeric value. No action taken.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %if %upcase(&_cstTestMode)=N %then
      %do;
        lock &_cstTransactionDS clear;
      %end; 
      %goto ABORT_PROCESS;
    %end;

    proc sql noprint; 
      select max(length(&_cstColumn)) into :_cstMaxLength 
      from &_cstDS (keep=&_cstColumn); 
    quit;
    
    %********************************************************;
    %*  Remove prepended $ for valid attribute check above  *;
    %********************************************************;
    %let _cstAttrValue=%sysfunc(translate(&_cstAttrValue,%str( ),$));

    %if &_cstMaxLength > &_cstAttrValue %then 
    %do;
      %let _cst_rc=1;
      %let _cst_rcmsg=&_cstTestMsg New LENGTH value [&_cstAttrValue] is shorter then maximum data value length [%trim(%left(&_cstMaxLength))]. Will cause truncated data. No action taken.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %if %upcase(&_cstTestMode)=N %then
      %do;
        lock &_cstTransactionDS clear;
      %end; 
      %goto ABORT_PROCESS;
    %end;
    
    %let _cstAttrStatement=&_cstColumn char(&_cstAttrValue);

  %end;
  
  proc sql;
   alter table &_cstOutDS modify &_cstAttrStatement;
  quit;
   
  %let _cst_rc=0;
  %let _cst_rcmsg_thismacro=&_cstTestMsg Attribute modification of column %upcase(&_cstColumn) [%upcase(&_cstAttr = %nrbquote(&_cstAttrValue))] successful. &_cstWarningText;

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
      cstactiontype="UPDATE";
      cstentity="COLUMN";
      output;
    run;
   
    %***********************************;
    %*  Write to transaction data set  *;
    %***********************************;
    %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS) ;
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
%mend cstutilmodifycolumnattribute;