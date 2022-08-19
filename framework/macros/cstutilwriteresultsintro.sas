%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilwriteresultsintro                                                       *;
%*                                                                                *;
%* Adds intro records to the Results data set.                                    *;
%*                                                                                *;
%* This macro gets the name of the currently executing SAS program. The program   *;
%* name can be extracted in batch mode or when executing after the program file   *;
%* is opened by the SAS Enhanced Editor in Windows environments.                  *;
%*                                                                                *;
%* You can specify the program name in the _cstPGM parameter. The macro uses this *;
%* name only when the macro cannot determine the program name.                    *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstResultFlag Results: Problem was detected                           *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstVersion Version of Clinical Standards Toolkit                      *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%*                                                                                *;
%* @param _cstResultID - required - The result ID of the matching record in the   *;
%*            Messages data set.                                                  *;
%* @param _cstProcessType - required - Process Type to report.                    *;
%*            Default: REPORTING                                                  *;
%* @param _cstPgm - optional - The name of the driver module calling this macro.  *;
%*            Default: CST0200                                                    *;
%*                                                                                *;
%* @since  1.5                                                                    *;
%* @exposure internal                                                             *;

%macro cstutilwriteresultsintro(
    _cstResultID=CST0200,
    _cstProcessType=REPORTING,
    _cstPgm=
    ) / des='Adds intro records to the Results data set';

    %local
      _cstProgram
      _cstTempDS
      _cstTempLib
      _cstrunsasref
    ;

    %if %nrbquote(%sysfunc(getoption(SYSIN))) EQ and &sysscp eq WIN
      %then %do;
           %if %sysfunc(sysexist(SAS_EXECFILENAME)) %then %let _cstProgram = %sysget(SAS_EXECFILENAME);
      %end;

    %* For CDI;
    %if %sysevalf(%superq(_cstProgram)=,boolean) %then %do;
     %if %symexist(etls_jobName) %then %let _cstProgram = %nrbquote(&etls_jobName);
    %end;

    %* For CDI or EG;
    %if %sysevalf(%superq(_cstProgram)=,boolean) %then %do;
     %if %symexist(_CLIENTTASKLABEL) %then %let _cstProgram = %nrbquote(&_CLIENTTASKLABEL);
    %end;

    %* For EG;
    %if %sysevalf(%superq(_cstProgram)=,boolean) %then %do;
     %if %symexist(_SASPROGRAMFILE) %then %let _cstProgram = %scan(%nrbquote(&_SASPROGRAMFILE), -1, %str(\/));
    %end;

    %if %sysevalf(%superq(_cstProgram)=,boolean) %then %do;
      %put [CSTLOG%str(MESSAGE).&sysmacroname]: Program name could not be determined and has been set to %nrbquote(&_cstPgm);
      %let _cstProgram = %nrbquote(&_cstPgm);
    %end;

    %if %symexist(_cstSASrefs) %then
    %do;
      %if not %sysevalf(%superq(_cstSASrefs)=, boolean) %then
      %do;
        %if %sysfunc(exist(&_cstSASrefs)) %then
        %do;

          %* Get runtime SASReferences path *;
          %let _cstrunsasref=;
          data _null_;
            length _csttemp $2096;
            set &_cstSASrefs (where=(upcase(standard)="&_cstStandard"));
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
            %if %sysfunc(kindexc(&_cstsasrefs,'.')) %then
            %do;
              %let _cstTempLib=%sysfunc(kscan(&_cstsasrefs,1,'.'));
              %let _cstTempDS=%sysfunc(kscan(&_cstsasrefs,2,'.'));
            %end;
            %else
            %do;
              %let _cstTempLib=work;
              %let _cstTempDS=&_cstsasrefs;
            %end;
            %let _cstrunsasref=%sysfunc(pathname(&_cstTempLib))/&_cstTempDS..sas7bdat;
          %end;

        %end;
      %end;
    %end;

    %* Write information to the results data set about this run. *;
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STANDARD: &_cstStandard,_cstSeqNoParm=1,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STANDARDVERSION: &_cstStandardVersion,_cstSeqNoParm=2,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS DRIVER: &_cstProgram,_cstSeqNoParm=3,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS DATE: %sysfunc(datetime(), is8601dt.),_cstSeqNoParm=4,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS TYPE: &_cstProcessType,_cstSeqNoParm=5,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS SASREFERENCES: &_cstrunsasref,_cstSeqNoParm=6,_cstSrcDataParm=&_cstSrcData);
    %if %symexist(studyRootPath) %then
      %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STUDYROOTPATH: &studyRootPath,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %else
      %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STUDYROOTPATH: <not used>,_cstSeqNoParm=7,_cstSrcDataParm=&_cstSrcData);
    %if %symexist(studyOutputPath) %then
      %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STUDYOUTPUTPATH: &studyOutputPath,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
    %else
      %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS STUDYOUTPUTPATH: <not used>,_cstSeqNoParm=8,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS GLOBALLIBRARY: &_cstGRoot,_cstSeqNoParm=9,_cstSrcDataParm=&_cstSrcData);
    %cstutil_writeresult(_cstResultID=&_cstResultID,_cstResultParm1=PROCESS CSTVERSION: &_cstVersion,_cstSeqNoParm=10,_cstSrcDataParm=&_cstSrcData);
    %let _cstSeqCnt=9;

%mend cstutilwriteresultsintro;
