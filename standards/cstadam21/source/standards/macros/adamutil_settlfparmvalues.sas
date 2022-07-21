%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* adamutil_settlfparmvalues                                                      *;
%*                                                                                *;
%* Translates TLF metadata values into macro variable values.                     *;
%*                                                                                *;
%* The macro variables created are in the form of _cst + <dataset> + <column>,    *;
%* as in _CSTTLF_MASTERCODEPATH (where dataset=TLF_MASTER and column=CODEPATH).   *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstTLFLibrary SAS library containing TLF metadata, typically created  *;
%*             via a call to %adamutil_gettlfmetadata(_cstOutLib=&_cstTLFLibrary) *;
%*                                                                                *;
%* @param _cstTLFDS - required - The type of metadata. Example: tlf_master.       *;
%* @param _cstTLFDSWhereClause - optional - The WHERE clause to subset _cstTLFDS. *;
%*            Example:  Linenum='1'                                               *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure internal                                                             *;

%macro adamutil_settlfparmvalues(
    _cstTLFDS=,
    _cstTLFDSWhereClause=
     ) / des='CST: Create TLF metadata macro variables';

  data _null_;
    set &_cstTLFLibrary..&_cstTLFDS

    %if %length(&_cstTLFDSWhereClause)>0 %then
    %do;
      (where=(&_cstTLFDSWhereClause))
    %end;
    ;
    * These two temporary variables are only created to prevent the warning messages that *;
    * occur when an array is created with undefined variables.                            *;
    attrib _forceNumVarToExist_  length=8  label="Avoids Array Warning If Dataset Lacks a Num Var"
           _forceCharVarToExist_ length=$1 label="Avoids Array Warning If Dataset Lacks a Char Var"
           ;
    drop _forceNumVarToExist_ _forceCharVarToExist_;
    array _allCharVars_{*} _character_;
    array _allNumVars_{*}  _numeric_;
    length _varname_ $32;
    do _i_=lbound(_allCharVars_) to hbound(_allCharVars_);
      call vname(_allCharVars_{_i_}, _varName_);
      if (_varName_ ^= "_forceCharVarToExist_") then
      do;
        call symputx("_cst" || "&_cstTLFDS" || _varName_, _allCharVars_{_i_}, 'G');
      end;
    end;
    do _i_=lbound(_allNumVars_) to hbound(_allNumVars_);
      call vname(_allNumVars_{_i_}, _varName_);
      if (_varName_ ^= "_forceNumVarToExist_") then
      do;
        call symputx("_cst" || "&_cstTLFDS" || _varName_, _allNumVars_{_i_}, 'G');
      end;
    end;
  run;

  %if (%symexist(_cstDebug)) %then
  %do;
    proc sort data=sashelp.vmacro (where=(lowcase(name) =: "_cst&_cstTLFDS")) out=work._cstmacros;
      by name;
    run;
    data _null_;
      set work._cstmacros;
      if _n_ = 1 then
      do;
        put "NOTE: adamutil_settlfparmvalues created the following macro variables from &_cstTLFLibrary.&_cstTLFDS:";
      end;
      put "NOTE: " +5 name 32. "="  value;
    run;
    proc datasets lib=work nolist;
      delete _cstmacros;
    quit;
  %end;

%mend adamutil_settlfparmvalues;
