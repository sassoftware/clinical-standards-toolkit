%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* crtdds_adamtodefine                                                            *;
%*                                                                                *;
%* Populates most of the tables in the SAS representation of the CRT-DDS model.   *;
%*                                                                                *;
%* This macro extracts data from the ADaM metadata files (_cstSource*) and        *;
%* converts the metadata into a subset (20 tables) of all of the tables in the    *;
%* SAS representation of the CRT-DDS model.                                       *;
%*                                                                                *;
%* These CRT-DDS tables are created:                                              *;
%*                                                                                *;
%*      definedocument                                                            *;
%*      study                                                                     *;
%*      metadataversion                                                           *;
%*      computationmethods                                                        *;
%*      clitemdecodetranslatedtext                                                *;
%*      itemdefs                                                                  *;
%*      itemgroupdefitemrefs                                                      *;
%*      itemgroupdefs                                                             *;
%*      itemgroupleaf                                                             *;
%*      itemgroupleaftitles                                                       *;
%*      codelists                                                                 *;
%*      codelistitems                                                             *;
%*      externalcodelists                                                         *;
%*                                                                                *;
%*      ValueLists                                                                *;
%*      ValueListItemRefs                                                         *;
%*      ItemValueListRefs                                                         *;
%*                                                                                *;
%*      AnnotatedCRFs                                                             *;
%*      SupplementalDocs                                                          *;
%*      MDVLeaf                                                                   *;
%*      MDVLeafTitles                                                             *;
%*                                                                                *;
%* The metadata source is specified in a SASReferences file.                      *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstTrgStandardVersion The ADaM version of interest, defined in the    *;
%*             calling driver module.                                             *;
%* @macvar _cstVersion Version of the SAS Clinical Standards Toolkit              *;
%*                                                                                *;
%* @param  _cstOutLib - required - The library reference where the resulting      *;
%*             tables are written.                                                *;
%* @param  _cstSourceTables - required - The data set that contains the ADaM      *;
%*             metadata for the domains to include in the CRT-DDS file.           *;
%* @param  _cstSourceColumns - required - The data set that contains the ADaM     *;
%*             metadata for the Domain columns to include in the CRT-DDS file.    *;
%* @param  _cstSourceValues  - optional - The data set that contains the ADaM     *;
%*             metadata for the Value Level columns to include in the CRT-DDS     *;
%*             file.                                                              *;
%* @param  _cstSourceDocuments - optional - The data set that contains the ADaM   *;
%*             metadata for document references to include in the CRT-DDS file.   *;
%* @param  _cstSourceStudy - required - The data set that contains the metadata   *;
%*             for the studies to include in the CRT-DDS file.                    *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure external                                                             *;

%macro crtdds_adamtodefine(
    _cstOutLib=,
    _cstSourceTables=,
    _cstSourceColumns=,
    _cstSourceStudy=,
    _cstSourceValues=,
    _cstSourceDocuments=
    ) / des='CST: Build CRTDDS files from ADaM';

%local
    _cstCTCnt
    _cstCTLibrary
    _cstCTMember
    _cstCTPath
    _cstRandom
    _cstSrcData
    _cstCatalogs
    dsidbd dsidbd2 dsidbd3 dsidbd4
    stdy stdydescr rc defdoc stdy prot
    ds1 ds2 ds3 ds4 ds5 ds6 ds7 ds8 ds9 ds10 ds11
    _cstIter i n foo whr1 name std stdver std_formal stdver_formal
    _cstrundt
    _cstrunsasref
    _cstrunstd
    _cstrunstdver
    _cstThisMacro
    ;

    %let _cstCTCnt=0;
    %let _cstCTLibrary=;
    %let _cstCTMember=;
    %let _cstCTPath=;

    %let _cstrundt=;
    %let _cstrunsasref=;
    %let _cstrunstd=;
    %let _cstrunstdver=;
    %let _cstThisMacro=&sysmacroname;

  %* _cstsourcevalues and _cstsourcedocuments are not required*;
  %if %sysfunc(strip("&_cstoutlib"))=""
    or  %sysfunc(strip("&_cstsourcecolumns"))=""
    or %sysfunc(strip("&_cstsourcestudy"))=""
    or %sysfunc(strip("&_cstSourceTables"))=""
  %then %do;
      %cstutil_writeresult(
                _cstResultId=CST0005
                ,_cstResultParm1=&_cstThisMacro
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
      %goto exit;
    %end;
  %if %symexist(_cstOutlib) %then %do;
    %if (%sysfunc(libref(&_cstoutlib)) ne 0) %then %do;
        %cstutil_writeresult(
                _cstResultId=CST0101
                ,_cstResultParm1=&_cstOutlib
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
        %goto exit;
    %end;
  %end;
  %else %let _cstoutlib=work;
  %if ^%sysfunc(exist(&_cstSourceTables)) %then
  %do;
    %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstSourceTables
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;
  %if &_cst_rc or ^%sysfunc(exist(&_cstSourceColumns)) %then
  %do;
    %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstSourceColumns
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;

  %if &_cst_rc or ^%sysfunc(exist(&_cstSourceStudy)) %then
  %do;
    %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstSourceStudy
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;

  %if &_cst_rc or %cstutilnobs(_cstDatasetName=&_cstSourceStudy) ne 1 %then
  %do;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] ERR%str(OR): The &_cstThisMacro process only allows 1 record in &_cstSourceStudy..;
    %cstutil_writeresult(
                _cstResultId=CRT0014
                ,_cstResultParm1=&_cstThisMacro
                ,_cstResultParm2=&_cstSourceStudy
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;

%if %sysfunc(strip("&_cstSourceValues")) ne "" %then %do;
  %if &_cst_rc or ^%sysfunc(exist(&_cstSourceValues))  %then
  %do;
        %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstSourceValues
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;
%end;

%if %sysfunc(strip("&_cstSourceDocuments")) ne "" %then %do;
  %if &_cst_rc or ^%sysfunc(exist(&_cstSourceDocuments))  %then
  %do;
        %cstutil_writeresult(
                _cstResultId=CST0111
                ,_cstResultParm1=&_cstSourceDocuments
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
    %goto exit;
  %end;
%end;

  data _null_;
    set &_cstSASrefs (where=(upcase(standard)="CDISC-CRTDDS"));

    attrib _csttemp format=$500. label='Temporary variable string';

    if _n_=1 then do;
      call symputx('_cstrundt',put(datetime(),is8601dt.));
      call symputx('_cstrunstd',standard);
      call symputx('_cstrunstdver',standardversion);
    end;

    if upcase(type)="CONTROL" and upcase(subtype)="REFERENCE" then
    do;
      if path ne '' and memname ne '' then
      do;
        if kindexc(ksubstr(kreverse(path),1,1),'/\') then
          _csttemp=catx('',path,memname);
        else
          _csttemp=catx('/',path,memname);
      end;
      else
        _csttemp="&_cstsasrefs";
      call symputx('_cstrunsasref',_csttemp);
    end;

  run;

  %if %length(&_cstrunsasref)=0 %then
  %do;
    %if %sysfunc(indexc(&_cstsasrefs,'.')) %then
    %do;
      %let _cstTempLib=%SYSFUNC(scan(&_cstsasrefs,1,'.'));
      %let _cstTempDS=%SYSFUNC(scan(&_cstsasrefs,2,'.'));
    %end;
    %else
    %do;
      %let _cstTempLib=work;
      %let _cstTempDS=&_cstsasrefs;
    %end;
    %let _cstrunsasref=%sysfunc(pathname(&_cstTempLib))/&_cstTempDS..sas7bdat;
  %end;

%*************************************************************;
%* Write information to the results data set about this run. *;
%*************************************************************;
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARD: &_cstrunstd,_cstSeqNoParm=1,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STANDARDVERSION: &_cstrunstdver,_cstSeqNoParm=2,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DRIVER: &_cstThisMacro,_cstSeqNoParm=3,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS DATE: &_cstrundt,_cstSeqNoParm=4,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS TYPE: ADAM TO CRTDDS ,_cstSeqNoParm=5,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstThisMacro);
%if %symexist(studyRootPath) %then
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
%else
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=8,_cstSrcDataParm=&_cstThisMacro);
%cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=9,_cstSrcDataParm=&_cstThisMacro);
%let _cstSeqCnt=9;

%cstutil_getsasreference(_cstStandard=CDISC-TERMINOLOGY,_cstSASRefType=fmtsearch,_cstSASRefsasref=_cstCTLibrary,
                         _cstSASRefmember=_cstCTMember,_cstAllowZeroObs=1,_cstConcatenate=1);
%let _cstSrcData=&sysmacroname;

%if %length(&_cstCTLibrary)>0 %then
%do;
  %let _cstCTCnt=%SYSFUNC(countw(&_cstCTLibrary,' '));
  %do _cstIter=1 %to &_cstCTCnt;
    %let _cstCTPath=&_cstCTPath %sysfunc(ktranslate(%sysfunc(kstrip(%sysfunc(pathname(%scan(&_cstCTLibrary,&_cstIter,' '))))),'/','\'));
    %if %length(&_cstCTMember)>0 %then
      %let _cstCTPath=&_cstCTPath/%scan(&_cstCTMember,&_cstIter,' ');
  %end;

  %if %symexist(_cstCTDescription) %then
  %do;
    %if %length(&_cstCTDescription)>0 %then
      %let _cstCTPath=&_cstCTPath (&_cstCTDescription);
  %end;
  %cstutil_writeresult(_cstResultID=CST0200,_cstResultParm1=PROCESS CONTROLLED TERMINOLOGY SOURCE: &_cstCTPath,_cstSeqNoParm=10,_cstSrcDataParm=&_cstThisMacro);
  %let _cstSeqCnt=10;
%end;


%* create crt-dds sastables;
%cst_createtablesfordatastandard(_CSTSTANDARD=CDISC-CRTDDS, _CSTOUTPUTLIBRARY=&_cstOutLib);


%defdoc:
%*************************************************************;
%* build definedocument dataset.                             *;
%*************************************************************;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds1=_c01defdoc&_cstRandom;

%if %symexist(_cstsourcestudy) %then %do;
  %if %sysfunc(exist(&_cstsourcestudy)) %then %do;
        %let dsidbd=%sysfunc(open(&_cstsourcestudy,i));
        %if &dsidbd>0 %then %do;
            %let n=%sysfunc(attrn(&dsidbd, nlobs));
            %if &n<=0 %then %do;
              %put No observations found in dataset, _cstsourcestudy.;
              %let rc=%sysfunc(close(&dsidbd));
              %goto cleanup;
            %end;
            %do i=1%to &n;
                %let rc=%sysfunc(fetchobs(&dsidbd, &i));
                %if &rc ne 0 %then
                    %put %sysfunc(sysmsg());
                %else %do;
                    %let defdoc=%nrbquote(%ktrim(%nrbquote(%sysfunc(getvarc(&dsidbd,%sysfunc(varnum(&dsidbd,DEFINEDOCUMENTNAME)))))));
                    %crtdds_definedocument(
                      _cstname=%nrbquote(&defdoc),
                      _cstdescr=,
                      _cstoutDefineDocDS=&_cstOutlib..definedocument
                    );
                %end;
            %end;
            %let rc=%sysfunc(close(&dsidbd));
        %end;
        %else %put Cannot open dataset, &_cstsourcestudy;
  %end;
%end;

%if %sysfunc(exist(&_cstOutlib..definedocument)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..definedocument (%cstutilnobs(_cstDatasetName=&_cstOutlib..definedocument) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_DEFINEDOCUMENT
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;

%study:
%*************************************************************;
%* build study dataset.                                      *;
%*************************************************************;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds2=_c02study&_cstRandom;
%if %symexist(_cstsourcestudy) %then %do;
  %if %sysfunc(exist(&_cstsourcestudy)) %then %do;
    proc sort data=&_cstsourcestudy out=&ds2 nodupkey;
        by definedocumentname studyname;
      run;
        %let dsidbd2=%sysfunc(open(&ds2,i));
        %if &dsidbd2>0 %then %do;
            %let n=%sysfunc(attrn(&dsidbd2, nlobs));
            %if &n<=0 %then %do;
              %put No observations found in dataset, &_cstsourcestudy.;
              %let rc=%sysfunc(close(&dsidbd2));
              %goto cleanup;
            %end;
            %do i=1 %to &n;
                %let rc=%sysfunc(fetchobs(&dsidbd2, &i));
                %if &rc ne 0 %then
                    %put %sysfunc(sysmsg());
                %else %do;
                    %let stdy=%nrbquote(%ktrim(%nrbquote(%sysfunc(getvarc(&dsidbd2,%sysfunc(varnum(&dsidbd2,STUDYNAME)))))));
                    %let stdydescr=%nrbquote(%ktrim(%nrbquote(%sysfunc(getvarc(&dsidbd2,%sysfunc(varnum(&dsidbd2,STUDYDESCRIPTION)))))));
                    %let prot=%nrbquote(%ktrim(%nrbquote(%sysfunc(getvarc(&dsidbd2,%sysfunc(varnum(&dsidbd2,PROTOCOLNAME)))))));
                    %let defdoc=%nrbquote(%ktrim(%nrbquote(%sysfunc(translate(%sysfunc(getvarc(&dsidbd2,%sysfunc(varnum(&dsidbd2,DEFINEDOCUMENTNAME)))),'_',' ')))));
                    %crtdds_study(
                      _cstname=%nrbquote(&stdy),
                      _cstdescr=%nrbquote(&stdydescr),
                      _cstprotocol=%nrbquote(&prot),
                      _cstdefineDS=&_cstoutlib..definedocument,
                      _cstdefinename=%nrbquote(&defdoc),
                      _cstoutStudyDS=&_cstoutlib..Study
                    );
                %end;
            %end;
            %closeds:
            %let rc=%sysfunc(close(&dsidbd2));
        %end;
        %else %put Cannot open dataset, &ds2;
   %end;
%end;
%if %sysfunc(exist(&_cstOutlib..study)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..study (%cstutilnobs(_cstDatasetName=&_cstOutlib..study) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_STUDY
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;

%metadataversion:
%*************************************************************;
%* build metadataversion dataset.                            *;
%*************************************************************;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds3=_c03scrcstdy_&_cstRandom;
%let ds4=_c04coltab_&_cstRandom;
%let ds5=_c05stdcoltab_&_cstRandom;

%if %symexist(_cstsourcestudy) %then %do;
  %if %sysfunc(exist(&_cstsourcestudy)) %then %do;
      proc sort data=&_cstsourcestudy out=&ds3 nodupkey;
        by definedocumentname studyname sasref;
      run;

      data _null_;
       length allrefs $2000;
       retain allrefs ;
       set &ds3 end=eof;
       if _n_=1 then allrefs="'"||strip(UPCASE(sasref))||"'";
       else allrefs=strip(allrefs)||","||"'"||strip(UPCASE(sasref))||"'";
       if eof=1 then call symput('whr1',strip(allrefs));
     run;

     data &ds3;
     set &ds3;
     sasref=UPCASE(SASREF);
     run;

     data &ds4(keep= sasref standard standardversion);
     set &_cstSourceColumns &_cstSourceTables;
     sasref=upcase(sasref);
     if sasref in (&whr1);
     run;

     proc sort data=&ds4 nodupkey;
        by standard standardversion sasref;
     run;

     proc sort data=&ds4;
       by sasref;
     run;

     proc sort data=&ds3;
       by standard standardversion sasref;
     run;

     data &ds5;
       merge &ds3(in=study) &ds4(in=b);
       by standard standardversion sasref;
       if  study=1 and b=1;
     run;

        %let dsidbd3=%sysfunc(open(&ds5,i));
        %if &dsidbd3>0 %then %do;
            %let n=%sysfunc(attrn(&dsidbd3, nlobs));
            %if &n<=0 %then %do;
              %put No observations found in dataset, &_cstsourcestudy.;
              %let rc=%sysfunc(close(&dsidbd3));
              %goto igd;
            %end;
            %do i=1%to &n;
                %let rc=%sysfunc(fetchobs(&dsidbd3, &i));
                %if &rc ne 0 %then
                    %put %sysfunc(sysmsg());
                %else %do;
                    %let std=%sysfunc(getvarc(&dsidbd3,%sysfunc(varnum(&dsidbd3,standard))));
                    %if %sysfunc(varnum(&dsidbd3,FormalStandardName))
                      %then
                        %let std_formal=%sysfunc(getvarc(&dsidbd3,%sysfunc(varnum(&dsidbd3,FormalStandardName))));
                      %else
                        %let std_formal=&std;

                    %let stdver=%sysfunc(getvarc(&dsidbd3,%sysfunc(varnum(&dsidbd3,standardversion))));
                    %if %sysfunc(varnum(&dsidbd3,Formalstandardversion))
                      %then
                        %let stdver_formal=%sysfunc(getvarc(&dsidbd3,%sysfunc(varnum(&dsidbd3,Formalstandardversion))));
                      %else
                        %let stdver_formal=&stdver;

                    %let stdy=%nrbquote(%sysfunc(getvarc(&dsidbd3,%sysfunc(varnum(&dsidbd3,studyname)))));

                    %let name=&std &stdver;
                    %crtdds_metadataversion(
                      _cstname=%nrbquote(&name),
                      _cstdescr=%nrbquote(&name),
                      _cstStandard=%nrbquote(&std_formal),
                      _cstVersion=%nrbquote(&stdver_formal),
                      _cstdefineversion=1.0.0,
                      _cststudyDS=&_cstoutlib..study, _cststudyname=%nrbquote(&stdy),
                      _cstoutmdvds=&_cstoutlib..metadataversion
                     );

                %end;
            %end;
            %let rc=%sysfunc(close(&dsidbd3));
        %end;
        %else %put Cannot open dataset, &ds5;
   %end;
%end;
%if %sysfunc(exist(&_cstOutlib..metadataversion)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..metadataversion (%cstutilnobs(_cstDatasetName=&_cstOutlib..metadataversion) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_METADATAVERSION
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;


%igd:

* build the itemgroupdef dataset ;
%*************************************************************;
%* build itemgroupdef dataset.                               *;
%*************************************************************;

%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds6=_c06ig&_cstRandom;

%if %symexist(_cstSourceTables) %then %do;
  %if %sysfunc(exist(&_cstSourceTables)) %then %do;
    proc sort data=&_cstSourceTables out=&ds6 nodupkey;
        by standard standardversion;
      run;
        %let dsidbd4=%sysfunc(open(&ds6,i));
        %if &dsidbd4>0 %then %do;
            %let n=%sysfunc(attrn(&dsidbd4, nlobs));
            %if &n<=0 %then %do;
              %put No observations found in dataset, &_cstSourceTables.;
              %let rc=%sysfunc(close(&dsidbd4));
              %goto cl;
            %end;
            %do i=1%to &n;
                %let rc=%sysfunc(fetchobs(&dsidbd4, &i));
                %if &rc ne 0 %then
                    %put %sysfunc(sysmsg());
                %else %do;
                    %let std=%sysfunc(getvarc(&dsidbd4,%sysfunc(varnum(&dsidbd4,standard))));
                    %let stdver=%sysfunc(getvarc(&dsidbd4,%sysfunc(varnum(&dsidbd4,standardversion))));
                    %let name=&std &stdver;
                    %crtdds_itemgroupdefs_adam(
                      _cstsourcetables=&_cstSourceTables,
                      _cstsourcestudy=&_cstsourcestudy,
                      _cststudyds=&_cstoutlib..study,
                      _cstmdvDS=&_cstoutlib..metadataversion,
                      _cstoutitemgroupdefsds=&_cstoutlib..itemgroupdefs
                     );
                %end;
            %end;
            %let rc=%sysfunc(close(&dsidbd4));
        %end;
        %else %put Cannot open dataset, &ds6;
   %end;
%end;
%if %sysfunc(exist(&_cstOutlib..itemgroupdefs)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..itemgroupdefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..itemgroupdefs) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_ITEMGROUPDEFS_ADAM
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;

%cl:
* build the codelists dataset ;
%*************************************************************;
%* build codelists dataset.                                  *;
%*************************************************************;
%cstutil_getRandomNumber(_cstVarname=_cstRandom);
%let ds8=_c08cl&_cstRandom;
  data _null_;
        attrib _cstCatalog format=$char17.
               _cstfmts format=$char200.
               _cstCatalogs format=$char200.;
        _cstfmts = translate(getoption('FMTSEARCH'),'','()');
        do i = 1 to countw(_cstfmts,' ');
          _cstCatalog=scan(_cstfmts,i,' ');
          if index(_cstCatalog,'.') = 0 then do;
               if libref(_cstcatalog)=0 then
                _cstCatalog = catx('.',_cstCatalog,'FORMATS');
          end;
          if exist(_cstCatalog,'CATALOG') then
              _cstCatalogs = catx(' ',_cstCatalogs,_cstCatalog);
        end ;
        IF STRIP(_CSTCATALOG) NE ''
          then call symput('_cstCatalogs',STRIP(_cstCatalogs));
        else call symput('_cstCatalogs','');
      run;
      %if "&_cstCatalogs"="" %then %goto idef;

      %* Concatenate format catalogs into a single reference  *;
      %IF %SYSFUNC(STRIP("&_cstCatalogs")) NE "" %THEN %DO;
      catname _cstfmts ( &_cstCatalogs ) ;
      proc format lib = work._cstfmts cntlout=&ds8 (rename=(fmtname=Name));
      run ;
      catname _cstfmts clear;
      %END;
        %if %sysfunc(exist(&ds8)) %then %do;
            %let fmdsid=%sysfunc(open(&ds8,i));
            %if &fmdsid>0 %then %do;
             %let n=%sysfunc(attrn(&fmdsid, nlobs));
             %let rc=%sysfunc(close(&fmdsid));
             %if &n<=0 %then %do;
                %goto idef;
             %end;
            %end;
        %end;

%let ds7=_c07srccol&_cstRandom;
%if %symexist(_cstSourceColumns) %then %do;
  %if %sysfunc(exist(&_cstSourceColumns)) %then %do;
    data &ds7;
      set &_cstSourceColumns;
        if xmlcodelist^='';
        xmlcodelist=upcase(xmlcodelist);
    run;

    %LET N=0;
    %if &sqlobs>0 %then %do;
      %let ds9=_c09cl&_cstRandom;
    proc sort data=&ds7 ;
      by xmlcodelist;
    run;
    data &ds9( keep=xmlcodelist);
      set &ds8(rename=name=xmlcodelist);
    run;
    proc sort data=&ds9 nodupkey;
      by xmlcodelist;
    run;
    %let ds10=_c10clsrccol&_cstRandom;
    data &ds10;
      merge &ds9( in=a) &ds7(in=b);
        by xmlcodelist;
      if a=1 and b=1;
    run;
    %let ds11=_c11clsrccol&_cstRandom;
    proc sort data=&ds10 out=&ds11 nodupkey;
      by  standard standardversion;
    run;
    %if %sysfunc(exist(&ds11))=0 %then %goto idef;

    %let dsidmd=%sysfunc(open(&ds11,i));
    %if &dsidmd>0 %then %do;
        %let n=%sysfunc(attrn(&dsidmd, nlobs));
        %if &n<=0 %then %do;
          %put No codelists found in dataset, &_cstSourceTables.;
          %goto idef;
        %end;
        %let rc=%sysfunc(close(&dsidmd));
    %end;

    %end;
  %end;
 %end;

%let dsidcl=%sysfunc(open(&ds10,i));
%if &dsidcl>0 and &sqlobs>0 %then %do; * if source_columns do not have any codelists then do not run this step;
  %* now create the codelists datatset *;
  %do i=1 %to &n;
    %let rc=%sysfunc(fetchobs(&dsidcl, &i));
    %if &rc ne 0 %then
      %put %sysfunc(sysmsg());
    %else %do;
      %let std=%sysfunc(getvarc(&dsidcl,%sysfunc(varnum(&dsidcl,standard))));
      %let stdver=%sysfunc(getvarc(&dsidcl,%sysfunc(varnum(&dsidcl,standardversion))));
      %let name=&std &stdver;
    %end;
    %if (%symexist(name)=1) %then
      %crtdds_codelists(
       _cstsourcecolumns=&_cstSourceColumns,
       _cstsourcevalues=&_cstSourceValues,
       _cstmdvds=&_cstoutlib..metadataversion,
       _cstmdvname=%nrbquote(&name),
       _cstoutcodelistsds=&_cstoutlib..codelists
      );
  %end;
%end;
%let rc=%sysfunc(close(&dsidcl));


%*************************************************************;
%* build codelistitems dataset.                              *;
%*************************************************************;
%LET NOCODELIST=0;
%if %sysfunc(exist(&_cstoutlib..codelists))=0 %then %LET NOCODELIST=1;
%IF &NOCODELIST NE 1 %THEN %DO;
  %let dsidcl2=%sysfunc(open(&_cstoutlib..codelists,i));
  %if &dsidcl2>0 %then %do;
    %let n=%sysfunc(attrn(&dsidcl2, nlobs));
    %if &n<=0 %then %do;
      %put No observations found in the codelists dataset, &_cstoutlib..codelists.;
      %let rc=%sysfunc(close(&dsidcl2));
      %goto idef;
    %end;
    %let rc=%sysfunc(close(&dsidcl2));
    %crtdds_codelistitems(
      _cstsourcecolumns=&_cstSourceColumns,
      _cstsourcevalues=&_cstSourceValues,
      _cstcodelistsds=&_cstoutlib..codelists,
      _cstoutcodelistitemsds=&_cstoutlib..codelistitems
      );

    %crtdds_clitemdecodetrans(
      _cstsourcestudy=&_cstsourceStudy ,
      _cstsourcecolumns=&_cstSourceColumns,
      _cstsourcevalues=&_cstSourceValues,
      _cstcodelistitemsds=&_cstoutlib..codelistitems,
      _cstcodelistsds=&_cstoutlib..codelists,
      _cststudyds=&_cstoutlib..study,
      _cstmdvDS=&_cstoutlib..metadataversion,
      _cstCLlang=en,
      _cstoutclitemdecodetransds=&_cstoutlib..clitemdecodetranslatedtext
     );
  %end;
  %else %put Cannot open codelist dataset.;
%END;
%if %sysfunc(exist(&_cstOutlib..codelists)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..codelists (%cstutilnobs(_cstDatasetName=&_cstOutlib..codelists) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_CODELISTS
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;
%if %sysfunc(exist(&_cstOutlib..codelistitems)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..codelistitems (%cstutilnobs(_cstDatasetName=&_cstOutlib..codelistitems) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_CODELISTITEMS
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;
%if %sysfunc(exist(&_cstOutlib..clitemdecodetranslatedtext)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..clitemdecodetranslatedtext (%cstutilnobs(_cstDatasetName=&_cstOutlib..clitemdecodetranslatedtext) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_CLITEMDECODETRANS
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;

%idef:
%*************************************************************;
%* build itemdefs / itemgroupdefitemrefs datasets.           *;
%*************************************************************;
%crtdds_itemdefs(
  _cstsourcecolumns=&_cstSourceColumns,
  _cstsourcestudy=&_cstSourceStudy,
  _cststudyds=&_cstoutlib..study,
  _cstmdvds=&_cstoutlib..metadataversion,
  _cstcodelistsDS=&_cstoutlib..codelists,
  _cstoutitemdefsds2=&_cstoutlib..itemdefs2,
  _cstoutitemdefsds=&_cstoutlib..itemdefs
 );

%crtdds_itemgroupdefitemrefs_adam(
  _cstsourcecolumns=&_cstSourceColumns,
  _cstsourcetables=&_cstSourceTables,
  _cstsourcestudy=&_cstsourcestudy,
  _cstmdvDS=&_cstoutlib..metadataversion,
  _cstitemgroupdefsDS=&_cstoutlib..itemgroupdefs,
  _cstitemdefsDS2=&_cstoutlib..itemdefs2,
  _cststudyds=&_cstoutlib..study,
  _cstoutitemgroupdefitemrefsds=&_cstoutlib..itemgroupdefitemrefs
 );

%if %sysfunc(exist(&_cstOutlib..itemdefs)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..itemdefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..itemdefs) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_ITEMDEFS
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;
%if %sysfunc(exist(&_cstOutlib..itemgroupdefitemrefs)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..itemgroupdefitemrefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..itemgroupdefitemrefs) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_ITEMGROUPDEFITEMREFS_ADAM
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;

%idefleaf:
%*************************************************************;
%* build itemgroupleaf / itemgroupleaftitles datasets.       *;
%*************************************************************;
%crtdds_itemgroupleaf(
  _cstsourcetables=&_cstSourceTables,
  _cstsourcestudy=&_cstSourceStudy,
  _cststudyds=&_cstoutlib..study,
  _cstmdvDS=&_cstoutlib..metadataversion ,
  _cstoutitemgroupleafds=&_cstOutlib..itemgroupleaf
 );

%crtdds_itemgroupleaftitles(
  _cstsourcetables=&_cstSourceTables,
  _cstsourcestudy=&_cstSourceStudy,
  _cststudyds=&_cstoutlib..study,
  _cstmdvDS=&_cstoutlib..metadataversion ,
  _cstoutitemgroupleaftitlesds=&_cstOutlib..itemgroupleaftitles
 );

%if %sysfunc(exist(&_cstOutlib..itemgroupleaf)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..itemgroupleaf (%cstutilnobs(_cstDatasetName=&_cstOutlib..itemgroupleaf) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_ITEMGROUPLEAF
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;
%if %sysfunc(exist(&_cstOutlib..itemgroupleaftitles)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..itemgroupleaftitles (%cstutilnobs(_cstDatasetName=&_cstOutlib..itemgroupleaftitles) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_ITEMGROUPLEAFTITLES
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;



%compmeth:
%*************************************************************;
%* build computationmethods dataset.                         *;
%*************************************************************;
%crtdds_computationmethods(
  _cstsourcecolumns=&_cstSourceColumns,
  _cstsourcestudy=&_cstSourceStudy,
  _cstmdvds=&_cstoutlib..metadataversion,
  _cstitemdefsds=&_cstoutlib..itemdefs,
  _cststudyds=&_cstoutlib..study,
  _cstoutcomputationmethodsds=&_cstoutlib..computationmethods
 );

%if %sysfunc(exist(&_cstOutlib..computationmethods)) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0102
                ,_cstResultParm1=&_cstOutlib..computationmethods (%cstutilnobs(_cstDatasetName=&_cstOutlib..computationmethods) obs)
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_COMPUTATIONMETHODS
                ,_cstResultFlagParm=0
                ,_cstRCParm=0
                ,_cstResultsDSParm=&_cstResultsDS
                );
%end;


%documents:
%*******************************************************************************;
%* build AnnotatedCRFs, SupplementalDocs, MDVLeaf and MDVLeafTitles data sets. *;
%*******************************************************************************;
%if %sysfunc(strip("&_cstSourceDocuments")) ne "" %then %do;
  %crtdds_sourcedocuments(
    _cstsourcedocuments=&_cstSourceDocuments,
    _cstsourcestudy=&_cstSourceStudy,
    _cstStudyDS=&_cstoutlib..Study,
    _cstmdvDS=&_cstoutlib..MetaDataVersion,
    _cstoutAnnotatedCRFs=&_cstoutlib..AnnotatedCRFs,
    _cstoutSupplementalDocs=&_cstoutlib..SupplementalDocs,
    _cstoutMDVLeaf=&_cstoutlib..MDVLeaf,
    _cstoutMDVLeafTitles=&_cstoutlib..MDVLeafTitles,
    _cstStandard=CDISC ADAM,
    _cstStandardVersion=&_cstTrgStandardVersion,
    _cstMode=replace,
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg
  );
  %if %sysfunc(exist(&_cstOutlib..AnnotatedCRFs)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..annotatedcrfs (%cstutilnobs(_cstDatasetName=&_cstOutlib..AnnotatedCRFs) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEDOCUMENTS
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..SupplementalDocs)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..supplementaldocs (%cstutilnobs(_cstDatasetName=&_cstOutlib..SupplementalDocs) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEDOCUMENTS
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..MDVLeaf)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..mdvleaf (%cstutilnobs(_cstDatasetName=&_cstOutlib..MDVLeaf) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEDOCUMENTS
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..MDVLeafTitles)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..mdvleaftitles (%cstutilnobs(_cstDatasetName=&_cstOutlib..MDVLeafTitles) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEDOCUMENTS
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
%end;

%******************************************************************************************************;
%* build ValueLists, ValueListItemRefs, ItemValueListRefs, ItemDefs and ComputationMethods data sets. *;
%******************************************************************************************************;
%if %sysfunc(strip("&_cstSourceValues")) ne "" %then %do;
  %crtdds_sourcevalues(
    _cstsourcevalues=&_cstSourceValues,
    _cstsourcestudy=&_cstSourceStudy,
    _cstStudyDS=&_cstoutlib..Study,
    _cstmdvDS=&_cstoutlib..MetaDataVersion,
    _cstCodeListsDS=&_cstoutlib..CodeLists,
    _cstItemGroupDefsDS=&_cstoutlib..ItemGroupDefs,
    _cstItemGroupDefItemRefsDS=&_cstoutlib..ItemGroupDefItemRefs,
    _cstoutItemDefs=&_cstoutlib..ItemDefs,
    _cstoutValueLists=&_cstoutlib..ValueLists,
    _cstoutValueListItemRefs=&_cstoutlib..ValueListItemRefs,
    _cstoutItemValueListRefs=&_cstoutlib..ItemValueListRefs,
    _cstoutComputationMethods=&_cstoutlib..ComputationMethods,
    _cstStandard=CDISC ADAM,
    _cstStandardVersion=&_cstTrgStandardVersion,
    _cstMode=replace,
    _cstReturn=_cst_rc,
    _cstReturnMsg=_cst_rcmsg
  );

  %if %sysfunc(exist(&_cstOutlib..ValueLists)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..valuelists (%cstutilnobs(_cstDatasetName=&_cstOutlib..ValueLists) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEVALUES
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..ItemValueListRefs)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..itemvaluelistrefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..ItemValueListRefs) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEVALUES
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..ValueListItemRefs)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..valuelistitemrefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..ValueListItemRefs) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEVALUES
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..ComputationMethods)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..computationmethods (%cstutilnobs(_cstDatasetName=&_cstOutlib..ComputationMethods) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEVALUES
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
  %if %sysfunc(exist(&_cstOutlib..ItemDefs)) %then %do;
     %cstutil_writeresult(
                  _cstResultId=CST0102
                  ,_cstResultParm1=&_cstOutlib..itemdefs (%cstutilnobs(_cstDatasetName=&_cstOutlib..ItemDefs) obs)
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=&_cstThisMacro..CRTDDS_SOURCEVALUES
                  ,_cstResultFlagParm=0
                  ,_cstRCParm=0
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;
%end;

%cleanup:

%if (&_cstDebug ne 1) %then %do;
  %do i=1 %to 11;
    %let d=ds&i;
    %if %symexist(&d)  %then %do;
      %let foo=&&&d;
      %if ("&foo" ne "") %then %do;
        %if %sysfunc(exist(&&&d)) %then %do;
          proc datasets nolist lib=work;
            delete &&&d;
          quit;
          run;
        %end;
      %end;
    %end;
  %end;
%end;

%cstutil_deleteDataSet(_cstDataSetName=&_cstoutlib..itemdefs2);

%exit:

%* Persist the results if specified in sasreferences  *;
%cstutil_saveresults();

%* reset the resultSequence/SeqCnt variables;
%*****cstutil_internalManageResults(_cstAction=RESTORE);


%mend crtdds_adamtodefine;
