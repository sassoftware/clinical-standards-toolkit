%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_definedocument                                                          *;
%*                                                                                *;
%* Creates the SAS CRT-DDS DefineDocument data set from source metadata.          *;
%*                                                                                *;
%* @param _cstname - required - The /ODM/@Id attribute.                           *;
%* @param _cstdescr - optional - The /ODM/@description attribute.                 *;
%* @param _cstoutdefinedocds - required - The DefineDocument data set to create   *;
%*            (for example, srcdata.DefineDocument).                              *;
%*                                                                                *;
%* @history 2013-10-24 _cstdescr is now optional.                                 *;
%*                     AsOfDateTime and Id are no longer supplied.                *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro  crtdds_definedocument(
    _cstname=,
    _cstdescr=,
    _cstoutdefinedocds=
    ) / des="Creates SAS CRT-DDS DefineDocument data set";

%local _cstRandom ds;

 %if %length(&_cstname)=0 or %length(&_cstoutdefinedocds)=0  %then %goto exit;

%* remove blanks from name of the define document;
%if %length(&_cstname) %then
  %let _cstname=%sysfunc(translate(&_cstname,'_',' '));

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds=_d&_cstRandom;

proc sql;
 create table &ds
 (FileOID char(128),
  Archival char(3),
  AsOfDateTime char(32),
  Description char(2000),
  FileType char(13),
  Granularity char(15),
  Id char(128),
  ODMVersion char(2000),
  Originator char(2000),
  PriorFileOID char(128),
  SourceSystem char(2000),
  SourceSystemVersion char(2000));
  insert into &ds
    values("%nrbquote(&_cstname)","","", "%nrbquote(&_cstDESCR)", "Snapshot", "", "", "1.2.1" ,"", "", "", "");
quit;

data &_cstoutDefineDocDS;
  set &_cstoutDefineDocDS &ds;
run;

%cstutil_deleteDataSet(_cstDataSetName=&ds);

%exit:

%mend crtdds_definedocument;
