%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* adamutil_gettlfmetadata                                                        *;
%*                                                                                *;
%* Creates SAS data sets with TLF metadata from an XML source.                    *;
%*                                                                                *;
%* The sources defined in SASReferences point to the TLF XML file and a SAS XML   *;
%* map file to render that XML metadata in SAS.                                   *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. This macro references a specific XML representation of the mock table     *;
%*      shell metadata. Alternative representations of the metadata require       *;
%*      modifications to this macro to read that metadata content.                *;
%*   2. The implementation of the sample ADaM reports provided by the SAS         *;
%*      Clinical Standards Toolkit is intended to provide a sample workflow of    *;
%*      report generation within the context of the SAS Clinical Standards Toolkit*;
%*      framework. You can use alternative means to capture and use metadata      *;
%*      to support the reports to be submitted.                                   *;
%*                                                                                *;
%* @macvar _cstDisplayID ID of the display from the designated metadata source    *;
%* @macvar _cst_MsgID Results: Result or validation check ID                      *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1                                    *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2                                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstTLFxmlfile TLF metadata library (XML engine using map file)        *;
%* @macvar _cst_rc Task error status                                              *;
%*                                                                                *;
%* @param _cstOutLib - optional - The library for the SAS representation of TLF   *;
%*            metadata.                                                           *;
%*            Default: WORK                                                       *;
%* @param _cstMetaDataType - optional - The type of metadata. Example: tlf_master.*;
%*            If this parameter is not specified, all available metadata is       *;
%*            created in _cstOutLib.                                              *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure internal                                                             *;

%macro adamutil_gettlfmetadata(
    _cstOutLib=WORK,
    _cstMetaDataType=
    ) /des='CST: Create TLF SAS metadata data sets';

  %local
    _cstExitError
  ;

  %if %length(&_cstDisplayID)<1 %then
  %do;
    %*put ERROR:  Missing required parameter displayid;
    %let _cst_MsgID=CST0081;
    %let _cst_MsgParm1=%str( - displayid);
    %let _cst_MsgParm2=;
    %let _cstSrcData=&sysmacroname;
    %let _cstExitError=1;
    %goto exit_error;
  %end;

  %put --> In adamutil_gettlfmetadata: _cstDisplayID=&_cstDisplayID;

  data &_cstOutLib..tlf_index;
    attrib  dsname format=$32. label="TLF data set name"
            keys format=$200.  label="TLF data set keys"
            metadatatype format=$20. label="TLF data set type"
    ;
    call missing(of _all_);
    if _n_=1 then stop;
  run;
  proc sql;
    insert into &_cstOutLib..tlf_index
      values ("tlf_master"     "dispid"                 "metadata")
      values ("tlf_titles"     "dispid linenum"         "titles")
      values ("tlf_footnotes"  "dispid linenum"         "footnotes")
      values ("tlf_rows"       "dispid id"              "rows")
      values ("tlf_columns"    "dispid id"              "columns")
      values ("tlf_statistics" "dispid parent parentid" "statistics")
    ;
  quit;

  %if %length(&_cstMetaDataType)>0 %then
  %do;
    data &_cstOutLib..&_cstMetaDataType;
      set &_cstTLFxmlLib..&_cstMetaDataType

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data &_cstOutLib..tlf_index;
      set &_cstOutLib..tlf_index (where=(upcase(dsname)=upcase("&_cstMetaDataType")));
    run;
  %end;
  %else
  %do;
    data &_cstOutLib..tlf_master;
      set &_cstTLFxmlLib..tlf_master

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data &_cstOutLib..tlf_titles;
      set &_cstTLFxmlLib..tlf_titles

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data &_cstOutLib..tlf_footnotes;
      set &_cstTLFxmlLib..tlf_footnotes

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data &_cstOutLib..tlf_rows;
      set &_cstTLFxmlLib..tlf_rows

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data work.tlf_rowstat;
     set &_cstTLFxmlLib..tlf_rowstat

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data &_cstOutLib..tlf_columns;
      set &_cstTLFxmlLib..tlf_columns

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data work.tlf_columnstat;
      set &_cstTLFxmlLib..tlf_columnstat

        %if %length(&_cstDisplayID)>0 %then
        %do;
          (where=(upcase(dispid)=upcase("&_cstDisplayID")))
        %end;
      ;
    run;
    data work.tlf_statistics;
      set work.tlf_rowstat
          work.tlf_columnstat;
    run;
    proc sort data=work.tlf_statistics out=&_cstOutLib..tlf_statistics;
      by dispid parent parentid;
    run;
  %end;


%exit_error:

    %if &_cstExitError=1 %then
    %do;
      %put ********************************************************;
      %put ERROR: Fatal error encountered, process cannot continue.;
      %put ********************************************************;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(
                  _cstResultID=&_cst_MsgID
                  ,_cstResultParm1=&_cst_MsgParm1
                  ,_cstResultParm2=&_cst_MsgParm2
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&_cstSrcData
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
    %end;

%mend adamutil_gettlfmetadata;

