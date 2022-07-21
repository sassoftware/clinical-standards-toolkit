%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcomparecodelists                                                        *;
%*                                                                                *;
%* Compares two codelist sources.                                                 *;
%*                                                                                *;
%* This macro compares two codelist sources of the same type (for example, data   *;
%* set or catalog) and reports the differences between the two sources.           *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The data sets must generally conform to the structure of cterm data sets  *;
%*      as provided in the <cstGlobalLibrary>/standards/cdisc-terminology-x.x/    *;
%*      <standard>/.../formats folders. The data sets must include at least       *;
%*      codelist and cdisc_submission_value from the following columns:           *;
%*         codelist - The codelist value (for example, ACN)                       *;
%*         codelist_code - The unique NCI codelist code (for example, C66767)     *;
%*         codelist_name - The full description of the codelist name (for example,*;
%*                         Action Taken with Study Treatment)                     *;
%*         code - The unique NCI item value code (for example, C49503)            *;
%*         cdisc_submission_value - The value of the codelist item (for example,  *;
%*                                  DOSE INCREASED)                               *;
%*   2. PROC FORMAT CNTLOUT= is used for catalogs to identify codelist as the     *;
%*      FTMNAME value and cdisc_submission_value as the START value.              *;
%*   3. Librefs in the macro parameters have been allocated.                      *;
%*   4. If _cstRptType=_CSTRESULTSDS, one or both of the following macros must    *;
%*      be run if the &_cstResultsDS macro variable is not defined or the         *;
%*      Results data set does not exist:                                          *;
%*         %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,                 *;
%*                                   _cstSubType=initialize)                      *;
%*         %cstutil_createTempMessages()                                          *;
%*                                                                                *;
%* @param _cstFileType - required - The type of file that contains the codelists. *;
%*            Values:  DATASET | CATALOG                                          *;
%*            Default: CATALOG                                                    *;
%* @param _cstBaseCT - required - The context-specific reference to the first     *;
%*            codelist source. Here are examples:                                 *;
%*               DATASET:   libref.dataset                                        *;
%*               CATALOG:   libref.catalog                                        *;
%* @param _cstNewCT - required - The context-specific reference to the second     *;
%*            (for example, new) codelist source. Here are examples:              *;
%*               DATASET:   libref.dataset                                        *;
%*               CATALOG:   libref.catalog                                        *;
%* @param _cstCompareCL - optional - Compare the codelists between the two        *;
%*            codelist sources.                                                   *;
%*            Values: Y | N                                                       *;
%*            Default: Y                                                          *;
%* @param _cstCLVar - required when _cstFileType=DATASET - The name of the data   *;
%*            set column that contains the codelist name.                         *;
%* @param _cstCompareCLI - optional - Compare the codelist items (values) between *;
%*            the two codelist sources.                                           *;
%*            Values: Y | N                                                       *;
%*            Default: Y                                                          *;
%* @param _cstCLValueVar - required when _cstFileType=DATASET and _cstCompareCLI=Y*;
%*            The name of the data set column that contains the codelist values.  *;
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

%macro cstutilcomparecodelists(
  _cstFileType=CATALOG,
  _cstBaseCT=,
  _cstNewCT=,
  _cstCompareCL=Y,
  _cstCLVar=,
  _cstCompareCLI=Y,
  _cstCLValueVar=,
  _cstRptType=LOG,
  _cstRptDS=,
  _cstOverwrite=N
  ) / des='CST: Compare codelists';
  
  %local _cstCnt _cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);

  %if %length(&_cstBaseCT) < 1 or %length(&_cstNewCT) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstBaseCT and _cstNewCT parameter values are required.;
    %goto exit_error;
  %end;
  %if %upcase(&_cstFileType) ^= CATALOG and %upcase(&_cstFileType) ^= DATASET %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstFileType value must be DATASET or CATALOG.;
    %goto exit_error;
  %end;
  %if %upcase(&_cstFileType)=CATALOG %then 
  %do;
    %if %sysfunc(cexist(&_cstBaseCT))=0 %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] CATALOG &_cstBaseCT does not exist.;
      %goto exit_error;
    %end;
    %if %sysfunc(cexist(&_cstNewCT))=0 %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] CATALOG &_cstNewCT does not exist.;
      %goto exit_error;
    %end;
  %end;
  %else %if %upcase(&_cstFileType)=DATASET %then 
  %do;
    %if %sysfunc(exist(&_cstBaseCT))=0 %then 
    %do;
      %put [ERR%STR(OR): CSTLOG%str(MESSAGE).&sysmacroname] DATA SET &_cstBaseCT does not exist.;
      %goto exit_error;
    %end;
    %if %sysfunc(exist(&_cstNewCT))=0 %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] DATA SET &_cstNewCT does not exist.;
      %goto exit_error;
    %end;
    
    %if %upcase(&_cstCompareCL)=Y  or %upcase(&_cstCompareCLI)=Y %then 
    %do;
      %if %length(&_cstCLVar) < 1 %then
      %do;
        %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstCLVar must be specified.;
        %goto exit_error;
      %end;

      %if %cstutilcheckvarsexist(_cstDataSetName= &_cstBaseCT, _cstVarList=&_cstCLVar)=0
        %then %do;
          %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The &_cstCLVar column cannot be found in &_cstBaseCT..;
          %goto exit_error;
        %end;
      
      %if %cstutilcheckvarsexist(_cstDataSetName= &_cstNewCT, _cstVarList=&_cstCLVar)=0
        %then %do;
          %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The &_cstCLVar column cannot be found in &_cstNewCT..;
          %goto exit_error;
        %end;

    %end;
    %if %upcase(&_cstCompareCLI)=Y %then 
    %do;
      %if %length(&_cstCLValueVar) < 1 %then
      %do;
        %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstCLValueVar must be specified when _cstCompareCLI=Y.;
        %goto exit_error;
      %end;

      %if %cstutilcheckvarsexist(_cstDataSetName= &_cstBaseCT, _cstVarList=&_cstCLValueVar)=0
        %then %do;
          %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The &_cstCLValueVar column cannot be found in &_cstBaseCT..;
          %goto exit_error;
        %end;

      %if %cstutilcheckvarsexist(_cstDataSetName= &_cstNewCT, _cstVarList=&_cstCLValueVar)=0
        %then %do;
          %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The &_cstCLValueVar column cannot be found in &_cstNewCT..;
          %goto exit_error;
        %end;

    %end;
    %if %upcase(&_cstCompareCL)^=Y and %upcase(&_cstCompareCLI)^=Y %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] Either (or both) _cstCompareCL and _cstCompareCLI must be set to Y.;
      %goto exit_error;
    %end;
  %end;

  %if %length(&_cstRptType) < 1 %then
    %let _cstRptType=LOG;  
  %else %if %upcase(&_cstRptType) ^= LOG and %upcase(&_cstRptType) ^= DATASET and %upcase(&_cstRptType) ^= _CSTRESULTSDS %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptType value must be LOG or DATASET or _CSTRESULTSDS.;
    %goto exit_error;
  %end;
  %_cstutilreporting(_cstType=&_cstRptType,_cstDS=&_cstRptDS,_cstOWrite=&_cstOverwrite);

  %if %upcase(&_cstFileType)=CATALOG %then 
  %do;
    proc format lib=&_cstBaseCT cntlout=work.base_codelists_&_cstRandom (keep=fmtname start);
    run;
    proc format lib=&_cstNewCT cntlout=work.new_codelists_&_cstRandom (keep=fmtname start);
    run;
    
    %let _cstCLVar=fmtname;

    %if %upcase(&_cstCompareCL)=Y %then
    %do;
      %if %upcase(&_cstCompareCLI)^=Y %then 
        %let _cstCLValueVar=;
      proc sql noprint;
        create table work._cstbaseCL_&_cstRandom
        as select distinct fmtname 
        from work.base_codelists_&_cstRandom
        order by fmtname;
      quit;
      proc sql noprint;
        create table work._cstnewCL_&_cstRandom
        as select distinct fmtname
        from work.new_codelists_&_cstRandom
        order by fmtname;
      quit;

      data work._cstCLdiffs_&_cstRandom;
        merge work._cstbaseCL_&_cstRandom (in=old)
              work._cstnewCL_&_cstRandom (in=new);
          by fmtname;
        attrib message format=$500.
               actual format=$240.;
        if old ne new then 
        do;
          if old then 
          do;
            condition=1;
            message="Codelist found in &_cstBaseCT but not found in &_cstNewCT"; 
            actual=catx('=','Codelist',fmtname);
          end;
          else do;
            condition=2;
            message="Codelist found in &_cstNewCT but not found in &_cstBaseCT"; 
            actual=catx('=','Codelist',fmtname);
          end;
          output;
        end;
      run;
    %end;

    %if %upcase(&_cstCompareCLI)=Y %then
    %do;
      %let _cstCLValueVar=start;
      data work._cstCLIdiffs_&_cstRandom;
        merge work.base_codelists_&_cstRandom (in=old)
              work.new_codelists_&_cstRandom (in=new);
          by fmtname start;
        attrib message format=$500.
               actual format=$240.;
        if old ne new then 
        do;
          if old then 
          do;
            condition=3;
            message="Codelist value found in &_cstBaseCT but not found in &_cstNewCT"; 
            actual=cats(catx('=','Codelist',fmtname),', ',catx('=','Value',start));
          end;
          else do;
            condition=4;
            message="Codelist value found in &_cstNewCT but not found in &_cstBaseCT"; 
            actual=cats(catx('=','Codelist',fmtname),', ',catx('=','Value',start));
          end;
          output;
        end;
      run;
    %end;
  %end;
  %else %do;
    %if %upcase(&_cstCompareCL)=Y %then
    %do;
      %if %upcase(&_cstCompareCLI)^=Y %then 
        %let _cstCLValueVar=;
      proc sql noprint;
        create table work._cstbaseCL_&_cstRandom
        as select distinct &_cstCLVar
        from &_cstBaseCT
        order by &_cstCLVar;
      quit;
      proc sql noprint;
        create table work._cstnewCL_&_cstRandom
        as select distinct &_cstCLVar
        from &_cstNewCT
        order by &_cstCLVar;
      quit;

      data work._cstCLdiffs_&_cstRandom;
        merge work._cstbaseCL_&_cstRandom (in=old)
              work._cstnewCL_&_cstRandom (in=new);
          by &_cstCLVar;
        attrib message format=$500.
               actual format=$240.;
        if old ne new then 
        do;
          if old then 
          do;
            condition=1;
            message="Codelist found in &_cstBaseCT but not found in &_cstNewCT"; 
            actual=catx('=','Codelist',&_cstCLVar);
          end;
          else do;
            condition=2;
            message="Codelist found in &_cstNewCT but not found in &_cstBaseCT"; 
            actual=catx('=','Codelist',&_cstCLVar);
          end;
          output;
        end;
      run;
    %end;

    %if %upcase(&_cstCompareCLI)=Y %then
    %do;
      proc sort data=&_cstBaseCT (keep=&_cstCLVar &_cstCLValueVar) 
                out=work.base_codelists_&_cstRandom;
        by &_cstCLVar &_cstCLValueVar;
      run;
      proc sort data=&_cstNewCT (keep=&_cstCLVar &_cstCLValueVar) 
                out=work.new_codelists_&_cstRandom;
        by &_cstCLVar &_cstCLValueVar;
      run;
      data work._cstCLIdiffs_&_cstRandom;
        merge work.base_codelists_&_cstRandom (in=old)
              work.new_codelists_&_cstRandom (in=new);
          by &_cstCLVar &_cstCLValueVar;
        attrib message format=$500.
               actual format=$240.;
        if old ne new then 
        do;
          if old then 
          do;
            condition=3;
            message="Codelist value found in &_cstBaseCT but not found in &_cstNewCT"; 
            actual=cats(catx('=','Codelist',&_cstCLVar),', ',catx('=','Value',&_cstCLValueVar));
          end;
          else do;
            condition=4;
            message="Codelist value found in &_cstNewCT but not found in &_cstBaseCT"; 
            actual=cats(catx('=','Codelist',&_cstCLVar),', ',catx('=','Value',&_cstCLValueVar));
          end;
          output;
        end;
      run;
    %end;
  %end;

  data work._cstDifferences_&_cstRandom;
    %if %sysfunc(exist(work._cstCLdiffs_&_cstRandom)) or %sysfunc(exist(work._cstCLIdiffs_&_cstRandom)) %then 
    %do;
      set
      %if %sysfunc(exist(work._cstCLdiffs_&_cstRandom)) %then 
      %do;
        work._cstCLdiffs_&_cstRandom
      %end;
      %if %sysfunc(exist(work._cstCLIdiffs_&_cstRandom)) %then 
      %do;
        work._cstCLIdiffs_&_cstRandom
      %end;
      ;
    %end;
    %else %do;
      if _n_=1 then stop;
    %end;
  run;

  %let _cstCnt=%cstutilnobs(_cstDataSetName=work._cstDifferences_&_cstRandom);  
  
  %if &_cstCnt>0 %then
  %do;
    proc sort data=work._cstDifferences_&_cstRandom;
      by &_cstCLVar condition &_cstCLValueVar;
    run;

    %if %upcase(&_cstRptType)=LOG %then
    %do;
      data _null_;
        set work._cstDifferences_&_cstRandom;
        
        if _n_=1 then 
          put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] The following Controlled Terminology differences were detected:";
        put message;
        put @6 actual;
      run;
    %end;
    %else %if %upcase(&_cstRptType)=DATASET %then
    %do;
      data &_cstRptDS;
        set work._cstDifferences_&_cstRandom;
      run;
    %end;
    %else %do;
  
      data work._cstDifferences_&_cstRandom;
        set work._cstDifferences_&_cstRandom end=last;
          
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

      %cstutil_appendresultds(_cstErrorDS=work._cstDifferences_&_cstRandom,_cstVersion=1.2,_cstSource=CST,_cstOrderBy=seqno);
    %end;

  %end;
  %else
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] No differences between &_cstBaseCT and &_cstNewCT were detected.;

  %cstutil_deleteDataSet(_cstDataSetName=work._cstCLDiffs_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstCLIDiffs_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstDifferences_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work.base_codelists_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work.new_codelists_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstbasecl_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstnewcl_&_cstRandom);


%exit_error:

%mend cstutilcomparecodelists;
