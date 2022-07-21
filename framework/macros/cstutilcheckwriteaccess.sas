%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcheckwriteaccess                                                        *;
%*                                                                                *;
%* Checks for Write access for an output object.                                  *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%*                                                                                *;
%* @param _cstFileType - required -  The type of object to check within the SAS   *;
%*            Clinical Standards Toolkit:                                         *;
%*            CATALOG: Checks for Write access to a SAS format catalog that is    *;
%*                     specified in _cstFileRef. This macro requires that the     *;
%*                     libname be assigned before invoking this macro. A two-part *;
%*                     filename is required (for example, mysas.formats) for a    *;
%*                     catalog in _cstfileref.                                    *;
%*            DATASET: Checks for Write access to a SAS data set that is specified*;
%*                     in _cstFileRef. The libname must be assigned before        *;
%*                     invoking this macro.                                       *;
%*            FILE:    Checks for Write access to a file that is specified in     *;
%*                     _cstFilePath _cstFileRef.                                  *;
%*            FOLDER:   Checks for Write access to a folder that is specified in  *;
%*                     _cstfilepath.                                              *;
%*            LIBNAME: Checks for Write access to a SAS libname that is specified *;
%*                     in _cstfileref.                                            *;
%*            Values: CATALOG | DATASET | FILE | FOLDER | LIBNAME                 *;
%*                                                                                *;
%* @param _cstFilePath - conditional - The physical path of the file or folder to *;
%*            check. Required only when  _cstFileType is FOLDER or FILE (for      *;
%*            example, _cstfilepath=C:\cstSampleLibrary\cdisc-sdtm-3.1.2).        *;
%* @param _cstFileRef - required - The name of the object to check. For example:  *;
%*            _cstFileType=CATALOG _cstFileRef=cat1.formats                       *;
%*            _cstFileType=DATASET _cstFileRef=mysas.dm                           *;
%*            _cstFileType=FILE    _cstFileRef=dm.sas7bdat                        *;
%*            _cstFileType=FOLDER  _cstFileRef=                                   *;
%*            _cstFileType=LIBNAME _cstFileRef=mysas                              *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure external                                                             *;

%macro cstutilcheckwriteaccess(
    _cstFileType=,
    _cstFilePath=,
    _cstFileRef=
    ) / des='CST: Check objects for write access';

 
  %if %symexist(_cstDebug) %then 
  %do;
    %if &_cstDebug=1 %then
    %do;
      %put *********************** BEGINNING of macro CSTUTCHECKWRITEACCESS DEBUG ***********************;
      %put * Starting macro &sysmacroname;
      %put *  Parameter _cstFilePath = &_cstFilePath;
      %put *  Parameter _cstFileRef  = &_cstFileRef;
      %put *  _cst_rc                = &_cst_rc;
      %put *  _cst_rcmsg             = &_cst_rcmsg;
      %put **********************************************************************************************;
    %end;
  %end;
  %***********************************;
  %*  Check _cstFileType parameters  *;
  %***********************************;
  %if %upcase(&_cstFileType) ne FILE and
      %upcase(&_cstFileType) ne CATALOG and
      %upcase(&_cstFileType) ne DATASET and
      %upcase(&_cstFileType) ne LIBNAME and
      %upcase(&_cstFileType) ne FOLDER %then
  %do;
    %let _cst_rc=1;
    %let _cst_rcmsg=Macro parameter _cstFileType=%upcase(&_cstFileType) is invalid;
    %goto exit_macro;
  %end;

  %local _cstdatname
         _cstdir
         _cstdir2
         _cstfid
         _cstlibname
         _cstlibpath
         _cstpostexist
         _cstpreexist
         _cstrandom
         _csttempname
         rc;

  %*****************************************;
  %*  Set error code and message variable  *;
  %*****************************************;
  %let _cst_rc=0;
  %let _cst_rcmsg=;

  %***********************************;
  %*  Check _cstFileType parameters  *;
  %***********************************;

  %if %upcase(&_cstFileType)=FILE or %upcase(&_cstFileType)=FOLDER %then
  %do;
    %*************************************************;
    %* Does the macro have the parameters it needs?  *;
    %*************************************************;
    %if %upcase(&_cstFileType)=FOLDER and %quote(&_cstFilePath)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstFilePath parameter is required when checking _cstFileType=FOLDER;
      %goto exit_macro;
    %end;
    %if %upcase(&_cstFileType)=FILE and (%quote(&_cstFilePath)=%str() or %quote(&_cstFileRef)=%str()) %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = The _cstFilePath and _cstFileRef parameters are required when checking _cstFileType=FILE;
      %goto exit_macro;
    %end;
    %***********************************************;
    %*  Check to see if directory for file exists  *;
    %***********************************************;
    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstDir=_cst&_cstRandom;

    %let rc=%sysfunc(filename(_cstDir,&_cstFilePath));
    %if %sysfunc(fexist(&_cstDir)) ne 1 %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg = Specified directory %sysfunc(ktranslate(&_cstFilePath,/,\)) does not exist;
      %goto exit_macro;
    %end;

    %***************************************************************;
    %*  Make sure directory has trailing / slash for concatenation *;
    %***************************************************************;
    %if %sysfunc(kindexc(%sysfunc(kreverse(%ktrim(%kleft(&_cstFilePath)))),\/)) ne 1 %then %let _cstlibpath=%ktrim(%kleft(&_cstFilePath))/;

    %cstutil_getRandomNumber(_cstVarname=_cstRandom);
    %let _cstDir=_cst&_cstRandom;

    %*****************************************************************************************;
    %*  To check WRITE capability for a folder attempt to create a dummy file there          *;
    %*  Since _cstFileRef parameter is not required for a folder check, create a dummy file  *;
    %*****************************************************************************************;
    %if %quote(&_cstFileRef)=%str() %then %let _cstdatname=&_cstDir;
    %else %let _cstdatname=%trim(%left(&_cstFileRef));

    %let rc=%sysfunc(filename(_cstDir,&_cstlibpath&_cstdatname));

    %**************************************************************************;
    %*  Attempt to open file in append mode using A option in FOPEN function  *;
    %*  _cstpreexist=0 and _cstfid=0 then directory is write protected        *;
    %*  _cstpreexist=1 and _cstfid=0 then file is write protected             *;
    %**************************************************************************;
    %let _cstpreexist=%sysfunc(fexist(&_cstDir));

    %********************************************************************************;
    %*  Following block of code was added to handle change in FOPEN/FCLOSE/FDELETE  *;
    %********************************************************************************;
    %if &_cstpreexist=0 %then
    %do;
      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstdir2=_cst&_cstRandom;
      %let _csttempname=&_cstlibpath&_cstdir2;
      %let rc=%sysfunc(filename(_cstdir2,&_csttempname));
      %let _cstfid=%sysfunc(fopen(&_cstdir2,a,0,e));
      %let rc=%sysfunc(fclose(&_cstfid)); 
      %let rc=%sysfunc(fdelete(&_cstdir2));
      %let rc=%sysfunc(filename(_cstdir2));    
    %end;
    %else %let _cstfid=%sysfunc(fopen(&_cstDir,a,0,e));

    %if &_cstfid=0 %then
    %do;
      %let _cst_rc = 1;
      %let rc=%sysfunc(filename(_cstdir));    
      %if &_cstpreexist=0 %then %let _cst_rcmsg = Directory %sysfunc(ktranslate(&_cstlibpath,/,\)) cannot be opened for OUTPUT;
      %else %let _cst_rcmsg = File &_cstdatname cannot be opened for OUTPUT;
      %goto exit_macro;
    %end;
    %else
    %do;
      %***********************************************************************;
      %*  Cleanup - close any open file                                      *;
      %*  if FOPEN created a file that did not previously exist - delete it  *;
      %***********************************************************************;
      %let _cstpostexist=%sysfunc(fexist(&_cstDir));
      %if &_cstpreexist %then 
      %do;
        %if %sysfunc(fclose(&_cstfid)) %then %put [CSTLOG%str(MESSAGE).&sysmacroname] 1 FCLOSE %sysfunc(sysmsg()); 
      %end;
      %if &_cstpreexist=0 and &_cstpostexist=1 %then
      %do;
        %if %sysfunc(fdelete(&_cstdir)) %then %put [CSTLOG%str(MESSAGE).&sysmacroname] FDELETE %sysfunc(sysmsg());
      %end;
      %let rc=%sysfunc(filename(_cstdir));    
    %end;
  %end;

  %******************************************************;
  %*  Check if _cstFileType is DATASET/CATALOG/LIBNAME  *;
  %******************************************************;
  %else
  %do;
    %**************************************************;
    %*  Does the macro have the parameters it needs?  *;
    %**************************************************;
    %if %quote(&_cstFileRef)=%str() %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg =The _cstFileRef parameter is required when checking _cstFileType=LIBNAME|DATASET|CATALOG;
      %goto exit_macro;
    %end;
    %if (%sysfunc(count(%trim(%left(&_cstFileRef)),.)) gt 0 and %upcase(&_cstFileType)=LIBNAME) or
        (%sysfunc(count(%trim(%left(&_cstFileRef)),.)) gt 1 and %upcase(&_cstFileType)^=LIBNAME)
    %then
    %do;
      %let _cst_rc = 1;
      %let _cst_rcmsg =Invalid value for libname in _cstFileRef parameter (&_cstFileRef);
      %goto exit_macro;
    %end;
    %***********************************************************************;
    %*  Separate out the libname and data set name for further processing  *;
    %*  where _cstFileType is not equal to LIBNAME.                        *;
    %*  The following data _NULL_ will determine existence of the libname  *;
    %*  and its READONLY status using sashelp.vlibnam                      *;
    %***********************************************************************;
    %if %upcase(&_cstFileType)^=LIBNAME %then
    %do;
      %let _cstlibname=%sysfunc(scan(%trim(%left(&_cstFileRef)),1,.));
      %let _cstdatname=%sysfunc(scan(%trim(%left(&_cstFileRef)),-1,.));
    %end;
    %else
    %do;
      %let _cstlibname=%trim(%left(&_cstFileRef));
    %end;

    data _null_;
      set sashelp.vlibnam end=eof;
      retain libfound 0;
      if upcase(libname)="%upcase(&_cstlibname)" then
      do;
        libfound+1;
        if readonly='yes' then
        do;
          call symputx('_cst_rc',1);
          call symputx('_cst_rcmsg',"Libname &_cstlibname is READ ONLY.");
          goto exit_null;
        end;
      end;
      exit_null:
      if eof and libfound=0 then
      do;
        call symputx('_cst_rc',1);
        call symputx('_cst_rcmsg',"Libname &_cstlibname does not exist check _cstFileRef parameter.");
      end;
    run;

    %if %eval(&_cst_rc)=1 %then %goto exit_macro;

    %if %upcase(&_cstFileType)^=LIBNAME %then
    %do;
      %********************************************************;
      %*  Retrieve path for libname to use in FOPEN function  *;
      %********************************************************;
      %let _cstlibpath=%sysfunc(pathname(&_cstlibname))/;
      %*******************************************;
      %*  Add file extension for FOPEN function  *;
      %*  DATASET filetype has .sas7bdat         *;
      %*  CATALOG filetype has .sas7bcat         *;
      %*******************************************;
      %if %upcase(&_cstFileType)=DATASET %then %let _cstdatname=&_cstdatname..sas7bdat;
      %else %let _cstdatname=&_cstdatname..sas7bcat;

      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let _cstDir=_cst&_cstRandom;
      %let rc=%sysfunc(filename(_cstDir,&_cstlibpath&_cstdatname));
      %let _cstpreexist=%sysfunc(fexist(&_cstDir));

      %********************************************************************************;
      %*  Following block of code was added to handle change in FOPEN/FCLOSE/FDELETE  *;
      %********************************************************************************;
      %if &_cstpreexist=0 %then
      %do;
        %cstutil_getRandomNumber(_cstVarname=_cstRandom);
        %let _cstdir2=_cst&_cstRandom;
        %let _csttempname=&_cstlibpath&_cstdir2;
        %let rc=%sysfunc(filename(_cstdir2,&_csttempname));
        %let _cstfid=%sysfunc(fopen(&_cstdir2,a,0,e));
        %let rc=%sysfunc(fclose(&_cstfid)); 
        %let rc=%sysfunc(fdelete(&_cstdir2));
        %let rc=%sysfunc(filename(_cstdir2));    
      %end;
      %else %let _cstfid=%sysfunc(fopen(&_cstDir,a,0,e));

      %if &_cstfid=0 %then
      %do;
        %let _cst_rc = 1;
        %let rc=%sysfunc(filename(&_cstDir));
        %if %upcase(&_cstFileType)=DATASET %then %let _cst_rcmsg = Data set %upcase(&_cstdatname) in library %upcase(&_cstlibname) cannot be opened for OUTPUT;
        %else %let _cst_rcmsg = Format catalog %upcase(&_cstdatname) in library %upcase(&_cstlibname) cannot be opened for OUTPUT;
        %goto exit_macro;
      %end;
      %else
      %do;
        %***********************************************************************;
        %*  Cleanup - close any open file                                      *;
        %*  if FOPEN created a file that did not previously exist - delete it  *;
        %***********************************************************************;
        %let _cstpostexist=%sysfunc(fexist(&_cstDir));
        %if &_cstpreexist %then 
        %do;
          %if %sysfunc(fclose(&_cstfid)) %then %put [CSTLOG%str(MESSAGE).&sysmacroname] 2 FCLOSE %sysfunc(sysmsg()); 
        %end;
        %if &_cstpreexist=0 and &_cstpostexist=1 %then
        %do;
          %if %sysfunc(fdelete(&_cstdir)) %then %put [CSTLOG%str(MESSAGE).&sysmacroname] FDELETE %sysfunc(sysmsg());
        %end;
        %let rc=%sysfunc(filename(_cstDir));
      %end;
    %end;
  %end;

  %exit_macro:

  %if &_cst_rc=1 %then %put [CSTLOG%str(MESSAGE)] &_cst_rcmsg;

  %if %symexist(_cstDebug) %then 
  %do;
    %if &_cstDebug=1 %then
    %do;
      %put **********************************************************************************************;
      %put * LEAVING macro &sysmacroname;
      %put *  Parameter _cstFileType = &_cstFileType;
      %put *  Parameter _cstFilePath = &_cstFilePath;
      %put *  Parameter _cstFileRef  = &_cstFileRef;
      %put *  _CST_RC                = &_CST_RC;
      %put *  _CST_RCMSG             = &_CST_RCMSG;
      %put *  DUMPING ALL MACRO VARIABLES:;
      %put _ALL_;
      %put ************************** END of macro CSTUTCHECKWRITEACCESS DEBUG **************************;
    %end;
  %end;
%mend cstutilcheckwriteaccess;