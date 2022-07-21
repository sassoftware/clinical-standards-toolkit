%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmutil_buildcheckdomainlist                                                  *;
%*                                                                                *;
%* Builds a data set that specifies domains to validate by each check.            *;
%*                                                                                *;
%* This macro builds a data set that specifies the domains to validate by each    *;
%* check, based on the contents of the validation check data set columns          *;
%* tableScope and columnScope.                                                    *;
%*                                                                                *;
%* Required File Inputs:                                                          *;
%*   only as specified in the parameters                                          *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cst_MsgID Results: Result or validation check ID                      *;
%* @macvar _cst_MsgParm1 Messages: Parameter 1                                    *;
%* @macvar _cst_MsgParm2 Messages: Parameter 2                                    *;
%* @macvar _cstSrcData Results: Source entity being evaluated                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%*                                                                                *;
%* @param _cstCheckDS - optional - The validation check data set that contains    *;
%*            the checks for a standard and standardversion. Typically, this is   *;
%*            the validation_master data set.                                     *;
%* @param _cstWhereClause - optional - The WHERE clause to subset _cstCheckDS.    *;
%*            The syntax must comply with a SAS statement argument such as any of *;
%*            these: VAR=1                                                        *;
%*                   upcase(var2)="Y"                                             *;
%*                   checkstatus>0                                                *;
%* @param _cstOutputDS - required - The data set that is returned to the calling  *;
%*            program. This data set contains a record for each domain that is    *;
%*            referenced by a checkid, standardversion, and checksource.          *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure internal                                                             *;

%macro sdtmutil_buildcheckdomainlist(
    _cstCheckDS=,
    _cstWhereClause=,
    _cstOutputDS=
    ) / des="CST: Build table list by checkid";

  %local
    _cstCheckCnt
    _cstCheckID
    _cstCheckSeqCount
    _cstChecksource
    _cstColumnScope
    _cstexit_error
    _cstOldCheckID
    _cstSASrefLibs
    _cstSASrefMembers
    _cstStdVersion
    _cstTableScope
    _csttempds
    _cstUseSourceMetadata
  ;

  %let _cst_rc=0;
  %let _cst_MsgID=;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cstexit_error=0;

  %let _cstOldCheckID=;
  %let _cstCheckSeqCount=0;

  %if &_cstOutputDS= %then %do;
    %put sdtmutil_buildcheckdomainlist macro parameter _cstOutputDS cannot be missing.;
    %goto exit_error;
  %end;

  %if %length(&_cstCheckDS)=0 %then
  %do;
    %cstutil_getsasreference(_cstSASRefType=referencecontrol,_cstSASRefSubtype=validation,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers,_cstAllowZeroObs=1);
    %if %length(&_cstSASrefLibs)<1 or %length(&_cstSASrefMembers)<1 %then
    %do;
      %cstutil_getsasreference(_cstSASRefType=control,_cstSASRefSubtype=validation,_cstSASRefsasref=_cstSASrefLibs,_cstSASRefmember=_cstSASrefMembers);
      %if &_cst_rc %then
      %do;
        %let _cst_MsgID=CST0003;
        %let _cst_MsgParm1=Validation check data set;
        %let _cst_MsgParm2=;
        %let _cstSrcData=&sysmacroname;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;
    %end;
    %let _cstCheckDS=&_cstSASrefLibs..&_cstSASrefMembers;
  %end;

  %if %length(&_cstWhereClause)>0 %then
  %do;
    data work._cstCheckDataSet;
      set &_cstCheckDS (where=(&_cstWhereClause));
    run;
  %end;
  %else
  %do;
    data work._cstCheckDataSet;
      set &_cstCheckDS;
    run;
  %end;

  data _null_;
    if 0 then set work._cstCheckDataSet nobs=_numobs;
    call symputx('_cstCheckCnt',_numobs);
    stop;
  run;

  data &_cstOutputDS;
    attrib checkid format=$8. label="Validation check identifier"
       table format=$32. label="Table Name"
       standardversion format=$20. label="Standard version"
       checksource format=$40. label="Source of check"
       resultseq format=8. label="Unique invocation of check"
    ;
    retain checkid table standardversion checksource '' resultseq . ;
    stop;
  run;

  %* Create a temporary work data set. *;
  data _null_;
    attrib _csttemp label="Text string field for file names"  format=$char12.;
           _csttemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
    call symputx('_csttempds',_csttemp);
  run;

  %do check=1 %to &_cstCheckCnt;
      data _null_;
        set work._cstCheckDataSet (keep=checkid standardversion checksource tablescope columnscope usesourcemetadata firstObs=&check);
          call symputx('_cstCheckID',checkid);
          call symputx('_cstStdVersion',standardversion);
          call symputx('_cstChecksource',checksource);
          call symputx('_cstTableScope',tablescope);
          call symputx('_cstColumnScope',columnscope);
          call symputx('_cstUseSourceMetadata',usesourcemetadata);
        stop;
      run;
      %if &_cstCheckID=&_cstOldCheckID %then
      %do;
        %let _cstCheckSeqCount=%eval(&_cstCheckSeqCount+1) ;
      %end;
      %else
        %let _cstCheckSeqCount=1;

      %* Call macro to interpret tableScope and columnScope to build work._cstcolumnmetadata for each check   *;
      %* _cstDomSubOverride=Y parameter allows us to also look at check records with unequal sublist lengths  *;
      %cstutil_buildcollist(_cstFormatType=DATASET,_cstDomSubOverride=Y);
      %if &_cst_rc  or ^%sysfunc(exist(work._cstColumnMetadata)) %then
      %do;
        %let _cst_MsgID=CST0004;
        %let _cst_MsgParm1=;
        %let _cst_MsgParm2=;
        %let _cst_rc=1;
        %let _cstexit_error=1;
        %goto exit_error;
      %end;

      proc sql noprint;
        create table &_csttempds as
        select distinct table, "&_cstCheckID" as checkid length=8,
                  &_cstCheckSeqCount as resultseq,
                  "&_cstStdVersion" as standardversion length=20,
                  "&_cstChecksource" as checksource length=40
        from work._cstcolumnmetadata;
      quit;

      proc append base=&_cstOutputDS data=&_csttempds force;
      run;

      %let _cstOldCheckID=&_cstCheckID;

      * Clear contents for next loop, in case of problems *;
      data &_csttempds;
        set &_csttempds;
        if _n_=1 then stop;
      run;

  %end;

  proc datasets nolist lib=work;
    delete &_csttempds;
  quit;

%exit_error:

  %if %sysfunc(exist(work._cstCheckDataSet)) %then
  %do;
    proc datasets nolist lib=work;
      delete _cstCheckDataSet;
    quit;
  %end;

  %if %sysfunc(exist(work._cstcolumnmetadata)) %then
  %do;
    proc datasets nolist lib=work;
      delete _cstcolumnmetadata _csttablemetadata _cstrefcolumnmetadata _cstsrccolumnmetadata _cstreftablemetadata _cstsrctablemetadata;
    quit;
  %end;

  %if &_cstexit_error %then
  %do;
    %cstutil_writeresult(
                   _cstResultID=&_cst_MsgID
                   ,_cstValCheckID=&_cst_MsgID
                   ,_cstResultParm1=&_cst_MsgParm1
                   ,_cstResultParm2=&_cst_MsgParm2
                   ,_cstResultSeqParm=1
                   ,_cstSeqNoParm=1
                   ,_cstSrcDataParm=&sysmacroname
                   ,_cstResultFlagParm=-1
                   ,_cstRCParm=&_cst_rc
                   ,_cstActualParm=%str(tableScope=&_cstTableScope,columnScope=&_cstColumnScope)
                   ,_cstKeyValuesParm=
                   ,_cstResultsDSParm=&_cstResultsDS
                   );
  %end;

%mend sdtmutil_buildcheckdomainlist;

