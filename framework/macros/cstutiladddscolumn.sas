%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutiladddscolumn.sas                                                         *;
%*                                                                                *;
%* Adds a column to a SAS Clinical Standards Toolkit data set.                    *;
%*                                                                                *;
%* All actions that change the content of the data set are written to a           *;
%* transaction file as specified by the SAS Clinical Standards Toolkit.           *;
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
%*             reference in which to add the column. Before invoking this macro,  *;
%*             the libname must be initialized.                                   *;
%* @param _cstColumn - required - The column to add to _cstDS.                    *;
%* @param _cstColumnLabel - required - The column label for the column to add.    *;
%* @param _cstColumnType - required - The column type for the column to add:      *;
%*             C: Character                                                       *;
%*             N: Numeric                                                         *;
%*             Values: C | N                                                      *;
%* @param _cstColumnLength - required - The NUMERIC column length for the column  *;
%*             to add. The macro handles the $ in the length attribute for        *;
%*             character data.                                                    *;
%* @param _cstColumnFmt - optional - The column format for the column to add.     *;
%*             For example, $12., 8.3, or BEST12.                                 *;
%* @param _cstColumnInitValue - optional - The column initial value for the       *;
%*             column to add.                                                     *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutiladddscolumn(
       _cstStd=
       ,_cstStdVer=
       ,_cstDS=
       ,_cstColumn=
       ,_cstColumnLabel=
       ,_cstColumnType=
       ,_cstColumnLength=
       ,_cstColumnFmt=
       ,_cstColumnInitValue=
       ) / des='CST: Add a column to any CST data set';

  %local _cstAttrStatement
         _cstAttrString
         _cstCheckVal
         _cstDSKeys
         _cstDSLabel
         _cstDSLabelStatement
         _cstNeedToDeleteMsgs
         _cstParm1
         _cstParm2       
         _cstRandom 
         _cstResultSeq
         _cstSeqCnt
         _cstSrcMacro
         _cstTemp1
         _cstTempTable
         _cstTransCopyDS
         _cst_rcmsg_thismacro
         ;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  
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

  %************************************************;
  %*  One or more missing parameter values for    *;
  %*  _cstStd, _cstStdVer, _cstDS, or _cstColumn  *;
  %************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstColumn)=0) or 
      (%klength(&_cstColumnLabel)=0) or (%klength(&_cstColumnType)=0) or (%klength(&_cstColumnLength)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstColumn _cstColumnLabel _cstColumnType _cstColumnLength;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=One or more of the following parameters is missing _cstStd, _cstStdVer, _cstDS, _cstColumn, _cstColumnLabel, _cstColumnType, or _cstColumnLength.;
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
    %let _cst_rcmsg=The standard &_cstParm1 is not registered.;
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
    %let _cst_rcmsg=The data set [&_cstDS] macro parameter does not follow <libname>.<dsname> construct.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %*********************************************************************;
  %*  Verify input data set exists and column variable does not exist  *;
  %*********************************************************************;
  %let _cst_rc=;
  %if not %sysfunc(exist(&_cstDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstDS] specified in the _cstDS macro parameter does not exist.;
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
       %let _cst_rcmsg=The column value [&_cstColumn] specified in the _cstColumn macro parameter contains more than one column.;
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
      %let _cst_rcmsg=Column [&_cstColumn] is an invalid SAS column name - no action performed.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;

    %********************************************;
    %*  Verify specified column does not exist  *;
    %********************************************;
    %if %cstutilgetattribute(_cstDataSetName=&_cstDS,_cstVarName=&_cstColumn,_cstAttribute=VARNUM) ne 0 %then
    %do;
       %let _cst_rc=1;
       %let _cst_rcmsg=The column [&_cstColumn] specified in the _cstColumn macro parameter ALREADY EXISTS. No action taken.;
       %let _cstMsgID=CST0202;
       %let _cstParm1=&_cst_rcmsg;
       %let _cstParm2=;
       %goto ABORT_PROCESS;
    %end;

    %************************************************************;
    %*  Retrieve key variables if they exist for sorting later  *;
    %************************************************************;
    %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=SORTEDBY);
  %end;
  
  %*****************************************;
  %*  Verify write access to the data set  *;
  %*****************************************;
  %cstutilcheckwriteaccess(_cstFileType=DATASET,_cstFileRef=&_cstDS);
  %if &_cst_rc %then
  %do;
    %let _cstMsgID=CST0111;
    %let _cstParm1=&_cstDS with write access;
    %let _cstParm2=;
    %let _cst_rcmsg=Unable to open data set &_cstParm1.;
    %goto ABORT_PROCESS;
  %end;

  %************************************************;
  %*  Verify that all macro attribute parameters  *; 
  %*  are consistent with column type             *; 
  %************************************************;
  
  %*************************************;
  %*  Verify column LENGTH is numeric  *;
  %*************************************;
  %if %sysfunc(notdigit(&_cstColumnLength)) gt 0 %then
  %do;
    %let _cst_rc_=1;
    %let _cst_rcmsg=Column length [&_cstColumnLength] contains non numeric data or decimals - no action performed.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %*******************************************;
  %*  Check (C) character column attributes  *;
  %*  Check (N) numeric column attributes    *;
  %*  If neither abort process               *;
  %*******************************************;
  %if %upcase(&_cstColumnType)=C %then 
  %do;
    %if &_cstColumnLength=0 or &_cstColumnLength gt 32767 %then
    %do;
      %*******************************************************;
      %*  Check for out of range lengths for character data  *;
      %*******************************************************;
      %let _cst_rc_=1;
      %let _cst_rcmsg=Incorrect column length [&_cstColumnLength] for CHARACTER data - no action performed.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;
    %if %klength(&_cstColumnInitValue) gt 0 %then
    %do;
      %if %klength(&_cstColumnInitValue) gt &_cstColumnLength %then 
      %do;
        %***************************************************************************;
        %*  Check data value length greater than column length for character data  *;
        %***************************************************************************;
        %let _cst_rc_=1;
        %let _cst_rcmsg=Length Column initial value [%klength(%ktrim(&_cstColumnInitValue))] is longer than column length provided [&_cstColumnLength] for CHARACTER data - no action performed.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;
    %end;
    %if %klength(&_cstColumnFmt) gt 0 %then
    %do;
      %********************************************************************;
      %*  For character data check to see if format has $, if not add it  *; 
      %*  Validation will occur later in the code                         *;
      %********************************************************************;
      %let _cstCheckVal=%sysfunc(indexc("&_cstColumnFmt",'$'));
      %if &_cstCheckVal=0 %then %let _cstColumnFmt=$&_cstColumnFmt;
    %end;
  %end;
  %else %if %upcase(&_cstColumnType)=N %then 
  %do;
    %if %klength(&_cstColumnFmt) gt 0 %then
    %do;
      %let _cstCheckVal=%sysfunc(indexc("&_cstColumnFmt",'$'));
      %if &_cstCheckVal gt 0 %then 
      %do;
        %*******************************************************;
        %*  Character format ($) associated with numeric data  *;
        %*******************************************************;
        %let _cst_rc_=1;
        %let _cst_rcmsg=Column format [&_cstColumnFMT] is incorrectly constructed for NUMERIC data - no action performed.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;
    %end;
    %if &_cstColumnLength lt 3 or &_cstColumnLength gt 8 %then
    %do;
      %*****************************************************;
      %*  Check for out of range lengths for numeric data  *;
      %*****************************************************;
      %let _cst_rc_=1;
      %let _cst_rcmsg=Incorrect column length [&_cstColumnLength] for NUMERIC data - no action performed.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;
    %if %klength(&_cstColumnInitValue) gt 0 %then
    %do;
      %let _cstTemp1=%sysfunc(kcompress(&_cstColumnInitValue,'.'));
      %let _cstCheckVal=%sysfunc(notdigit(&_cstTemp1));
      %if &_cstCheckVal gt 0 %then 
      %do;
        %*********************************************;
        %*  Non numeric data found for numeric data  *;
        %*********************************************;
        %let _cst_rc_=1;
        %let _cst_rcmsg=Column initial value contains non-numeric data [&_cstColumnInitValue] - no action performed.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;
    %end;
  %end;
  %else 
  %do;
    %******************************************;
    %*  Invalid Column Type - Must be N or C  *;
    %******************************************;
    %let _cst_rc_=1;
    %let _cst_rcmsg=Improper value [%upcase(&_cstColumnType)] for parameter Column Type - no action performed.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
    
  %if %klength(&_cstColumnLabel) gt 256 %then 
  %do;
    %********************************************************;
    %*  Column label exceeds maximum length allowed by SAS  *;
    %********************************************************;
    %let _cst_rc_=1;
    %let _cst_rcmsg=Column label exceeds 256 character maximum - no action performed.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;
  
  %********************************************;
  %*  Remove any double quotes if they exist  *;
  %********************************************;
  %let _cstColumnLabel=%sysFunc(ktranslate(%nrbquote(&_cstColumnLabel),%str( ),%str(%")));
   
  %********************************************************;
  %*  Pre-pend ($) on column length for character column  *;
  %********************************************************;
  %if %upcase(&_cstColumnType)=C %then %let _cstColumnLength=$%ktrim(&_cstColumnLength);

  %*********************************;
  %*  Initialize ATTRIB statement  *;
  %*********************************;
  %let _cstAttrStatement=attrib &_cstColumn length=&_cstColumnLength label="&_cstColumnLabel";

  %***************************************************;
  %*  Check for valid format statement if it exists  *;
  %***************************************************;
  %if %klength(&_cstColumnFmt) gt 0 %then 
  %do;
    %let _cst_rc=0;
  
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstTempTable=%sysfunc(pathname(work))/_cst&_cstRandom._log.log;
  
    filename _csttest "&_cstTempTable";
  
    proc printto log=_csttest;
    run;
  
    data _null_;
      attrib &_cstColumn format=&_cstColumnFmt;
    run;
  
    %let _cst_rc=&SYSERR;
  
    proc printto;
    run;
  
    %let _cstTemp1=%sysfunc(fdelete(_csttest));

    %if &_cst_rc %then
    %do;
      %let _cst_rc=1;
      %let _cst_rcmsg=Invalid FORMAT=&_cstColumnFmt used with ATTRIB statement - no action performed.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;
    %else %let _cstAttrStatement=&_cstAttrStatement format=&_cstColumnFmt;
  %end;

  %****************************;
  %*  Add column to data set  *;
  %****************************;
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
 
  %*****************************************************************;
  %*  Perform addition of new column                               *;
  %*  If keys exist use proc sort to maintain SORTEDBY attributes  *;
  %*****************************************************************;
  %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=LABEL);
  %if %klength(&_cstDSLabel) gt 0 
    %then %let _cstDSLabelStatement=(label="&_cstDSLabel");
    %else %let _cstDSLabelStatement=;

  %let _cstAttrString=;
  %cstutilbuildattrfromds(_cstSourceDS=&_cstDS,_cstAttrVar=_cstAttrString);

  data &_cstDS &_cstDSLabelStatement;
    attrib &_cstAttrString;
    &_cstAttrStatement;
    set &_cstDS;
    %if %klength(&_cstColumnInitValue) gt 0 %then
    %do;
      %if %upcase(&_cstColumnType)=N %then  
      %do;
        &_cstColumn=&_cstColumnInitValue;
      %end;
      %else 
      %do;
        &_cstColumn="&_cstColumnInitValue";
      %end;
    %end;
  run;

  %if %klength(&_cstDSkeys) gt 0 %then
  %do;
    proc sort data=&_cstDS;
      by &_cstDSKeys;
    run;
  %end;
    
  %let _cst_rc=0;
  %let _cst_rcmsg_thismacro=Addition of new column [&_cstColumn] successful;

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
    cstactiontype="ADD";
    cstentity="COLUMN";
    output;
  run;
   
  %***********************************;
  %*  Write to transaction data set  *;
  %***********************************;
  %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS) ;
  %cstutil_deletedataset(_cstDataSetName=&_cstTransCopyDS);

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
%mend cstutiladddscolumn;