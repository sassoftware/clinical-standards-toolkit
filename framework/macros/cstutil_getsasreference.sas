%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_getsasreference                                                        *;
%*                                                                                *;
%* Gets row-level metadata from SASReferences, given the type and subtype.        *;
%*                                                                                *;
%* The SASReferences data set contains references to each library, SAS file, and  *;
%* non-SAS file that is required to perform some SAS Clinical Standards Toolkit   *;
%* function. This macro gets the SAS libref (and, optionally, member name) or the *;
%* fileref for a specific SASReferences record, given the type and, optionally,   *;
%* the subtype.                                                                   *;
%*                                                                                *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* Required file inputs:                                                          *;
%*   sasreferences data set (as defined by &_cstSASRefs)                          *;
%*                                                                                *;
%* @param _cstStandard - optional - The name of a registered standard. If blank,  *;
%*            no subsetting by standard is attempted.                             *;
%* @param _cstStandardVersion - optional - The version of the registered standard.*;
%*            If blank, no subsetting by version is attempted.                    *;
%* @param _cstSASRefType - required - The file or data type from                  *;
%*            sasreferences.type.                                                 *;
%*            Values (representative): autocall | control | sourcedata            *;
%* @param _cstSASRefSubtype - optional - The file or data subtype from            *;
%*            sasreferences.subtype.  Values are specific to the type. Some types *;
%*            do not have subtypes.                                               *;
%*            Values (representative): column | lookup | table | validation       *;
%* @param _cstSASRefsasref - conditional - The name of the calling macro variable *;
%*            to populate with the value of sasreferences.sasref. Either (or both)*;
%*            _cstSASRefsasref or _cstSASRefmember must be non-null.              *;
%* @param _cstSASRefmember -conditional - The name of the calling macro variable  *;
%*            to populate with the value of sasreferences.memname, based on the   *;
%*            value of _cstFullname. Either (or both) _cstSASRefsasref or         *;
%*            _cstSASRefmember must be non-null.                                  *;
%* @param _cstConcatenate - optional - Return multiple row values, space-         *;
%*            delimited, for each macro variable requested (sasref and member).   *;
%*            1: Return multiple row values.                                      *;
%*            0: Return a single value. Do not concatenate.                       *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstFullname - optional - Return the full name from                     *;
%*            sasreferences.memname.                                              *;
%*            1: Return the full name.                                            *;
%*            0: Return the file name without the suffix.                         *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstAllowZeroObs - optional - Allow SASReferences to operate without    *;
%*            Warnings, when a row that is requested is not found and, therefore, *;
%*            returns zero observations. 0 = no, 1 = yes.                         *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_getsasreference(
    _cstStandard=,
    _cstStandardVersion=,
    _cstSASRefType=,
    _cstSASRefSubtype=,
    _cstSASRefsasref=,
    _cstSASRefmember=,
    _cstConcatenate=0,
    _cstFullname=0,
    _cstAllowZeroObs=0
    ) / des='CST: Get sasreferences values';

  %cstutil_setcstgroot;

  %local
    _cstActual
    _cstErrorIndicator
    _cstEType
    _cstExitError
    _cstSASRefRecords
    _cstTemp
    _cstValidStd
  ;

  %let _cstExitError=0;
  %let _cstErrorIndicator=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstSrcData=&sysmacroname;


  %***********************************;
  %* Check that _cstSASRefs exists.  *;
  %***********************************;

  %if %symexist(_cstSASRefs) %then
  %do;
    %if %sysfunc(exist(&_cstSASRefs)) %then;
    %else %goto exit_error;
  %end;
  %else %goto exit_error;
  %* Not currently written to results data set *;

  %******************************************************************;
  %* Check that _cstStandard parameter is valid, recognized value.  *;
  %******************************************************************;

  %if %length(&_cstStandard)>0 %then
  %do;
    data _null_;
      attrib _cstTemp label="Text string field for file names"  format=$char12.;
        _cstTemp = "_cs6" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstTemp',_cstTemp);
    run;
    %cst_getRegisteredStandards(_cstOutputDS=&_cstTemp);

    %let _cstValidStd=0;
    data _null_;
      set &_cstTemp end=last;
      retain _cstfound 0;
        if _n_=1 then _cstfound=0;
        if upcase("&_cstStandard")=upcase(standard) then _cstfound=1;
      if last then
        call symputx('_cstValidStd',_cstfound);
    run;

    %cstutil_deleteDataSet(_cstDataSetName=work.&_cstTemp);

    %if ^&_cstValidStd %then
    %do;
       * Invalid standard.  *;
       %let _cst_MsgID=CST0082;
       %let _cst_MsgParm1=&_cstStandard;
       %let _cst_MsgParm2=;
       %let _cst_rc=1;
       %let _cstExitError=1;
       %goto exit_error;
    %end;
  %end;

  %******************************************************************;
  %* Check that caller has specified return macros to contain the   *;
  %*  libref and member name.                                       *;
  %******************************************************************;

  %if %length(&_cstSASRefsasref)=0  and %length(&_cstSASRefmember)=0 %then
  %do;
     * Parameter specification to macro incomplete.  *;
     %let _cst_MsgID=CST0005;
     %let _cst_MsgParm1=cstutil_getsasreference;
     %let _cst_MsgParm2=;
     %let _cst_rc=1;
     %let _cstExitError=1;
     %goto exit_error;
  %end;

  %******************************************************************;
  %* Check that caller has specified a record type to search for    *;
  %* Note that subtype is optional                                  *;
  %******************************************************************;

  %if "&_cstSASRefType" =  %then
  %do;
     * Parameter specification to macro incomplete.  *;
     %let _cst_MsgID=CST0005;
     %let _cst_MsgParm1=cstutil_getsasreference;
     %let _cst_MsgParm2=;
     %let _cst_rc=1;
     %let _cstExitError=1;
     %goto exit_error;
  %end;

  * Create a temporary results data set.                                           *;
  data _null_;
    attrib _cstTemp label="Text string field for file names"  format=$char12.;
      _cstTemp = "_cs7" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_cstTemp',_cstTemp);
  run;

  data &_cstTemp (label="Subset of sasreferences");
      %if %length(&_cstSASRefSubtype)>0 %then
      %do;
        set &_cstSASRefs (where=(upcase(type)=upcase("&_cstSASRefType") and
                                 upcase(subtype)=upcase("&_cstSASRefSubtype")));
      %end;
      %else
      %do;
        set &_cstSASRefs (where=(upcase(type)=upcase("&_cstSASRefType")));
      %end;
  run;

  %if %length(&_cstStandard)>0 %then
  %do;
    %if %length(&_cstStandardVersion)>0 %then
    %do;
      data &_cstTemp (label="Subset of sasreferences");
         set &_cstTemp (where=(upcase("&_cstStandard")=upcase(standard) and
                               upcase("&_cstStandardVersion")=upcase(standardversion)));
      run;
    %end;
    %else
    %do;
      data &_cstTemp (label="Subset of sasreferences");
         set &_cstTemp (where=(upcase("&_cstStandard")=upcase(standard)));
      run;
    %end;
  %end;

  data _null_;
    if 0 then set &_cstTemp nobs=_numobs;
    call symputx('_cstSASRefRecords',_numobs);
    stop;
  run;

  %if &_cstSASRefRecords %then
  %do;
    %if &_cstSASRefRecords=1 %then
    %do;
      * One record, no ambiguities, return the single memname.  *;
      data _null_;
        set &_cstTemp;

          attrib _cstTemp format=$char50. label="Return value for macro variable";
          _cstTemp='';

          %if %length(&_cstSASRefsasref)>0 %then
          %do;
            call symputx("&_cstSASRefsasref",SASRef);
          %end;
          %if %length(&_cstSASRefmember)>0 %then
          %do;
            %if &_cstFullname %then
            %do;
              _cstTemp=memname;
            %end;
            %else
            %do;
              _cstTemp=scan(memname,1,'.');
            %end;
            call symputx("&_cstSASRefmember",_cstTemp);
          %end;
      run;
    %end;
    %else
    %do;

      * Multiple records, processing dependent on _cstConcatenate parameter.*;
      data _null_;
        set &_cstTemp end=last;

          attrib _cstTemp format=$char50. label="Derived memname"
                 %if %length(&_cstSASRefsasref)>0 %then _cstAllSASref format=$char200. label="All SASRefs for type/subtype";
                 %if %length(&_cstSASRefmember)>0 %then _cstAllMemname format=$char2000. label="All memnames for type/subtype";
                 _cstErrorIndicator format=8. label="Error indicator"
          ;
          retain _cstTemp ''
                 %if %length(&_cstSASRefsasref)>0 %then _cstAllSASref;
                 %if %length(&_cstSASRefmember)>0 %then _cstAllMemname;
                 _cstErrorIndicator
                 ;

          if _n_=1 then
            _cstErrorIndicator = 0;

          %* Consumer request to return SASref value ;
          %if %length(&_cstSASRefsasref)>0 %then
          %do;
            if (SASref ne '') then
            do;
              %if &_cstConcatenate %then
              %do;
                 if _cstAllSASref='' then
                   _cstAllSASref = SASref;
                 else
                   _cstAllSASref = catx(' ',_cstAllSASref,SASref);
              %end;
              %else
              %do;
                _cstErrorIndicator = 1;
                call symputx('_cstErrorIndicator',_cstErrorIndicator);
              %end;
            end;
          %end;

          %* Consumer request to return memname value ;
          %if %length(&_cstSASRefmember)>0 %then
          %do;
            if (memname ne '') then
            do;
              %if &_cstConcatenate %then
              %do;
                %if &_cstFullname %then
                %do;
                  _cstTemp=memname;
                %end;
                %else
                %do;
                  _cstTemp=scan(memname,1,'.');
                %end;
                if _cstAllMemname='' then
                  _cstAllMemname = _cstTemp;
                else
                  _cstAllMemname = catx(' ',_cstAllMemname,_cstTemp);
              %end;
              %else
              %do;
                _cstErrorIndicator = 1;
                call symputx('_cstErrorIndicator',_cstErrorIndicator);
              %end;
            end;
          %end;

          if last and _cstErrorIndicator=0 then
          do;
            %if %length(&_cstSASRefsasref)>0 %then
            %do;
              %if &_cstConcatenate %then
              %do;
                call symputx("&_cstSASRefsasref",_cstAllSASref);
              %end;
              %else
              %do;
                call symputx("&_cstSASRefsasref",SASRef);
              %end;
            %end;
            %if %length(&_cstSASRefmember)>0 %then
            %do;
              %if &_cstConcatenate %then
              %do;
                call symputx("&_cstSASRefmember",_cstAllMemname);
              %end;
              %else
              %do;
                call symputx("&_cstSASRefmember",_cstTemp);
              %end;
            %end;
          end;

      run;

      %if %length(&_cstSASRefsasref)>0 and %length(&_cstSASRefmember)>0 %then
      %do;
        %if %SYSFUNC(countw(&_cstSASRefsasref,' ')) ^= %SYSFUNC(countw(&_cstSASRefmember,' ')) %then
        %do;
          * sasreferences lookup returned inconsistent SASref and memname values  *;
          %let _cst_MsgID=CST0012;
          %let _cst_MsgParm1=;
          %let _cst_MsgParm2=;
          %let _cst_rc=1;
          %let _cstExitError=1;
          %goto exit_error;
        %end;
      %end;

      %if &_cstErrorIndicator %then
      %do;
        * sasreferences lookup returned multiple records  *;
        %let _cst_MsgID=CST0010;
        %let _cst_MsgParm1=&_cstSASRefsasref;
        %let _cst_MsgParm2=cstutil_getsasreference;
        %let _cst_rc=1;
        %let _cstExitError=1;
        %goto exit_error;
      %end;
    %end;
  %end;
  %else
  %do;
    %**************************************;
    %*  Default is to NOT allow zero obs  *;
    %*  Ignore zero obs if set to 1       *;
    %**************************************;
    %if &_cstAllowZeroObs=0 %then
    %do;
      * sasreferences lookup returned no records  *;
      %let _cst_MsgID=CST0007;
      %let _cst_MsgParm1=&_cstSASRefsasref;
      %let _cst_MsgParm2=cstutil_getsasreference;
      %let _cst_rc=1;
      %let _cstExitError=1;
      %goto exit_error;
    %end;
  %end;

%exit_error:


  %if %sysfunc(exist(work.&_cstTemp)) %then
    %cstutil_deleteDataSet(_cstDataSetName=work.&_cstTemp);

  %if &_cstExitError %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %let _cstActual=%str(type=&_cstSASRefType,subtype=&_cstSASRefSubtype);
    %if %symexist(_cstCheckID) %then
       %let _cstEType=&_cstCheckID;
    %else
       %let _cstEType=&_cst_MsgID;

    %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstValCheckID=&_cstEType
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=%str(&_cstActual)
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;

  %if &_cstDebug %then
  %do;
    %put <<< cstutil_getsasreference;
    %put sasref=&_cstSASRefsasref;
    %put member=&_cstSASRefmember;
  %end;

%mend cstutil_getsasreference;

