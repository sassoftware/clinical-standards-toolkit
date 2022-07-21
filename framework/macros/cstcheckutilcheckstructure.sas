%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstcheckutilcheckstructure                                                     *;
%*                                                                                *;
%* Compares the structure of data sets against a template.                        *;
%*                                                                                *;
%* This macro compares the structure of data sets referenced within a             *;
%* StandardSASReferences data set or a SASReferences data set against a template. *;
%*                                                                                *;
%* The structure of the data set is specified by the TYPE, SUBTYPE, SASREF, and   *;
%* MEMNAME columns that are specified by _cstSourceDS. Using this information,    *;
%* a call to cstutil_getsasreference retrieves the associated lookup data set to  *;
%* provide the template data set location. The referenced data set is compared to *;
%* the template data set using cstutilcomparestructure. If the structure does not *;
%* conform, this macro creates work._cstproblems.                                 *;
%*                                                                                *;
%* NOTE: This macro is called within _cstCodeLogic at a DATA step level (for      *;
%*       example, a full DATA step or PROC SQLinvocation) and is used within the  *;
%*       cstcheck_dsmismatch macro.                                               *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_rcmsg Message associated with _cst_rc                             *;
%* @macvar _cstDSLookup Name of _cstSourceDS data set                             *;
%* @macvar _cstLookupDS  Data set associated with _cst_rc                         *;
%* @macvar _cstLookupLB  - Libname retrievedTask error status                     *;
%* @macvar _cstMemname - Filename retrieved from memname column in _cstSourceDS   *;
%* @macvar _cstNumObs - Number of observations from _cstSourceDS data set that    *;
%*             match _cstFileType                                                 *;
%* @macvar _cstTemplateMemname - Name of template returned from &_cstLookupDS     *;
%*                                                                                *;
%* @param _cstSourceDS - required - The source data set to evaluate by the        *;
%*            validation check.                                                   *;
%*            Default: &_cstTableScope                                            *;
%* @param _cstStndrd - required - The standard under investigation, CST-FRAMEWORK.*;
%*            Default: &_cstStandard                                              *;
%* @param _cstStndrdVersion - required - The version of the standard.             *;
%*            Default: &_cstStandardVersion                                       *;
%* @param _cstFileType - required - The FILETYPE column value from the data set   *;
%*            that is specified by _cstSourceDS (folder, dataset, catalog, or     *;
%*            file).                                                              *;
%*            Default: DATASET                                                    *;
%* @param _cstColumn - required - The SAS Clinical Standards Toolkit column name  *;
%*            value in the StandardLookup data set to use to filter the template  *;
%*            information.                                                        *;
%* @param _cstRefColumn - optional - The associated SAS Clinical Standards Toolkit*;
%*            column name in the StandardLookup data set to use to further filter *;
%*            the template information, if needed.                                *;
%* @param _cstCmpRc - required - The minimum cstutilcomparestructure returncode   *;
%*            to consider an error. For more information, see the documentation   *;
%*            for the cstutilcomparestructure macro.                              *;
%*            _cstCmpRc=16: ignore labels, formats, and informat differences      *;
%*            Default: 16                                                         *;
%*                                                                                *;
%* @since 1.5                                                                     *;
%* @exposure internal                                                             *;

%macro cstcheckutilcheckstructure(
    _cstSourceDS=&_cstTableScope,
    _cstStndrd=&_cstStandard,
    _cstStndrdVersion=&_cstStandardVersion,
    _cstFileType=DATASET,
    _cstColumn=,
    _cstRefColumn=,
    _cstCmpRc=16) / des='CST: Creates work._cstproblems if structures are different';

  %local _cstDSLookup
         _cstLookupDS 
         _cstLookupLB
         _cstMemname
         _cstNumObs 
         _cstStd
         _cstStdV
         _cstTemplateMemname; 
 
  %let _cstLookupLB=;
  %let _cstLookupDS=;
  %let _cstNumObs=0;

  %*****************************************************;
  %* Need data set name from _cstSourceDS to use when  *;
  %* subsetting standardlookup data set.               *;
  %*****************************************************;
  %if %sysfunc(countw('&_cstSourceDS','.')) gt 0 %then %let _cstDSlookup=%kscan(&_cstSourceDS,2,'.');
  %else %let _cstDSlookup=&_cstSourceDS;
 
  %*******************************************;
  %* Retrieve number of records according to *;
  %* file type provided via macro parameter  *; 
  %*******************************************;
  data work._cstDataSetFile(compress=no);
    set &_cstSourceDS (where=(upcase(filetype)=upcase("&_cstFileType"))) end=eof ;
    if eof then call symput('_cstNumObs',_n_);
  run;

  %****************************;
  %* Retrieve Lookup data set *;
  %****************************;
  %cstutil_getsasreference(_cstStandard=&_cstStndrd,_cstStandardVersion=&_cstStndrdVersion,_cstSASRefType=lookup,
                           _cstSASRefsasref=_cstLookupLB, _cstSASRefmember=_cstLookupDS);

  %do i=1 %to &_cstNumObs;
    %let _cstLibname=;
    %let _cstMemname=;
    %let _cst_rc=0;
    %let _cst_rcmsg=;
    data _null_;
      obsno=&i;
      set work._cstDataSetFile point=obsno;
      call symputx('_cstStd',standard);
      call symputx('_cstStdV',standardversion);
      call symputx('_cstLibname',sasref);
      call symputx('_cstMemname',kstrip(scan(memname,1,'.')));
      call symputx('_cstRefValue',upcase(type));
      call symputx('_cstSubType',upcase(subtype));
      stop;
    run;

    %if %eval(&i)=1 %then 
    %do;
      data work._cstProblems;
        length baseDS compDS description _cstMsgParm1 $50 name $32 issue $8 baseValue compValue $256 
               actual $240 resultdetails $200 keyvalues $2000 table $29 sasref $8 errorcode 8.; 
        call missing (of _all_); 
        stop;
      run;
    %end;
 
    %if %quote(&_cstmemname) ne %str() %then
    %do;
      %let _cstTemplateMemname=;
      %if %length(&_cstSubtype)>0 %then
      %do;
        data _null_;
          set &_cstLookupLB..&_cstLookupDS;
          where upcase(standard)=upcase("&_cstStd") and upcase(standardversion)=upcase("&_cstStdV") and upcase(table)=upcase("&_cstDSLookup") 
          and upcase(refcolumn)=upcase("&_cstRefColumn") and upcase(column)=upcase("&_cstColumn") and upcase(refvalue)=trim("&_cstRefValue") 
          and upcase(value)=trim("&_cstSubType");           
          call symputx('_cstTemplateMemname',template);
        run;
      %end;
      %else %do;
        data _null_;
          set &_cstLookupLB..&_cstLookupDS;
          where upcase(standard)=upcase("&_cstStd") and upcase(standardversion)=upcase("&_cstStdV") and upcase(table)=upcase("&_cstDSLookup") 
          and upcase(column)=upcase("&_cstRefColumn") and upcase(value)=trim("&_cstRefValue");           
          call symputx('_cstTemplateMemname',template);
        run;
      %end;

     %cstutilcomparestructure(_cstBaseDSName=&_cstTemplateMemname,
                               _cstCompDSName=&_cstLibname..&_cstMemname,
                               _cstResultsDS=work._cstProb);

      %if %eval(&_cst_rc) ge &_cstCmpRc %then 
      %do;
        data work._cstProb;
          set work._cstProb;
          length actual $240 resultdetails $200 keyvalues $2000 sasref $8 _cstMsgParm1 $50;
          retain table "&_cstSourceDS" sasref keyvalues "";
          baseDS="&_cstTemplateMemname";
          compDS="&_cstLibname..&_cstMemname";
          _cstMsgParm1=kstrip(compDS);

          select;
            when(errorCode=1 and errorCode ge &_cstCmpRc) 
            do;
              actual=cats("&_cstLibname..&_cstMemname", 'DSLABEL' ,'=',compValue);
              resultdetails=cats(Description, '; template.DSLABEL=', baseValue);
              output;
            end;
            when (errorCode in(2,4,8,16,32) and errorCode ge &_cstCmpRc) 
            do;
              actual=cats("&_cstLibname..&_cstMemname", 'DSLABEL' ,'=',compValue);
              resultdetails=cats(Description, '; template.DSLABEL=', baseValue);
              output;
            end;
            when (errorCode=64 and errorCode ge &_cstCmpRc) 
            do;
              actual=cats("&_cstLibname..&_cstMemname", name);
              resultdetails=cats(Description, ': template.', name);
              output;
            end;
            when (errorCode=128 and errorCode ge &_cstCmpRc) 
            do;
              actual='';
              resultdetails=cats(Description, ': ', name);
              output;
            end;
            otherwise delete;
          end;
        run;

        proc datasets nowarn nodetails nolist;
          append base=work._cstProblems data=work._cstProb;
        quit;

        %cstutil_deleteDataSet(_cstDataSetName=work._cstProb);

      %end;
      %else;
      %do;
        %************************************************************;
        %* Issues in work._cstProb that are not considered problems *;
        %************************************************************;
        %if %eval(&_cst_rc) ne -1 %then 
        %do;
          %cstutil_deleteDataSet(_cstDataSetName=work._cstProb);
        %end;
      %end;
    %end;
  %end;

  %let _cst_rc=0;

  %***********;
  %*  exit   *;
  %***********;
  %exit_macro:

%mend cstcheckutilcheckstructure;