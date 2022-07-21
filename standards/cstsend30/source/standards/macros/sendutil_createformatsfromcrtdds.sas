%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sendutil_createformatsfromcrtdds                                               *;
%*                                                                                *;
%* Derives codelists from a CRT-DDS data library.                                 *;
%*                                                                                *;
%* This sample utility macro derives code lists from a CRT-DDS data library that  *;
%* is derived from define.xml for a CDISC SEND study.                             *;
%*                                                                                *;
%* These source metadata files are used by the SAS Clinical Standards Toolkit to  *;
%* create codelists as provided in the CDISC CRT-DDS (define.xml) files:          *;
%*          codelists                                                             *;
%*          codelistitems                                                         *;
%*          clitemdecodetranslatedtext                                            *;
%*                                                                                *;
%* This is the general strategy:                                                  *;
%*    1. Combine CRT-DDS data to create the cntlin data set.                      *;
%*    2. Read the cntlin data set using PROC FORMAT to create format catalog.     *;
%*                                                                                *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. The source data is read from a single SAS library. You can modify the    *;
%*       code to reference multiple libraries by using library concatenation.     *;
%*    2. You can specify only one study reference. Multiple study references      *;
%*       require modification of the code.                                        *;
%*    3. The following macro variables have been set either before invoking this  *;
%*       macro or be derived from the _cstSASRefs data set:                       *;
%*           _cstCTCat (type=fmtsearch, format catalog name)                      *;
%*           _cstCTLibrary (type=fmtsearch, target library for formats)           *;
%*           _cstSASrefLib (type=sourcedata, library of derived CRT-DDS data sets)*;
%*    4. The following macro variables have been set previously:                  *;
%*           _cstStandard (for example, CDISC-SEND)                               *;
%*           _cstStandardVersion (for example, 3.0)                               *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar _cstCTLibrary Target library for formats                               *;
%* @macvar _cstSASrefLib Library of derived CDT-DDS data sets                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstSASRefs  Run-time SASReferences data set derived in process setup  *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstCTCat Format catalog name                                          *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro sendutil_createformatsfromcrtdds(
    ) / des='CST: Create Formats from CRTDDS Codelists';

  %local
    _cstDir
    _cstErrorFlag
    _cstFileref
    _cstRandom
    _cstRC
    _cstrundt
    _cstTempDS1
    _cst_Error
  ;

  %let _cstSeqCnt=0;
  %let _cstSrcData=&sysmacroname;

  %* Write information about this process to the results data set  *;
  %if %symexist(_cstResultsDS) %then
  %do;
    data _null_;
      call symputx('_cstrundt',put(datetime(),is8601dt.));
    run;

    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstStandard,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStandardVersion,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: CREATE_CODELISTFROMCRTDDS,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: METADATA DERIVATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstsasrefs,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
    %if %symexist(studyRootPath) %then
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %else
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=9;
  %end;

  %****************************************************;
  %*  Check for existence of required LIBNAME values  *;
  %****************************************************;
  %if ^%symexist(_cstCTLibrary) %then
    %cstutil_getsasreference(_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,_cstSASRefmember=_cstCTCat);

  %if "&_cstCTLibrary"="" %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: Location for output data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for output data sets required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if ^%symexist(_cstSASrefLib) %then
    %cstutil_getsasreference(_cstSASRefType=sourcedata,_cstSASRefsasref=_cstSASrefLib);

  %if "&_cstSASrefLib"="" %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: Location for CRTDDS input data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for CRTDDS input data sets required.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if &_cst_Error=1 %then %goto exit_macro;

  %*********************************************;
  %*  Check existence of required data tables  *;
  %*********************************************;
  %if not %sysfunc(exist(&_cstSASrefLib..codelists)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: The &_cstSASrefLib..codelists data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstSASrefLib..codelists data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if not %sysfunc(exist(&_cstSASrefLib..codelistitems)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: The &_cstSASrefLib..codelistitems data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstSASrefLib..codelistitems data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if not %sysfunc(exist(&_cstSASrefLib..clitemdecodetranslatedtext)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: The &_cstSASrefLib..clitemdecodetranslatedtext data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstSASrefLib..clitemdecodetranslatedtext data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %let _cstDir=%sysfunc(pathname(&_cstCTLibrary));
  %let _cstRC = %sysfunc(filename(_cstFileref,&_cstDir)) ;
  %if ^%sysfunc(fexist(&_cstFileref)) %then
  %do;
    %let _cst_Error=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: Location for the &_cstCTLibrary catalog does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstCTLibrary  catalog library does not exist.,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if &_cst_Error=1 %then %goto exit_macro;

  %********************************;
  %*  Generate needed work files  *;
  %********************************;


  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS1=_cst&_cstRandom;

  data work.&_cstTempDS1._codelists(drop=regex);
   retain regex;
   set &_cstSASrefLib..codelists;
      if _n_=1 then do;
        regex = prxparse('m/^(?=.{1,32}$)([\$a-zA-Z_][a-zA-Z0-9_]*[a-zA-Z_])$/');
      end;
      %* try name if SASFormatName is missing;
      if missing(sasformatname) then do;
        sasformatname=kcompress(kstrip(name));
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Missing SASFormatName "
            "replaced with " sasformatname "(" OID= +(-1) ").";
      end;

      %* Check if the last character is a digit. If yes, add F;
      if (anydigit(sasformatname , length(sasformatname) * (-1)) eq length(sasformatname)) then do;
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Invalid SASFormatName " sasformatname +(-1)
            " updated to: " sasformatname +(-1) "F (" OID= +(-1) ").";
        sasformatname=ktrim(sasformatname)||"F";
      end;

      %* Check if we have a valid format name. If not, then set SASFormatName to missing;
      if not prxmatch(regex, trim(sasformatname)) then do;
        put "[CSTLOG%str(MESSAGE).&sysmacroname]: Invalid SASFormatName " sasformatname +(-1) 
            " will not be used, set to missing (" OID= name= +(-1) ").";
        call missing(sasformatname);
      end;
  run;

  proc sql noprint;
    create table work.&_cstTempDS1 as
    select ds2.codedvalue as start,
      ds2.codedvalue as end,
      ds2.rank,
      ds3.translatedtext as label,
      case when upcase(ds1.datatype)='TEXT' then 'C'
        else 'N'
      end as type,
      "" as hlo,
      ds1.sasformatname as fmtname
    from work.&_cstTempDS1._codelists ds1,
         &_cstSASrefLib..codelistitems ds2,
         &_cstSASrefLib..clitemdecodetranslatedtext ds3
    where (ds1.oid=ds2.fk_codelists and ds2.oid=ds3.fk_codelistitems and (not missing(fmtname)))
    order by sasformatname, rank;
  quit;

  proc format library=&_cstCTLibrary..&_cstCTCat cntlin=work.&_cstTempDS1;
  run;

  %if &_cstDebug %then %do;
    proc format library=&_cstCTLibrary..&_cstCTCat fmtlib;
      title 'FMTLIB Output for the &_cstCTCat Format Catalog';
    run;
  %end;

  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  proc datasets lib=work nolist;
    delete &_cstTempDS1/memtype=data;
  quit;

  %exit_macro:

  %let _cstSrcData=&sysmacroname;
  %if %symexist(_cstResultsDS) %then
  %do;
    %if &_cst_Error=1 %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,
                           _cstResultParm1=%str(Process failed to complete successfully, please check results data set for more information),
                           _cstResultFlagParm=1,
                           _cstSeqNoParm=&_cstSeqCnt,
                           _cstSrcDataParm=&_cstSrcData);
    %end;
    %else
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=Process completed successfully,_cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %******************************************************;
    %* Persist the results if specified in sasreferences  *;
    %******************************************************;
    %cstutil_saveresults();
  %end;
  %else %if &_cst_Error= 1 %then
  %do;
    %let _cstSrcData=&sysmacroname;
    %put Error &_cstSrcData ended prematurely, please check log;
  %end;

%mend sendutil_createformatsfromcrtdds;