%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutilcheckfile                                                          *;
%*                                                                                *;
%* Determines whether a file exists as defined by columns in a source data set.   *;
%*                                                                                *;
%* The file is specified by _cstSourceFileRef and the directory is specified by   *;
%* _cstSourceDir. The determination is based on the type of standard as defined   *;
%* by ISDATASTANDARD, ISXMLSTANDARD, ISCSTFRAMEWORK, or SUPPORTSVALIDATION.       *;
%*                                                                                *;
%* _cstSourceDir is appended to the ROOTPATH value from the glmeta.standards data *;
%* set. If the file does not exist, this macro creates work._cstproblems.         *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (for      *;
%*       example, a full DATA step or PROC SQL invocation) and is used within     *;
%*       the cstcheck_columncompare macro.                                        *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstSourceDS - required - The source data set to evaluate by the        *;
%*            validation check.                                                   *;
%*            Default: &_cstDSName                                                *;
%* @param _cstSourceC1  - required - _cstColumn1 macro variable value that        *;
%*            represents the ROOTPATH column from the glmeta.standards data set.  *;
%*            Default: &_cstColumn1                                               *;
%* @param _cstSourceC2 - required - The _cstColumn2 macro variable value that     *;
%*            represents the ISDATASTANDARD, ISXMLSTANDARD, ISCSTFRAMEWORK, or    *;
%*            SUPPORTSVALIDATION column from the glmeta.standards data set.       *;
%*            Default: &_cstColumn2                                               *;
%* @param _cstSourceDir  - optional -  The directory path that is appended to     *;
%*            ROOTPATH.                                                           *;
%* @param _cstSourceFileRef - required - The file to look up. For example,        *;
%*            standardlookup.sas7bdat.                                            *;
%* @param _cstWhereStatement - optional - A SAS WHERE statement to subset         *;
%*            _cstSourceDS. For example, WHERE standard="CDISC-ADAM".             *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutilcheckfile(
    _cstSourceDS=&_cstDSName,
    _cstSourceC1=&_cstColumn1,
    _cstSourceC2=&_cstColumn2,
    _cstSourceDir=,
    _cstSourceFileRef=,
    _cstWhereStatement=
    ) / des='CST: Creates work._cstproblems if file does not exist';

  %local _cstNumObs _cstObsNum _cstPath;

  %*************************************************;
  %*  Handle optional WHERE statement to retrieve  *; 
  %*  correct number of observations.              *;
  %*************************************************;
  data work._cstSourceDS;
    set &_cstSourceDS;
    %if %length(&_cstWhereStatement)>0 %then
    %do;
      &_cstWhereStatement;
    %end;
  run;

  %let _cstNumObs=%cstutilnobs(_cstDataSetName=work._cstSourceDS);
  %if &_cstNumObs=0 %then %goto exit_macro;

  data work._cstProblems;
    set work._cstSourceDS;
    stop;
  run;

  %let _cst_rc=0;

  %do _cstObsNum= 1 %to &_cstNumObs;
    %let _cstPath=;
    data _null_;
      set work._cstSourceDS(firstObs=&_cstObsNum obs=&_cstObsNum);
      if upcase(&_cstSourceC2) eq 'Y' then call symputx('_cstPath', &_cstSourceC1);
    run;

    %if %length(&_cstPath) gt 0 %then
    %do;
      %let _cstPath=&_cstPath.&_cstSourceDir;
      %cstutilfindvalidfile(_cstfiletype=FILE,_cstfilepath=&_cstPath,_cstfileref=&_cstSourceFileRef);
      %if %eval(&_cst_rc) eq 1 %then
      %do;
        data work._cstProblems;
          set work._cstProblems work._cstSourceDS(firstObs=&_cstObsNum obs=&_cstObsNum);
        run;
        %let _cst_rc=0;
      %end;
    %end;
  %end;
  %EXIT_MACRO:
  %cstutil_deleteDataSet(_cstDataSetName=work._cstSourceDS); 
%mend cstcheckutilcheckfile;
