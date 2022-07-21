%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutildropmissingvars                                                         *;
%*                                                                                *;
%* Drops variables from a data set that have only missing values.                 *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param _cstDataSetName - required - The (libname.)memname of the data set.     *;
%* @param _cstDataSetOutName - required - The (libname.)memname of the output     *;
%*            data set.                                                           *;
%* @param _cstNoDrop - optional - The list of the variables that will not be      *;
%*            dropped, even if they have only missing values.                     *;
%*            This list can contain a number of blank-separated variables or any  *;
%*            valid variable shortcut like _Numeric_, _character_, c:, var1-var3, *;
%*            varx -- varz.                                                       *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

 %macro cstutildropmissingvars(
    _cstDataSetName=,
    _cstDataSetOutName=,
    _cstNoDrop=
    ) / des='CST: Drop missing variables from dataset';

     %local _cstRandom dsid rc _cstLabel i namenum namechar countnum countchar nvars;

    %*****************************************;
    %*  Set error code and message variable  *;
    %*****************************************;
    %let _cst_rc=0;
    %let _cst_rcmsg=;

    %*************************************************;
    %* Does the macro have the parameters it needs?  *;
    %*************************************************;
    %if %quote(&_cstDataSetName)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstDataSetName parameter is required;
      %goto exit_macro;
    %end;

    %if %quote(&_cstDataSetOutName)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstDataSetOutName parameter is required;
      %goto exit_macro;
    %end;

    %*************************************************;
    %* Get data set label for later use              *;
    %*************************************************;
     %let dsid=%sysfunc(open(&_cstDataSetName,i));
     %let _cstLabel=%nrbquote(%sysfunc(attrc(&dsid,label)));
     %let rc=%sysfunc(close(&dsid));
     %if %length(&_cstLabel)>0 %then %let _cstLabel= %str(label="&_cstLabel");

     %cstutil_getRandomNumber(_cstVarname=_cstRandom);
     proc contents
        data = &_cstDataSetName (drop=&_cstNoDrop)
        out = ds&_cstRandom memtype=data noprint;
     run;
     proc sql noprint;
       select  count(*) into :countnum from ds&_cstRandom where type=1;
       select  name into :namenum separated by ' ' from ds&_cstRandom where type=1;
       select  count(*) into :countchar from ds&_cstRandom where type=2;
       select  name into :namechar separated by ' ' from ds&_cstRandom where type=2;
       drop table  ds&_cstRandom;
     quit;

     %let nvars=%eval(&countnum + &countchar);
     data _null_;
       if _n_ = 1 then call execute(
         "data &_cstDataSetOutName(%nrbquote(&_cstLabel));set &_cstDataSetName;");
       if __eof then call execute('run;' );
       set &_cstDataSetName end=__eof;
       %if ( &nvars > 0) %then %do;
         %if &countnum > 0  %then array ___n{*} &namenum;;
         %if &countchar > 0 %then array ___c{*} &namechar;;
         array ___fill{&nvars} _temporary_;
         do __i=1 to &nvars;
           %if &countnum > 0 %then %do;
             if __i<=&countnum then do;
               if ___n{__i}^=. then ___fill{__i}=1;
             end;
           %end;
           %if &countchar > 0 %then %do;
             if __i>&countnum then do;
               if ___c{__i-&countnum} ^= ' ' then ___fill{__i}=1;
             end;
           %end;
         end;
         if __eof then do __i=1 to &nvars;
           if ___fill{__i}^=1 then do;
             %if &countnum > 0 %then %do;
               if __i<=&countnum then do;
                 call execute('if _n_=1 then put "[CSTLOG" '||'"MESSAGE[" '||'"&sysmacroname]: '||
                              vname(___n{__i})||' is all missing and will be dropped."'||';');
                 call execute('drop '||vname(___n{__i})||';');
               end;
             %end;
             %if &countchar > 0 %then %do;
               if __i>&countnum then do;
                 call execute('if _n_=1 then put "[CSTLOG" '||'"MESSAGE[" '||'"&sysmacroname]: '||
                              vname(___c{__i-&countnum})||' is all missing and will be dropped."'||';');
                 call execute('drop '||vname(___c{__i-&countnum})||';');
               end;
             %end;
           end;
         end;
       %end;
     run;

  %exit_macro:

  %if &_cst_rc=1 %then %put [CSTLOG%str(MESSAGE).&sysmacroname] &_cst_rcmsg;

%mend cstutildropmissingvars;
