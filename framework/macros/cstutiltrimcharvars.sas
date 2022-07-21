%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutiltrimcharvars                                                            *;
%*                                                                                *;
%* Trims character variables to their minimum lengths.                            *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param _cstDataSetName - required - The (libname.)memname of the data set.     *;
%* @param _cstDataSetOutName - required - The (libname.)memname of the output     *;
%*            data set.                                                           *;
%* @param _cstNoTrim - optional - The list of blank-delimited variables not to    *;
%*            trim.                                                               *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstutiltrimcharvars(
    _cstDataSetName=,
    _cstDataSetOutName=,
    _cstNoTrim=
    ) / des="CST: Trim character variables";

     %local dsid rc i _cstLabel _cstNobs _cstNvars
            _cstVar _cstLen _cstAllVars _cstType _cstSaveOptions
            ;

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
    %if %klength(&_cstLabel)>0 %then %let _cstLabel= %str(label="&_cstLabel");

    %let _cstNvars=%sysfunc(attrn(&dsid,nvars));
    %let _cstNobs=%sysfunc(attrn(&dsid,nobs));

    %if &_cstNobs>0 %then %do;

        %let _cstAllVars=;

        proc sql noprint;
        %do i=1 %to &_cstNvars;
          %let _cstVar=%sysfunc(varname(&dsid,&i));
          %let _cstType=%sysfunc(vartype(&dsid,&i));
          %let _cstLen=%sysfunc(varlen(&dsid,&i));
          %let _cstLenOrig = &_cstLen;

          %if &_cstType=C %then %do;
            %if (%kindex(" %kupcase(&_cstNoTrim) ", %str( %kupcase(%ktrim(&_cstVar)) )) = 0) %then %do;
              select max(klength(&_cstVar)) into :_cstLen from &_cstDataSetName(keep=&_cstVar);
              %if &_cstLen=0 %then %do;
                %let _cstLen=1;
                %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname]: &_cstVar all missing and will be trimmed to $&_cstLen;
              %end;
              %let _cstLen=&_cstLen;
            %end;
            %else %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname]: &_cstVar not trimmed;
          %end;

          %if &_cstType=C %then %do;
            %if &_cstLenOrig ne &_cstLen %then
              %if &_cstDebug %then %put [CSTLOG%str(MESSAGE).&sysmacroname]: &_cstVar will be trimmed from $&_cstLenOrig to $&_cstLen;
            %let _cstLen=$&_cstLen;
          %end;
          %let _cstAllVars=&_cstAllVars &_cstVar &_cstLen;
        %end;
        quit;

        %let rc=%sysfunc(close(&dsid));

        %let _cstSaveOptions = %sysfunc(getoption(varlenchk, keyword));
        options varlenchk=nowarn;

        data &_cstDataSetOutName(%nrbquote(&_cstLabel));
          length &_cstAllVars;
          set &_cstDataSetName;
          informat _character_ _numeric_;
          format _character_ _numeric_;
        run;

        options &_cstSaveOptions;

    %end;
    %else %do;

        data &_cstDataSetOutName(%nrbquote(&_cstLabel));
          set &_cstDataSetName;
        run;

    %end;

  %exit_macro:

  %if &_cst_rc=1 %then %put [CSTLOG%str(MESSAGE).&sysmacroname] &_cst_rcmsg;

%mend cstutiltrimcharvars;
