%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutil_formatlookup                                                      *;
%*                                                                                *;
%* Performs a lookup in a format value column.                                    *;
%*                                                                                *;
%* This macro creates work._cstproblems that contains records that are included   *;
%* in the data set that is specified by _cstSourceDS, where the value of a column *;
%* is not found in the format value column.                                       *;
%*                                                                                *;
%* For example, in the TS domain, TSPARMCD has a value of SEX. The $SEXPOP format *;
%* is associated with this variable and has these values: BOTH, F, and M. TSVAL   *;
%* has to contain one of these values to be correct. Otherwise, an error condition*;
%* exists.                                                                        *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (that is, *;
%*       a full DATA step or PROC SQL invocation).                                *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%*                                                                                *;
%* @param _cstDSN - required - The domain and table that contain _cstCol2.        *;
%* @param _cstDomOnly - required - The alias for _cstDSN (only domain).           *;
%* @param _cstCol1 - required - The variable that contains the value to check     *;
%*            (TSVAL).                                                            *;
%* @param _cstCol2 - required - The variable that defines the record to check     *;
%*            (TSPARMCD).                                                         *;
%* @param _cstCol2Value - required - The value from _cstCol2.                     *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutil_formatlookup(
    _cstDSN=&_cstDSName,
    _cstDomOnly=,
    _cstCol1=&_cstColumn,
    _cstCol2=,
    _cstCol2Value=
    ) / des="CST: Performs column lookup";


  %local _cstDSRowCt;

  %if &_cstDebug %then
  %do;
    %put &sysmacroname >>>;
    %put "*********************************************************";
    %put "_cstDSN       = &_cstDSN                                 ";
    %put "_cstDomOnly   = &_cstDomOnly                             ";
    %put "_cstCol1      = &_cstCol1                                ";
    %put "_cstCol2      = &_cstCol2                                ";
    %put "_cstCol2Value = &_cstCol2Value                           ";
    %put "*********************************************************";
  %end;

  %let _cstDSRowCt=;

  %***********************************************;
  %*  Check to see if value exists in the domain *;
  %*  If not, exit macro and alert user          *;
  %***********************************************;

  proc sql noprint;
    select count(*)
    into :_cstDSRowCt
    from &_cstDSN
    where upcase(&_cstCol2)="%upcase(&_cstCol2Value)";
  quit;

  %if &_cstDSRowCt=0 %then %goto exit_macro;

  proc sql noprint;
    create table work._cstproblems as
    select &_cstDomOnly..*, _uv
    from &_cstDSN &_cstDomOnly
      left join
        (select _uv, _uvlabel from
          (select distinct &_cstCol1 as _uv from &_cstDSN)
        left join work._cstformats
          on _uv = _uvlabel
          where _uvlabel = "")
        on _uv = &_cstCol1
        where _uv ne "" and upcase(&_cstCol2)="%upcase(&_cstCol2Value)";
  quit;

  %exit_macro:

  %if &_cstDebug %then
  %do;
    %put <<< cstcheckutil_formatlookup;
  %end;

%mend cstcheckutil_formatlookup;
