%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilbuildattrfromds                                                         *;
%*                                                                                *;
%* Builds a DATA step ATTRIB statement based on columns in the input data set.    *;
%*                                                                                *;
%* This macro builds ATTRIB statement content based on the columns identified in  *;
%* the data set referenced in _cstSourceDS.                                       *;
%*                                                                                *;
%* Example:  var1 length=$8 label="Variable 1" format=$8.                         *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code. If 1, error exists.              *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstSourceDS - required - The source data set <libref.dset>.            *;
%* @param _cstAttrVar - required - The macro variable to contain the ATTRIB       *;
%*            content.                                                            *;
%*                                                                                *;
%* @since 1.6                                                                     *;
%* @exposure external                                                             *;

%macro cstutilbuildattrfromds(
    _cstSourceDS=,
    _cstAttrVar=
    ) / des='CST: Build ATTRIB statement content';

  %local
    _cstCheckVal
    _cstTemp1
  ;

  %let _cst_rc=0;
  %let _cst_rcmsg=;
  
  %************************************************;
  %*  One or more missing parameter values for    *;
  %*  _cstSourceDS or _cstAttrVar                 *;
  %************************************************;
  %if (%klength(&_cstSourceDS)=0) or (%klength(&_cstAttrVar)=0) %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=One or more of the following parameters is missing _cstSourceDS or _cstAttrVar.;
    %goto EXIT_MACRO;
  %end;
  
  %*****************************************************************;
  %*  Parameter _cstSourceDS not in required form of <libname>.<dsname>  *;
  %*****************************************************************;
  %let _cstCheckVal=%sysfunc(countc("&_cstSourceDS",'.'));
  %if &_cstCheckVal=1 %then
  %do;
    %********************************************;
    %*  Check for a leading or trailing period  *;
    %********************************************;
    %let _cstTemp1=%sysfunc(kindexc(%str(&_cstSourceDS),%str(.)));
    %if &_cstTemp1=1 or &_cstTemp1=%klength(&_cstSourceDS) %then
    %do;
      %let _cstCheckVal=0;
    %end;
  %end;
  %else %if &_cstCheckVal=0 %then
  %do;
  %* Single level data set assumed to be in WORK *;
    %let _cstSourceDS=work.&_cstSourceDS;
    %let _cstCheckVal=1;
  %end;
  %if %eval(&_cstCheckVal) ne 1 %then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstSourceDS] macro parameter does not follow <libname>.<dsname> construct.;
    %goto EXIT_MACRO;
  %end;

  %if not %sysfunc(exist(&_cstSourceDS))%then 
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The data set [&_cstSourceDS] specified in the _cstSourceDS macro parameter does not exist.;
    %goto EXIT_MACRO;
  %end;

  %if (%symexist(&_cstAttrVar)=0) %then %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=The macro variable [&_cstAttrVar] specified in the _cstAttrVar macro parameter does not exist.;
    %goto EXIT_MACRO;
  %end;

  %*******************************;
  %*  Start column processing    *;
  %*******************************;

  proc contents data=&_cstSourceDS out=work._cstContents 
         (keep=name type length varnum label format formatl formatd) noprint;
  run;
  proc sort data=work._cstContents;
    by varnum;
  run;
  data _null_;
    set work._cstContents end=last;
      attrib singlevar format=$500. attrstmt format=$32767.;
      retain attrstmt;
    select(type);
      when(1) do;
        if indexc(label,'&')>1 
          then singlevar=catx(' ',name,cats('length=',length),cats("label='",label,"'"));
          else singlevar=catx(' ',name,cats('length=',length),cats('label="',label,'"')); 
        if missing(format) and formatl=0 then;
        else do;
          if formatl>0 then do;
            if formatd>0 then do;
              singlevar=catx(' ',singlevar,cats('format=',format,formatl,'.',formatd));
            end;
            else singlevar=catx(' ',singlevar,cats('format=',format,formatl,'.'));
          end;
          else
            singlevar=catx(' ',singlevar,cats('format=',length,'.'));
        end;
      end;
      otherwise do;
        if indexc(label,'&')>1 
          then singlevar=catx(' ',name,cats('length=$',length),cats("label='",label,"'"));
          else singlevar=catx(' ',name,cats('length=$',length),cats('label="',label,'"')); 
        if missing(format) and formatl=0 then;
        else do;
          if formatl>0 then do;
            singlevar=catx(' ',singlevar,cats('format=',format,formatl,'.'));
          end;
          else
            singlevar=catx(' ',singlevar,cats('format=$',length,'.'));
        end;
      end;
    end;
    attrstmt=catx(' ',attrstmt,singlevar);
    if (last) then
      call symputx("&_cstAttrVar",attrstmt);
  run;  

  %cstutil_deleteDataSet(_cstDataSetName=work._cstContents);

  %EXIT_MACRO:

%mend cstutilbuildattrfromds;

