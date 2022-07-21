%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_getStatic                                                               *;
%*                                                                                *;
%* Returns constant values that are used by other macros.                         *;
%*                                                                                *;
%* @param _cstName The name of the value to retrieve.                             *;
%*         Values: CRTDDS_SASREF_TYPE_REFXML | CRTDDS_SASREF_TYPE_EXTXML |        *;
%*                 CRTDDS_SASREF_SUBTYPE_XML | CRTDDS_SASREF_SUBTYPE_STYLESHEET | *;
%*                 CRTDDS_JAVA_PARAMSCLASS | CRTDDS_JAVA_IMPORTCLASS |            *;
%*                 CRTDDS_JAVA_EXPORTCLASS | CRTDDS_JAVA_PICKLIST                 *;
%* @param _cstVar  The macro variable to populate with the value.                 *;
%*                                                                                *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro crtdds_getStatic(
    _cstName=,
    _cstVar=
    ) / des="";

  %*
  CRTDDS - sasreferences values.
  ;
  %if (&_cstName=CRTDDS_SASREF_TYPE_REFXML) %then %let &_cstVar=referencexml;
  %else %if (&_cstName=CRTDDS_SASREF_TYPE_EXTXML) %then %let &_cstVar=externalxml;

  %else %if (&_cstName=CRTDDS_SASREF_SUBTYPE_XML) %then %let &_cstVar=xml;
  %else %if (&_cstName=CRTDDS_SASREF_SUBTYPE_STYLESHEET) %then %let &_cstVar=stylesheet;

  %*
  CRTDDS JAVA Information
  ;
  %else %if (&_cstName=CRTDDS_JAVA_PARAMSCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLTransformerParams;
  %else %if (&_cstName=CRTDDS_JAVA_IMPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLImporter;
  %else %if (&_cstName=CRTDDS_JAVA_EXPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLExporter;
  %else %if (&_cstName=CRTDDS_JAVA_PICKLIST) %then %let &_cstVar=cstframework/cstframework.txt;

%mend crtdds_getStatic;
