%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* odm_getStatic                                                                  *;
%*                                                                                *;
%* Returns constant values that are used by other macros.                         *;
%*                                                                                *;
%* @param _cstName The name of the value to retrieve.                             *;
%*            Values: ODM_SASREF_TYPE_REFXML | ODM_SASREF_TYPE_EXTXML |           *;
%*                    ODM_SASREF_SUBTYPE_XML | ODM_SASREF_SUBTYPE_STYLESHEET |    *;
%*                    ODM_JAVA_PARAMSCLASS | ODM_JAVA_IMPORTCLASS |               *;
%*                    ODM_JAVA_EXPORTCLASS | ODM_JAVA_PICKLIST                    *;
%* @param _cstVar  The macro variable to populate with the value.                 *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro odm_getStatic(
    _cstName=,
    _cstVar=
    ) / des="";

  %*
  ODM - sasreferences values.
  ;
  %if (&_cstName=ODM_SASREF_TYPE_REFXML) %then %let &_cstVar=referencexml;
  %else %if (&_cstName=ODM_SASREF_TYPE_EXTXML) %then %let &_cstVar=externalxml;

  %else %if (&_cstName=ODM_SASREF_SUBTYPE_XML) %then %let &_cstVar=xml;
  %else %if (&_cstName=ODM_SASREF_SUBTYPE_STYLESHEET) %then %let &_cstVar=stylesheet;

  %*
  ODM JAVA Information
  ;
  %else %if (&_cstName=ODM_JAVA_PARAMSCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLTransformerParams;
  %else %if (&_cstName=ODM_JAVA_IMPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLImporter;
  %else %if (&_cstName=ODM_JAVA_EXPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLExporter;
  %else %if (&_cstName=ODM_JAVA_PICKLIST) %then %let &_cstVar=cstframework/cstframework.txt;

%mend odm_getStatic;
