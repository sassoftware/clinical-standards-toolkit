%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutilcheckfolder                                                        *;
%*                                                                                *;
%* Determines whether a folder exists as defined by columns in a source data set. *;
%*                                                                                *;
%* If the folder specified in _cstSourceC1 does not exist, this macro creates     *;
%* work._cstproblems.                                                             *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (for      *;
%*       example, a full DATA step or PROC SQL invocation) and is used within     *;
%*       the cstcheck_columncompare macro.                                        *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstSourceDS  - required - The source data set to evaluate by the       *;
%*            validation check glmeta.standards data set.                         *;
%*            Default: &_cstDSName                                                *;
%* @param _cstSourceC1  - required - The _cstColumn1 macro variable value that    *;
%*            represents the ROOTPATH column from the glmeta.standards data set.  *;
%*            Default: &_cstColumn1                                               *;
%* @param _cstSourceC2  - required - The _cstColumn2 macro variable value that    *;
%*            represents the STANDARDS column for reporting purposes only.        *;
%*            Default: &_cstColumn2                                               *;
%* @param _cstWhereStatement - optional - A SAS WHERE statement to subset         *;
%*            _cstSourceDS. For example, WHERE standard="CDISC-ADAM".             *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutilcheckfolder(
    _cstSourceDS=&_cstDSName,
    _cstSourceC1=&_cstColumn1,
    _cstSourceC2=&_cstColumn2,
    _cstWhereStatement=
    ) / des='CST: Creates work._cstproblems if folder does not exist';

  %local _cstNumObs _cstObsNum _cstPath _cstFullPath;

  %let _cstNumObs=%cstutilnobs(_cstDataSetName=&_cstSourceDS);
  %let _cst_rc=0;

  data work._cstProblems;
    set &_cstSourceDS;
    stop;
  run;

  %do _cstObsNum= 1 %to &_cstNumObs;
    %let _cstPath=;
    data _null_;
      set &_cstSourceDS(firstObs=&_cstObsNum obs=&_cstObsNum);
      %if %length(&_cstWhereStatement)>0 %then
      %do;
        &_cstWhereStatement;
      %end;
      call symputx('_cstPath', &_cstSourceC1);
    run;
    %let _cstFullPath=&_cstPath;
    %if %length(&_cstPath) gt 0 %then
    %do;
      %cstutilfindvalidfile(_cstfiletype=FOLDER,_cstfilepath=&_cstFullPath);
      %if %eval(&_cst_rc) eq 1 %then
      %do;
        data work.cc&_cstObsNum;
          set &_cstSourceDS(firstObs=&_cstObsNum obs=&_cstObsNum);
          length _cstMsgParm1 $200;
          _cstMsgParm1=symget("_cstFullPath");
        run;
        data work._cstProblems;
          set work._cstProblems work.cc&_cstObsNum;
        run;
        proc datasets library=work memtype=data nolist;
          delete cc&_cstObsNum;
        quit;
        %let _cst_rc=0;
      %end;
    %end;
  %end;
%mend cstcheckutilcheckfolder;
