%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_createdsfromtemplate                                                       *;
%*                                                                                *;
%* Creates a zero-observation data set that is based on a template.               *;
%*                                                                                *;
%* The template is provided by a registered standard.                             *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param  _cstStandard - required - The name of a registered standard.           *;
%* @param  _cstStandardVersion - optional - The version of the standard that the  *;
%*             data set is created from. If this is omitted, the default          *;
%*             version for the standard is used. If a default version is not      *;
%*             defined, an error is generated.                                    *;
%* @param  _cstType - required - The type of data set to create. This value comes *;
%*             from the TYPE column in the SASReferences file for the standard-   *;
%*             version combination.                                               *;
%* @param  _cstSubType - optional - The subtype for the type. This value comes    *;
%*             from the SUBTYPE column in the SASReferences file for the          *;
%*             standard-version combination. If the type has no subtypes, the     *;
%*             value can be omitted. Otherwise, it must be specified.             *;
%* @param  _cstOutputDS - required - The name of the data set to create.          *;
%* @param  _cstOutputDSLabel - optional - The label of the data set to create.    *;
%* @param  _cstResultsOverrideDS - optional - The (libname.)member that refers to *;
%*             the Results data set to create. If omitted, the Results data set   *;
%*             that is specified by &_cstResultsDS is used.                       *;
%*                                                                                *;
%* @history 2013-07-30 Added look-through capability. If a template is not found  *;
%*             for any non-Framework standard, the cross-standard Framework       *;
%*             template library is also searched.                                 *;
%*                                                                                *;
%* @since  1.5                                                                    *;
%* @exposure external                                                             *;

%macro cst_createdsfromtemplate(
    _cstStandard=,
    _cstStandardVersion=,
    _cstType=,
    _cstSubType=,
    _cstOutputDS=,
    _cstOutputDSLabel=,
    _cstResultsOverrideDS=
    ) / des='CST: Create data set from template';

  %cstutil_setcstgroot;

  %* declare local variables used in the macro;
  %local
    _cstActual
    _cstError
    _cstGlobalMDPath
    _cstGlobalStdDS
    _cstGlobalStdLookupDS
    _cstGlobalStdSASRefsDS
    _cstGlobalMDLib
    _cstMsgDir
    _cstMsgMem
    _cstNeedToDeleteMsgs
    _cstParamInError
    _cstParm1
    _cstParm2
    _cstRandom
    _cstSaveResultSeq
    _cstSaveSeqCnt
    _cstStdLookupDS
    _cstStdLookupLib
    _cstStdLookupPath
    _cstTempDS1
    _cstTemplateLibrary
    _cstTemplatePath
    _cstTempLib
    _cstThisMacroRC
    _cstThisResultsDS
    _cstThisResultsDSLib
    _cstThisResultsDSMem
    _cstTmpltDS
    _cstUsingResultsOverride
    _cstDSLabel
    ;

  %if ^%symexist(_cst_rc) %then 
  %do;
    %global _cst_rc _cst_rcmsg;
  %end;

  %let _cstThisMacroRC=0;

  %* retrieve static variables;
  %cst_getStatic(_cstName=CST_GLOBALMD_PATH,_cstVar=_cstGlobalMDPath);
  %cst_getStatic(_cstName=CST_GLOBALMD_REGSTANDARD,_cstVar=_cstGlobalStdDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_SASREFS,_cstVar=_cstGlobalStdSASRefsDS);
  %cst_getStatic(_cstName=CST_GLOBALMD_LOOKUP,_cstVar=_cstGlobalStdLookupDS);

  %* Generate the random names used in the macro;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstGlobalMDLib=_cst&_cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  %* Create a temporary messages data set if required;
  %cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

  %* Set up the location of the results data set to write to;
  %cstutil_internalManageResults(_cstAction=SAVE);
  %let _cstResultSeq=1;
  %let _cstSeqCnt=0;

  * Assign the libname to the global metadata library;
  libname &_cstGlobalMDLib "%unquote(&_cstGlobalMDPath)" access=readonly;

  %* Pre-requisite: _cstStandard is not blank;
  %if (%length(&_cstStandard)=0) %then %do;
    %* process an error;
    %let _cstParamInError=_cstStandard;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstType is not blank;
  %if (%length(&_cstType)=0) %then %do;
    %let _cstParamInError=_cstType;
    %goto NULL_PARAMETER;
  %end;

  %* Pre-requisite: _cstOutputDS is not blank;
  %if (%length(&_cstOutputDS)=0) %then %do;
    %let _cstParamInError=_cstOutputDS;
    %goto NULL_PARAMETER;
  %end;

  * Pre-requisite: Check that the standard is valid;
  %let _cstError=Y;
  data &_cstTempDS1;
    set &_cstGlobalMDLib..&_cstGlobalStdDS
      (where=(upcase(standard)=%sysfunc(upcase("&_cstStandard"))));
    if (_n_=1) then call symputx('_cstError','N','L');
  run;

  %if (&_cstError=Y) %then %do;
    %goto INVALID_STD;
  %end;

  * Pre-requisite: Check that the version is valid (if provided) or a default exists if not;
  %if (%length(&_cstStandardVersion)>0) %then %do;
    %let _cstError=Y;
    * Check that the version is valid;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion"))));
      if (_n_=1) then call symputx('_cstError','N','L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %goto INVALID_VERSION;
    %end;
  %end;
  %else %do;
    %let _cstError=Y;
    * Check that there is a default version specified and retrieve it;
    data &_cstTempDS1;
      set &_cstTempDS1
        (where=(isstandarddefault="Y"));
      if (_n_=1) then call symputx('_cstError','N','L');
      call symputx('_cstStandardVersion',standardVersion,'L');
    run;

    %* process an error;
    %if (&_cstError=Y) %then %do;
      %let _cstParm1=&_cstStandardVersion;
      %let _cstParm2=&_cstStandard;
      %goto NO_DEFAULT_VERSION;
    %end;
  %end;

  %***************************************************************;
  %* Start of core code having confirmed valid parameter values  *;
  %***************************************************************;

  %* General flow:  See if standard-specific standardlookup has a template defined for the specified type
      (and subtype, if provided as a parameter).  If not, report this and exit. If yes:  Does the
      template data set exist using the template value?  If not, report this and exit. *;

  %let _cst_rcmsg=;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempLib=_cst&_cstRandom;

  %* Point to the standard-specific lookup data set *;
  data _null_;
     set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDS (where=(
            upcase(standard)=%sysfunc(upcase("&_cstStandard")) and upcase(standardversion)=%sysfunc(upcase("&_cstStandardVersion")) and
            upcase(type)='LOOKUP'));
       call symputx('_cstStdLookupPath',path);
       call symputx('_cstStdLookupLib',"&_cstTempLib");
       call symputx('_cstStdLookupDS',strip(scan(memname,1,'.')));
  run;

  %let _cstActual=%str(type=&_cstType,subtype=&_cstSubType);

  %if (%length(&_cstStdLookupLib)>0) %then %do;
    libname &_cstStdLookupLib "&_cstStdLookupPath";

    %if %sysfunc(exist(&_cstStdLookupLib..&_cstGlobalStdLookupDS)) %then
    %do;
      data _null_;
        * Only interested in records with templates *;
        set &_cstStdLookupLib..&_cstGlobalStdLookupDS (where=(template ne ''));

          %if (%length(&_cstSubType)>0) %then %do;
            if upcase(column)='SUBTYPE' and upcase(refcolumn)='TYPE' and
               upcase(refvalue)=%sysfunc(upcase("&_cstType")) and
               upcase(value)=%sysfunc(upcase("&_cstSubType")) then
            do;
              if upcase(templatetype)='DATASET' then
                call symputx('_cstTmpltDS',template);
            end;
          %end;
          %else %do;
            if upcase(column)='TYPE' and
               upcase(value)=%sysfunc(upcase("&_cstType")) then
            do;
              if upcase(templatetype)='DATASET' then
                call symputx('_cstTmpltDS',template);
            end;
          %end;
      run;
      %if (%length(&_cstTmpltDS)>0) %then %do;
        %if %sysfunc(exist(&_cstTmpltDS)) %then
        %do;
          %* Everything is okay;
          %let _cstTemplateLibrary=%scan(&_cstTmpltDS,1,.);
        %end;
        %else
        %do;

          %*****************************************************************************;
          %* A template data set was found but we cannot get to it.  This most likely  *;
          %*  results from an unallocated libref.  To check this, we will use the      *;
          %*  rootpath + templateSubFolder columns of the standards data set to        *;
          %*  create a libref pointer to the default location for standard-specific    *;
          %*  templates. This action is noted in the results data set.  If this        *;
          %*  behavior is not desired, be certain librefs are allocated prior to the   *;
          %*  call to this method.                                                     *;
          %* Set _cst_rcmsg for any problem identified.                                *;
          %*****************************************************************************;

          %let _cst_rcmsg=%str(- specified associated template data set does not exist);
          %let _cstTemplateLibrary=%scan(&_cstTmpltDS,1,.);
          data _null_;
             set &_cstTempDS1;

               if templateSubFolder ne '' then
               do;
                 if indexc(templateSubFolder,'/\') then
                   call symputx('_cstTemplatePath',cats(rootpath,templateSubFolder));
                 else
                   call symputx('_cstTemplatePath',catx('/',rootpath,templateSubFolder));
               end;
               else
                   call symputx('_cst_rcmsg','- specified associated template data set does not exist and no default templateSubFolder exists');
          run;

          %if (%klength(&_cstTemplatePath)>0) %then %do;
            libname &_cstTemplateLibrary "&_cstTemplatePath";

            %if %sysfunc(exist(&_cstTmpltDS)) %then
            %do;
              %* Everything is okay;
              %let _cst_rcmsg=;
              %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
              %cstutil_writeresult(
                          _cstResultId=CST0200
                          ,_cstResultParm1=%str(The SAS libref &_cstTemplateLibrary was allocated to &_cstTemplatePath to perform the template lookup)
                          ,_cstResultSeqParm=&_cstResultSeq
                          ,_cstSeqNoParm=&_cstSeqCnt
                          ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                          ,_cstResultFlagParm=0
                          ,_cstRCParm=0
                          ,_cstResultsDSParm=&_cstThisResultsDS
                          );
            %end;
          %end;
        %end;
      %end;
      %else %let _cst_rcmsg=%str(- an associated template data set could not be found);
    %end;
    %else %let _cst_rcmsg=%str(- specified standard-level standardlookup data set does not exist);

    libname &_cstStdLookupLib;

  %end;
  %else %let _cst_rcmsg=%str(- standard-level standardlookup data set could not be found);

  %* A template was not found above, so lets look in the cross-standard Framework template library. *;

  %if (%length(&_cst_rcmsg)>0) %then %do;

    %if %sysfunc(upcase("&_cstStandard")) ^= "CST-FRAMEWORK" %then
    %do;

      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstTempLib=_cst&_cstRandom;

      %* Point to the standard-specific lookup data set *;
      data _null_;
        set &_cstGlobalMDLib..&_cstGlobalStdSASRefsDS (where=(
                standard="CST-FRAMEWORK" and upcase(type)='LOOKUP'));
          call symputx('_cstStdLookupPath',path);
          call symputx('_cstStdLookupLib',"&_cstTempLib");
          call symputx('_cstStdLookupDS',strip(scan(memname,1,'.')));
      run;

      libname &_cstStdLookupLib "&_cstStdLookupPath";

      data _null_;
        * Only interested in records with templates *;
        set &_cstStdLookupLib..&_cstGlobalStdLookupDS (where=(standard="CST-FRAMEWORK" and template ne ''));

          %if (%length(&_cstSubType)>0) %then %do;
            if upcase(column)='SUBTYPE' and upcase(refcolumn)='TYPE' and
               upcase(refvalue)=%sysfunc(upcase("&_cstType")) and
               upcase(value)=%sysfunc(upcase("&_cstSubType")) then
            do;
              if upcase(templatetype)='DATASET' then
                call symputx('_cstTmpltDS',template);
            end;
          %end;
          %else %do;
            if upcase(column)='TYPE' and
               upcase(value)=%sysfunc(upcase("&_cstType")) then
            do;
              if upcase(templatetype)='DATASET' then
                call symputx('_cstTmpltDS',template);
            end;
          %end;
      run;

      %* Reset librefs and data sets so we can do a CST-FRAMEWORK look-up *;
      %if (%length(&_cstTemplateLibrary)>0) %then %do;
        libname &_cstTemplateLibrary;
      %end;
      %let _cstError=Y;
      data &_cstTempDS1;
        set &_cstGlobalMDLib..&_cstGlobalStdDS (where=(upcase(standard)='CST-FRAMEWORK'));
          if (_n_=1) then call symputx('_cstError','N','L');
      run;

      %if (%length(&_cstTmpltDS)>0) %then %do;
        %if %sysfunc(exist(&_cstTmpltDS)) %then
        %do;
          %* Everything is okay;
          %let _cst_rcmsg=;
          %let _cstTemplateLibrary=%scan(&_cstTmpltDS,1,.);
        %end;
        %else
        %do;

          %*****************************************************************************;
          %* A template data set was found but we cannot get to it.  This most likely  *;
          %*  results from an unallocated libref.  To check this, we will use the      *;
          %*  rootpath + templateSubFolder columns of the standards data set to        *;
          %*  create a libref pointer to the default location for standard-specific    *;
          %*  templates. This action is noted in the results data set.  If this        *;
          %*  behavior is not desired, be certain librefs are allocated prior to the   *;
          %*  call to this method.                                                     *;
          %* Set _cst_rcmsg for any problem identified.                                *;
          %*****************************************************************************;

          %let _cst_rcmsg=%str(- specified associated template data set does not exist);
          %let _cstTemplateLibrary=%scan(&_cstTmpltDS,1,.);
          data _null_;
             set &_cstTempDS1;

               if templateSubFolder ne '' then
               do;
                 if indexc(templateSubFolder,'/\') then
                   call symputx('_cstTemplatePath',cats(rootpath,templateSubFolder));
                 else
                   call symputx('_cstTemplatePath',catx('/',rootpath,templateSubFolder));
               end;
               else
                   call symputx('_cst_rcmsg','- specified associated template data set does not exist and no default templateSubFolder exists');
          run;

          %if (%klength(&_cstTemplatePath)>0) %then %do;
            libname &_cstTemplateLibrary "&_cstTemplatePath";

            %if %sysfunc(exist(&_cstTmpltDS)) %then
            %do;
              %* Everything is okay;
              %let _cst_rcmsg=;
              %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
              %cstutil_writeresult(
                          _cstResultId=CST0200
                          ,_cstResultParm1=%str(The SAS libref &_cstTemplateLibrary was allocated to &_cstTemplatePath to perform the template lookup)
                          ,_cstResultSeqParm=&_cstResultSeq
                          ,_cstSeqNoParm=&_cstSeqCnt
                          ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                          ,_cstResultFlagParm=0
                          ,_cstRCParm=0
                          ,_cstResultsDSParm=&_cstThisResultsDS
                          );
            %end;
          %end;
        %end;
      %end;
      %else %let _cst_rcmsg=%str(- an associated template data set could not be found);

      libname &_cstStdLookupLib;

    %end;
  %end;


  %if (%length(&_cst_rcmsg)>0) %then %do;
    %* Report that data set could not be created  *;
    %goto TMPLT_CREATE_FAILED;
  %end;

  %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=&_cstTmpltDS,_cstAttribute=LABEL);

  proc sql noprint;
    create table &_cstOutputDS %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)"); like &_cstTmpltDS;
  quit;

  %if (&sqlrc gt 0) %then
  %do;
    %let _cst_rcmsg=%str(- proc sql step failed, see SAS log);
    %goto TMPLT_CREATE_FAILED;
  %end;

  libname &_cstTemplateLibrary;

  %* Report success. *;

  %let _cstThisMacroRC=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutputDS (%nrbquote(&_cstDSLabel))
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%NULL_PARAMETER:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0081
                ,_cstResultParm1=&_cstParamInError
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );
  %goto CLEANUP;

%INVALID_STD:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0082
                ,_cstResultParm1=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%INVALID_VERSION:
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstStandardVersion
                ,_cstResultParm2=&_cstStandard
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%NO_DEFAULT_VERSION:
  %* ERROR: No version was supplied and there is no default for &_cstStandard.;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0083
                ,_cstResultParm1=&_cstParm1
                ,_cstResultParm2=&_cstParm2
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%TMPLT_CREATE_FAILED:
  %* ERROR: No data set memname is available for the specified type/subtype;
  %let _cstThisMacroRC=1;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(
                _cstResultId=CST0113
                ,_cstResultParm1=&_cst_rcMsg
                ,_cstResultParm2=
                ,_cstResultSeqParm=&_cstResultSeq
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=CST_CREATEDSFROMTEMPLATE
                ,_cstResultFlagParm=&_cstThisMacroRC
                ,_cstRCParm=&_cstThisMacroRC
                ,_cstActualParm=%str(&_cstActual)
                ,_cstResultsDSParm=&_cstThisResultsDS
                );

  %goto CLEANUP;

%CLEANUP:
  %* reset the resultSequence/SeqCnt variables;
  %cstutil_internalManageResults(_cstAction=RESTORE);

  * Clear the libname;
  libname &_cstGlobalMDLib;

  * Clean up temporary data sets if they exist;
  proc datasets nolist lib=work;
    delete &_cstTempDS1  / mt=data;
    quit;
  run;

  %* Delete the temporary messages data set if it was created here;
  %if (&_cstNeedToDeleteMsgs=1) %then %do;
    %if %eval(%index(&_cstMessages,.)>0) %then %do;
      %let _cstMsgDir=%scan(&_cstMessages,1,.);
      %let _cstMsgMem=%scan(&_cstMessages,2,.);
    %end;
    %else %do;
      %let _cstMsgDir=work;
      %let _cstMsgMem=&_cstMessages;
    %end;
    proc datasets nolist lib=&_cstMsgDir;
      delete &_cstMsgMem / mt=data;
      quit;
    run;
  %end;

  %let _cst_rc=&_cstThisMacroRC;

%mend cst_createdsfromtemplate;
