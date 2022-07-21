%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_createsubdir                                                           *;
%*                                                                                *;
%* Creates a subdirectory on a computer that is not running Microsoft Windows.    *;
%*                                                                                *;
%* The SAS Clinical Standards Toolkit sample drivers create output files that     *;
%* need to have Read and Write access to the subdirectories. This macro creates   *;
%* the subdirectories in the specified workspace. If a value is missing, the      *;
%* StudyOutputPath points to the Work directory, and any subdirectories are       *;
%* created under it. StudyOutputPath is referenced in SASReferences.              *;
%*                                                                                *;
%* @macvar studyOutputPath Toolkit output path for a study                        *;
%*                                                                                *;
%* @param _cstSubDir - optional - The subdirectory to create. If this parameter   *;
%*            is not specified, the macro assumes no subdirectory is needed.      *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_createsubdir(
    _cstSubDir=
    ) / des='CST: Create subdirectory';

  %local
    dir
    firstchar
    tworkPath
  ;

  %****************************************************;
  %*  Check system, if not Windows assume UNIX-style  *;
  %****************************************************;
  %if  &sysscp ^= WIN %then
  %do;
    %let tworkPath=%sysfunc(pathname(work));

    %if %symexist(studyOutputPath) %then
    %do;
      %if %length(&studyOutputPath)<1 %then
      %do;
        %let studyOutputPath=&tworkPath;
      %end;
    %end;
    %else
      %let studyOutputPath=&tworkPath;

    %*****************************************************************;
    %*  No subdirectory specified. Assume no subdirectory is needed  *;
    %*****************************************************************;
    %if %length(&_cstSubDir) = 0 %then
    %do;
      %goto exit_macro;
    %end;
    %else
    %do;
      %********************************************************;
      %*  Handle incorrect \ delimiter for UNIX, change to /  *;
      %********************************************************;
      %let _cstSubDir=%sysfunc(tranwrd(%sysfunc(trim(&_cstSubDir)),%str(\),%str(/)));

      %********************************************************;
      %*  Handle missing / at beginning of subdirectory name  *;
      %********************************************************;
      %let firstchar=%substr(%left(&_cstSubDir),1,1);
      %if "&firstchar" ne "/" %then
      %do;
        %let _cstSubDir=/&_cstSubDir;
      %end;
      %let dir=mkdir -p &studyOutputPath&_cstSubDir;
      %syscall system(dir);
    %end;
  %end;

  %exit_macro:

%mend cstutil_createsubdir;