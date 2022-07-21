%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilupdatemetadatarecords.sas                                               *;
%*                                                                                *;
%* Updates an observation in a SAS Clinical Standards Toolkit data set.           *;
%*                                                                                *;
%* This macro updates a record/row in the specified data set. All actions that    *;
%* change the data set are written to the specified log file.                     *;
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
%* @param _cstDS - required - The <Libname>.<DSname> SAS data set to modify.      *;
%*           Before invoking this macro, the libname must be initialized.         *;
%* @param _cstDSIfClause - required - A SAS subset clause that specifies the      *;
%*           records to update. The clause is used only in an IF statement and    *;
%*           must adhere to the syntax rules of an IF statement.                  *;
%*           All records that match the criteria of the clause are updated.       *;
%*           Clauses that are syntactically incorrect (for example,               *;
%*           %str(keys ? 'TRT')) or contain non-existent column references        *;
%*           generate errors and cause the macro to exit without performing any   *;
%*           action.                                                              *;
%*           NOTE: Double quotation marks are translated into single quotation    *;
%*                 marks to simplify processing. Single apostrophes in the string *;
%*                 must be changed to double apostrophes. For example,            *;
%*                 comment="Event can''t happen").                                *;
%*           The syntax can update from 0 to all records.                         *;
%*           Example: Modify the keys for the TR domain in reference_tables       *;
%*           _cstDSIfClause=%str(sasref='REFMETA' and table='TR')                 *;
%* @param _cstColumn - required - The name of the column in _cstDS. Only one      *;
%*           column can be specified.                                             *;
%*           Limitation: Data set keys cannot be updated using this macro. Use    *;
%*                       cstutilappendmetadatarecords() instead.                  *;
%* @param _cstValue - required - The new value of _cstDS._cstColumn. You must     *;
%*           a valid type-specific value for _cstColumn. Null character values    *;
%*           must be specified as %str( ).                                        *;
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

%macro cstutilupdatemetadatarecords(
       _cstStd=,
       _cstStdVer=,
       _cstDS=,
       _cstDSIfClause=,
       _cstColumn=,
       _cstValue=,
       _cstTestMode=Y
       ) / des='CST: Update a CST data set observation';

  %local _cstAttrString
         _cstCheckVal
         _cstDeleteFiles
         _cstDSKeys
         _cstDSIfClause_orig
         _cstDSLabel
         _cstDSRecCnt
         _cstDSWork
         _cstNeedToDeleteMsgs
         _cstMsgID
         _cstOutDS
         _cstParm1
         _cstParm2       
         _cstRandom 
         _cstRandom1
         _cstSASoption
         _cstSeqCnt
         _cstSrcMacro
         _cstTemp1
         _cstTestMsg
         _cstThisMacroRC
         _cstThisMacroRCmsg
         _cstTransCopyDS
         _cstUseResultsDS
         _cstVarType
         ;

  %let _cstDeleteFiles=1;
  %let _cstSeqCnt=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstThisMacroRC=0;
  %let _cstUseResultsDS=0;
  %let _cstTestMsg=; 
  
  %* Reporting will be to the CST results data set if available, otherwise to the SAS log.  *;  
  %if (%symexist(_cstResultsDS)=1) %then 
  %do;
    %if (%klength(&_cstResultsDS)>0) and %sysfunc(exist(&_cstResultsDS)) %then;  
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
    %let _cstTestMsg=**Test Mode**;
  %end;
  
  %*******************************************************************;
  %*  One or more missing parameter values for _cstStd, _cstStdVer,  *;
  %*  _cstDS, _cstDSIfClause, _cstColumn or _cstValue                *;
  %*******************************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstDSIfClause)=0) or (%klength(&_cstColumn)=0) or (%klength(&_cstValue)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstDSIfClause _cstColumn _cstValue;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg One or more of the following parameters is missing _cstStd, _cstStdVer, _cstDS, _cstDSIfClause, _cstColumn or _cstValue.;
    %goto ABORT_PROCESS;
  %end;
  
  %************************************************************************;
  %*  Is the standard/standardversion combination a registered standard?  *;
  %************************************************************************;
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
    %else
      %let _cstDSWork=_cstWorkFile;
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

  %*****************************************************;
  %*  Verify input data set and column variable exist  *;
  %*****************************************************;
  %let _cst_rc=;
  %if not %sysfunc(exist(&_cstDS)) %then 
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
    
    %let _cstDSKeys=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=SORTEDBY);

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
    
    %*****************************************;
    %*  Verify selected column is not a key  *;
    %*****************************************;
    %if %sysfunc(indexw(%upcase(%str(&_cstDSKeys)),%upcase(%str(&_cstColumn))))>0 %then
    %do;
       %let _cst_rc_=1;
       %let _cst_rcmsg=&_cstTestMsg The column [&_cstColumn] specified in the _cstColumn macro parameter is a key in &_cstDS and cannot be modified.;
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

  %**************************************************************************;
  %*  Translate _cstDSIfClause to change any double quotes to single quotes *;
  %*  Report this in the log only if _cstDSIfClause is modified.            *;
  %**************************************************************************;
  %let _cstDSIfClause_orig=&_cstDSIfClause;
  %let _cstDSIfClause=%sysfunc(ktranslate(&_cstDSIfClause,%str(%'),%str(%")));
  %if "&_cstDSIfClause" ne "&_cstDSIfClause_orig" %then
    %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: Double quotes have been translated to single quotes for the _cstDSIfClause parameter; 
   
  %***************************;
  %*  Update observation(s)  *;
  %***************************;

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
  %end;
  
  %*******************************************;
  %*  Macro isnumeric checks parameter value *;
  %*  for valid numeric value.               *;
  %*******************************************;  
  %macro isnumeric(_cstParmValue=);                                                                                                           
    %global _cstIsNumeric;                                                                                                                
    %local _cstcommafound _cstnondigitfound _cstvaluelength;                                                                                                                
                                                                                                                                      
    %let _cstcommafound=%sysfunc(findc(&_cstParmValue,","));                                                                                      
    %let _cstvaluelength=%length(&_cstParmValue);
    %if &_cstvaluelength=1 
      %then %let _cstnondigitfound=%sysfunc(notdigit(&_cstParmValue));
      %else %let _cstnondigitfound=0;

    data _null_;                                                                                                                          
      isnumeric='N';                                                                                                                      
      if "&_cstParmValue"="." then                                                                                                            
      do;                                                                                                                                 
        isnumeric='Y';                                                                                                                    
        goto exit;                                                                                                                        
      end;                                                                                                                                
      if &_cstvaluelength=1 and &_cstnondigitfound>0 then goto exit;                                                                                                                                      
      if &_cstvaluelength=2 then                                                                                                     
      do;                                                                                                                                 
        position=prxmatch(prxparse("\[.][[:alpha:]_]\"), "&_cstParmValue");                                                                   
        if position=1 then                                                                                                                
        do;                                                                                                                               
          isnumeric='Y';                                                                                                                  
          goto exit;                                                                                                                      
        end;                                                                                                                              
      end;                                                                                                                                
      %if (&_cstcommafound=0) and (&_cstvaluelength>0 and &_cstnondigitfound=0) %then                                                                                                             
      %do;                                                                                                                                
        if ^missing(input("&_cstParmValue",??BEST32.)) or                                                                                     
           ^missing(input(&_cstParmValue,??BEST32.))then isnumeric='Y';                                                                       
      %end;                                                                                                                               
      exit:                                                                                                                               
      call symputx('_cstIsNumeric',isnumeric);                                                                                            
    run;                                                                                                                                  
  %mend isnumeric;
  
  %**************************************;
  %*  Attempt to make requested change  *;
  %**************************************;
  %let _cstVarType=%cstutilgetattribute(_cstDataSetName=&_cstDS, _cstVarName=&_cstColumn,_cstAttribute=VARTYPE);  

  %**************************************************;
  %*  If numeric column make sure value is numeric  *;
  %**************************************************;
  %if %upcase(&_cstVarType)=N %then
  %do;
    %isnumeric(_cstParmValue=%str(&_cstValue));
    %if %upcase(&_cstIsNumeric)=N %then 
    %do;
      %if %upcase(&_cstTestMode)=N %then 
      %do;
        lock &_cstTransactionDS clear;
      %end;
      %let _cst_rc_=1;
      %let _cst_rcmsg=&_cstTestMsg The column is numeric but the value [&_cstValue] is non-numeric.;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
     %end;
  %end;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  
  data work._cst&_cstRandom._sub
       work._cst&_cstRandom._nonsub;
    set &_cstDS;
    record_order=_n_;
    if &_cstDSIfClause then
    do;
      %if &_cstVarType=C %then 
      %do;
        &_cstColumn="&_cstValue";
      %end;
      %else 
      %do;
        &_cstColumn=&_cstValue;
      %end;
      output work._cst&_cstRandom._sub;
    end;
    else output work._cst&_cstRandom._nonsub ;
  run;
  %if &SYSERR %then 
  %do;
    %if %upcase(&_cstTestMode)=N %then 
    %do;
      lock &_cstTransactionDS clear;
    %end;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg There is a problem with the subset clause [%upcase(&_cstDSIfClause)] - check syntax and verify variable(s) exist. SEE LOG;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %**************************************************************************;
  %*  Check number of observations. Send NOTE to log or results data set    *;
  %*  and bypass transaction log if no updates were made.  Otherwise,       *;
  %*  update transaction log.                                               *;
  %**************************************************************************;
  %let _cstDSRecCnt=%cstutilgetattribute(_cstDataSetName=work._cst&_cstRandom._sub,_cstAttribute=NOBS);  

  %if &_cstDSRecCnt>0 %then
  %do;
    %if %upcase(&_cstTestMode)=N %then
    %do;
      %******************************************;
      %*  Create transaction template data set  *;
      %******************************************;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom1);
      %let _cstTransCopyDS=work._cst&_cstRandom1;
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

      data &_cstTransCopyDS (keep=cststandard cststandardversion cstuser cstmacro cstfilepath cstmessage
            cstcurdtm cstdataset cstcolumn cstactiontype cstentity);
        attrib &_cstAttrString;
        set work._cst&_cstRandom._sub end=last;
        attrib _cstkeys format=$200.;
        retain _cstkeys;
      
        if _n_=1 then
          _cstkeys=symget('_cstDSKeys');

        cststandard=ktrim("&_cstStd");
        cststandardversion=ktrim("&_cstStdVer");
        cstuser=ktrim("&SYSUSERID");
        cstmacro=ktrim("&_cstSrcMacro");
        cstfilepath=ktrim(pathname(ksubstr("&_cstDS",1,kindexc(ktrim("&_cstDS"),'.')-1)));
        cstcurdtm=datetime();
        cstdataset=ktrim("&_cstDS");
        cstcolumn=ktrim("&_cstColumn");
        cstactiontype="UPDATE";
        cstentity="RECORD";

        if not missing(_cstkeys) then
        do;
          if missing(cstmessage) then
          do;
            cstmessage="%upcase(&_cstColumn) value changed to '&_cstValue' for";
            keycnt=0;
          end;
          do k=1 to countw(_cstkeys,' ');
            if k=1 then
              cstmessage=catx(' ',cstmessage,catx(', ', cats(kscan("&_cstDSKeys",1,' '),'=',vvaluex(kscan(_cstkeys,k,' ')))));
            else
              cstmessage=catx(', ',cstmessage,cats(kscan("&_cstDSKeys",k,' '),'=',vvaluex(kscan(_cstkeys,k,' '))));
          end;
          output;
        end;
        else
        do;
          if last then do;
            cstmessage="%upcase(&_cstColumn) value changed to '&_cstValue' for &_cstDSRecCnt records matching [%upcase(&_cstDSIfClause)]";
            output;
          end;
        end;
      run;
      %if &SYSERR %then 
      %do;
        lock &_cstTransactionDS clear;
        %let _cst_rc=1;
        %let _cst_rcmsg=Unable to create a working copy of the transaction log;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;
    %end;
    
    %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstDS,_cstAttribute=LABEL);
    
    * Put updated and non-updated records back together to rebuild edited data set *;
    data work.&_cstDSWork;
      set work._cst&_cstRandom._sub
          work._cst&_cstRandom._nonsub;
    run;
    
    %if %klength(&_cstDSLabel)>0 %then %do;
      proc sort data=work.&_cstDSWork out=&_cstOutDS (drop=record_order label="%quote(&_cstDSLabel)");
    %end;
    %else %do;
      proc sort data=work.&_cstDSWork out=&_cstOutDS (drop=record_order);
    %end;
    %if "&_cstDSkeys" ne "" %then
    %do;
        by &_cstDSKeys;
    %end;
    %else %do;
        by record_order;
    %end;
    run;
    %if &SYSERR %then 
    %do;
      %if %upcase(&_cstTestMode)=N %then 
      %do;
        lock &_cstTransactionDS clear;
      %end;
      %let _cst_rc=1;
      %let _cst_rcmsg=&_cstTestMsg Unable to successfully post updates to &_cstOutDS. SEE LOG;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;

    %* Capture successful outcome of request (_cst_rc will be reset in call to cstutillogevent() below). *;
    %let _cstThisMacroRC=0;
    %let _cstThisMacroRCmsg=&_cstTestMsg Update of &_cstDSRecCnt record(s) successful using subset clause %UPCASE(&_cstDSIfClause);
    
    %**************************************************;
    %*  Write to transaction data set                 *;
    %*  cstutillogevent unlocks transaction data set  *;
    %**************************************************;
    %if %upcase(&_cstTestMode)=N %then %cstutillogevent(_cstLockDS=&_cstTransactionDS,_cstUpdateDS=&_cstTransCopyDS);
    
    %if &_cst_rc %then
    %do;
      %let _cstMsgID=CST0202;
      %let _cstParm1=&_cst_rcmsg=;
      %let _cstParm2=;
      %goto ABORT_PROCESS;
    %end;
    
    %* Clean up work files *;
    %if %symexist(_cstDebug) %then %do;
      %if &_cstDebug %then
        %let _cstDeleteFiles=0;
    %end;
    %if (&_cstDeleteFiles) %then
    %do;
      %cstutil_deleteDataSet(_cstDataSetName=&_cstDSWork);
      %if %klength(&_cstTransCopyDS)>0 %then 
      %do;
        %cstutil_deleteDataSet(_cstDataSetName=&_cstTransCopyDS);
      %end;
      proc datasets nolist lib=work;
        delete _cst&_cstRandom._sub _cst&_cstRandom._nonsub / mt=data;
        quit;
      run;
    %end;

    %let _cst_rc=&_cstThisMacroRC;
    %let _cst_rcmsg=&_cstThisMacroRCmsg;

  %end;
  %else
  %do;
    %if %upcase(&_cstTestMode)=N %then 
    %do;
      lock &_cstTransactionDS clear;
    %end;
    %let _cst_rc=0;
    %let _cst_rcmsg=&_cstTestMsg No records found that match the subset clause [%upcase(&_cstDSIfClause)]. No action performed.;
  %end;

%UPDATE_RESULTS:
  %*****************************;
  %*  Update Results data set  *;
  %*****************************;
  %if (&_cstUseResultsDS=1) %then 
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultId=CST0200
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
 
%ABORT_PROCESS:
  %****************************;
  %*  Handle any errors here  *;
  %****************************;
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
  
%mend cstutilupdatemetadatarecords;