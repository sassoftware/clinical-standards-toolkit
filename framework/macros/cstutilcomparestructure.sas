%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcomparestructure                                                        *;
%*                                                                                *;
%* Compares the metadata structure of two data sets.                              *;
%*                                                                                *;
%* This macro stores a return code in _cstReturn. The value of the return code    *;
%* provides information about the result of the comparison. By inspecting the     *;
%* value of _cstReturn after this macro runs, you can use the results of this to  *;
%* determine a course of action or the parts of a SAS program to execute.         *;
%*                                                                                *;
%* The following table is the key to interpret the _cstReturn return code. For    *;
%* each of the conditions listed, if the condition is true, the associated bit is *;
%* set in the return code. Thus, the _cstReturn return code is the sum of the     *;
%* codes that are listed in this table:                                           *;
%*                                                                                *;
%* Bit   Condition  Code  Description                                             *;
%* ===   =========  ====  ==================================================      *;
%*   1     DSLABEL     1  Data set labels differ                                  *;
%*   2    INFORMAT     2  Variable has different informat                         *;
%*   3      FORMAT     4  Variable has different format                           *;
%*   4       LABEL     8  Variable has different label                            *;
%*   5        TYPE    16  Variable has different datatype                         *;
%*   6      LENGTH    32  Variable has different length                           *;
%*   7     BASEVAR    64  Base data set has variables not in comparison           *;
%*   8     COMPVAR   128  Comparison data set has variables not in base           *;
%*                                                                                *;
%* These codes are ordered and scaled to enable a simple check of the degree to   *;
%* which the data sets differ in structure. For example, if you want to check     *;
%* whether two data sets contain the same variables, but you do not care about    *;
%* differences in labels, informats, and formats, use the following statements    *;
%* after running this macro:                                                      *;
%*                                                                                *;
%*   %if &_cst_rc >= 16 %then                                                     *;
%*      %do;                                                                      *;
%*         handle error;                                                          *;
%*      %end;                                                                     *;
%*                                                                                *;
%* You can examine individual bits in _cstReturn by using DATA step bit-testing   *;
%* features to check for specific conditions. For example, to chceck for the      *;
%* presence of observations in the base data set that are not in the comparison   *;
%* data set, use the following statements:                                        *;
%*                                                                                *;
%*     data _null_;                                                               *;
%*       if &_cst_rc='1'b                                                         *;
%*         then put 'Data set labels differ';                                     *;
%*       if &_cst_rc='1.'b                                                        *;
%*         then put 'Variable has different informat';                            *;
%*       if &_cst_rc='1..'b                                                       *;
%*         then put 'Variable has different format';                              *;
%*       if &_cst_rc='1...'b                                                      *;
%*         then put 'Variable has different label';                               *;
%*       if &_cst_rc='1....'b                                                     *;
%*         then put 'Variable has different datatype';                            *;
%*       if &_cst_rc='1.....'b                                                    *;
%*         then put 'Variable has different length';                              *;
%*       if &_cst_rc='1......'b                                                   *;
%*         then put 'Base data set has variables not in comparison';              *;
%*       if &_cst_rc='1.......'b                                                  *;
%*         then put 'Comparison data set has variables not in base';              *;
%*     run;                                                                       *;
%*                                                                                *;
%* The Results data set has the following structure:                              *;
%*                                                                                *;
%*    baseDS      char(50)  label='Base data set name'                            *;
%*    compDS      char(50)  label='Comparison data set name'                      *;
%*    Name        char(32)  label='Variable name'                                 *;
%*    Issue       char(8)   label='Issue (code)'                                  *;
%*    Description char(50)  label='Issue description'                             *;
%*    baseValue   char(256) label='Value in base data set'                        *;
%*    compValue   char(256) label='Value in comparison data set'                  *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar &_cstReturn Task error status                                          *;
%* @macvar &_cstReturnMsg Message associated with _cst_rc                         *;
%*                                                                                *;
%* @param _cstReturn - required - The macro variable that contains the return     *;
%*            value that is set by this macro.                                    *;
%*            Default: _cst_rc                                                    *;
%* @param _cstReturnMsg - required - The macro variable that contains the return  *;
%*            message that is set by this macro.                                  *;
%*            Default: _cst_rcmsg                                                 *;
%* @param _cstBaseDSName - required - The reference data set, typically a         *;
%*            zero-observation template data set.                                 *;
%* @param _cstCompDSName - required - The data set that is compared against the   *;
%*            reference data set.                                                 *;
%* @param _cstResultsDS - optional - The data set in which to save the detailed   *;
%*            results.                                                            *;
%*            Default: work._cstCompareStructure.                                 *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcomparestructure(
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg,
    _cstBaseDSName=,
    _cstCompDSName=,
    _cstResultsDS=work._cstCompareStructure
    ) / des='CST: Compare dataset metadata';

  %local _cstRandom _cstLine _cstBaseDSLabel  _cstCompDSLabel ;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstLine=%sysfunc(repeat(*,%sysfunc(getoption(linesize))-1));


  %if %symexist(_cstDeBug) %then %do;
    %if &_cstDebug=1 %then
    %do;
      %put &_cstLine;
      %put * STARTING macro &sysmacroname;
      %put *  Parameter _cstReturn      = &_cstReturn;
      %put *  Parameter _cstReturnMsg   = &_cstReturnMsg;
      %put *  Parameter _cstBaseDSName  = &_cstBaseDSName;
      %put *  Parameter _cstCompDSName  = &_cstCompDSName;
      %put *  Parameter _cstResultsDS   = &_cstResultsDS;
      %put &_cstLine;
    %end;
  %end;
  %else %put NOTE: (&sysmacroname) %str
             ()Global debugging macro variable _CSTDEBUG has not been defined.;

  %***************************************************;
  %*  Check _cstReturn and _cstReturnMsg parameters  *;
  %***************************************************;
  %if (%length(&_cstReturn)=0) or (%length(&_cstReturnMsg)=0) %then %do;
    %* We are not able to communicate other than to the LOG;
    %put %str(ERR)OR:(&sysmacroname) %str
      ()macro parameters _CSTRETURN and _CSTRETURNMSG can not be missing.;
    %goto exit_abort;
  %end;

  %if (%eval(not %symexist(&_cstReturn))) %then %global &_cstReturn;
  %if (%eval(not %symexist(&_cstReturnMsg))) %then %global &_cstReturnMsg;

  %*************************************************;
  %*  Set _cstReturn and _cstReturnMsg parameters  *;
  %*************************************************;
  %let &_cstReturn=0;
  %let &_cstReturnMsg=;

  %************************************;
  %*  Check _cstBaseDSName parameter  *;
  %************************************;
  %if (%length(&_cstBaseDSName)=0) %then %do;
    %let &_cstReturn=-1;
    %let &_cstReturnMsg=No compare: macro parameter _cstBaseDSName not specified;
    %goto exit_macro;
  %end;
  %else %do;
  %* Check for the presence of the data set, required for compare *;
  %if (^%sysfunc(exist(&_cstBaseDSName))) %then %do;
    %let &_cstReturn=-1;
    %let &_cstReturnMsg=No compare: reference data set _cstBaseDSName=&_cstBaseDSName does not exist;
    %goto exit_macro;
  %end;

  %end;
  %************************************;
  %*  Check _cstCompDSName parameter  *;
  %************************************;
  %if (%length(&_cstCompDSName)=0) %then %do;
    %let &_cstReturn=-1;
    %let &_cstReturnMsg=No compare: macro parameter _cstCompDSName was not specified;
    %goto exit_macro;
  %end;
  %else %do;
  %* Check for the presence of the data set, required for compare *;
  %if (^%sysfunc(exist(&_cstCompDSName))) %then %do;
    %let &_cstReturn=-1;
    %let &_cstReturnMsg=No compare: data set _cstCompDSName=&_cstCompDSName does not exist;
    %goto exit_macro;
  %end;
  %end;

  %********************;
  %*  Perform Compare *;
  %********************;

  %let &_cstReturn=0;
  %let &_cstReturnMsg=;

  proc datasets nolist nodetails;
    contents data=&_cstBaseDSName out=work._cstBase_&_cstRandom (
      keep=name libname memname memlabel label type length
           informat informl informd format formatl formatd
      rename=(libname=libname_b memname=memname_b memlabel=memlabel_b
              label=label_b type=type_b length=length_b
              informat=informat_b informl=informl_b informd=informd_b
              format=format_b formatd=formatd_b formatl=formatl_b)
      ) nodetails noprint  ;
    contents data=&_cstCompDSName out=work._cstComp_&_cstRandom (
      keep=name libname memname memlabel label type length
           informat informl informd format formatl formatd
      rename=(libname=libname_c memname=memname_c memlabel=memlabel_c
              label=label_c type=type_c length=length_c
              informat=informat_c informl=informl_c informd=informd_c
              format=format_c formatd=formatd_c formatl=formatl_c)
      ) nodetails noprint  ;
  quit;

  %********************************************;
  %*  Ignore case differrences in name column *;
  %********************************************;
  data work._cstBase_&_cstRandom;
    set work._cstBase_&_cstRandom;
    if _n_=1 then do;
      if strip(memlabel_b)='"'  or strip(memlabel_b)="'"
        then call missing(memlabel_b); %* Empty labels return one quote;
      memlabel_b=tranwrd(memlabel_b, '"', "'");
      call symputx('_cstBaseDSLabel',memlabel_b);
    end;
    name=upcase(name);
  run;
  proc sort data=work._cstBase_&_cstRandom;
  by name;
  run;

  data work._cstComp_&_cstRandom;
    set work._cstComp_&_cstRandom;
    if _n_=1 then do;
      if strip(memlabel_c)='"' or strip(memlabel_c)="'"
        then call missing(memlabel_c); %* Empty labels return one quote;
      memlabel_c=tranwrd(memlabel_c, '"', "'");
      call symputx('_cstCompDSLabel',memlabel_c);
    end;
    name=upcase(name);
  run;
  proc sort data=work._cstComp_&_cstRandom;
  by name;
  run;


  %********************************************;
  %*  Merge base and comparison metadata      *;
  %********************************************;
  data work._cstMerge_&_cstRandom;
    attrib
      _cstReturn length=8
      varname length=$32 label="Variable name"
      Name length=$32 label="Variable name"
      Issue length=$8 label="Issue (code)"
      Description length=$50 label="Issue description"
      baseValue length=$256 label="Value in base data set"
      compValue length=$256 label="Value in comparison data set"
      errorCode length=8 label="Error Code"
    ;
    retain nIssues 0 _cstReturn 0 libname_b libname_c
           memname_b memname_c memlabel_b memlabel_c
           label_b label_c type_b type_c length_b length_c;
    merge work._cstBase_&_cstRandom (in=base)
          work._cstComp_&_cstRandom (in=comp);
    by name;

    restmp='DSLABEL/INFORMAT/FORMAT/LABEL/TYPE/LENGTH/BASEVAR/COMPVAR';

    if _n_=1 then do;
       if "&_cstBaseDSLabel" ne "&_cstCompDSLabel" then do;
         _cstReturn  = 1;
         errorCode=1;
         Issue='DSLABEL';
         Description='Data set labels differ';
         baseValue=left("&_cstBaseDSLabel");
         compValue=left("&_cstCompDSLabel");
         varname='';
         nIssues=1;
         output;
       end;
    end;

    Issue='';
    baseValue='';
    compValue='';

    varname=name;
    if comp=0 then do;
      _cstReturn = bor(_cstReturn, 64);
      errorCode=64;
      Issue='BASEVAR';
      Description='Base data set has variable not in comparison';
      baseValue=Name;
      compValue='';
      nIssues=nIssues+1;
      output;
    end;
    if base=0 then do;
      _cstReturn = bor(_cstReturn, 128);
      errorCode=128;
      Issue='COMPVAR';
      Description='Comparison data set has variable not in base';
      baseValue='';
      compValue=Name;
      nIssues=nIssues+1;
      output;
    end;
    if base=1 and comp=1 then do;
      if label_c ne label_b
      then do;
        _cstReturn = bor(_cstReturn, 8);
        errorCode=8;
        Issue='LABEL';
        Description='Variable has different label';
        baseValue=label_b;
        CompValue=label_c;
        nIssues=nIssues+1;
        output;
      end;
      if type_c ne type_b
      then do;
        _cstReturn = bor(_cstReturn, 16);
        errorCode=16;
        Issue='TYPE';
        Description='Conflicting variable types';
        if type_b=1 then baseValue='NUM';
                    else baseValue='CHAR';
        if type_c=1 then compValue='NUM';
                    else compValue='CHAR';
        nIssues=nIssues+1;
        output;
      end;
      if length_c   ne length_b
      then do;
        _cstReturn = bor(_cstReturn, 32);
        errorCode=32;
        Issue='LENGTH';
        Description='Variable has different length';
        baseValue=strip(put(length_b, best.));
        compValue=strip(put(length_c, best.));
        nIssues=nIssues+1;
        output;
      end;

      baseValue='';
      compValue='';
      if informat_c  ne informat_b or
         informl_c ne informl_b or
         informd_c ne informd_b then do;
           _cstReturn = bor(_cstReturn, 2);
           errorCode=2;
           Issue='INFORMAT';
           Description='Variable has different informat';
           if informat_b=:'$' then do;
                                     if informl_b > 0
                                       then baseValue=CATS(informat_b, informl_b, '.');
                                       else baseValue=CATS(informat_b, '.');
                                   end;
                           else if informl_b > 0 then do;
                                baseValue=CATS(informl_b, '.', informd_b);
                                baseValue=tranwrd(baseValue, '.0', '.');
                           end;
           if informat_c=:'$' then do;
                                     if informl_c > 0
                                       then compValue=CATS(informat_c, informl_c, '.');
                                       else compValue=CATS(informat_c, '.');
                                   end;
                           else if informl_c > 0 then do;
                               compValue=CATS(informl_c, '.', informd_c);
                               compValue=tranwrd(compValue, '.0', '.');
                           end;
           nIssues=nIssues+1;
           output;
      end;

      baseValue='';
      compValue='';
      if format_c  ne format_b or
         formatl_c ne formatl_b or
         formatd_c ne formatd_b then do;
           _cstReturn = bor(_cstReturn, 4);
           errorCode=4;
           Issue='FORMAT';
           Description='Variable has different format';
           if format_b=:'$' then do;
                                  if formatl_b > 0
                                    then baseValue=CATS(format_b, formatl_b, '.');
                                    else baseValue=CATS(format_b, '.');
                                 end;
                           else if formatl_b > 0 then do;
                                baseValue=CATS(format_b, formatl_b, '.', formatd_b);
                                baseValue=tranwrd(baseValue, '.0', '.');
                           end;
           if format_c=:'$' then do;
                                  if formatl_c > 0
                                    then compValue=CATS(format_c, formatl_c, '.');
                                    else compValue=CATS(format_c, '.');
                                 end;
                           else if formatl_c > 0 then do;
                               compValue=CATS(formatl_c, '.', formatd_c);
                               compValue=tranwrd(compValue, '.0', '.');
                           end;
           nIssues=nIssues+1;
           output;
      end;
    end;
   call symputx("&_cstReturn",_cstReturn);

   if nIssues eq 1 then
     call symputx("&_cstReturnMsg",
                  catx(' ', nIssues, 'structural difference was detected.'));
   else if nIssues gt 1 then
     call symputx("&_cstReturnMsg",
                  catx(' ', nIssues, 'structural differences were detected.'));

  run;

  %**************************;
  %*  Save detailed results *;
  %**************************;

  %if %length(&_cstResultsDS) %then %do;
    data &_cstResultsDS(keep=baseDS compDS varname Issue Description baseValue compValue errorCode
                        rename=(varname=Name));
    attrib
      baseDS length=$50 label="Base data set name"
      compDS length=$50 label="Comparison data set name"
    ;
    set work._cstMerge_&_cstRandom;
      baseDS="&_cstBaseDSName";
      compDS="&_cstCompDSName";
    run;
  %end;

  %**************;
  %*  Clean-up  *;
  %**************;
  %cstutil_deleteDataSet(_cstDataSetName=work._cstBase_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstComp_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstMerge_&_cstRandom);

%***********;
%*  exit   *;
%***********;
%exit_macro:

  %if %symexist(_cstDeBug) %then
    %if &_cstDebug=1 %then
    %do;
      %put &_cstLine;
      %put * LEAVING macro &sysmacroname;
      %put *  Parameter &_cstReturn    = &&&_cstReturn;
      %put *  Parameter &_cstReturnMsg = &&&_cstReturnMsg;
      %put &_cstLine;
    %end;

%*****************************************;
%*  exit without return macro variables  *;
%*****************************************;
%exit_abort:

%mend cstutilcomparestructure;
