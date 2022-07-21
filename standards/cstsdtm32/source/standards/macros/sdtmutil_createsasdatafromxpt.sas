%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmutil_createsasdatafromxpt                                                  *;
%*                                                                                *;
%* Derives source metadata files from a CRT-DDS data library.                     *;
%*                                                                                *;
%* This sample utility macro derives source metadata files from a CRT-DDS data    *;
%* library that is derived from the define.xml file for a CDISC SDTM study.       *;
%*                                                                                *;
%* The itemgroupleaf data set is used by this macro to generate a list of XPT     *;
%* files.                                                                         *;
%*                                                                                *;
%* This is the general strategy:                                                  *;
%*    1. Read the itemgroupleaf data set to create a list of XPT files, and       *;
%*       generate SAS code to create SAS data sets using the XPORT LIBNAME option.*;
%*    2. Submit the generated code to create the SAS data sets.                   *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*    1. CRT-DDS data is read from a single SAS library.                          *;
%*    2. The following macro variables have been set either before calling this   *;
%*       macro or be derived from the _cstSASRefs data set:                       *;
%*           _cstSASrefLib (type=sourcedata, library of derived CRT-DDS data sets)*;
%*           _cstXMLLibrary (type=externalxml, fileref of define xml file)        *;
%*    3. The following macro variables have been set previously:                  *;
%*           _cstStandard (for example, CDISC-SDTM)                               *;
%*           _cstStandardVersion (for example, 3.1.2)                             *;
%*                                                                                *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSASrefLib Library of derived CRT-DDS data sets                     *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstStudyLibrary Target library for new data sets                      *;
%* @macvar _cstXMLLibrary Fileref of define xml file                              *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar studyRootPath Root path of the study library                           *;
%* @macvar _cstSASRefs  Run-time SASReferences data set derived in process setup  *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure external                                                             *;

%macro sdtmutil_createsasdatafromxpt(
    ) / des='CST: Create SAS Data Sets from XPT';

  %local
    _cstFile
    _cstNextCode
    _cstRandom
    _cstRecCnt
    _cstrund
    _cstTempDS5
    _cstErrorFlag
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
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: CREATE_SASDATAFROMXPT,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: DATA DERIVATION,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstsasrefs,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
    %if %symexist(studyRootPath) %then
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %else
      %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=9;
  %end;

  %let _cstRecCnt=0;
  %let _cstErrorFlag=0;

  %************************************************************;
  %*  Check for existence of needed libraries and data sets   *;
  %************************************************************;
  %if ^%symexist(_cstStudyLibrary) %then
    %cstutil_getsasreference(_cstSASRefType=targetdata,_cstSASRefsasref=_cstStudyLibrary);

  %if "&_cstStudyLibrary"="" %then
  %do;
    %let _cstErrorFlag=1;
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
    %let _cstErrorFlag=1;
   %put [CSTLOG%str(MESSAGE)] ERROR: Location for CRTDDS input data sets required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location for CRTDDS input data sets required,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  %if not %sysfunc(exist(&_cstSASrefLib..itemgroupleaf)) %then
  %do;
    %let _cstErrorFlag=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: The &_cstSASrefLib..itemgroupleaf data set does not exist.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %let _cstSrcData=&sysmacroname;
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=The &_cstSASrefLib..itemgroupleaf data set does not exist.,
        _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&sysmacroname);
    %end;
  %end;

  %if ^%symexist(_cstXMLLibrary) %then
    %cstutil_getsasreference(_cstSASRefType=externalxml,_cstSASRefsasref=_cstXMLLibrary);

  %if "&_cstXMLLibrary"="" %then
  %do;
    %let _cstErrorFlag=1;
    %put [CSTLOG%str(MESSAGE)] ERROR: Location of define xml file required.;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=Location of define xml file required,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
  %end;

  * We must have 1+ itemgroupleaf records (i.e. XPT file references) to proceed  *;
  data _null_;
    if 0 then set &_cstSASrefLib..itemgroupleaf nobs=_numobs;
    call symputx('_cstRecCnt',_numobs);
    stop;
  run;

  %********************************;
  %*  Error found exit the macro  *;
  %********************************;

  %if &_cstErrorFlag=1 %then %goto exit_macro;


  %if &_cstRecCnt<1 %then
  %do;
    %let _cstErrorFlag=2;
    %goto exit_macro;
  %end;

  %***********************************;
  %*  Create needed random filename  *;
  %***********************************;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTempDS5=_cst&_cstRandom;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstNextCode=_cst&_cstRandom;

  %***********************************************************;
  %*  Assign a filename for the code that will be generated  *;
  %*  Generate code to read the individual XPT files         *;
  %***********************************************************;
  filename &_cstNextCode CATALOG "work.&_cstNextCode..nextcode.source" &_cstLRECL;

  %********************;
  %*  Read XPT files  *;
  %********************;
  data _null_;
    set &_cstSASrefLib..itemgroupleaf;
    length domain $8 line1-line4 rhref $255 path xpt xmlpath $200 startslash $1;
    file &_cstNextCode;
    relcount=count(href,'..');
    %*****************************************************;
    %*  Check for Relative Path using '..' as indicator  *;
    %*****************************************************;
    if relcount > 0 then
    do;
      %***********************************************************************;
      %*  Determine if there is a leading / (Unix) in the external XML path  *;
      %***********************************************************************;
      startslash='';
      xmlpath=pathname("&_cstXMLLibrary");
      startslash=ksubstr(kleft(xmlpath),1,1);
      if startslash="/" or startslash="\" then
      do;
        startslash="/";
        xmlpath=ksubstr(kleft(xmlpath),2);
      end;
      else startslash='';

      %********************************************;
      %*  Count slashes in the external XML path  *;
      %********************************************;
      slashcount=countc(xmlpath,"/\");

      %********************************************;
      %*  Count slashes in the relative XPT path  *;
      %********************************************;
      slashcount2=countc(href,"/\");
      loopcount=slashcount-relcount;
      do i=1 to loopcount;
        if i=1 then path=kstrip(startslash)||kstrip(kleft(kscan(xmlpath,i,"/\")));
        else path=kstrip(kleft(path))||"/"||kstrip(left(kscan(xmlpath,i,"/\")));
      end;
      rhref=kreverse(kstrip(href));
      if slashcount2 > 0 then
      do;
        do i=1 to slashcount2;
          if i=1 then xpt=kstrip(kleft(kscan(rhref,i,"/\")));
          else xpt=kstrip(kleft(xpt))||"/"||kstrip(kleft(kscan(rhref,i,"/\")));
        end;
      end;
      start=kindex(xpt,'.')+1;
      end=kindexc(xpt,'\/');
      range=end-start;
      domain=ksubstr(xpt,start,range);
      domain=kstrip(kreverse(domain));
      xpt=kstrip(kreverse(xpt));
      path=kstrip(path)||"/"||kstrip(xpt);
    end;
    else
    do;
    %*************************;
    %*  Static path assumed  *;
    %*************************
    else
    do;
      path=kstrip(href);
      if path ne '' then
      do;
        rhref=kreverse(kstrip(href));
        start=kindex(rhref,".");
        start=start+1;
        end=kindexc(rhref,"\/");
        range=end-start;
        domain=ksubstr(rhref,start,range);
        domain=kstrip(kreverse(domain));
      end;
    end;

    %************************;
    %*  Verify file exists  *;
    %************************;
    if fileexist(path) then
    do;
      line1="libname xportout xport '"||kstrip(path)||"';";
      line1=strip(line1);
      line2="proc copy in=xportout out=&_cstStudyLibrary memtype=data;";
      line2=strip(line2);
      line3="select "||strip(domain)||";";
      line3=strip(line3);
      line4="run;";
      put line1;
      put line2;
      put line3;
      put line4;
    end;
    else
    do;
      call symputx('_cstFile',kstrip(path));
      call symputx('_cstErrorFlag',"1");
      stop;
    end;
  run;

  %let _cstSrcData=&sysmacroname;
  %if &_cstErrorFlag=1 %then
  %do;
    %put [CSTLOG%str(MESSAGE)] ERROR: XPT File (&_cstFile) does not exist;
    %if %symexist(_cstResultsDS) %then
    %do;
      %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
      %cstutil_writeresult(_cstResultID=CST0202,_cstResultParm1=XPT File (&_cstFile) does not exist,
      _cstResultFlagParm=1, _cstSeqNoParm=&_cstSeqCnt,_cstSrcDataParm=&_cstSrcData);
    %end;
    %goto exit_macro;

  %end;

  %include &_cstNextCode;

  %*****************************;
  %*  Cleanup temporary files  *;
  %*****************************;
  %* Clear the filename;

  filename &_cstNextCode;

  proc datasets lib=work nolist;
    delete &_cstNextCode/memtype=catalog;
  quit;

  %exit_macro:
    %let _cstSrcData=&sysmacroname;
    %if %symexist(_cstResultsDS) %then
    %do;
      %if &_cstErrorFlag=1 %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0202,
                             _cstResultParm1=%str(Process failed to complete successfully, please check results data set for more information),
                             _cstResultFlagParm=1,
                             _cstSeqNoParm=&_cstSeqCnt,
                             _cstSrcDataParm=&_cstSrcData);
      %end;
      %else %if &_cstErrorFlag=2 %then
      %do;
        %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
        %cstutil_writeresult(_cstResultID=CST0202,
                             _cstResultParm1=%str(Process could not be completed, ItemGroupLeafs contains no records providing XPT file information),
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
    %let _cstSrcData=&sysmacroname;
    %if &_cstErrorFlag= 1 %then
    %do;
      %put Error &_cstSrcData ended prematurely, please check log or results data set;
    %end;

%mend sdtmutil_createsasdatafromxpt;