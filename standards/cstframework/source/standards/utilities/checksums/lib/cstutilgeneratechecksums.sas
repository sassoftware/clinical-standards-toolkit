%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilgeneratechecksums                                                       *;
%*                                                                                *;
%* Generates an MD5 checksum file for a folder.                                   *;
%*                                                                                *;
%* This macro uses a Groovy script to create an MD5 checksum XML file that is     *;
%* similar to the standard SAS IQ MD5 checksum file located here:                 *;
%*   <SASHome>/InstallMisc/InstallLogs/ValidationFileList.xml)                    *;
%*                                                                                *;
%* @param  _cstFolder - required - The full path to the folder for which to       *;
%*            create the checksum file (for example, c:\cstGlobalLibrary).        *;
%* @param  _cstXMLFile - required - The full path and filename of the checksum    *;
%*            XML file to create.                                                 *;
%* @param  _cstProdCode - optional - The product code that identifies the folder. *;
%*            The product codes cstframework, cstgblstdlib, and cstsamplelib      *;
%*            match the product codes framework, global library, and sample       *;
%*            library, which are used by the SAS IQ tool for the SAS Clinical     *;
%*            Standards Toolkit.                                                  *;
%* @param  _cstLabel - optional - The label for the folder structure.             *;
%* @param  _cstAlgorithm - required - The checksum algorithm to use.              *;
%*            Default: MD5                                                        *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilgeneratechecksums(
  _cstFolder=,
  _cstXMLFile=,
  _cstProdCode=,
  _cstLabel=,
  _cstAlgorithm=MD5
  ) / des='CST: Generate MD5 checksum XML file';

  %local _cstReqParams _cstReqParam i rc fileref;

  %* Check required parameters;
  %let _cstReqParams=_cstFolder _cstXMLFile _cstAlgorithm;
  %do i=1 %to %sysfunc(countw(&_cstReqParams));
     %let _cstReqParam=%kscan(&_cstReqParams, &i);
     %if %sysevalf(%superq(&_cstReqParam)=, boolean) %then %do;
        %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstReqParam parameter value is required.;
        %goto exit_macro;
     %end;
  %end;

  %let rc = %sysfunc(filename(fileref,&_cstFolder)) ;
  %if %sysfunc(fexist(&fileref))=0 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstFolder does not exist.;
    %goto exit_macro;
  %end;

  %let _cstFolder=%sysfunc(ktranslate(&_cstFolder,/,\));
  %let _cstXMLFile=%sysfunc(ktranslate(&_cstXMLFile,/,\));

  data _null_;
    dcl javaobj j("Checksums");
    call j.callVoidMethod("getChecksums", "&_cstFolder", "&_cstProdCode", "&_cstAlgorithm", "&_cstXMLFile", "&_cstLabel");
  run;

%exit_macro:

%mend cstutilgeneratechecksums;
