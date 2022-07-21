%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcompareproperties                                                       *;
%*                                                                                *;
%* Compares two property files.                                                   *;
%*                                                                                *;
%* These results are reported:                                                    *;
%*      Property missing                                                          *;
%*      New property                                                              *;
%*      Different value detected                                                  *;
%*                                                                                *;
%* @param _cstBasePath - required - The full path and filename of the property    *;
%*            file to compare against.                                            *;
%* @param _cstNewPath - required - The full path and filename of the property     *;
%*            file to compare.                                                    *;
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
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;
 
%macro cstutilcompareproperties(
  _cstBasePath=, 
  _cstNewPath=, 
  _cstRptType=LOG,
  _cstRptDS=,
  _cstOverwrite=N
  ) / des='CST: Compare properties (global macvars)';

  %local 
    rc
    _cstRandom
    _cstBase
    _cstNew
    _cstSeqCnt
  ;
  
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);

  %**********************************;
  %*  Check Macro parameter values  *;
  %**********************************;
  %if %length(&_cstBasePath) < 1 or %length(&_cstNewPath) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstBasePath and _cstNewPath parameter values are required.;
    %goto exit_error;
  %end;

  %let rc = %sysfunc(filename(_cstBase,&_cstBasePath)) ; 
  %if %sysfunc(fexist(&_cstBase))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstBasePath does not exist.;
    %goto exit_error;
  %end;

  %let rc = %sysfunc(filename(_cstNew,&_cstNewPath)) ; 
  %if %sysfunc(fexist(&_cstNew))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstNewPath does not exist.;
    %goto exit_error;
  %end;

  %let _cstSeqCnt=0;

  %if %length(&_cstRptType) < 1 %then
    %let _cstRptType=LOG;  
  %else %if %upcase(&_cstRptType) ^= LOG and %upcase(&_cstRptType) ^= DATASET and %upcase(&_cstRptType) ^= _CSTRESULTSDS %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptType value must be LOG or DATASET or _CSTRESULTSDS.;
    %goto exit_error;
  %end;
  %_cstutilreporting(_cstType=&_cstRptType,_cstDS=&_cstRptDS,_cstOWrite=&_cstOverwrite);
 
  %**********************************************;
  %*  Read in the files to temporary data sets  *;
  %**********************************************;
  %cstutilreadproperties(_cstPropertiesFile=&_cstBasePath,_cstOutputDSName=work._csttempds1_&_cstRandom);
  %cstutilreadproperties(_cstPropertiesFile=&_cstNewPath,_cstOutputDSName=work._csttempds2_&_cstRandom);

  proc sort data=work._csttempds1_&_cstRandom;
    by name value;
  run;

  proc sort data=work._csttempds2_&_cstRandom;
    by name value;
  run;
  
  %*************************************************;
  %*  Compare the differences between the 2 files  *;      
  %*************************************************;
  data work._cstbasediff_&_cstRandom(drop=new newfile newvalue) 
       work._cstnewdiff_&_cstRandom(drop=base basefile basevalue);
    length newfile basefile $200 base new $3 condition 8;
    merge work._csttempds1_&_cstRandom(in=inbase) work._csttempds2_&_cstRandom(in=innew);
    by name value;
    comment='';
    if inbase and ^innew then 
    do;
      base="Yes";
      basefile="&_cstBasePath";
      basevalue=kstrip(value);
      condition=1;
      output work._cstbasediff_&_cstRandom;
    end;
    if ^inbase and innew then 
    do;
      new="Yes";
      newfile="&_cstNewPath";
      newvalue=kstrip(value);
      condition=2;
      output work._cstnewdiff_&_cstRandom;
    end;
    drop value;
  run;

  %********************************************************;
  %*  Create a single data set  containing discrepancies  *;      
  %********************************************************;
  data work._cstpropertydiff_&_cstRandom;
    length message $500;
    merge work._cstbasediff_&_cstRandom(in=inbase drop=comment condition) 
          work._cstnewdiff_&_cstRandom(in=innew drop=comment condition);
    by name;
    if inbase and innew then 
      message=catx('',"Property values different between BASE and NEW. Name: ",kstrip(name)," Base Value: ",kstrip(basevalue)," New Value:",kstrip(newvalue));
    if inbase and ^innew then 
      message=catx('',"Property value found in BASE but not in NEW. Name/Value: ",kstrip(name)," = ",kstrip(basevalue));
    if ^inbase and innew then 
      message=catx('',"Property value found in NEW but not in BASE. Name/Value: ",kstrip(name)," = ",kstrip(newvalue));
  run;

  %if %upcase(&_cstRptType)=LOG %then
  %do;
    data _null_;
      set work._cstpropertydiff_&_cstRandom;
       
      if _n_=1 then 
        put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] The following properties differ between the two property files:";
      put message;
    run;
  %end;
  %else %if %upcase(&_cstRptType)=DATASET %then
  %do;
    data &_cstRptDS;
      set work._cstpropertydiff_&_cstRandom;
    run;
  %end;
  %else %do;
    data work._cstpropertydiff_&_cstRandom;
      set work._cstpropertydiff_&_cstRandom end=last;
      
      %cstutil_resultsdskeep;
      attrib _cstSeqNo format=8. label="Sequence counter for result column"
             _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
             _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
             ;
      
      %cstutil_resultsdsattr;
      keep _cstMsgParm1 _cstMsgParm2;
      
      retain _cstSeqNo 0;
      if _n_=1 then _cstSeqNo=&_cstSeqCnt;
        
      message=kstrip(message);
        
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
      if basevalue='' then basevalue='<Missing>';
      if newvalue='' then newvalue='<Missing>';
      actual=catx('','Base =',basevalue,'New =',newvalue);
      keyvalues=cats('Property name=',name);
      _cstSeqNo+1;
      seqno=_cstSeqNo;
      
      if last then
        call symputx('_cstSeqCnt',_cstSeqNo);
    run;

    %cstutil_appendresultds(_cstErrorDS=work._cstpropertydiff_&_cstRandom,_cstVersion=1.2,_cstSource=CST,_cstOrderBy=seqno);
  %end;

  %****************************;
  %*  Cleanup the work area.  *;
  %****************************;

  %cstutil_deleteDataSet(_cstDataSetName=work._csttempds1_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._csttempds2_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstbasediff_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstnewdiff_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstpropertydiff_&_cstRandom);

  %exit_error:

%mend cstutilcompareproperties;
