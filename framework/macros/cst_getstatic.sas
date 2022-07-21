%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cst_getStatic                                                                  *;
%*                                                                                *;
%* Returns constant values that are used by other macros.                         *;
%*                                                                                *;
%* &macvar _cstGRoot Root path of the global standards library                    *;
%*                                                                                *;
%* @param _cstName - required - The name of the value to retrieve.                *;
%*   Values:                                                                      *;
%*    CST_DSTYPE_UTTABLE | CST_DSTYPE_UTCOLUMN | CST_DSTYPE_UTLOOKUP |            *;
%*    CST_DSTYPE_SASREFS | CST_DSTYPE_STANDARD | CST_DSTYPE_STANDARDBASE |        *;
%*    CST_DSTYPE_STANDARDL10N | CST_DSTYPE_STANDARDMACROS |                       *;
%*    CST_DSTYPE_STANDARDSASREFS | CST_DSTYPE_RESULT | CST_DSTYPE_LOCALIZATION |  *;
%*    CST_DSTYPE_MESSAGES | CST_DSTYPE_METRICS | CST_DSTYPE_ |                    *;
%*    CST_GLOBALMD_PATH | CST_GLOBALMD_REGSTANDARD | CST_GLOBALMD_SASREFS |       *;
%*    CST_GLOBALMD_LOOKUP | CST_GLOBALMD_MVARS | CST_GLOBALMD_MVARVALS |          *;
%*    CST_GLOBALMD_TRANSFORMSXML | CST_GLOBALSTD_PATH | CST_GLOBALXSD_PATH |      *;
%*    CST_GLOBALXSL_PATH | CST_CT_SUBTYPES_DATA | CST_SASREF_TYPE_SOURCEDATA |    *;
%*    CST_SASREF_TYPE_REFMD | CST_SASREF_SUBTYPE_TABLE |                          *;
%*    CST_SASREF_SUBTYPE_COLUMN | CST_SASREF_SUBTYPE_LOOKUP |                     *;
%*    XML_SASREF_TYPE_REFXML | XML_SASREF_TYPE_EXTXML |                           *;
%*    XML_SASREF_SUBTYPE_XML | XML_SASREF_SUBTYPE_STYLESHEET                      *;
%*    XML_JAVA_PARAMSCLASS | XML_JAVA_IMPORTCLASS |                               *;
%*    XML_JAVA_EXPORTCLASS | XML_JAVA_PICKLIST                                    *;
%*    CST_LOGGING_PATH | CST_LOGGING_DS                                           *;
%*                                                                                *;
%* @param _cstVar - optional - The macro variable to populate with the value.     *;
%*                                                                                *;
%* @history 2013-09-16 Added CST_LOGGING_PATH | CST_LOGGING_DS                    *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure external                                                             *;
%macro cst_getStatic(
    _cstName=,
    _cstVar=
    ) / des='CST: Returns constant values used by other macros';

  %cstutil_setcstgroot;

  %* Toolkit data set types - used in the creation of new data sets of this type.;

  %if (&_cstName=CST_DSTYPE_UTTABLE) %then %let &_cstVar=utilityTableMetadata;
  %else %if (&_cstName=CST_DSTYPE_UTCOLUMN) %then %let &_cstVar=utilityColumnMetadata;
  %else %if (&_cstName=CST_DSTYPE_UTLOOKUP) %then %let &_cstVar=utilityLookupMetadata;
  %else %if (&_cstName=CST_DSTYPE_SASREFS) %then %let &_cstVar=SASReferences;
  %else %if (&_cstName=CST_DSTYPE_STANDARD) %then %let &_cstVar=standard;
  %else %if (&_cstName=CST_DSTYPE_STANDARDBASE) %then %let &_cstVar=standardBase;
  %else %if (&_cstName=CST_DSTYPE_STANDARDL10N) %then %let &_cstVar=standardLocalization;
  %else %if (&_cstName=CST_DSTYPE_STANDARDMACROS) %then %let &_cstVar=standardMacros;
  %else %if (&_cstName=CST_DSTYPE_STANDARDSASREFS) %then %let &_cstVar=standardSASReferences;
  %else %if (&_cstName=CST_DSTYPE_RESULT) %then %let &_cstVar=result;
  %else %if (&_cstName=CST_DSTYPE_LOCALIZATION) %then %let &_cstVar=localization;
  %else %if (&_cstName=CST_DSTYPE_MESSAGES) %then %let &_cstVar=messages;
  %else %if (&_cstName=CST_DSTYPE_METRICS) %then %let &_cstVar=metrics;

  %* The location of global (or cross-standard) metadata and the names of the data sets.;

  %else %if (&_cstName=CST_GLOBALMD_PATH) %then %let &_cstVar=&_cstGRoot./metadata;
  %else %if (&_cstName=CST_GLOBALMD_REGSTANDARD) %then %let &_cstVar=standards;
  %else %if (&_cstName=CST_GLOBALMD_SASREFS) %then %let &_cstVar=standardSASReferences;
  %else %if (&_cstName=CST_GLOBALMD_LOOKUP) %then %let &_cstVar=standardLookup;
  %else %if (&_cstName=CST_GLOBALMD_MVARS) %then %let &_cstVar=standardmacrovariables;
  %else %if (&_cstName=CST_GLOBALMD_MVARVALS) %then %let &_cstVar=standardmacrovariabledetails;
  %else %if (&_cstName=CST_GLOBALMD_TRANSFORMSXML) %then %let &_cstVar=availabletransforms.xml;
  %else %if (&_cstName=CST_GLOBALSTD_PATH) %then %let &_cstVar=&_cstGRoot./standards;
  %else %if (&_cstName=CST_GLOBALXSD_PATH) %then %let &_cstVar=&_cstGRoot./schema-repository;
  %else %if (&_cstName=CST_GLOBALXSL_PATH) %then %let &_cstVar=&_cstGRoot./xsl-repository;
  %else %if (&_cstName=CST_LOGGING_PATH) %then %let &_cstVar=&_cstGRoot./logs;
  %else %if (&_cstName=CST_LOGGING_DS) %then %let &_cstVar=transactionlog;

  %* The Controlled Terminology subtypes file;

  %else %if (&_cstName=CST_CT_SUBTYPES_DATA) %then %let &_cstVar=standardsubtypes;

  %* The subtypes in the SAS References file;

  %else %if (&_cstName=CST_SASREF_TYPE_SOURCEDATA) %then %let &_cstVar=sourcedata;
  %else %if (&_cstName=CST_SASREF_TYPE_REFMD) %then %let &_cstVar=referencemetadata;
  %else %if (&_cstName=CST_SASREF_SUBTYPE_TABLE) %then %let &_cstVar=table;
  %else %if (&_cstName=CST_SASREF_SUBTYPE_COLUMN) %then %let &_cstVar=column;
  %else %if (&_cstName=CST_SASREF_SUBTYPE_LOOKUP) %then %let &_cstVar=lookup;

  %else %if (&_cstName=XML_SASREF_TYPE_REFXML) %then %let &_cstVar=referencexml;
  %else %if (&_cstName=XML_SASREF_TYPE_EXTXML) %then %let &_cstVar=externalxml;
  %else %if (&_cstName=XML_SASREF_SUBTYPE_XML) %then %let &_cstVar=xml;
  %else %if (&_cstName=XML_SASREF_SUBTYPE_STYLESHEET) %then %let &_cstVar=stylesheet;

  %* DEFINE Java Information;
  
  %else %if (&_cstName=XML_JAVA_PARAMSCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLTransformerParams;
  %else %if (&_cstName=XML_JAVA_IMPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLImporter;
  %else %if (&_cstName=XML_JAVA_EXPORTCLASS) %then %let &_cstVar=com/sas/ptc/transform/xml/StandardXMLExporter;
  %else %if (&_cstName=XML_JAVA_PICKLIST) %then %let &_cstVar=cstframework/cstframework.txt;

%mend cst_getStatic;