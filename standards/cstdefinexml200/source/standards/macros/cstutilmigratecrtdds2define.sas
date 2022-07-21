%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilmigratecrtdds2define                                                    *;
%*                                                                                *;
%* Migrates source metadata data sets from CRT-DDS v1.0 to Define-XML v2.0.       *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The librefs in the macro parameters have been allocated.                  *;
%*   2. If _cstSrcDS exists in the _cstTrgLib, it is overwritten.                 *;
%*                                                                                *;
%* @macvar &_cstReturn Task error status                                          *;
%* @macvar &_cstReturnMsg Message associated with _cst_rc                         *;
%*                                                                                *;
%* @param  _cstSrcLib - required - The libname for the CRT-DDS version 1 source   *;
%*            metadata data set to migrate to Define-XML version 2.               *;
%* @param  _cstSrcDS - required - The name of the CRT-DDS version 1 source        *;
%*            metadata data set to migrate to Define-XML version 2.               *;
%* @param  _cstSrcType - conditionally required - The type of the CRT-DDS version *;
%*            1 source metadata data set to migrate to Define-XML version 2.      *;
%*            Required in case _cstSrcDS does not have one of the values:         *;
%*              source_study, source_tables, source_columns, source_values,       *;
%*              source_documents                                                  *;
%*            Values: study | table| column | value | document | analysisresult   *;
%* @param  _cstTrgDS - required - The (libname.)member for the Define-XML         *;
%*            version 2 metadata data set to migrate from CRT-DDS version 1.      *;
%* @param  _cstStudyVersion - required - The study identifier to use to bind      *;
%*            together the source data sets and as ODM/Study/MetaDataVersion/@OID *;
%*            in the define.xml file.                                             *;
%* @param  _cstStandard - optional - The target standard. This value is used for  *;
%*            some standard-specific checking and migration.                      *;
%*            Values: CDISC-ADAM | CDISC-SDTM | CDISC-SEND                        *;
%* @param  _cstStandardVersion - optional - The target standard version.          *;
%* @param  _cstCheckValues - required - Validate the content.                     *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param  _cstReturn - required - The macro variable that contains the return    *;
%*            value as set by this macro.                                         *;
%*            Default: _cst_rc                                                    *;
%* @param  _cstReturnMsg - required - The macro variable that contains the return *;
%*            message as set by this macro.                                       *;
%*            Default: _cst_rcmsg                                                 *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilmigratecrtdds2define(
  _cstSrcLib=,
  _cstSrcDS=,
  _cstSrcType=, 
  _cstTrgDS=,
  _cstStudyVersion=, 
  _cstStandard=, 
  _cstStandardVersion=,
  _cstCheckValues=N,
  _cstReturn=_cst_rc,
  _cstReturnMsg=_cst_rcmsg
  ) / des = "CST: migrate source metadata data sets";

  %local i _cstReqParams _cstReqParam _cstRandom _cstVars
         _cstTrgLib _cstRandom;

  %let cstRandom=%sysfunc(putn(%sysevalf(%sysfunc(ranuni(0))*10000,floor),z4.));

  %***************************************************;
  %*  Check _cstReturn and _cstReturnMsg parameters  *;
  %***************************************************;
  %if (%length(&_cstReturn)=0) or (%length(&_cstReturnMsg)=0) %then %do;
    %* We are not able to communicate other than to the LOG;
    %put ERR%str(OR): [CSTLOG%str(MESSAGE).&sysmacroname] %str
      ()macro parameters _CSTRETURN and _CSTRETURNMSG can not be missing.;
    %goto exit_macro_nomsg;
  %end;

  %if (%eval(not %symexist(&_cstReturn))) %then %global &_cstReturn;
  %if (%eval(not %symexist(&_cstReturnMsg))) %then %global &_cstReturnMsg;

  %*************************************************;
  %*  Set _cstReturn and _cstReturnMsg parameters  *;
  %*************************************************;
  %let &_cstReturn=0;
  %let &_cstReturnMsg=;

  %let _cstRandom=%sysfunc(putn(%sysevalf(%sysfunc(ranuni(0))*10000,floor),z4.));

  %* Check required parameters;
  %let _cstReqParams=_cstSrcLib _cstSrcDS _cstTrgDS _cstStudyVersion _cstCheckValues;
  %do i=1 %to %sysfunc(countw(&_cstReqParams));
     %let _cstReqParam=%kscan(&_cstReqParams, &i);
     %if %sysevalf(%superq(&_cstReqParam)=, boolean) %then %do;
        %let &_cstReturn=1;
        %let &_cstReturnMsg=&_cstReqParam parameter value is required.;
        %goto exit_macro;
     %end;
  %end;

  %* This logic is needed to maintain backward compatibility because of the new _cstSrcType parameter;
  %if %sysevalf(%superq(_cstSrcType)=, boolean) %then %do;
    %if "%upcase(&_cstSrcDS)" eq "SOURCE_STUDY" %then %let _cstSrcType=study;
    %if "%upcase(&_cstSrcDS)" eq "SOURCE_TABLES" %then %let _cstSrcType=table;
    %if "%upcase(&_cstSrcDS)" eq "SOURCE_COLUMNS" %then %let _cstSrcType=column;
    %if "%upcase(&_cstSrcDS)" eq "SOURCE_VALUES" %then %let _cstSrcType=value;
    %if "%upcase(&_cstSrcDS)" eq "SOURCE_DOCUMENTS" %then %let _cstSrcType=document;
  %end;

  %if "%upcase(&_cstSrcType)" ne "STUDY" and 
      "%upcase(&_cstSrcType)" ne "TABLE" and 
      "%upcase(&_cstSrcType)" ne "COLUMN" and 
      "%upcase(&_cstSrcType)" ne "VALUE" and 
      "%upcase(&_cstSrcType)" ne "DOCUMENT" and
      "%upcase(&_cstSrcType)" ne "ANALYSISRESULT" %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=_cstSrcType=%str(&_cstSrcType) must be study, table, column, value, document or analysisresult.;
    %goto exit_macro;
  %end;

  %if %upcase(&_cstCheckValues) ne N and %upcase(&_cstCheckValues) ne Y %then 
  %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=_cstCheckValues value must be Y or N.;
    %goto exit_macro;
  %end;
  %else %do;
    %* We can only check for known standards;    
    %if "%upcase(&_cstStandard)" ne "CDISC-ADAM" and 
        "%upcase(&_cstStandard)" ne "CDISC-SDTM" and 
        "%upcase(&_cstStandard)" ne "CDISC-SEND" %then 
    %do;
      %let &_cstReturn=1;
      %let &_cstReturnMsg=When _cstCheckValues=Y, _cstStandard=%str(&_cstStandard) value must be %str(CDISC-ADAM, CDISC-SDTM or CDISC-SEND).;
      %goto exit_macro;
    %end;
  %end;
  
  %* Check source libref;
  %if (%sysfunc(libref(&_cstSrcLib))) %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Libref _cstSrcLib=&_cstSrcLib has not been assigned.;
    %goto exit_macro;
  %end;  


  %* Check target library;
  %if %sysfunc(kindexc(&_cstTrgDS,.)) %then %do;  
    %let _cstTrgLib=%sysfunc(scan(%trim(%left(&_cstTrgDS)),1,.));
    %if %sysfunc(libref(&_cstTrgLib)) %then %do;
      %let &_cstReturn=1;
      %let &_cstReturnMsg=Libref &_cstTrgLib in _cstTrgDS parameter has not been assigned.;
      %goto exit_macro;
    %end;  
  %end;

  %*************************************************;
  %* Support macro                                 *;
  %*************************************************;
  %macro cst_attr_check(displayvar=, checkvar=, allowedvalues=);
    %if &_cstCheckValues=Y %then %do;
      if not (&checkvar in (&allowedvalues)) then 
      %if %sysevalf(%superq(displayvar)=, boolean) %then
        put "WAR%str(NING): [CSTLOG%str(MESSAGE).&sysmacroname] " &checkvar.= "has to be in (&allowedvalues)";
      %else  
        put "WAR%str(NING): [CSTLOG%str(MESSAGE).&sysmacroname] " &displayvar &checkvar.= "has to be in (&allowedvalues)";;
    %end;
  %mend cst_attr_check;
      
  %******************************************************;
  %*   source_study metadata                            *;
  %******************************************************;
  %if %upcase(&_cstSrcType)=STUDY %then %do;
    
    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType,_cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=definedocumentname);
      set &_cstSrcLib..&_cstSrcDS;

      %if %sysfunc(cexist(work.formats._cststd.formatc)) %then %do; 
        formalstandardname=put(formalstandardname, $_cststd.);
      %end;
      
      %if %sysfunc(cexist(work.formats._cststv.formatc)) %then %do; 
        formalstandardversion=put(formalstandardversion, $_cststv.);
      %end;

      %* attribute checks;
      %cst_attr_check(checkvar=formalstandardname, 
         allowedvalues=%str('SDTM-IG' 'SEND-IG' 'ADaM-IG'));
     run;  
    
  %end;

  %******************************************************;
  %*   source_tables metadata                           *;
  %******************************************************;
  %if %upcase(&_cstSrcType)=TABLE %then %do;
    
    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType,_cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=standardref purpose1);
      length domain $32 comment $1000. label $200. purpose $10.;
      set &_cstSrcLib..&_cstSrcDS(rename=(purpose=purpose1));
      purpose=purpose1;
      
      %if %sysfunc(cexist(work.formats._cstcls.formatc)) %then %do;
        class=put(upcase(class), $_cstcls.);
      %end;
      
      order=_n_;

      domain="";
      %if %sysfunc(cexist(work.formats._cstdom.formatc)) %then %do;
        domain=strip(put(table, $_cstdom32.));
      %end;

      if (domain ne table) and (not missing(domain)) then do;
        %if %sysfunc(cexist(work.formats._cstdomd.formatc)) %then %do;
          length domaindescription $256;
          domaindescription=put(table, $_cstdomd.);
        %end;
      end;
      
      if not missing(keys) then do;
        if indexw(upcase(strip(reverse(Keys))),"DIJBUSU")>1
          then Repeating = "Yes";
          else Repeating = "No";
        if indexw(upcase(Keys) ,"USUBJID")
          then IsReferenceData = "No";
          else IsReferenceData = "Yes";
      end;

      %* attribute checks;
      %if %upcase("&_cstStandard")="CDISC-ADAM" %then %do;
        %cst_attr_check(checkvar=purpose, displayvar=%str(table=), allowedvalues=%str('Analysis'));
        %cst_attr_check(checkvar=class, displayvar=%str(table=),  
           allowedvalues=%str('SUBJECT LEVEL ANALYSIS DATASET' 'BASIC DATA STRUCTURE' 'ADAM OTHER'));
      %end;
      %if %upcase("&_cstStandard")="CDISC-SDTM" or %upcase("&_cstStandard")="CDISC-SEND" %then %do;
        %cst_attr_check(checkvar=purpose, displayvar=%str(table=), allowedvalues=%str('Tabulation'));
        %cst_attr_check(checkvar=class, displayvar=%str(table=),  
           allowedvalues=%str('SPECIAL PURPOSE' 'FINDINGS' 'EVENTS' 'INTERVENTIONS' 'TRIAL DESIGN' 'RELATIONSHIP'));
      %end;  
    run;
    
  %end;
    
  %******************************************************;
  %*   source_columns metadata                          *;
  %******************************************************;
  %if %upcase(&_cstSrcType)=COLUMN %then %do;
    
    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType, _cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=term qualifiers standardref doctype)
         work.source_columns_documents_tmp(keep=sasref standard standardversion doctype table column origin);
      length displayformat $200. algorithmtype $11.;
      set &_cstSrcLib..&_cstSrcDS;
      if not missing(origin) then do;
        if index(upcase(origin), "CRF PAGE") then do;
          doctype="CRF";
          output work.source_columns_documents_tmp;
          origin="CRF";
        end;
      end;  

      if not missing (xmlcodelist) then xmlcodelist = 
        Ifc(ksubstr(upcase(xmlcodelist),1,3)="CL.",compress(xmlcodelist, '$'),"CL."||compress(xmlcodelist, '$'));
 
      if xmldatatype="float" and missing(SignificantDigits) and not missing(DisplayFormat) and index(DisplayFormat, ".") 
        then SignificantDigits=input(scan(DisplayFormat, 2, "."), ? best.); 

      if not missing(algorithm) and missing(algorithmtype) then algorithmtype="Computation";

      output work.&_cstSrcDS._&_cstRandom;

      %* attribute checks;
      %cst_attr_check(checkvar=xmldatatype, displayvar=%str(table= column=),
         allowedvalues=%str('text' 'integer' 'float' 'datetime' 'date' 'time' 'partialDate' 'partialTime' 'partialDatetime' 'incompleteDatetime' 'durationDatetime'));
      %cst_attr_check(checkvar=algorithmtype, displayvar=%str(table= column=),
         allowedvalues=%str('Computation' 'Imputation' 'Transpose' 'Other' ''));
      %if %upcase("&_cstStandard")="CDISC-ADAM" %then %do;
        %cst_attr_check(checkvar=origin, displayvar=%str(table= column=), 
           allowedvalues=%str('Derived' 'Assigned' 'Protocol' 'Predecessor' ''));
        %cst_attr_check(checkvar=core, displayvar=%str(table= column=), allowedvalues=%str('Req' 'Cond' 'Perm' 'Exp'));
      %end;
      %if %upcase("&_cstStandard")="CDISC-SDTM" %then %do;
        %cst_attr_check(checkvar=origin, displayvar=%str(table= column=),
           allowedvalues=%str('CRF' 'Derived' 'Assigned' 'Protocol' 'eDT' ''));
        %cst_attr_check(checkvar=core, displayvar=%str(table= column=), allowedvalues=%str('Req' 'Perm' 'Exp'));
      %end;  
      %if %upcase("&_cstStandard")="CDISC-SEND" %then %do;
        %cst_attr_check(checkvar=origin, displayvar=%str(table= column=),
           allowedvalues=%str('COLLECTED' 'DERIVED' 'OTHER' 'NOT AVAILABLE' ''));
        %cst_attr_check(checkvar=core, displayvar=%str(table= column=), allowedvalues=%str('Req' 'Perm' 'Exp'));
      %end;  
      %cst_attr_check(checkvar=type, displayvar=%str(table= column=), allowedvalues=%str('N' 'C'));
      
      %if &_cstCheckValues=Y %then %do;
        if xmldatatype="float" and missing(SignificantDigits) then
          put "WAR%str(NING): [CSTLOG%str(MESSAGE).&sysmacroname] " table= column= DisplayFormat= "xmldatatype='float', but SignificantDigits is missing.";
      %end;

    run;
    
    %if %cstutilnobs(_cstDatasetName=work.source_columns_documents_tmp) eq 0 %then %do;
      %cstutil_deleteDataSet(_cstDataSetName=work.source_columns_documents_tmp);
    %end;  
    
  %end;
    
  %******************************************************;
  %*   source_values metadata                           *;
  %******************************************************;
  %if %upcase(&_cstSrcType)=VALUE %then %do;

    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType,_cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=term qualifiers standardref tablecolumn doctype)
         work.source_values_documents_tmp(keep=sasref standard standardversion doctype table column whereclause origin);    
      length displayformat $200. tablecolumn $64 whereclause $1000 algorithmtype $11.;
      set &_cstSrcLib..&_cstSrcDS;
      tablecolumn=cats(table, ".", column);
      %if %upcase("&_cstStandard")="CDISC-ADAM" %then %do;
        if not missing(value) then do;
          whereclause=catx(" ", "PARAMCD EQ", cats('"', value, '"'));
          value="";
        end;  
      %end;
      %if %upcase("&_cstStandard")="CDISC-SDTM" or %upcase("&_cstStandard")="CDISC-SEND" %then %do;;
        if not missing(value) then do;
          whereclause=catx(" ", column, "EQ", cats('"', value, '"'));
          %if %sysfunc(cexist(work.formats._cstvlm.formatc)) %then %do;
            column=put(tablecolumn, $_cstvlm32.);  
          %end;
          value="";
        end;
      %end;
      if not missing(origin) then do;
        if index(upcase(origin), "CRF PAGE") then do;
          doctype="CRF";
          output work.source_values_documents_tmp;
          origin="CRF";
        end;
      end;

      if not missing (xmlcodelist) then xmlcodelist = 
        Ifc(ksubstr(upcase(xmlcodelist),1,3)="CL.",compress(xmlcodelist, '$'),"CL."||compress(xmlcodelist, '$'));

      if xmldatatype="float" and missing(SignificantDigits) and not missing(DisplayFormat) and index(DisplayFormat, ".") 
        then SignificantDigits=input(scan(DisplayFormat, 2, "."), ? best.); 

      if not missing(algorithm) and missing(algorithmtype) then algorithmtype="Computation";

      output work.&_cstSrcDS._&_cstRandom;

      %* attribute checks;
      %cst_attr_check(checkvar=xmldatatype, displayvar=%str(table= column= whereclause=), 
         allowedvalues=%str('text' 'integer' 'float' 'datetime' 'date' 'time' 'partialDate' 'partialTime' 'partialDatetime' 'incompleteDatetime' 'durationDatetime'));
      %cst_attr_check(checkvar=algorithmtype, displayvar=%str(table= column=),
         allowedvalues=%str('Computation' 'Imputation' 'Transpose' 'Other' ''));
      %if %upcase("&_cstStandard")="CDISC-ADAM" %then %do;
        %cst_attr_check(checkvar=origin,  displayvar=%str(table= column= whereclause=),
           allowedvalues=%str('Derived' 'Assigned' 'Protocol' 'Predecessor' ''));
        %cst_attr_check(checkvar=core, allowedvalues=%str('Req' 'Cond' 'Perm' 'Exp'));
      %end;
      %if %upcase("&_cstStandard")="CDISC-SDTM" %then %do;
        %cst_attr_check(checkvar=origin, displayvar=%str(table= column= whereclause=),
           allowedvalues=%str('CRF' 'Derived' 'Assigned' 'Protocol' 'eDT' ''));
        %cst_attr_check(checkvar=core,  displayvar=%str(table= column= whereclause=), allowedvalues=%str('Req' 'Perm' 'Exp'));
      %end;  
      %if %upcase("&_cstStandard")="CDISC-SEND" %then %do;
        %cst_attr_check(checkvar=origin, displayvar=%str(table= column= whereclause=),
           allowedvalues=%str('COLLECTED' 'DERIVED' 'OTHER' 'NOT AVAILABLE' ''));
        %cst_attr_check(checkvar=core,  displayvar=%str(table= column= whereclause=), allowedvalues=%str('Req' 'Perm' 'Exp'));
      %end;  
      %cst_attr_check(checkvar=type,  displayvar=%str(table= column= whereclause=), allowedvalues=%str('N' 'C'));

      %if &_cstCheckValues=Y %then %do;
        if xmldatatype="float" and missing(SignificantDigits) then
          put "WAR%str(NING): [CSTLOG%str(MESSAGE).&sysmacroname] " table= column= whereclause= DisplayFormat " xmldatatype='float', but SignificantDigits is missing.";
      %end;

    run;
    
    %if %cstutilnobs(_cstDatasetName=work.source_values_documents_tmp) eq 0 %then %do;
      %cstutil_deleteDataSet(_cstDataSetName=work.source_values_documents_tmp);
    %end;  

  %end;

  %******************************************************;
  %*   source_documents metadata                        *;
  %******************************************************;
  %if %upcase(&_cstSrcType)=DOCUMENT %then %do;

    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType, _cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=documentref);
      set &_cstSrcLib..&_cstSrcDS;
      select (doctype);
        when("CRF") output;
        when("DOC") do;
                      doctype="SUPPDOC";
                      output;
                    end;
        otherwise put "WAR%str(NING): [CSTLOG%str(MESSAGE).&sysmacroname] Documents not migrated: "
                      doctype= href= title=;
      end;
    run;

    %if %sysfunc(exist(work.source_columns_documents_tmp)) or
        %sysfunc(exist(work.source_values_documents_tmp)) %then %do;
      data work._cst_docs_&_cstRandom(rename=(origin=pdfpagerefs));
        set %if %sysfunc(exist(work.source_columns_documents_tmp)) %then work.source_columns_documents_tmp;
            %if %sysfunc(exist(work.source_values_documents_tmp)) %then work.source_values_documents_tmp;
            ;
      run;
    
      data work.&_cstSrcDS._2_&_cstRandom;
        merge work.&_cstSrcDS._&_cstRandom work._cst_docs_&_cstRandom;
        by sasref standard standardversion doctype;
      run;    
    %end;
    %else %do;
      data work.&_cstSrcDS._2_&_cstRandom;
        length pdfpagerefs $200;
        set work.&_cstSrcDS._&_cstRandom;
        call missing(pdfpagerefs);
      run;
    %end;  

    data work.&_cstSrcDS._&_cstRandom;
      set work.&_cstSrcDS._2_&_cstRandom;
      if index(upcase(pdfpagerefs), "CRF PAGE") then do;
        pdfpagereftype="PhysicalRef";
        pdfpagerefs=compress(pdfpagerefs, ",", 'a');
      end;
      %* attribute checks;
      if not missing(pdfpagereftype) then do;
        %cst_attr_check(checkvar=pdfpagereftype, displayvar=%str(table= column= whereclause=), allowedvalues=%str('PhysicalRef' 'NamedDestination'));
      end;
    run;
     
    %* Clean-up;
    %if not &_cstDebug %then %do;
      %cstutil_deleteDataSet(_cstDataSetName=work.source_columns_documents_tmp);
      %cstutil_deleteDataSet(_cstDataSetName=work.source_values_documents_tmp);
      %cstutil_deleteDataSet(_cstDataSetName=work._cst_docs_&_cstRandom);
      %cstutil_deleteDataSet(_cstDataSetName=work.&_cstSrcDS._2_&_cstRandom);
    %end;

  %end;

  %******************************************************;
  %*   source_analysisresults metadata                  *;
  %******************************************************;

  %if %upcase(&_cstSrcType)=ANALYSISRESULT %then %do;

    %cst_createdsfromtemplate(
      _cstStandard=CDISC-DEFINE-XML,_cstStandardVersion=2.0.0,
      _cstType=studymetadata,_cstSubType=&_cstSrcType, _cstOutputDS=work.&_cstSrcDS._tmpl_&_cstRandom
      );
     %let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom,_cstAttribute=LABEL);

    %* Check source dataset;
    %if not %sysfunc(exist(&_cstSrcLib..&_cstSrcDS)) %then %do;
      data &_cstTrgDS
        %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
        set work.&_cstSrcDS._tmpl_&_cstRandom;
      run;  

      %if %sysfunc(exist(&_cstTrgDS)) %then
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

      %goto exit_macro;
    %end;  

    data work.&_cstSrcDS._&_cstRandom(drop=_cstCounter resultid datasets selcrit param paramcd progstmt xmlpath reason);
      length table $%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom, _cstVarName=table, _cstAttribute=VARLEN)
             whereclause $%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom, _cstVarName=whereclause, _cstAttribute=VARLEN)
             resultidentifier $%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom, _cstVarName=resultidentifier, _cstAttribute=VARLEN)
             analysisreason $%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom, _cstVarName=analysisreason, _cstAttribute=VARLEN)
             analysispurpose $%cstutilgetattribute(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom, _cstVarName=analysispurpose, _cstAttribute=VARLEN)
             ;;
      set &_cstSrcLib..&_cstSrcDS(
       rename=(dispid=displayidentifier 
               dispname=displaydescription 
               xmltitle=resultdescription 
               analvar=analysisvariables 
               document=resultdocumentation
               ));
      displayname=compress(displayidentifier, '_');
      resultidentifier=cats(displayidentifier, ".", resultid);
      whereclause=selcrit;
      whereclause=tranwrd(whereclause, "=", " EQ ");
      %if %sysfunc(cexist(work.formats._cstar.formatc)) %then %do;
        analysisreason=put(upcase(reason), $_cstar.);
      %end;
      %if %sysfunc(cexist(work.formats._cstap.formatc)) %then %do;
        if missing(analysisreason) then analysispurpose=put(upcase(reason), $_cstap.);
      %end;
      
      if index(upcase(whereclause), 'PARAMCD') then parametercolumn="PARAMCD";
      %* Only add code if it does not seem to be a path to a code module;
      if kindexc(kscan(progstmt, 1, ' '),':\/.') = 0 then code=progstmt;
      CodeContext="SAS version &SYSVER";

      _cstCounter=1;
      table=kscan(datasets, _cstCounter);
      do while (not missing(table));
        output;
        _cstCounter = _cstCounter + 1;
        table=kscan(datasets, _cstCounter);
      end;
    run;

  %end;

  %******************************************************;

  data &_cstTrgDS
    %if %length(&_cstDSLabel)>0 %then (label="%nrbquote(&_cstDSLabel)");;
    set work.&_cstSrcDS._tmpl_&_cstRandom work.&_cstSrcDS._&_cstRandom;
    format _character_ _numeric_;
    if missing(SASRef) then SASRef="SRCDATA";
    if missing(StudyVersion) then StudyVersion="&_cstStudyVersion";
    if missing(Standard) then Standard="&_cstStandard";   
    if missing(StandardVersion) then StandardVersion="&_cstStandardVersion";   
  run;  
  
  %* Clean-up;
  %if not &_cstDebug %then %do;
    %cstutil_deleteDataSet(_cstDataSetName=work.&_cstSrcDS._&_cstRandom);
  %end;
  
  %if %sysfunc(exist(&_cstTrgDS)) %then
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] Data set &_cstTrgDS has been created with %cstutilnobs(_cstDataSetName=&_cstTrgDS) observation(s).;

  %exit_macro:
    %if %length(&&&_cstReturnMsg) %then 
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &&&_cstReturnMsg;


  %if not &_cstDebug %then %do;
    %cstutil_deleteDataSet(_cstDataSetName=work.&_cstSrcDS._tmpl_&_cstRandom);
  %end;

  %exit_macro_nomsg:

%mend cstutilmigratecrtdds2define;
