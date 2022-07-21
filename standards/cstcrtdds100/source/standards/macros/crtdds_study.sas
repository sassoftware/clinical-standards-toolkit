%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_study                                                                   *;
%*                                                                                *;
%* Creates the SAS CRT-DDS study data set from source metadata.                   *;
%*                                                                                *;
%* @param _cstname - required - The /ODM/Study/GlobalVariables/StudyName          *;
%*            attribute.                                                          *;
%* @param _cstdescr - required - The /ODM/Study/GlobalVariables/StudyDescription  *;
%*            attribute.                                                          *;
%* @param _cstprotocol - required - The /ODM/Study/GlobalVariables/ProtocolName   *;
%*            attribute.                                                          *;
%* @param _cstdefineds - required - The DefineDocument data set in the output     *;
%*            library (for example, srcdata.DefineDocument).                      *;
%* @param _cstdefinename - required - The value of the ID column in the           *;
%*            _cstdefineds data set.                                              *;
%* @param _cstoutstudyds - required - The Study data set to create                *;
%*            (for example, srcdata.Study).                                       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_study(
    _cstname=,
    _cstdescr=,
    _cstprotocol=,
    _cstdefineds=,
    _cstdefinename=,
    _cstoutstudyds=
    ) / des ="Creates SAS CRT-DDS Study data set";

%local _cstRandom ds keycnt key cnt add src2 defds rc dsidst;

%if %length(&_cstname)=0 or %length(&_cstdescr)=0 or %length(&_cstprotocol)=0
  or %length(&_cstdefineds)=0 or %length(&_cstdefinename)=0 or %length(&_cstoutstudyds)=0
    %then %goto exit;

%if ^%sysfunc(exist(&_cstdefineDS)) %then %goto exit;

 %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let ds=_s&_cstRandom;

  proc sql;
  create table &ds as
  select
      kstrip("&_cstdefinename") as OID length=128,
      "&_cstname" as StudyName length=128,
      "&_cstdescr" as StudyDescription length=2000,
      "&_cstprotocol" as ProtocolName length=128,
      fileoid as FK_DefineDocument
    from &_cstdefineDS
    ;
    quit;

  data &_cstoutStudyDS;
    set &_cstoutStudyDS &ds;
  run;

  %cstutil_deleteDataSet(_cstDataSetName=&ds);

%exit:

%mend crtdds_study;
