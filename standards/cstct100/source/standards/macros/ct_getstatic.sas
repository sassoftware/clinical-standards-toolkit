%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* ct_getstatic                                                                   *;
%*                                                                                *;
%* Returns constant values that are used by other macros.                         *;
%*                                                                                *;
%* @param _cstName The name of the value to retrieve.                             *;
%*            Values: CT_SASREF_TYPE_REFXML | CT_SASREF_TYPE_EXTXML |             *;
%*                    CT_SASREF_SUBTYPE_XML | CT_SASREF_SUBTYPE_STYLESHEET |      *;
%*                    CT_JAVA_PARAMSCLASS | CT_JAVA_IMPORTCLASS|                  *;
%*                    CT_JAVA_EXPORTCLASS | CT_JAVA_PICKLIST                      *;
%* @param _cstVar  The macro variable to populate with the value.                 *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro ct_getstatic(
    _cstName=,
    _cstVar=
    ) / des="";

  %*
  CT - sasreferences values.
  ;
  %if (&_cstName=CT_SASREF_TYPE_REFXML) %then %let &_cstVar=referencexml;
  %else %if (&_cstName=CT_SASREF_TYPE_EXTXML) %then %let &_cstVar=externalxml;

  %else %if (&_cstName=CT_SASREF_SUBTYPE_XML) %then %let &_cstVar=xml;
  %else %if (&_cstName=CT_SASREF_SUBTYPE_STYLESHEET) %then %let &_cstVar=stylesheet;

  %*
  ODM JAVA Information
  ;
  %else %if (&_cstName=CT_JAVA_PARAMSCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLTransformerParams;
  %else %if (&_cstName=CT_JAVA_IMPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLImporter;
  %else %if (&_cstName=CT_JAVA_EXPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLExporter;
  %else %if (&_cstName=CT_JAVA_PICKLIST) %then %let &_cstVar=cstframework/cstframework.txt;

%mend ct_getstatic;
