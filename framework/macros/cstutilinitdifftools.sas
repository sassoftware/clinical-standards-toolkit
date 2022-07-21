%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilinitdifftools                                                           *;
%*                                                                                *;
%* Initializes the comparison tools macros.                                       *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilinitdifftools()
   / des='CST: Makes difftool macros available';

  %*************************************************************************;
  %* Given a root folder, builds  a data set with folder names and a data  *;
  %* set of filenames within the root (and optionally, recursively) within *;
  %* all subfolders.                                                       *;
  %*                                                                       *;
  %* Acknowledgement:  Jack Hamilton provided the basis for this code.     *;
  %*     See http://www.wuss.org/proceedings12/55.pdf                      *;
  %*************************************************************************;
  %macro _cstutilgetfoldersfiles(
    _cstRoot=,
    _cstFiletype=,
    _cstFoldersOut=,
    _cstFilesOut=,
    _cstPathDelim=/,
    _cstRecurse=Y
    ) / des='CST: Retrieve folders and files';
    
    data &_cstFoldersOut;
      length root $2048. ;
      root = "&_cstRoot";
      output;
    run;
     
    data
      &_cstFoldersOut                     /* Updated list of directories searched */
      &_cstFilesOut (keep=path filename fileextension); /* Names of files found. */
    
      keep path filename fileextension;
      length fref $8 path $2048 filename $2048 fileextension $100;
      label fref='File reference (fileref)' path='Folder path' filename='File name' fileextension='File extension';
   
      modify &_cstFoldersOut; /* Read the name of a directory to search. */
      path = root;           /* Make a copy of the name, because we might reset root. */ 
     
      rc = filename(fref, path);
      if rc = 0 then 
      do;
        did = dopen(fref);
        rc = filename(fref);
      end;
      else 
      do;
        length msg $200.;
        msg = sysmsg();
        putlog msg=;
        did = .;
      end;
    
      if did <= 0 then 
      do;
        putlog "ER%str(ROR): Unable to open " Path=;
        * return;
      end;
     
      dnum = dnum(did);
      do i = 1 to dnum;
        fileextension = ' ';
        filename = dread(did, i);
        fid = mopen(did, filename);
        if fid > 0 /* File */
        then 
        do;
          /* fileextension is everything after the last dot. */
          /* If no dot, then no extension. */
          fileextension = prxchange('s/.*\.{1,1}(.*)/$1/', 1, filename);
          if filename = fileextension then fileextension = ' ';
          
          %if %length(&_cstFiletype)>0 %then %do;
            if upcase(fileextension) = upcase("&_cstFiletype") then output &_cstFilesOut;
          %end;
          %else %do;
            output &_cstFilesOut;
          %end;
        end;
        else 
        do; 
          /* Directory */
          root = catt(path, "&_cstPathDelim", filename);
   
          %if %upcase(&_cstRecurse) eq Y %then
          %do;
            output &_cstFoldersOut;
          %end;
          %else
          %do;
            %if %length(&_cstFiletype)>0 %then %do;
              if upcase(fileextension) = upcase("&_cstFiletype") then output &_cstFilesOut;
            %end;
            %else %do;
              output &_cstFilesOut;
            %end;
          %end;
        end;
      end;
     
      rc = dclose(did);
    run;
   
  %mend _cstutilgetfoldersfiles;
  
  %***********************************************************************;
  %* Compares data sets and returns any discrepancies found to data set  *;
  %* specified in the adTo parameter.                                    *;
  %***********************************************************************;
  %macro _cstutilcompds(
    fldrbase=, 
    fldrcomp=, 
    baseds=, 
    compds=, 
    adTo=
    ) / des='CST: Compare SAS data sets';
   
    %local _cstRandom 
           libbase 
           libcomp 
           rc;
      
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    
    %let libbase=base&_cstRandom;
    %let libcomp=comp&_cstRandom;
  
    libname &libbase "&fldrbase";
    libname &libcomp "&fldrcomp";
    
    data work.tempds_&_cstRandom;
      length fldrbase fldrcomp $2048 dsname dsnbase dsncomp $ 32 result nobsbase nobscomp 8 resultc $200;
      label dsname   = "Dataset name"
            dsnbase  = "BASE Dataset name"
            fldrbase = "BASE Folder name"
            dsncomp  = "COMP Dataset name"
            fldrcomp = "COMP Folder name"
            nobsbase = "# BASE obs"
            nobscomp = "# COMP obs"
            result   = "PROC COMPARE sysinfo"
            resultc  = "Result"
            ;
      call missing (of _all_);
      stop;
    run;  
  
    %if %sysfunc(exist(&libbase..&baseds))=0 or %sysfunc(exist(&libcomp..&compds))=0 %then 
    %do;
      %if %sysfunc(exist(&libbase..&baseds)) %then 
      %do;
        proc sql;
          insert into work.tempds_&_cstRandom(fldrbase, fldrcomp, dsname, dsnbase, nobsbase)
          values("&fldrbase", "&fldrcomp", "&baseds", "&baseds", %cstutilnobs(_cstDataSetName=&libbase..&baseds))
        ;
        quit;   
      %end;
      %else 
      %do;
        proc sql;
          insert into work.tempds_&_cstRandom(fldrbase, fldrcomp, dsname, dsncomp, nobscomp)
          values("&fldrbase", "&fldrcomp", "&compds", "&compds", %cstutilnobs(_cstDataSetName=&libcomp..&compds))
        ;
        quit;   
      %end;    
      %goto exit_nocompare;
    %end;  
  
    proc compare base=&libbase..&baseds compare=&libcomp..&compds noprint out=work.comp_&_cstRandom;
    run;
    %let rc=&sysinfo;
    
    %cstutil_deleteDataSet(_cstDataSetName=work.comp_&_cstRandom);    
      
    proc sql;
      insert into work.tempds_&_cstRandom(fldrbase, fldrcomp, dsname, dsnbase, nobsbase, dsncomp, nobscomp, result)
      values("&fldrbase", "&fldrcomp", "&baseds", "&baseds", %cstutilnobs(_cstDataSetName=&libbase..&baseds), "&compds", %cstutilnobs(_cstDataSetName=&libcomp..&compds), &rc)
      ;
    quit;   
  
    data work.tempds_&_cstRandom(drop=i restmp r1-r16);
      array r(*) 8 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15 r16;
      set work.tempds_&_cstRandom;  
      resultc="";
      restmp='/DSLABEL/DSTYPE/INFORMAT/FORMAT/LENGTH/LABEL/BASEOBS/COMPOBS'||
             '/BASEBY/COMPBY/BASEVAR/COMPVAR/VALUE/TYPE/BYVAR/ER'||'ROR/';
      do i=1 to 16;
        if result >= 0 then 
        do;
          if band(result, 2**(i-1)) then 
          do;
            resultc=cats(resultc, '/', kscan(restmp,i,'/'));
            r(i) = 1;
          end;
        end;  
      end;
      resultc=kstrip(resultc);
      if kindex(resultc,'/')=1 then resultc=ksubstr(resultc,2);
      output;
    run;
  
    %exit_nocompare:
  
    data &adTo;
      set &adTo work.tempds_&_cstRandom;
    run;  
    
    %cstutil_deleteDataSet(_cstDataSetName=work.tempds_&_cstRandom);
    
    libname &libbase clear;
    libname &libcomp clear;
  
  %mend _cstutilcompds;

  %************************************************************************;
  %* Performs parameter checking and setup in support of a specified      *;
  %* report type from the set (LOG | DATASET | _CSTRESULTSDS | HTML)      *;
  %* The calling macro should have a macrovariable _cstRptType defined.   *; 
  %************************************************************************;
  %macro _cstutilreporting(
    _cstType=,
    _cstDS=,
    _cstOWrite=N
    ) / des='CST: Report parameter checking and setup';
  
    %if %upcase(&_cstOWrite) ne Y %then %let _cstOWrite=N;
  
    %if %upcase(&_cstType)=DATASET and %length(&_cstDS) < 1 %then
    %do;
      %let _cstRptType=LOG;  
      %put WARN%STR(ING): [CSTLOG%str(MESSAGE).&sysmacroname] No data set for reporting differences has been provided. Results will be written to the log.;
    %end;
  
    %if %upcase(&_cstType)=_CSTRESULTSDS %then
    %do;
      %if (%symexist(_cstResultsDS)=1) %then 
      %do;
        %if %sysfunc(exist(&_cstResultsDS))<1 %then 
        %do;
          %cstutil_createTempMessages();
        %end;
      %end;
      %else %do;
        %cst_setStandardProperties(_cstStandard=CST-FRAMEWORK, _cstSubType=initialize);
        %cstutil_createTempMessages();
      %end;
    %end;
  
    %if %upcase(&_cstType)=DATASET and %length(&_cstDS)>0 %then
    %do;
      %if %sysfunc(exist(&_cstDS)) and %upcase(&_cstOWrite)=N %then
      %do;
        %let _cstRptType=LOG;  
        %put NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] &_cstDS exists but cannot be overwritten based on parameter settings. Results will be written to the log.;
      %end;
    %end;
        
  %mend _cstutilreporting;
  
%mend cstutilinitdifftools;
