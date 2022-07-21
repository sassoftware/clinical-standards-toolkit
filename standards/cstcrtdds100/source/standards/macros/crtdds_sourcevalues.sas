%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_sourcevalues                                                            *;
%*                                                                                *;
%* Creates the SAS CRT-DDS value level metadata data sets from source metadata.   *;
%*                                                                                *;
%* @macvar &_cstReturn Task error status                                          *;
%* @macvar &_cstReturnMsg Message associated with _cst_rc                         *;
%*                                                                                *;
%* @param _cstSourceValues - optional - The data set that contains the SDTM       *;
%*            metadata for the Value Level columns to include in the CRT-DDS file.*;
%*            Default: sampdata.source_values                                     *;
%* @param _cstSourceStudy Required. The data set that contains the metadata for   *;
%*            the studies to include in the CRT-DDS file.                         *;
%*            Default: sampdata.source_study                                      *;
%* @param _cstStudyDS - required - The Study data set in the output library.      *;
%*            Default: srcdata.Study                                              *;
%* @param _cstmdvDS - required - The MetaDataVersion data set in the output       *;
%*            library.                                                            *;
%*            Default: srcdata.MetaDataVersion                                    *;
%* @param _cstCodeListsDS - required - The CodeLists data set in the output       *;
%*            library.                                                            *;
%*            Default: srcdata.CodeLists                                          *;
%* @param _cstItemGroupDefsDS - required - The ItemGroupDefs data  set in the     *;
%*            output library.                                                     *;
%*            Default: srcdata.ItemGroupDefs                                      *;
%* @param _cstItemGroupDefItemRefsDS - required - The _cstItemGroupDefItemRefs    *;
%*            data set in the output library.                                     *;
%*            Default: srcdata.ItemGroupDefItemRefs                               *;
%* @param _cstoutItemDefs - required - The ItemDefs data set to create.           *;
%*            Default: srcdata.ItemDefs                                           *;
%* @param _cstoutValueLists - required - The ValueLists data set to create.       *;
%*            Default: srcdata.ValueLists                                         *;
%* @param _cstoutValueListItemRefs - required - The ValueListItemRefs data set to *;
%*            create.                                                             *;
%*            Default: srcdata.ValueListItemRefs                                  *;
%* @param _cstoutItemValueListRefs - required - The ItemValueListRefs data set to *;
%*            create.                                                             *;
%*            Default: srcdata.ItemValueListRefs                                  *;
%* @param _cstoutcomputationmethods - required - The ComputationMethods data set  *;
%*            to create.                                                          *;
%*            Default: srcdata.ComputationMethods                                 *;
%* @param _cstStandard - required - The value of the StandardName column in the   *;
%*            _cstmdvDS data set.                                                 *;
%*            Default: CDISC SDTM                                                 *;
%* @param _cstStandardVersion  - required - The value of the StandardVersion      *;
%*            column in the _cstmdvDS data set.                                   *;
%*            Default: 3.1.2                                                      *;
%* @param _cstMode - required - Append to or replace the output data sets.        *;
%*            Values: append | replace                                            *;
%*            Default: replace                                                    *;
%* @param _cstReturn - required - The macro variable that contains the return     *;
%*            value as set by this macro.                                         *;
%*            Default: _cst_rc                                                    *;
%* @param _cstReturnMsg - required - The macro variable that contains the return  *;
%*            message as set by this macro.                                       *;
%*            Default: _cst_rcmsg                                                 *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_sourcevalues(
    _cstsourcevalues=sampdata.source_values,
    _cstsourcestudy=sampdata.source_study,
    _cstStudyDS=srcdata.Study,
    _cstmdvDS=srcdata.MetaDataVersion,
    _cstCodeListsDS=srcdata.CodeLists,
    _cstItemGroupDefsDS=srcdata.ItemGroupDefs,
    _cstItemGroupDefItemRefsDS=srcdata.ItemGroupDefItemRefs,
    _cstoutItemDefs=srcdata.ItemDefs,
    _cstoutValueLists=srcdata.ValueLists,
    _cstoutValueListItemRefs=srcdata.ValueListItemRefs,
    _cstoutItemValueListRefs=srcdata.ItemValueListRefs,
    _cstoutComputationMethods=srcdata.ComputationMethods,
    _cstStandard=CDISC SDTM,
    _cstStandardVersion=3.1.2,
    _cstMode=replace,
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg
    ) / des="Creates SAS CRT-DDS value level metadata data sets";

%local _cstMissing _cstRandom _cstmdv ds1 ds2 ds3 ds4 ds5 ds6 mode;

%***************************************************;
%*  Check _cstReturn and _cstReturnMsg parameters  *;
%***************************************************;
%if (%length(&_cstReturn)=0) or (%length(&_cstReturnMsg)=0) %then %do;
  %* We are not able to communicate other than to the LOG;
  %put %str(ERR)OR:(&sysmacroname) %str
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

%******************************************************************************;
%* Parameter checks                                                           *;
%******************************************************************************;
%let _cstMissing=;
%if %sysfunc(strip("&_cstsourcevalues"))="" %then %let _cstMissing = &_cstMissing _cstsourcevalues;
%if %sysfunc(strip("&_cstsourcestudy"))="" %then %let _cstMissing = &_cstMissing _cstsourcestudy;
%if %sysfunc(strip("&_cstStudyDS"))="" %then %let _cstMissing = &_cstMissing _cstStudyDS;
%if %sysfunc(strip("&_cstmdvDS"))="" %then %let _cstMissing = &_cstMissing _cstmdvDS;
%if %sysfunc(strip("&_cstCodeListsDS"))="" %then %let _cstMissing = &_cstMissing _cstCodeListsDS;
%if %sysfunc(strip("&_cstItemGroupDefsDS"))="" %then %let _cstMissing = &_cstMissing _cstItemGroupDefsDS;
%if %sysfunc(strip("&_cstItemGroupDefItemRefsDS"))="" %then %let _cstMissing = &_cstMissing _cstItemGroupDefItemRefsDS;
%if %sysfunc(strip("&_cstoutItemDefs"))="" %then %let _cstMissing = &_cstMissing _cstoutItemDefs;
%if %sysfunc(strip("&_cstoutValueLists"))="" %then %let _cstMissing = &_cstMissing _cstoutValueLists;
%if %sysfunc(strip("&_cstoutValueListItemRefs"))="" %then %let _cstMissing = &_cstMissing _cstoutValueListItemRefs;
%if %sysfunc(strip("&_cstoutItemValueListRefs"))="" %then %let _cstMissing = &_cstMissing _cstoutItemValueListRefs;
%if %sysfunc(strip("&_cstoutComputationMethods"))="" %then %let _cstMissing = &_cstMissing _cstoutComputationMethods;
%if %sysfunc(strip("&_cstStandard"))="" %then %let _cstMissing = &_cstMissing _cstStandard;
%if %sysfunc(strip("&_cstStandardVersion"))="" %then %let _cstMissing = &_cstMissing _cstStandardVersion;
%if %sysfunc(strip("&_cstMode"))="" %then %let _cstMissing = &_cstMissing _cstMode;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Required macro parameter(s) missing: &_cstMissing;
    %goto exit_macro;
  %end;

%if "%upcase(&_cstMode)" ne "APPEND" and "%upcase(&_cstMode)" ne "REPLACE"
  %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Invalid _cstMode value (&_cstMode): should be APPEND or REPLACE;
    %goto exit_macro;
  %end;


%let _cstMissing=;
%* Expected source data sets  *;
%if ^%sysfunc(exist(&_cstsourcevalues)) %then %let _cstMissing = &_cstMissing _cstsourcevalues=&_cstsourcevalues;
%if ^%sysfunc(exist(&_cstsourcestudy)) %then %let _cstMissing = &_cstMissing _cstsourcestudy=&_cstsourcestudy;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Expected source data set(s) not existing: &_cstMissing;
    %goto exit_macro;
  %end;

%let _cstMissing=;
%* Expected CRT-DDS data sets, may be 0-observation  *;
%if ^%sysfunc(exist(&_cstStudyDS)) %then %let _cstMissing = &_cstMissing _cstStudyDS=&_cstStudyDS;
%if ^%sysfunc(exist(&_cstmdvDS)) %then %let _cstMissing = &_cstMissing _cstmdvDS=&_cstmdvDS;
%if ^%sysfunc(exist(&_cstCodeListsDS)) %then %let _cstMissing = &_cstMissing _cstCodeListsDS=&_cstCodeListsDS;
%if ^%sysfunc(exist(&_cstItemGroupDefsDS)) %then %let _cstMissing = &_cstMissing _cstItemGroupDefsDS=&_cstItemGroupDefsDS;
%if ^%sysfunc(exist(&_cstItemGroupDefItemRefsDS)) %then %let _cstMissing = &_cstMissing _cstItemGroupDefItemRefsDS=&_cstItemGroupDefItemRefsDS;
%if ^%sysfunc(exist(&_cstoutItemDefs)) %then %let _cstMissing = &_cstMissing _cstoutItemDefs=&_cstoutItemDefs;
%if ^%sysfunc(exist(&_cstoutValueLists)) %then %let _cstMissing = &_cstMissing _cstoutValueLists=&_cstoutValueLists;
%if ^%sysfunc(exist(&_cstoutValueListItemRefs)) %then %let _cstMissing = &_cstMissing _cstoutValueListItemRefs=&_cstoutValueListItemRefs;
%if ^%sysfunc(exist(&_cstoutItemValueListRefs)) %then %let _cstMissing = &_cstMissing _cstoutItemValueListRefs=&_cstoutItemValueListRefs;
%if ^%sysfunc(exist(&_cstoutComputationMethods)) %then %let _cstMissing = &_cstMissing _cstoutComputationMethods=&_cstoutComputationMethods;
%if %length(&_cstMissing) gt 0
  %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=Expected CRT-DDS data set(s) not existing: &_cstMissing;
    %goto exit_macro;
  %end;

%******************************************************************************;
%* End of parameter checks                                                    *;
%******************************************************************************;

%let mode=;
%if %upcase(&_cstMode)=REPLACE %then %let mode=%str(obs=0);

%* get metadataversion/@oid  *;
proc sql noprint;
 select OID_mdv into :_cstmdv separated by '' from (
   select OID_mdv
   from &_cstsourcestudy a left join
     (select a.oid as Study_OID, a.studyname,
             b.OID as OID_mdv, b.StandardName, b.StandardVersion
      from &_cstStudyDS a left join &_cstmdvDS b
      on (a.oid = b.FK_Study)) b
   on (a.studyname = b.studyname)
 )
 ;
quit;
%* There should only be one MetaDataVersion element *;
%If &sqlobs ne 1
  %then %do;
    %let &_cstReturn=1;
    %let &_cstReturnMsg=More than one MetaDataVersion element;
    %goto exit_macro;
  %end;

%******************************************************************************;
%* Read source metadata                                                       *;
%******************************************************************************;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds1=_srcval1&_cstRandom;
%let ds2=_srcval2&_cstRandom;
%let ds3=_srcval3&_cstRandom;
%let ds4=_srcval4&_cstRandom;
%let ds5=_srcval5&_cstRandom;
%let ds6=_srcval6&_cstRandom;

%* Create data set with table, column and ItemDef/@OID *;
proc sql;
  create table &ds1 as
  select a.*, b.Name as column
  from
    (select a.Name as table, b.ItemOiD as FK_ItemDefs
     from &_cstItemGroupDefsDS a left join &_cstItemGroupDefItemRefsDS b
     on (a.oid = b.fk_itemgroupdefs) and (a.fk_metadataversion = "&_cstmdv")) a
   left join &_cstoutItemDefs b
   on (a.FK_ItemDefs =b.OID) and (b.fk_metadataversion = "&_cstmdv")
  ;
quit;

%* Create fk_metadataversion and ValueListDef/@OID *;
data &ds2(rename=(Role=SourceRole));
length fk_metadataversion ValueListOID ItemOID ComputationMethodOID $128 Mandatory $3;
  set &_cstsourcevalues;
  fk_metadataversion="&_cstmdv";
  ValueListOID=cats("VL.", table, ".", column);
  ItemOID=catx(".", "IT", table, column, value);
  if not missing(algorithm) then ComputationMethodOID=catx(".", "CM", table, column, value);
  Mandatory = ifc(upcase(core)='REQ','Yes','No', 'No');
run;

%* join to get ItemOID and the CodeList OID *;
proc sql;
  create table &ds3 as
select a.*, b.OID as CodeListRef from
  (select a.*, b.FK_ItemDefs
  from &ds2 a left join &ds1 b
  on (a.table = b.table) and (a.column = b.column)) a
  left join &_cstCodeListsDS b
  on (a.xmlcodelist =b.Name) and (b.fk_metadataversion = "&_cstmdv")
  order by ItemOID, order
  ;
quit;

data &ds3;
  set &ds3;
  length SignificantDigits 8;
  if xmldatatype="float" and missing(SignificantDigits) and not missing(DisplayFormat) and index(DisplayFormat, ".") 
    then SignificantDigits=input(scan(DisplayFormat, 2, "."), ? best.); 
  if not (xmldatatype in ('text' 'string' 'integer' 'float')) then length=.;
run;

%******************************************************************************;
%* Create output data sets                                                    *;
%******************************************************************************;
proc sort data=&ds3 out=&ds4(keep=ValueListOID fk_metadataversion) nodupkey;
by ValueListOID;
run;

data &_cstoutValueLists;
  set &_cstoutValueLists(&mode) &ds4(rename=(ValueListOID=OID));
run;
%******************************************************************************;

proc sort data=&ds3 out=&ds5(keep=ValueListOID FK_ItemDefs) nodupkey;
by ValueListOID FK_ItemDefs;
run;

data &_cstoutItemValueListRefs;
  set &_cstoutItemValueListRefs(&mode) &ds5;
run;
%******************************************************************************;

data &_cstoutValueListItemRefs
       (keep=ItemOID OrderNumber Mandatory KeySequence
             ImputationMethodOID Role RoleCodeListOID FK_ValueLists);
  set &_cstoutValueListItemRefs(&mode)
      &ds3(rename=(ValueListOID=FK_ValueLists order=OrderNumber));
  Role=kstrip(SourceRole);  
  if not missing(SourceRole) then do;
    if length(Role) < length(kstrip(SourceRole)) then do;
      put "[CSTLOG%str(MESSAGE).&sysmacroname] WAR" "NING: Data truncation in Role.";
      put "[CSTLOG%str(MESSAGE).&sysmacroname] " FK_ValueLists= ItemOID=;
      put "[CSTLOG%str(MESSAGE).&sysmacroname]        Value: " Role;
      put "[CSTLOG%str(MESSAGE).&sysmacroname] Source Value: " SourceRole /;
    end;
  end;  
run;

%******************************************************************************;

%* add to existing ItemDefs;
data &_cstoutItemDefs(keep=OID Name DataType Length SignificantDigits SASFieldName SDSVarName Origin Comment CodeListRef Label DisplayFormat ComputationMethodOID FK_MetaDataVersion);
  set &_cstoutItemDefs
      &ds3(rename=(value=Name ItemOID=OID xmldatatype=DataType));
run;



%******************************************************************************;

proc sort data=&ds3 out=&ds6(keep=fk_metadataversion ComputationMethodOID algorithm where=(not missing(algorithm)));
by ComputationMethodOID;
run;

%* add to existing ComputationMethods;
data &_cstoutComputationMethods;
  set &_cstoutComputationMethods
      &ds6(rename=(ComputationMethodOID=OID algorithm=Method));
run;


%* Clean up *;
%cstutil_deleteDataSet(_cstDataSetName=work.&ds1);
%cstutil_deleteDataSet(_cstDataSetName=work.&ds2);
%cstutil_deleteDataSet(_cstDataSetName=work.&ds3);
%cstutil_deleteDataSet(_cstDataSetName=work.&ds4);
%cstutil_deleteDataSet(_cstDataSetName=work.&ds5);
%cstutil_deleteDataSet(_cstDataSetName=work.&ds6);

%exit_macro:
%if %length(&&&_cstReturnMsg) ne 0 %then %put ERR%str(OR)(&sysmacroname): &&&_cstReturnMsg;

%exit_macro_nomsg:

%mend crtdds_sourcevalues;
