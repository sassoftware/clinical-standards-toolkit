%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_sourcedocuments                                                         *;
%*                                                                                *;
%* Creates the SAS CRT-DDS SourceDocuments-related data sets from source metadata.*;
%*                                                                                *;
%* @macvar &_cstReturn Task error status                                          *;
%* @macvar &_cstReturnMsg Message associated with _cst_rc                         *;
%*                                                                                *;
%* @param _cstSourceDocuments - optional - The data set that contains the SDTM    *;
%*            metadata for document references to include in the CRT-DDS file.    *;
%*            Default: sampdata.source_documents                                  *;
%* @param _cstSourceStudy - required - The data set that contains the metadata    *;
%*            for the studies to include in the CRT-DDS file.                     *;
%*            Default: sampdata.source_study                                      *;
%* @param _cstStudyDS - required - The Study dataset in the output library.       *;
%*            Default: srcdata.Study                                              *;
%* @param _cstmdvDS - required - The MetaDataVersion dataset in the output        *;
%*            library.                                                            *;
%*            Default: srcdata.MetaDataVersion                                    *;
%* @param _cstoutAnnotatedCRFs - required - The AnnotatedCRFs data set to create. *;
%*            Default: srcdata.AnnotatedCRFs                                      *;
%* @param _cstoutSupplementalDocs - required - The SupplementalDocs data set to   *;
%*             create.                                                            *;
%*            Default: srcdata.SupplementalDocs                                   *;
%* @param _cstoutMDVLeaf - required - The MDVLeaf data set to create.             *;
%*            Default: srcdata.MDVLeaf                                            *;
%* @param _cstoutMDVLeafTitles - required - The MDVLeafTitles data set to create. *;
%*            Default: srcdata.MDVLeafTitles                                      *;
%* @param _cstStandard - required - The value of the StandardName column in the   *;
%*            _cstmdvDS data set.                                                 *;
%*            Default: CDISC SDTM                                                 *;
%* @param _cstStandardVersion - required - The value of the StandardVersion       *;
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

%macro crtdds_sourcedocuments(
    _cstsourcedocuments=sampdata.source_documents,
    _cstsourcestudy=sampdata.source_study,
    _cstStudyDS=srcdata.Study,
    _cstmdvDS=srcdata.MetaDataVersion,
    _cstoutAnnotatedCRFs=srcdata.AnnotatedCRFs,
    _cstoutSupplementalDocs=srcdata.SupplementalDocs,
    _cstoutMDVLeaf=srcdata.MDVLeaf,
    _cstoutMDVLeafTitles=srcdata.MDVLeafTitles,
    _cstStandard=CDISC SDTM,
    _cstStandardVersion=3.1.2,
    _cstMode=replace,
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg
    ) / des ="Creates SAS CRT-DDS sourcedocuments related data sets";

%local _cstMissing _cstRandom _cstmdv ds1 mode;

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
%if %sysfunc(strip("&_cstsourcedocuments"))="" %then %let _cstMissing = &_cstMissing _cstsourcedocuments;
%if %sysfunc(strip("&_cstsourcestudy"))="" %then %let _cstMissing = &_cstMissing _cstsourcestudy;
%if %sysfunc(strip("&_cstStudyDS"))="" %then %let _cstMissing = &_cstMissing _cstStudyDS;
%if %sysfunc(strip("&_cstmdvDS"))="" %then %let _cstMissing = &_cstMissing _cstmdvDS;
%if %sysfunc(strip("&_cstoutAnnotatedCRFs"))="" %then %let _cstMissing = &_cstMissing _cstoutAnnotatedCRFs;
%if %sysfunc(strip("&_cstoutSupplementalDocs"))="" %then %let _cstMissing = &_cstMissing _cstoutSupplementalDocs;
%if %sysfunc(strip("&_cstoutMDVLeaf"))="" %then %let _cstMissing = &_cstMissing _cstoutMDVLeaf;
%if %sysfunc(strip("&_cstoutMDVLeafTitles"))="" %then %let _cstMissing = &_cstMissing _cstoutMDVLeafTitles;
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
      %let &_cstReturnMsg=Invalid _cstMode value (&_cstMode): should be APPEND or REPLACE;;
      %goto exit_macro;
    %end;


%let _cstMissing=;
%* Expected source data sets  *;
%if ^%sysfunc(exist(&_cstsourcedocuments)) %then %let _cstMissing = &_cstMissing _cstsourcedocuments=&_cstsourcedocuments;
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
%if ^%sysfunc(exist(&_cstoutAnnotatedCRFs)) %then %let _cstMissing = &_cstMissing _cstoutAnnotatedCRFs=&_cstoutAnnotatedCRFs;
%if ^%sysfunc(exist(&_cstoutSupplementalDocs)) %then %let _cstMissing = &_cstMissing _cstoutSupplementalDocs=&_cstoutSupplementalDocs;
%if ^%sysfunc(exist(&_cstoutMDVLeaf)) %then %let _cstMissing = &_cstMissing _cstoutMDVLeaf=&_cstoutMDVLeaf;
%if ^%sysfunc(exist(&_cstoutMDVLeafTitles)) %then %let _cstMissing = &_cstMissing _cstoutMDVLeafTitles=&_cstoutMDVLeafTitles;
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
%let ds1=_srcdoc&_cstRandom;

proc sort data=&_cstsourcedocuments out=&ds1;
by SASRef doctype href;
run;

data &ds1;
retain _cstcounter;
length fk_metadataversion $128 leafid $64 _cstcounter 8;
 set &ds1;
 by SASRef doctype href;
 fk_metadataversion=strip("&_cstmdv");
 if first.doctype then do;
    _cstcounter=1;
    select (doctype);
      when ('CRF') leafid='lf.blankcrf';
      when ('DOC') leafid='lf.supplementaldoc';
      otherwise put 'WAR' "NING(&sysmacroname):" ' invalid doctype=' doctype;
    end;
 end;
 else do;
    _cstcounter=sum(_cstcounter,1);
    if upcase(doctype) = 'CRF'
      then leafid=cats('lf.blankcrf', put(_cstcounter, best.));
    if upcase(doctype) = 'DOC'
      then leafid=cats('lf.supplementaldoc', put(_cstcounter, best.));
 end;
run;

%******************************************************************************;
%* Create output data sets                                                    *;
%******************************************************************************;
data &_cstoutAnnotatedCRFs(keep=documentref leafid fk_metadataversion);
 set &_cstoutAnnotatedCRFs(&mode)
     &ds1(where=(upcase(doctype)="CRF"));
run;

data &_cstoutSupplementalDocs(keep=documentref leafid fk_metadataversion);
  set &_cstoutSupplementalDocs(&mode)
      &ds1(where=(upcase(doctype)="DOC"));
run;

data &_cstoutMDVLeaf(keep=id href fk_metadataversion);
  set &_cstoutMDVLeaf(&mode)
      &ds1(rename=(leafid=id) where=(upcase(doctype) in ("CRF" "DOC")));
run;

data &_cstoutMDVLeafTitles(keep=title fk_mdvleaf);
  set &_cstoutMDVLeafTitles(&mode)
      &ds1(rename=(leafid=fk_mdvleaf) where=(upcase(doctype) in ("CRF" "DOC")));
run;

%* Clean up *;
%cstutil_deleteDataSet(_cstDataSetName=work.&ds1);

%exit_macro:
%if %length(&&&_cstReturnMsg) ne 0 %then %put ERR%str(OR)(&sysmacroname): &&&_cstReturnMsg;

%exit_macro_nomsg:

%mend crtdds_sourcedocuments;
