%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcopyfolderhierarchy                                                     *;
%*                                                                                *;
%* Copies a folder hierarchy and, optionally, its contents.                       *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The librefs in the macro parameters have been allocated.                  *;
%*   2. If _cstFolderDS or _cstFileDS exist, it is overwritten.                   *;
%*                                                                                *;
%* @param _cstSourceFolder - required - The folder hierarchy to copy.             *;
%* @param _cstNewFolder - required - The folder hierarchy to create.              *;
%* @param _cstOverWrite - optional - Overwrite the folder specified by            *;
%*            _cstNewFolder.                                                      *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param _cstBuildFoldersOnly - optional - Copy only the folder hierarchy and    *;
%*            not the contents.                                                   *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%* @param _cstFolderDS - required - The libref.dataset that contains the list of  *;
%*            all folders in _cstSourceFolder.                                    *;
%* @param _cstFileDS - required - The libref.dataset that contains the list of    *;
%*            all of the files in _cstSourceFolder.                               *;
%*                                                                                *;
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;

%macro cstutilcopyfolderhierarchy(
  _cstSourceFolder=,
  _cstNewFolder=,
  _cstOverWrite=N,
  _cstBuildFoldersOnly=N,
  _cstFolderDS=,
  _cstFileDS=
  ) / des='CST: Copy folder hierarchy and content';


  %local
    rc
    copycmd
    pathdelim
    saveopt
    workPath
    _cstTempCmd
    _cstTempCmdFile
    _cstTempCmdCopy
    _cstTempCmdFileCopy
  ;
  
  %*************************************************;
  %*  Check for existence of _cstDebug             *;
  %*************************************************;
  %if ^%symexist(_cstDeBug) %then
  %do;
    %global _cstDeBug;
    %let _cstDebug=0;
  %end;
  
  %************************;
  %* Parameter checking   *;
  %************************;

  %if %length(&_cstSourceFolder) < 1 or %length(&_cstNewFolder) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstSourceFolder and _cstNewFolder parameter values are required.;
    %goto exit_error;
  %end;
  %if %length(&_cstFolderDS) < 1 or %length(&_cstFileDS) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstFolderDS and _cstFileDS parameter values are required.;
    %goto exit_error;
  %end;
  %if %length(&_cstBuildFoldersOnly) < 1 %then
    %let _cstBuildFoldersOnly=N;

  %let rc = %sysfunc(filename(fileref,&_cstSourceFolder)) ; 
  %if %sysfunc(fexist(&fileref))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstSourceFolder does not exist.;
    %goto exit_error;
  %end;
  %let rc = %sysfunc(filename(fileref,&_cstNewFolder)) ; 
  %if %sysfunc(fexist(&fileref)) %then 
  %do;
    %if %upcase(&_cstOverWrite) ne Y %then
    %do;
      %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstNewFolder already exists - set _cstOverWrite=Y to overwrite.;
      %goto exit_error;
    %end;
  %end;

  %let workPath=%sysfunc(pathname(work));
  %if  &sysscp ^= WIN %then
  %do;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstSourceFolder,_cstFoldersOut=&_cstFolderDS,_cstFilesOut=&_cstFileDS, _cstPathDelim=/);
    %let pathdelim=/;
    %let copycmd=cp;
    %let _cstTempCmd=bash "&workPath.&pathdelim.makedir.sh";
    %let _cstTempCmdFile=&workPath.&pathdelim.makedir.sh;
    %let _cstTempCmdCopy=bash "&workPath.&pathdelim.copyfiles.sh";
    %let _cstTempCmdFileCopy=&workPath.&pathdelim.copyfiles.sh;
  %end;
  %else %do;
    %let saveopt=%sysfunc(getoption(XWAIT));
    options noxwait;
    %_cstutilgetfoldersfiles(_cstRoot=&_cstSourceFolder,_cstFoldersOut=&_cstFolderDS,_cstFilesOut=&_cstFileDS, _cstPathDelim=\);
    %let pathdelim=\;
    %let copycmd=copy;
    %let _cstTempCmd="&workPath.&pathdelim.makedir.bat";
    %let _cstTempCmdFile=&workPath.&pathdelim.makedir.bat;
    %let _cstTempCmdCopy="&workPath.&pathdelim.copyfiles.bat";
    %let _cstTempCmdFileCopy=&workPath.&pathdelim.copyfiles.bat;
  %end;
  
  filename cmdfile "&_cstTempCmdFile";
  data _null_;
    set &_cstFolderDS;
      attrib tempvar format=$2054.;
    file cmdfile;
    tempvar=catx(' ','mkdir',cats('"', kstrip(tranwrd(root, "&_cstSourceFolder", "&_cstNewFolder")), '"'));
    put tempvar;
    %if &_cstDebug %then putlog tempvar;;
  run;
  
  %sysExec(&_cstTempCmd);
  %if &sysrc>0 %then
    %put  WAR%STR(NING): [CSTLOG%str(MESSAGE).&sysmacroname] 0 folders were created.;
  %else
    %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] %cstutilnobs(_cstDatasetName=&_cstFolderDS) folders were created.;

  filename cmdfile clear;

  %if %upcase(&_cstBuildFoldersOnly)=N %then
  %do;
    
    proc sort data=&_cstFileDS;
      by path filename;
    run;

    filename cmdfile "&_cstTempCmdFileCopy";

    data _null_;
      set &_cstFileDS;
        by path;
      attrib tempvar format=$2054.;
      file cmdfile;
      if first.path then
      do;
      %if  &sysscp ^= WIN %then
      %do;
        tempvar=catx(' ',"&copycmd",cats('"', path,"&pathdelim", '"', '*.*'),cats('"', kstrip(tranwrd(path, "&_cstSourceFolder", "&_cstNewFolder")),'"'));
      %end;
      %else %do;
        tempvar=catx(' ',"&copycmd",cats('"', path,"&pathdelim",'*.*', '"'),cats('"', kstrip(tranwrd(path, "&_cstSourceFolder", "&_cstNewFolder")),'"'));
      %end;  
        put tempvar;
        %if &_cstDebug %then putlog tempvar;;
      end;
    run;
    
    %sysExec(&_cstTempCmdCopy);
    %if &sysrc>0 %then
      %put  WAR%STR(NING): [CSTLOG%str(MESSAGE).&sysmacroname] 0 files were copied.;
    %else
      %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] %cstutilnobs(_cstDatasetName=&_cstFileDS) files were copied.;
      
    filename cmdfile clear;

  %end;
  
  %if  &sysscp = WIN %then
  %do;
    options &saveopt;
  %end;

%exit_error:

%mend cstutilcopyfolderhierarchy;
