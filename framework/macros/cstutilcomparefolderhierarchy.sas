%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcomparefolderhierarchy                                                  *;
%*                                                                                *;
%* Compares the folder hierarchy of two folders.                                  *;
%*                                                                                *;
%* This macro compares the folder structure, files, and data set structures of    *;
%* two folders. The comparison includes such items as the presence or absence of  *;
%* subdirectories and files, and the differences in data sets (such as the number *;
%* of observations and the changes in values).                                    *;
%*                                                                                *;
%* For the best results, the subfolders of each directory must share a similar    *;
%* naming convention or structure, although this is not required.                 *;
%*                                                                                *;
%* @param _cstBaseFolder - required - The full path to the folder to compare      *;
%*            against (for example, C:\cstGlobalLibrary).                         *;
%* @parm  _cstBaseVersion - optional - If comparing folders that were supplied    *;
%*            with a version of the SAS Clinical Standards Toolkit (such as the   *;
%*            global standards library), the version of the SAS Clinical          *;
%*            Standards Toolkit that supplied _cstBaseFolder.                     *;
%* @param _cstCompFolder - required - The full path to the folder to compare (for *;
%*            example, C:\cstGlobalLibrary_Copy15).                               *;
%* @parm  _cstCompVersion - optional - If comparing folders that were supplied    *;
%*            with a version of the SAS Clinical Standards Toolkit (such as the   *;
%*            global standards library), the version of the SAS Clinical          *;
%*            Standards Toolkit that supplied _cstCompFolder.                     *;
%* @param _cstRptDiff - required - The data set to contain the differences.       *;
%*            Default: work._cstResultsDS                                         *;
%* @param _cstRptDiffType - required - The type of comparision.                   *;
%*            values: FOLDER | FILE | DATASET | ALL                               *;
%*            FOLDER:  Compare folders.                                           *;
%*            FILE:    Compare files.                                             *;
%*            DATASET: Compare data sets.                                         *;
%*            ALL:     Compare folders, files, and data sets.                     *;
%*            Default: ALL                                                        *;
%* @param _cstOverWrite - required - Overwrite the data set that is specified by  *;
%*             _cstRptDS. If this value is not specified as Y or A (Append) and   *;
%*               _cstRptDiff exists, this macro aborts.                           *;
%*            Values: Y | N | A                                                   *;
%*            Default: A                                                          *;
%* @param  _cstOutReportPath - optional - The path to the output folder for the   *;
%*            report file.                                                        *;
%*            NOTE: If a SAS Output Delivery System destination does not support  *;
%*            PATH, this value must be blank.                                     *;
%* @param  _cstOutReportFile - optional - The filename of the report file. If     *;
%*            _cstOutReportPath is not specified, this value must be a full       *;
%*            path.                                                               *;
%* @param  _cstODSReportType - optional - The type of report.                     *;
%*            Values:  html                                                       *;
%*            Default: html                                                       *;
%* @param  _cstODSStyle - optional - The SAS Output Delivery System style to use  *;
%*            for the report.                                                     *;
%* @param  _cstODSOptions - optional - Additional SAS Output Delivery System      *;
%*            options.                                                            *;
%*                                                                                *;
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;

%macro cstutilcomparefolderhierarchy(
  _cstBaseFolder=,
  _cstBaseVersion=,
  _cstCompFolder=,
  _cstCompVersion=,
  _cstRptDiff=work._cstResultsDS,
  _cstRptDiffType=ALL,
  _cstOverwrite=A,
  _cstOutReportPath=,
  _cstOutReportFile=,
  _cstODSReportType=html,
  _cstODSStyle=SASWeb,
  _cstODSOptions=
  ) / des='CST: Compares folders and files between two hierarchies';

  %local rc
         _cstRandom
         _cstBaseFolder1
         _cstCompFolder1
         _cstexit_flag
         _cstNew
         RegexID
         Regex
         ;

  %cstutil_getRandomNumber(_cstVarname=_cstRandom);

  %************************;
  %*  Parameter checking  *;
  %************************;
  %let _cstexit_flag=0;

  %if %length(&_cstBaseFolder) < 1 or %length(&_cstCompFolder) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstBaseFolder and _cstCompFolder parameter values are required.;
    %let _cstexit_flag=1;
  %end;

  %if %length(&_cstBaseFolder) > 0 %then
  %do;
    %let rc = %sysfunc(filename(fileref,&_cstBaseFolder)) ; 
    %if %sysfunc(fexist(&fileref))=0 %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstBaseFolder does not exist.;
      %let _cstexit_flag=1;
    %end;
  %end;

  %if %length(&_cstCompFolder) > 0 %then
  %do;
    %let rc = %sysfunc(filename(fileref,&_cstCompFolder)) ; 
    %if %sysfunc(fexist(&fileref))=0 %then 
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstCompFolder does not exist.;
      %let _cstexit_flag=1;
    %end;
  %end;

  %if %length(&_cstRptDiff) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptDiff parameter value is required.;
    %let _cstexit_flag=1;
  %end;

  %if %sysfunc(exist(&_cstRptDiff)) and (%upcase(&_cstOverwrite) ne A and %upcase(&_cstOverwrite) ne Y) %then
  %do;
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] &_cstRptDiff exists but cannot be overwritten based on _cstOverwrite parameter setting (&_cstOverwrite). Macro did not run.;
    %let _cstexit_flag=1;
  %end;

  %let Regex=/^[1-9].(\d)+$/;
  %let RegexID=%sysfunc(PRXPARSE(&Regex)); 

  %if %length(&_cstBaseVersion)>0 %then
  %do;
    %if %sysfunc(PRXMATCH(&RegexID, &_cstBaseVersion))=0 %then
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The _cstBaseVersion value (&_cstBaseVersion) is an incorrect Clinical Standards Toolkit Version.;
      %let _cstexit_flag=1;
    %end;
  %end;

  %if %length(&_cstCompVersion)>0 %then
  %do;
    %if %sysfunc(PRXMATCH(&RegexID, &_cstCompVersion))=0 %then
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] The _cstCompVersion value (&_cstCompVersion) is an incorrect Clinical Standards Toolkit Version.;
      %let _cstexit_flag=1;
    %end;
  %end;
  %syscall PRXFREE(RegexID); 
  
  %if (%length(&_cstCompVersion)>0 and %length(&_cstBaseVersion)<1) or (%length(&_cstCompVersion)<1 and %length(&_cstBaseVersion)>0) %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] Value is present for one version but missing for the other. Check _cstBaseVersion and _cstCompVersion parameters.;
    %let _cstexit_flag=1;
  %end;

  %if %length(&_cstRptDiffType)>0 and %upcase(&_cstRptDiffType) ne FOLDER and %upcase(&_cstRptDiffType) ne FILE and %upcase(&_cstRptDiffType) ne DATASET and %upcase(&_cstRptDiffType) ne ALL %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] Incorrect _cstRptDiffType value (&_cstRptDiffType). Value must be FOLDER, FILE, DATASET, or ALL.;
    %let _cstexit_flag=1;
  %end;
  %else %if %length(&_cstRptDiffType) < 1 %then
  %do;
    %let _cstRptDiffType=ALL;
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptDiffType parameter was blank - defaulting value to ALL.;
  %end;

  %********************************;
  %*  Parameter problem detected  *;
  %********************************;
  %if &_cstexit_flag=1 %then %goto exit_error;

  %*******************************;
  %*  Clean up any output files  *; 
  %*******************************;
  %if %upcase(&_cstOverwrite)=Y %then
  %do;
    %if %sysfunc(exist(&_cstRptDiff)) %then
      %do;
        %cstutil_deleteDataSet(_cstDataSetName=&_cstRptDiff);
      %end;
  %end;

  %****************************;
  %*  Start of Utility Macro  *;
  %****************************;
  
  %let rc = %sysfunc(filename(_cstNew,&_cstBaseFolder)); 
  %let _cstBaseFolder1=%sysfunc(pathname(&_cstNew));
  %let rc = %sysfunc(filename(_cstNew,&_cstCompFolder)); 
  %let _cstCompFolder1=%sysfunc(pathname(&_cstNew));
 
  %if  &sysscp ^= WIN %then
  %do;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstBaseFolder1, 
      _cstFoldersOut=dirs_found_&_cstRandom, _cstFilesOut=BaseRoot_&_cstRandom, 
      _cstPathDelim=/, _cstRecurse=Y);
  %end;
  %else %do;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstBaseFolder1, 
      _cstFoldersOut=dirs_found_&_cstRandom, _cstFilesOut=BaseRoot_&_cstRandom, 
      _cstPathDelim=\, _cstRecurse=Y);    
  %end;

  data work._cstBaseRoot_&_cstRandom;
    length fldrbase fldrroot subfolder subfolder2 $2048 dsname dsnbase $32;
    set BaseRoot_&_cstRandom(rename=(path=fldrbase));
    subfolder=ksubstr(fldrbase, length("&_cstBaseFolder1")+2);    
    dsname=scan(filename, 1, ".");
    if upcase(fileextension)="SAS7BDAT" 
      then dsname=kcompress(tranwrd(filename,".sas7bdat",""));
      else dsname='';
    dsnbase=dsname;
    %if %length(&_cstBaseVersion)>0 %then
    %do;
      if kindex(subfolder,"-&_cstBaseVersion") > 0 
        then subfolder2=kcompress(tranwrd(subfolder,"-&_cstBaseVersion",""));
        else subfolder2=subfolder;
      if kindex(fldrbase,"-&_cstBaseVersion") > 0 
        then fldrroot=kcompress(tranwrd(fldrbase,"-&_cstBaseVersion",""));
        else fldrroot=fldrbase;
    %end;
    %else 
    %do;
      subfolder2=subfolder;
      fldrroot=fldrbase;
    %end;
    fldrroot=tranwrd(fldrroot,"&_cstBaseFolder1","Root Folder");
  run;
  
  %if  &sysscp ^= WIN %then
  %do;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstCompFolder1, 
      _cstFoldersOut=dirs_found_&_cstRandom, _cstFilesOut=CompRoot_&_cstRandom, 
      _cstPathDelim=/, _cstRecurse=Y);
  %end;
  %else %do;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstCompFolder1, 
      _cstFoldersOut=dirs_found_&_cstRandom, _cstFilesOut=CompRoot_&_cstRandom, 
      _cstPathDelim=\, _cstRecurse=Y);    
  %end;
  
  data work._cstCompRoot_&_cstRandom;
    length fldrcomp fldrroot subfolder subfolder2 $2048 dsname dsncomp $32;
    set CompRoot_&_cstRandom(rename=(path=fldrcomp));
    subfolder=ksubstr(fldrcomp, length("&_cstCompFolder1")+2);    
    dsname=scan(filename, 1, ".");
    if upcase(fileextension)="SAS7BDAT" 
      then dsname=kcompress(tranwrd(filename,".sas7bdat",""));
      else dsname='';
    dsncomp=dsname;
    %if %length(&_cstCompVersion)>0 %then
    %do;
      if kindex(subfolder,"-&_cstCompVersion") > 0 
        then subfolder2=kcompress(tranwrd(subfolder,"-&_cstCompVersion",""));
        else subfolder2=subfolder;
      if kindex(fldrcomp,"-&_cstCompVersion") > 0 
        then fldrroot=kcompress(tranwrd(fldrcomp,"-&_cstCompVersion",""));
        else fldrroot=fldrcomp;
    %end;
    %else 
    %do;
      subfolder2=subfolder;
      fldrroot=fldrcomp;
    %end;
    fldrroot=tranwrd(fldrroot,"&_cstCompFolder1","Root Folder");
  run;

  %*************************************************************************;
  %*                       Report Type = FOLDER                            *;
  %*************************************************************************;

  %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=FOLDER %then
  %do;

    proc sort data=work._cstBaseRoot_&_cstRandom out=_cstFldrBase_&_cstRandom(keep=subfolder2 fldrbase) nodupkey;
      by subfolder2;
    run;

    proc sort data=work._cstCompRoot_&_cstRandom out=_cstFldrComp_&_cstRandom(keep=subfolder2 fldrcomp) nodupkey;
      by subfolder2;
    run;

    data work._cstfolderresult_&_cstRandom(keep=fldrbase fldrcomp resultc resulttype condition);
      length fldrbase fldrcomp $2048 resultc $200 resulttype $8;
      label fldrbase = "BASE Folder name"
            fldrcomp = "COMP Folder name"
            resultc  = "Result"
            resulttype = "Report Type"
            condition = "Exists 1=In Base Only 2=In Comp Only"
            ;
      merge work._cstFldrBase_&_cstRandom(in=inbase) 
            work._cstFldrComp_&_cstRandom(in=incomp);
        by subfolder2;
      call missing(dsname,dsnbase,dsncomp,nobsbase,nobscomp);
      if inbase and ^incomp then 
      do; 
        resultc="Folder present in Base only";
        result=1;
        condition=1;
      end;
      if ^inbase and incomp then 
      do;
        resultc="Folder present in Comp only";
        result=1;
        condition=2;
      end;
      resulttype="Folder";
       if result=1;
      drop result;
    run;  

    data &_cstRptDiff;
      %if %sysfunc(exist(&_cstRptDiff)) and (%upcase(&_cstOverwrite)=A or %upcase(&_cstRptDiffType)=ALL) %then
      %do;
        set &_cstRptDiff work._cstfolderresult_&_cstRandom; 
      %end;
      %else
      %do;
        set work._cstfolderresult_&_cstRandom; 
      %end;
    run;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstfldrbase_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstfldrcomp_&_cstRandom);

  %end;
  
  %*************************************************************************;
  %*                       Report Type = FILE                              *;
  %*************************************************************************;

  %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=FILE %then
  %do;
    
    proc sort data=work._cstBaseRoot_&_cstRandom out=_cstFileBase_&_cstRandom nodupkey;
      by fldrroot filename;
      where filename ne '';
    run;

    proc sort data=work._cstCompRoot_&_cstRandom out=_cstFileComp_&_cstRandom nodupkey;
      by fldrroot filename;
      where filename ne '';
    run;

    data work._cstfileresult_&_cstRandom(keep=fldrbase fldrcomp filename resultc resulttype condition);
      length fldrbase fldrcomp $2048 resultc $200 resulttype $8;
      label filename = "Name of File"
            fldrbase = "BASE Folder name"
            fldrcomp = "COMP Folder name"
            resultc  = "Result"
            resulttype = "Report Type"
            condition ="Exists 1=In Base Only 2=In Comp Only";
            ;
      merge work._cstFileBase_&_cstRandom(in=inbase drop=subfolder subfolder2 dsname fileextension) 
            work._cstFileComp_&_cstRandom(in=incomp drop=subfolder subfolder2 dsname fileextension);
      by fldrroot filename;
      call missing(dsname,dsnbase,dsncomp,nobsbase,nobscomp);
      if inbase and ^incomp then 
      do; 
        resultc="File present in Base only";
        result=1;
        condition=1;
      end;
      if ^inbase and incomp then 
      do;
        resultc="File present in Comp only";
        result=1;
        condition=2;
      end;
      resulttype="File";
      if result=1;
      drop result;
    run;  

    data &_cstRptDiff;
      %if %sysfunc(exist(&_cstRptDiff)) and (%upcase(&_cstOverwrite)=A or %upcase(&_cstRptDiffType)=ALL) %then
      %do;
        set &_cstRptDiff work._cstfileresult_&_cstRandom; 
      %end;
      %else
      %do;
        set work._cstfileresult_&_cstRandom; 
      %end;
    run;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstfilebase_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstfilecomp_&_cstRandom);

  %end;  

  %*************************************************************************;
  %*                       Report Type = DATASET                           *;
  %*************************************************************************;

  %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=DATASET %then
  %do;

    proc sql;
      create table work._cstRptDiff_&_cstRandom as
      select b.subfolder, b.dsname, dsnbase, fldrbase, dsncomp, fldrcomp
      from work._cstBaseRoot_&_cstRandom as b, 
           work._cstCompRoot_&_cstRandom as c
      where (b.subfolder2=c.subfolder2) and (b.dsname=c.dsname) and (b.dsname ne '' and c.dsname ne '')
      ;
    quit;    

    filename _cstCode CATALOG "work._cst.code.source" LRECL=2048;

    data _null_;
      length _Code $1014;
      set work._cstRptDiff_&_cstRandom;
      file _cstCode;
      _Code=cats('%_cstutilcompds(fldrbase=',fldrbase,', fldrcomp=',fldrcomp,', baseds=',dsnbase,', compds=',dsncomp,", adTo=work._cstdataresult_&_cstRandom);");
      put _Code;
    run;
    
    %cstutil_deleteDataSet(_cstDataSetName=work._cstRptDiff_&_cstRandom);

    data work._cstdataresult_&_cstRandom;
      length fldrbase fldrcomp $2048 dsname dsnbase dsncomp $ 32 result nobsbase nobscomp 8 resultc $200 resulttype $8;
      label dsname   = "Dataset name"
            dsnbase  = "BASE Dataset name"
            fldrbase = "BASE Folder name"
            dsncomp  = "COMP Dataset name"
            fldrcomp = "COMP Folder name"
            nobsbase = "# BASE obs"
            nobscomp = "# COMP obs"
            result   = "PROC COMPARE sysinfo"
            resultc  = "Result"
            resulttype = "Report Type"
            ;
      call missing (of _all_);
      stop;
    run;  

    %include _cstCode;

    proc datasets nolist lib=work;
      delete _cst / memtype=catalog;
    quit;

    filename _cstCode clear;
    
    data work._cstdataresult_&_cstRandom;
      set work._cstdataresult_&_cstRandom; 
      resulttype="Dataset";
      where result ne 0;
    run;

    data &_cstRptDiff;
      %if %sysfunc(exist(&_cstRptDiff)) and (%upcase(&_cstOverwrite)=A or %upcase(&_cstRptDiffType)=ALL) %then
      %do;
        set &_cstRptDiff work._cstdataresult_&_cstRandom; 
      %end;
      %else
      %do;
        set work._cstdataresult_&_cstRandom; 
      %end;
    run;

    %cstutil_deleteDataSet(_cstDataSetName=work._cstbaseroot_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work._cstcomproot_&_cstRandom);

  %end;

  %*************************************;
  %*  ODS Code to print report output  *;
  %*************************************;
  %if %sysevalf(%superq(_cstOutReportFile)=, boolean)=0 %then 
  %do;
    %if %sysevalf(%superq(_cstODSReportType)=, boolean) %then 
    %do;
      %let _cstODSReportType=html;
      %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstODSReportType set to "&_cstODSReportType";
    %end;

    %if %sysevalf(%superq(_cstODSStyle)=, boolean) %then 
    %do;
      %let _cstODSStyle=SASWeb;
      %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstODSStyle set to "&_cstODSStyle";
    %end;

    ods listing close;
    ods escapechar = '^';
    ods &_cstODSReportType %if %sysevalf(%superq(_cstOutReportPath)=, boolean)=0 %then path="&_cstOutReportPath"; file="&_cstOutReportFile" style=&_cstODSStyle &_cstODSOptions;
    
    %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=FOLDER %then
    %do;
      title01 "Compare FOLDERS between Base and Compare Directories";
      title02 "Base Directory: &_cstBaseFolder";
      title03 "Compare Directory: &_cstCompFolder";
      proc print data=work._cstfolderresult_&_cstRandom label;
        var fldrbase fldrcomp resultc resulttype condition;  
      run;
    %end;
    
    %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=FILE %then
    %do;
      title01 "Compare FILES between Base and Compare Directories";
      title02 "Base Directory: &_cstBaseFolder";
      title03 "Compare Directory: &_cstCompFolder";
      proc print data=work._cstfileresult_&_cstRandom label;
        var filename fldrbase fldrcomp resultc resulttype condition;  
      run;
    %end;
    
    %if %upcase(&_cstRptDiffType)=ALL or %upcase(&_cstRptDiffType)=DATASET %then
    %do;
      title01 "Compare SAS Data Sets between Base and Compare Directories";
      title02 "Base Directory: &_cstBaseFolder";
      title03 "Compare Directory: &_cstCompFolder";
      proc print data=work._cstdataresult_&_cstRandom label;
        var dsname fldrbase fldrcomp nobsbase nobscomp resultc resulttype;  
      run;
    %end;
    
    ods &_cstODSReportType close;
    ods listing;
    
  %end;
  %else 
  %do;
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] _cstOutReportFile parameter not specified.;
  %end;

  %****************************;
  %*  Cleanup the work area.  *;
  %****************************;

  %cstutil_deleteDataSet(_cstDataSetName=work.baseroot_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work.comproot_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work.dirs_found_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstfolderresult_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstfileresult_&_cstRandom);
  %cstutil_deleteDataSet(_cstDataSetName=work._cstdataresult_&_cstRandom);

  %exit_error:

%mend cstutilcomparefolderhierarchy;
