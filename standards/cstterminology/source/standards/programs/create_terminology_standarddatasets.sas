**********************************************************************************;
* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
* SPDX-License-Identifier: Apache-2.0                                            *;
*                                                                                *;
* create_terminology_standarddatasets.sas                                        *;
*                                                                                *;
* Sample driver program to perform a primary Toolkit action, in this case,       *;
* to create the datasets that are needed to register Controlled Terminology:     *;
*                                                                                *;
*    control.standards                                                           *;
*    control.standardsasreferences                                               *;
*    control.standardsubtypes                                                    *;
*                                                                                *;
* CSTversion  1.6                                                                *;
**********************************************************************************;

%cstutil_setcstgroot;

* The user will have to assign a control libname where the data sets will be created;
libname control "&_cstGRoot./standards/cdisc-terminology-1.7/control";

* initialize the global variables needed by the framework;
%cst_setStandardProperties(_cstStandard=CST-FRAMEWORK,_cstSubType=initialize);



/* STANDARDS  */
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=cstmetadata,_cstSubType=standard,
                          _cstOutputDS=work.standards);
/*
Columns are:
  standard                 - Name of standard (required)
  mnemonic                 - Mnemonic for standard (required)
  standardVersion          - Standard version (required)
  groupname                - Standard group (required, "TERMINOLOGY" for Controlled Terminology)
  groupversion             - Standard group version (optional)
  comment                  - Comments (optional)
  rootpath                 - Root path for the standard (required)
  studylibraryrootpath     - (Sample) study root path (otional)
  controlsubfolder         - Relative (to rootpath) control folder path (optional)
  templatesubfolder        - Relative (to rootpath) template folder path (optional)
  standardDefault          - Is this the default version for the standard (Y/N)? (required)
  cstFramework             - Is this standard part of the CST framework (Y/N)? (required, "N" for Controlled Terminology)
  isDataStandard           - Is this a data standard (Y/N)? (required, "N" for Controlled Terminology)
  supportsValidation       - Standard supports validation (Y/N)? (required, "N" for Controlled Terminology)
  isXMLStandard            - Is this an xml-based standard (Y/N)? (required, "N" for Controlled Terminology)
  importxsl                - The location of the import XSL within the xsl-repository (optional, missing for Controlled Terminology)
  exportxsl                - The location of the export XSL within the xsl-repository (optional, missing for Controlled Terminology)
  schema                   - The location of the xml schema within the schema-repository (optional, missing for Controlled Terminology)
  productRevision          - The revision of the standard-standardversion (required)
*/


/* IMPORTANT: The groupname column needs to have the value TERMINOLOGY to be recognized as a Controlled Terminology package */
proc sql;
  insert into work.standards
    values('CDISC-TERMINOLOGY','CT','NCI_THESAURUS','TERMINOLOGY','NCI_THESAURUS','CDISC Terminology',
           '&_cstGRoot./standards/cdisc-terminology-1.7','','control','', 'Y','N','N','N','N','','', '','1.7');
  ;
quit;


proc sort data=work.standards out=control.standards (label="CDISC-TERMINOLOGY standard metadata");
  by standard standardversion;
run;


/*  STANDARDSASREFERENCES  */
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=cstmetadata,_cstSubType=sasreferences,
                          _cstOutputDS=work.standardsasreferences);
/*
Columns are:
  standard                 - Name of Standard (required)
  standardVersion          - Standard version (required)
  type                     - CST input/output data or metadata (required)
  subType                  - Data or metadata subtype within type (required)
  SASref                   - SAS libref or fileref (required)
  refType                  - Reference type (libref or fileref) (required)
  iotype                   - Input/output type (input,output,both) (required)
  filetype                 - File type (folder,dataset,catalog,file) (required)
  allowoverwrite           - Allow file to be overwritten (Y/N) (required)
  relpathprefix            - Relative path prefix (eg rootpath, studylibraryrootpath, &mypath)
  path                     - Path (required)
  order                    - Order within type (autocall,fmtseach)
  memname                  - Filename (null for libraries)
  comment                  - Explanatory comments (optional)
*/
proc sql;
  insert into work.standardsasreferences
    values('CDISC-TERMINOLOGY','NCI_THESAURUS','control','reference','stdmeta','libref','input','dataset','N','rootpath','control',.,'standardsasreferences.sas7bdat','Standard-specific SASReferences data set')
    values('CDISC-TERMINOLOGY','NCI_THESAURUS','cstmetadata','standard','stdmeta','libref','input','dataset','N','rootpath','control',.,'standards.sas7bdat','Standard-specific standards data set')
    values('CDISC-TERMINOLOGY','NCI_THESAURUS','cstmetadata','standardsubtypes','stdmeta','libref','input','dataset','N','rootpath','control',.,'standardsubtypes.sas7bdat','CT subtypes data set')
    values('CDISC-TERMINOLOGY','NCI_THESAURUS','cstmetadata','sasreferences','stdmeta','libref','input','dataset','N','rootpath','control',.,'standardsasreferences.sas7bdat','Standard-specific SASReferences data set')
    values('CDISC-TERMINOLOGY','NCI_THESAURUS','referencecontrol','internalvalidation','refcntl','libref','input','dataset','N','rootpath','validation/control',.,'validation_iv_checks.sas7bdat','')
  ;
quit;


proc sort data=work.standardsasreferences out=control.standardsasreferences (label="Standard sasreferences for CDISC-TERMINOLOGY");
  by standard standardversion type subtype;
run;


/*  STANDARDSUBTYPES  */
%cst_createdsfromtemplate(_cstStandard=CST-FRAMEWORK,_cstType=cstmetadata,_cstSubType=standardsubtypes,
                          _cstOutputDS=work.standardsubtypes);
/*
Columns are:
  standard                 - Name of standard (required)
  standardversion          - Standard version (required)
  standardsubtype          - Name of standard subtype (required)
  standardsubtypeversion   - Version of standard subtype (required)
  path                     - Path for the Controlled Terminology (required)
  memname                  - Name of Controlled Terminology data set or catalog (required)
  isstandarddefault        - Is this the default version for the subtype (Y/N)? (required)
  productrevision          - The revision of the standard-standardversion (required, 1.7 for this CST version)
  description              - Description of the subtype (optional)
*/

proc sql;
  insert into work.standardsubtypes
    values('CDISC-TERMINOLOGY','CDISC-ADAM', 'NCI_THESAURUS','201101', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-adam/201101/formats',  'cterms', 'N','1.7',
           'CDISC ADaM Controlled Terminology, released by NCI on 2011-01-07')
    values('CDISC-TERMINOLOGY','CDISC-ADAM', 'NCI_THESAURUS','201107', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-adam/201107/formats',  'cterms', 'N','1.7',
           'CDISC ADaM Controlled Terminology, released by NCI on 2011-07-22')
    values('CDISC-TERMINOLOGY','CDISC-ADAM', 'NCI_THESAURUS','201512', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-adam/201512/formats',  'cterms', 'N','1.7',
           'CDISC ADaM Controlled Terminology, released by NCI on 2015-12-18')
    values('CDISC-TERMINOLOGY','CDISC-ADAM', 'NCI_THESAURUS','202206', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-adam/202206/formats',  'cterms', 'Y','1.7',
           'CDISC ADaM Controlled Terminology, released by NCI on 2022-06-24')
    values('CDISC-TERMINOLOGY','CDISC-ADAM', 'NCI_THESAURUS','current','&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-adam/current/formats', 'cterms', 'N','1.7',
           'Current CDISC ADaM Controlled Terminology, Copy of 2022-06-24')

    values('CDISC-TERMINOLOGY','CDISC-CDASH','NCI_THESAURUS','201212', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-cdash/201212/formats', 'cterms', 'N','1.7',
           'CDISC CDASH Controlled Terminology, released by NCI on 2012-12-20')
    values('CDISC-TERMINOLOGY','CDISC-CDASH','NCI_THESAURUS','201312', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-cdash/201312/formats', 'cterms', 'N','1.7',
           'CDISC CDASH Controlled Terminology, released by NCI on 2013-12-20')
    values('CDISC-TERMINOLOGY','CDISC-CDASH','NCI_THESAURUS','201403', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-cdash/201403/formats', 'cterms', 'N','1.7',
           'CDISC CDASH Controlled Terminology, released by NCI on 2014-03-28')
    values('CDISC-TERMINOLOGY','CDISC-CDASH','NCI_THESAURUS','202209', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-cdash/202209/formats', 'cterms', 'Y','1.7',
           'CDISC CDASH Controlled Terminology, released by NCI on 2022-09-30')
    values('CDISC-TERMINOLOGY','CDISC-CDASH','NCI_THESAURUS','current','&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-cdash/current/formats', 'cterms','N','1.7',
           'Current CDISC CDASH Controlled Terminology, Copy of 2022-09-30')

    values('CDISC-TERMINOLOGY','CDISC-QS','NCI_THESAURUS','201312',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-qs/201312/formats',  'cterms', 'N','1.7',
           'CDISC QS Controlled Terminology, released by NCI on 2013-12-20')
    values('CDISC-TERMINOLOGY','CDISC-QS','NCI_THESAURUS','201406',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-qs/201406/formats',  'cterms', 'Y','1.7',
           'CDISC QS Controlled Terminology, released by NCI on 2014-06-27')
    values('CDISC-TERMINOLOGY','CDISC-QS','NCI_THESAURUS','current', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-qs/current/formats', 'cterms', 'N','1.7',
           'Current QS Controlled Terminology, Copy of 2014-06-27')

    values('CDISC-TERMINOLOGY','CDISC-DEFINE','NCI_THESAURUS','202209',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-define/202209/formats',  'cterms', 'Y','1.7',
           'CDISC Define XML Controlled Terminology, released by NCI on 2022-09-30')
    values('CDISC-TERMINOLOGY','CDISC-DEFINE','NCI_THESAURUS','current', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-define/current/formats', 'cterms', 'N','1.7',
           'Current Define XML Controlled Terminology, Copy of 2022-09-30')

    values('CDISC-TERMINOLOGY','CDISC-SDTM','NCI_THESAURUS','201212',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-sdtm/201212/formats',  'cterms', 'N','1.7',
           'CDISC SDTM Controlled Terminology, released by NCI on 2012-12-20')
    values('CDISC-TERMINOLOGY','CDISC-SDTM','NCI_THESAURUS','201312',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-sdtm/201312/formats',  'cterms', 'N','1.7',
           'CDISC SDTM Controlled Terminology, released by NCI on 2013-12-20')
    values('CDISC-TERMINOLOGY','CDISC-SDTM','NCI_THESAURUS','201406',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-sdtm/201406/formats',  'cterms', 'N','1.7',
           'CDISC SDTM Controlled Terminology, released by NCI on 2014-06-26')
    values('CDISC-TERMINOLOGY','CDISC-SDTM','NCI_THESAURUS','202209',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-sdtm/202209/formats',  'cterms', 'Y','1.7',
           'CDISC SDTM Controlled Terminology, released by NCI on 2022-09-30')
    values('CDISC-TERMINOLOGY','CDISC-SDTM','NCI_THESAURUS','current', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-sdtm/current/formats', 'cterms', 'N','1.7',
           'Current SDTM Controlled Terminology, Copy of 2022-09-30')

    values('CDISC-TERMINOLOGY','CDISC-SEND','NCI_THESAURUS','201212',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-send/201212/formats',  'cterms', 'N','1.7',
           'CDISC SEND Controlled Terminology, released by NCI on 2012-12-20')
    values('CDISC-TERMINOLOGY','CDISC-SEND','NCI_THESAURUS','201312',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-send/201312/formats',  'cterms', 'N','1.7',
           'CDISC SEND Controlled Terminology, released by NCI on 2013-12-20')
    values('CDISC-TERMINOLOGY','CDISC-SEND','NCI_THESAURUS','201406',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-send/201406/formats',  'cterms', 'N','1.7',
           'CDISC SEND Controlled Terminology, released by NCI on 2014-06-26')
    values('CDISC-TERMINOLOGY','CDISC-SEND','NCI_THESAURUS','202209',  '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-send/202209/formats',  'cterms', 'Y','1.7',
           'CDISC SEND Controlled Terminology, released by NCI on 2022-09-30')
    values('CDISC-TERMINOLOGY','CDISC-SEND','NCI_THESAURUS','current', '&_cstGRoot./standards/cdisc-terminology-1.7/cdisc-send/current/formats', 'cterms', 'N','1.7',
           'Current SEND Controlled Terminology, Copy of 2022-09-30')

  ;
quit;
proc sort data=work.standardsubtypes out=control.standardsubtypes (label='Controlled Terminology Packages');
  by standard standardversion standardsubtype standardsubtypeversion;
run;
