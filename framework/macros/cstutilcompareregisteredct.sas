%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcompareregisteredct                                                     *;
%*                                                                                *;
%* Compares two registered controlled terminology packages.                       *;
%*                                                                                *;
%* This macro compares the records in one controlled terminology standardsubtypes *;
%* data set with the records in another controlled terminology standardsubtypes   *;
%* data set. Generally, this macro is used to compare the controlled terminology  *;
%* packages between two versions of the SAS Clinical Standards Toolkit.           *;
%*                                                                                *;
%* This macro reports differences such as a previously registered package that    *;
%* no longer exists or a new package that exists.                                 *;
%*                                                                                *;
%* Here is the default folder location for the controlled terminology             *;
%* standardsubtypes data set:                                                     *;
%*    <cstGlobalLibrary>/standards/cdisc-terminology-<_cstVersion>/control        *;
%*                                                                                *;
%* These results are reported:                                                    *;
%*      Previous CT not found (the package is in _cstBaseCT but not in _cstNewCT) *;
%*      New CT found (the package is in _cstNewCT but not in _cstBaseCT)          *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The macro parameters are specified in keyword-parameter=<value> format.   *;
%*   2. The librefs in the macro parameters have been allocated.                  *;
%*                                                                                *;
%* @param _cstBaseCT - required - The libref.dataset for the controlled           *;
%*            terminology  standardsubtypes data set to compare against.          *;
%* @param _cstNewCT - required - The libref.dataset for the controlled            *;
%*            terminology  standardsubtypes data set to compare.                  *;
%* @param _cstRptType - required - The location to contain the results.           *;
%*            Values: LOG | DATASET | _CSTRESULTSDS                               *;
%*                    LOG:           The SAS log file.                            *;
%*                    DATASET:       The data set that is specified by _cstRptDS. *;
%*                    _CSTRESULTSDS: The Results data set that is specified in    *;
%*                                   the _cstResultsDS global macro variable.     *;
%*            Default: LOG                                                        *;
%* @param _cstRptDS - required when _cstRptType=DATASET - The name of the data    *;
%*            set to contain the results. If _cstRptType=LOG or _CSTRESULTSDS,    *;
%*            this value is ignored.                                              *;
%* @param _cstOverWrite - optional - Overwrite the data set that is specified by  *;
%*             _cstRptDS. If _cstRptType=LOG or _CSTRESULTSDS, this value is      *;
%*            ignored.                                                            *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%*            If the value is N and _cstRptDS exists, the results are written to  *;
%*            the SAS log file.                                                   *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcompareregisteredct(
  _cstBaseCT=,
  _cstNewCT=,
  _cstRptType=LOG,
  _cstRptDS=,
  _cstOverwrite=N
  ) / des='CST: Compare registered CT packages';

  %local _cstRandom;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);

  %************************;
  %* Parameter checking   *;
  %************************;
  
  %if %length(&_cstBaseCT) < 1 or %length(&_cstNewCT) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstBaseCT and _cstNewCT parameter values are required.;
    %goto exit_error;
  %end;
  %if %sysfunc(exist(&_cstBaseCT))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstBaseCT does not exist.;
    %goto exit_error;
  %end;
  %if %sysfunc(exist(&_cstNewCT))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstNewCT does not exist.;
    %goto exit_error;
  %end;

  %if %length(&_cstRptType) < 1 %then
    %let _cstRptType=LOG;  
  %else %if %upcase(&_cstRptType) ^= LOG and %upcase(&_cstRptType) ^= DATASET and %upcase(&_cstRptType) ^= _CSTRESULTSDS %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptType value must be LOG or DATASET or _CSTRESULTSDS.;
    %goto exit_error;
  %end;
  %_cstutilreporting(_cstType=&_cstRptType,_cstDS=&_cstRptDS,_cstOWrite=&_cstOverwrite);

  data work._cstCTDiff_&_cstRandom;
    merge &_cstNewCT (in=new keep=standard standardversion standardsubtype standardsubtypeversion)
          &_cstBaseCT (in=old keep=standard standardversion standardsubtype standardsubtypeversion);
      by standard standardversion standardsubtype standardsubtypeversion;
    attrib message format=$500.
           actual format=$240.;
    if old ne new then 
    do;
      if old then 
      do;
        condition=1;
        message="Previous CT package found in &_cstBaseCT but not found in &_cstNewCT"; 
        actual=catx(', ',standard,standardversion,standardsubtype,standardsubtypeversion);
      end;
      else do;
        condition=2;
        message="New CT package found in &_cstNewCT but not found in &_cstBaseCT"; 
        actual=catx(', ',standard,standardversion,standardsubtype,standardsubtypeversion);
      end;
      output;
    end;
  run;

  %if %upcase(&_cstRptType)=LOG %then
  %do;
    data _null_;
      set work._cstCTDiff_&_cstRandom;
        
      if _n_=1 then 
        put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] The following Controlled Terminology package differences were detected:";
      put message;
      put @6 actual;
    run;
  %end;
  %else %if %upcase(&_cstRptType)=DATASET %then
  %do;
    data &_cstRptDS;
      set work._cstCTDiff_&_cstRandom;
    run;
  %end;
  %else %do;
    data work._cstDifferences;
      set work._cstCTDiff_&_cstRandom end=last;
      
        %cstutil_resultsdskeep;
        attrib _cstSeqNo format=8. label="Sequence counter for result column"
               _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
               _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
               ;
      
        %cstutil_resultsdsattr;
        keep _cstMsgParm1 _cstMsgParm2;
      
        retain _cstSeqNo 0;
        if _n_=1 then _cstSeqNo=&_cstSeqCnt;
        
        srcdata = "&sysmacroname";
        resultid="CST0200";
        checkid="";
        _cstMsgParm1=message;
        _cstMsgParm2='';
        resultseq=1;
        resultflag=1;
        resultseverity='Info';
        resultdetails='';
        _cst_rc=0;
        keyvalues='';
        _cstSeqNo+1;
        seqno=_cstSeqNo;
      
        if last then
          call symputx('_cstSeqCnt',_cstSeqNo);
    run;

    %cstutil_appendresultds(_cstErrorDS=work._cstDifferences,_cstVersion=1.2,_cstSource=CST,_cstOrderBy=seqno);
    
    %cstutil_deleteDataSet(_cstDataSetName=work._cstDifferences);

  %end;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstCTDiff_&_cstRandom);

%exit_error:


%mend cstutilcompareregisteredct;
