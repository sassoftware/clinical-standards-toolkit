%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilappendmetadatarecords.sas                                               *;
%*                                                                                *;
%* Appends records to a SAS Clinical Standards Toolkit data set.                  *;
%*                                                                                *;
%* This macro appends a record/row to a SAS Clinical Standards Toolkit data set.  *;
%* All actions that change the data set are written to the specified log file.    *;
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
%*           reference of the base data set to receive new data. Before invoking  *;
%*           this macro, the libname must be initialized.                         *;
%* @param _cstNewDS - required - The <Libname>.<DSname> two-part SAS data set     *;
%*           reference that contains the records to append. Before invoking       *;
%*           this macro, the libname must be initialized. If the strcuture of     *;
%*           this data set does not match the structure that is specified in      *;
%*           _cstDS, this macro stops processing without performing any action.   *;
%* @param _cstUpdateDSType - required - Append or merge the records into the      *;
%*           _cstDS data set. If append, the new data is added to the _cstDS      *;
%*           data set. If merge, the data from _cstNewDS updates existing records *;
%*           and adds new records. In either case, if keys exist, the data set is *;
%*           sorted.                                                              *;
%*           Values: MERGE | APPEND                                               *;
%*           Default: MERGE                                                       *;
%* @param _cstOverwriteDup - optional - Allow the appended records to overwrite   *;
%*           records that exist in the base file. This parameter is used only     *;
%*           when _cstUpdateDSType is specified as MERGE.                         *;
%*           Values: Y | N                                                        *;
%*           Default: N                                                           *;
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

%macro cstutilappendmetadatarecords(
       _cstStd=
       ,_cstStdVer=
       ,_cstDS=
       ,_cstNewDS=
       ,_cstUpdateDSType=MERGE
       ,_cstOverwriteDup=N
       ,_cstTestMode=Y
       ) / des='CST: Merge or append observations to a CST data set';

  %local _cstCheckVal
         _cstDSKeys
         _cstDSLabel
         _cstDSLabelStatement
         _cstDSMerge
         _cstDSRecCnt
         _cstDSSortBy
         _cstNeedToDeleteMsgs
         _cstNew2DS
         _cstNumObs1
         _cstNumObs2
         _cstNumObs3
         _cstNumObsDup
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
         _cstTotalUpRec
         _cstTransCopyDS
         _cst_rcmsg_thismacro
         ;

  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;
  %let _cstUseResultsDS=0;
  %let _cstSrcMacro=&SYSMACRONAME;
  %let _cstTestMsg=;
  
  %if (%klength(&_cstOverwriteDup)=0) %then %let _cstOverwriteDup=N;
  
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
    %let _cst_rcmsg=&_cstTestMsg The _cstTestMode macro parameter value [&_cstTestMode] is not Y or N.;
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

  %********************************************************;
  %*  One or more missing parameter values for _cstSTD,   *;
  %*  _cstStdVer, _cstDS, _cstNewDS, or _cstUpdateDSType  *;
  %********************************************************;
  %if (%klength(&_cstStd)=0) or (%klength(&_cstStdVer)=0) or (%klength(&_cstDS)=0) or (%klength(&_cstNewDS)=0) or (%klength(&_cstUpdateDSType)=0) %then 
  %do;
    %let _cstMsgID=CST0081;
    %let _cstParm1=_cstStd _cstStdVer _cstDS _cstNewDS _cstUpdateDSType;
    %let _cstParm2=;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg One or more of the following REQUIRED parameters is missing _cstStd, _cstStdVer, _cstDS, _cstNewDS, or _cstUpdateDSType.;
    %goto ABORT_PROCESS;
  %end;

  %*********************************************;
  %*  _cstUpdateDSType must be MERGE or APPEND *;
  %*********************************************;
  %if %upcase(&_cstUpdateDSType) ne MERGE and %upcase(&_cstUpdateDSType) ne APPEND %then 
  %do;
    %let _cstMsgID=CST0202;
    %let _cst_rcmsg=&_cstTestMsg The _cstUpdateDSType macro parameter value [&_cstUpdateDSType] is not MERGE or APPEND.;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %let _cst_rc=1;
    %goto ABORT_PROCESS;
  %end;
  %else 
  %do;
    %*************************************;
    %*  _cstOverwriteDup must be Y or N  *;
    %*  if _cstUpdateDSType = MERGE      *;
    %*************************************;
    %if %upcase(&_cstUpdateDSType)=MERGE and (%upcase(&_cstOverwriteDup) ne Y and %upcase(&_cstOverwriteDup) ne N) %then 
    %do;
      %let _cstMsgID=CST0202;
      %let _cst_rcmsg=&_cstTestMsg The _cstOverwriteDup macro parameter value [&_cstOverwriteDup] is not Y or N and _cstUpdateDSType = MERGE.;
      %let _cstParm1=&_cst_rcmsg;
      %let _cstParm2=;
      %let _cst_rc=1;
      %goto ABORT_PROCESS;
    %end;
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
    %let _cst_rcmsg=&_cstTestMsg The data set macro parameter value [&_cstDS] does not follow <libname>.<dsname> construct.;
    %let _cstMsgID=CST0202;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end;

  %********************************************************************;
  %*  Parameter _cstNewDS not in required form of <libname>.<dsname>  *;
  %********************************************************************;
  %let _cstCheckVal=%sysfunc(countc("&_cstNewDS",'.'));
  %if &_cstCheckVal=1 %then
  %do;
    %********************************************;
    %*  Check for a leading or trailing period  *;
    %********************************************;
    %let _cstTemp1=%sysfunc(indexc(%str(&_cstNewDS),%str(.)));
    %if &_cstTemp1=1 or &_cstTemp1=%klength(&_cstNewDS) %then
    %do;
      %let _cstCheckVal=0;
    %end;
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg The new data set macro parameter value [&_cstNewDS] does not follow <libname>.<dsname> construct.;
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

  %***********************************;
  %*  Verify input data sets exists  *;
  %***********************************;
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
  
  %if not %sysfunc(exist(&_cstNewDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg The data set [&_cstNewDS] specified in the _cstNewDS macro parameter does not exist.;
    %let _cstMsgID=CST0008;
    %let _cstParm1=&_cstNewDS;
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
    
  %***********************************************;
  %*  Verify data set structure matches between  *;
  %*  _CSTDS and _CSTNEWDS data sets             *;
  %***********************************************;
 
  %cstutilcomparestructure(_cstReturn=_cst_rc,_cstReturnMsg=_cst_rcmsg,_cstBaseDSName=&_cstDS,_cstCompDSName=&_cstNewDS);
 
  %if &_cst_rc >= 16 %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=&_cstTestMsg &_cst_rcmsg These were detected in the %upcase(&_cstDS) and %upcase(&_cstNewDS) data sets. Data set structure must match.;
    %let _cstMsgID=CST0201;
    %let _cstParm1=&_cst_rcmsg;
    %let _cstParm2=;
    %goto ABORT_PROCESS;
  %end; 
  
 
  %************************;
  %*  Is this TEST mode?  *;
  %************************;
  
  %if %upcase(&_cstTestMode) = Y %then
  %do;
    %let _cstSASOption=%sysfunc(getoption(dlcreatedir));
    options dlcreatedir;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom); 
    %**********************************************************************;
    %*  Create a subdirectory in the WORK folder to ensure no user files  *;
    %*  are overwritten while in Test Mode and assign to _CSTTEST.        *;
    %**********************************************************************;
    libname _csttest "%sysfunc(pathname(work))/_csttest"; 
    options &_cstSASOption;
  
    %**********************************************************;
    %*  Create work copies of the data sets being used while  *
    %*  in TEST mode. Do not work with the actual data.       *;
    %**********************************************************;
    %let _cstOutDS=_csttest%sysfunc(substr(&_cstDS,%sysfunc(kindexc(&_cstDS,'.'))));
    data &_cstOutDS;
      set &_cstDS;
    run;

    %let _cstNew2DS=_csttest%sysfunc(substr(&_cstNewDS,%sysfunc(kindexc(&_cstNewDS,'.'))));
    data &_cstNew2DS;
      set &_cstNewDS;
    run;

    %******************************************;
    %*  Reset macro parameters to work files  *;
    %******************************************;
    %let _cstDS=&_cstOutDS;
    %let _cstNewDS=&_cstNew2DS;
  %end;
  %else 
  %do;
    %let _cstOutDS=&_cstDS; 
  
    %***********************************************;
    %*  Prepare to add observation(s) to data set  *;
    %***********************************************;
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

  %*******************************************;
  %*  Add/Update observation(s) to data set  *;
  %*******************************************;
  %let _cstNumObs3=0;
  
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempTable=work._cst&_cstRandom._app;

  %if %upcase(&_cstUpdateDSType)=MERGE %then
  %do;
    %**************************************************;
    %*  Setup data set LABEL option if label exists.  *;
    %**************************************************;
    %if %klength(&_cstDSLabel) gt 0 
      %then %let _cstDSLabelStatement=label="&_cstDSLabel";
      %else %let _cstDSLabelStatement=;
    
    %************************************************************;
    %*  Setup data set sort statement if keys exists. If not    *;
    %*  sort on _ALL_ to handle data sets that are not sorted.  *;
    %************************************************************;
    %if %klength(&_cstDSkeys) ne 0 
      %then %let _cstDSSortBy=&_cstDSKeys;
      %else %let _cstDSSortBy=_ALL_; 
  
    %*********************************************************;
    %*  Change merge order based on _cstOverwriteDup value.  *;
    %*********************************************************;
    %if %upcase(&_cstOverwriteDup)=Y 
      %then %let _cstDSMerge=merge &_cstDS (in=ina) &_cstNewDS (in=inb);
      %else %let _cstDSMerge=merge &_cstNewDS (in=inb) &_cstDS (in=ina);

    %**************************************************;
    %*  Remove any duplicate records in _cstNewDS to  *;
    %*  prevent merge with multiple by variables.     *;
    %*  Check to insure with MERGE there are no dup-  *;
    %*  cate keys in the parent data set and the new  *;
    %*  data set containg the updates.                *;
    %**************************************************;
    %if &_cstDSSortBy=_ALL_ %then 
    %do;
      proc sort data=&_cstDS;
        by &_cstDSSortBy;
      run;
    %end;
    %else 
    %do;
      proc sort data=&_cstDS nodupkey dupout=work._cstCheckdup;
        by &_cstDSSortBy;
      run;
      %let _cstNumObsDup=%cstutilnobs(_cstDataSetName=work._cstCheckdup);
      %cstutil_deletedataset(_cstDataSetName=work._cstCheckdup);
      %if &_cstNumObsDup>0 %then 
      %do;
        %if %upcase(&_cstTestMode)=N %then
        %do;
          lock &_cstTransactionDS clear;
        %end;
        %let _cst_rc=1;
        %let _cst_rcmsg=&_cstTestMsg The data set [&_cstDS] is NOT UNIQUE by the specified keys [&_cstDSSortBy] an inaccurate MERGE may result. No action taken.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %goto ABORT_PROCESS;
      %end;    
    %end;  

    proc sort data=&_cstNewDS nodupkey;
      by &_cstDSSortBy;
    run;

    %let _cstAttrString=;
    %cstutilbuildattrfromds(_cstSourceDS=&_cstDS,_cstAttrVar=_cstAttrString);
  
    data &_cstOutDS (drop=ttype &_cstDSLabelStatement) &_cstTempTable;
      attrib &_cstAttrString;
      &_cstDSMerge;
      by &_cstDSSortBy;
      if ina and inb then
      do;
        ttype="UPDATE";
        output &_cstTempTable;
      end;
      if ^ina and inb then 
      do;
        ttype="ADD";
        output &_cstTempTable;
      end;
      output &_cstOutDS;
    run;

    %if &_cstDSSortBy ne _ALL_ %then 
    %do;
      proc sort data=&_cstOutDS;
        by &_cstDSSortBy;
      run;
    %end;
  %end;
  %else %if %upcase(&_cstUpdateDSType)=APPEND %then
  %do;
    %if %upcase(&_cstTestMode)=N %then %let _cstOutDS=work%sysfunc(substr(&_cstDS,%sysfunc(kindexc(&_cstDS,'.'))))tmp;
    %**************************************************;
    %*  Setup data set LABEL option if label exists.  *;
    %**************************************************;
    %if %klength(&_cstDSLabel) gt 0 
      %then %let _cstDSLabelStatement=(label="&_cstDSLabel");
      %else %let _cstDSLabelStatement=;
    
    data &_cstOutDS &_cstDSLabelStatement;
      set &_cstDS &_cstNewDS;
    run;
    
    %if %klength(&_cstDSKeys) gt 0 %then
    %do;

      proc sort data=&_cstOutDS nodupkey dupout=work._cstCheckdup;
        by &_cstDSKeys;
      run;

      %*********************************************************;
      %*  Make sure the APPEND did not result in records with  *;
      %*  duplicate key values.  If so, abort the process      *; 
      %*********************************************************;                                         
      %let _cstNumObsDup=%cstutilnobs(_cstDataSetName=work._cstCheckdup);
      %cstutil_deletedataset(_cstDataSetName=work._cstCheckdup);
      %if &_cstNumObsDup>0 %then 
      %do;
        %if %upcase(&_cstTestMode)=N %then
        %do;
          lock &_cstTransactionDS clear;
        %end;
        %let _cst_rc=1;
        %let _cst_rcmsg=&_cstTestMsg Duplicate keys [&_cstDSKeys] are being detected for data set [&_cstDS] during the APPEND operation. No action taken.;
        %let _cstMsgID=CST0202;
        %let _cstParm1=&_cst_rcmsg;
        %let _cstParm2=;
        %if %upcase(&_cstTestMode)=N %then %cstutil_deletedataset(_cstDataSetName=&_cstOutDS);
        %goto ABORT_PROCESS;
      %end;
      %if %upcase(&_cstTestMode)=N %then
      %do;
        %*********************************************;
        %*  If not test mode and keys present then:  *;
        %*  Sort and write out to _cstDS, delete     *;
        %*  temp data set, and reset _cstOutDS.      *;     
        %*********************************************;
        proc sort data=&_cstOutDS out=&_cstDS &_cstDSLabelStatement;
    by &_cstDSKeys;
  run;
        %cstutil_deletedataset(_cstDataSetName=&_cstOutDS);
        %let _cstOutDS=&_cstDS; 
      %end;
      %else
      %do;
        proc sort data=&_cstOutDS &_cstDSLabelStatement;
    by &_cstDSKeys;
  run;
      %end;
    %end;
    %else %if %upcase(&_cstTestMode)=N %then 
    %do;
      %*****************************************************;
      %*  If not test mode and no keys then:               *;
      %*  Write out to _cstDS, delete temporary data set,  *;
      %*  and reset _cstOutDs back to _cstDS               *;
      %*****************************************************;
      data &_cstDS &_cstDSLabelStatement;
        set &_cstOutDS;
      run;
      %cstutil_deletedataset(_cstDataSetName=&_cstOutDS);
      %let _cstOutDS=&_cstDS; 
    %end;
    
    data &_cstTempTable;
      set &_cstNewDS;
      ttype="ADD";
    run;
  
  %end;

  %let _cstNumObs2=%cstutilnobs(_cstDataSetName=&_cstOutDS);
  %let _cstNumObs3=%cstutilnobs(_cstDataSetName=&_cstNewDS);

  %****************************************************************************;
  %*  Check number of observations, if equal, no records were added, however  *;
  %*  records may have been overwritten if _cstOverwriteDup=Y. If not then    *;
  %*  send NOTE to log or results data set and bypass transaction log since   *; 
  %*  no changes occurred.                                                    *;
  %*  If unequal, changes occurred and transaction log is updated.            *;
  %****************************************************************************;
  %if (&_cstNumObs1 ne &_cstNumObs2) or ((&_cstNumObs1 eq &_cstNumObs2) and &_cstNumobs3 gt 0 and %upcase(&_cstOverwriteDup=Y))  %then
  %do;
    %let _cstTotalUpRec=0;
    %let _cstTotalRec=%eval(&_cstNumObs2-&_cstNumObs1);
    %let _cstTotalUpRec=%eval(&_cstNumObs3-&_cstTotalRec);
    %let _cst_rc=0;
    %let _cst_rcmsg_thismacro=&_cstTestMsg Appended &_cstTotalRec record(s) and updated &_cstTotalUpRec record(s) to data set &_cstOutDS..;
    
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
        %let _cst_rcmsg=&_cstTestMsg No template dataset found for type=&_cstParm1, subtype=&_cstParm2.;
        %goto ABORT_PROCESS;
      %end;
  
      %**********************************************;
      %*  Populate values for transaction data set  *;
      %**********************************************;
      %let _cstAttrString=;
      %cstutilbuildattrfromds(_cstSourceDS=&_cstTransCopyDS,_cstAttrVar=_cstAttrString);

      data &_cstTransCopyDS (keep=cststandard cststandardversion cstuser cstmacro cstfilepath cstmessage cstcurdtm cstdataset cstcolumn cstactiontype cstEntity);
        attrib &_cstAttrString;
        set &_cstTempTable end=last;
        attrib _cstkeys format=$200. update_cnt format=8. append_cnt format=8.;
        retain _cstkeys update_cnt append_cnt;
      
        if _n_=1 then 
        do;
          _cstkeys=symget('_cstDSKeys');
          update_cnt=0;
          append_cnt=0;
        end;

        cststandard=ktrim("&_cstStd");
        cststandardversion=ktrim("&_cstStdVer");
        cstuser=ktrim("&SYSUSERID");
        cstmacro=ktrim("&_cstSrcMacro");
        cstfilepath=ktrim(pathname(ksubstr("&_cstOutDS",1,kindexc(ktrim("&_cstOutDS"),'.')-1)));
        cstcurdtm=datetime();
        cstdataset=ktrim("&_cstOutDS");
        cstcolumn="";
        if upcase(ttype)="ADD" then append_cnt+1;
        else if upcase(ttype)="UPDATE" then update_cnt+1;
        cstactiontype=upcase(ttype);
        cstentity="RECORD";

        %if %klength(&_cstDSkeys) gt 0 %then
        %do;
          if missing(cstmessage) then
          do;
            if upcase(ttype)="ADD" then cstmessage="&_cstTestMsg Record ADDED to &_cstOutDS for Key values";
            else cstmessage="&_cstTestMsg Record UPDATED in &_cstOutDS for Key values";
          end;
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
            cstmessage="&_cstTestMsg "||kstrip(update_cnt)||" records were UPDATED and "||kstrip(append_cnt)||" records were ADDED for data set %upcase(&_cstOutDS).";
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
    %let _cst_rc=0;
    %let _cst_rcmsg_thismacro=&_cstTestMsg There were no records updated or appended from append data set [&_cstNewDS]. No action performed.;
    %let _cst_rcmsg=&_cst_rcmsg_thismacro;
    %if %upcase(&_cstTestMode)=N %then
    %do;
      lock &_cstTransactionDS clear;
    %end;
  %end;

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
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] NOTE: &_cstTestMsg &_cst_rcmsg_thismacro;
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
  %else %put [CSTLOG%str(MESSAGE).&_cstSrcMacro] ERR%STR(OR): &_cstTestMsg &_cst_RCmsg;
  %goto EXIT_MACRO;

  %EXIT_MACRO:

  %if %klength(&_cstTempTable)>0 and %sysfunc(exist(&_cstTempTable)) %then %cstutil_deletedataset(_cstDataSetName=&_cstTempTable);
 
%mend cstutilappendmetadatarecords;