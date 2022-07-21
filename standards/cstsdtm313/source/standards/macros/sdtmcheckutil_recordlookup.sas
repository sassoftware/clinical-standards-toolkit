%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmcheckutil_recordlookup                                                     *;
%*                                                                                *;
%* Identifies records in _cstSourceDS not found in the referenced lookup data set.*;
%*                                                                                *;
%* This macro creates work._cstproblems, which contains any records that are      *;
%* included in the _cstSourceDS data set that cannot be found in the referenced   *;
%* lookup data set. For example, SUPPAE includes a record that points to a record *;
%* in the AE domain that does not exist with the key values specified.            *;
%*                                                                                *;
%* NOTE: This macro is called in _cstCodeLogic at a SAS DATA step level (that is, *;
%*       a full DATA step or PROC SQL invocation).                                *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstDSName Source data set evaluated by the validation check           *;
%* @macvar _cstRefOnly Source libref for the lookup (parent) domain               *;
%*                                                                                *;
%* @param _cstSourceDS - required - The source data set to evaluate by the        *;
%*            validation check. Must be an SDTM relational data set (for example, *;
%*            CO, RELREC, or SUPPxx).                                             *;
%*            Default: &_cstDSName                                                *;
%* @param _cstSourceLib - required - The source libref for the lookup (parent)    *;
%*            domain. The parent domain is determined by the RDOMAIN variable in  *;
%*            the source data set.                                                *;
%*            Default: &_cstRefOnly                                               *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure internal                                                             *;

%macro sdtmcheckutil_recordlookup (
    _cstSourceDS=&_cstDSName,
    _cstSourceLib=&_cstRefOnly
    ) / des="CST: SDTM check utility";

  %local
    _cstCLRecs
    _cstDSParent
    _cstIDvar
    _cstIDvars
    _cstRandom
    _cstRDomain
    _cstRDomains
    _cstSrcMacro
    dsid
    i
    j
    varnum
  ;

  %let _cstSrcMacro=&SYSMACRONAME;

  %if &_cstDebug %then
  %do;
    %put sdtmcheckutil_recordlookup >>>;
    %put "*********************************************************";
    %put "_cstSourceDS = &_cstSourceDS";
    %put "_cstSourceLib = &_cstSourceLib";
    %put "*********************************************************";
  %end;

  data work._cstproblems;
    set &_cstSourceDS;
    stop;
  run;

  proc sql noprint;
    select distinct kstrip(rdomain)
    into :_cstRDomains separated by " "
    from &_cstSourceDS
    where not missing(rdomain);
  quit;

  %let i=1;
  %let _cstRDomain = %kscan(&_cstRDomains, &i);
  %* loop over the distinct RDOMAINs;
  %do %while (&_cstRDomain ne);

    %* get distinct idvars;
    proc sql noprint;
      select distinct idvar
      into :_cstIDvars separated by " "
      from &_cstSourceDS
      where rdomain = "&_cstRDomain" and
      not missing(idvar);
    quit;

    %let j=1;
    %let _cstIDvar = %kscan(&_cstIDvars, &j);
    %* loop over the distinct IDVARs;
    %do %while (&_cstIDvar ne);

      %if &_cstDebug %then %put <<< sdtmcheckutil_recordlookup - RDOMAIN=&_cstRDomain IDVAR=&_cstIDvar;

      %cstutil_getRandomNumber(_cstVarname=_cstRandom);
      %let ds1=_cst_&_cstRDomain._&_cstIDvar._&_cstRandom;
      %let ds2=_cst_&_cstRDomain._Parent_&_cstRandom;
      %let ds3=_cstProblems_&_cstRDomain._&_cstIDvar._&_cstRandom;
      %let ds4=_cstProblems_&_cstRandom;

      %if &_cstDebug %then %put Checking <<<<<< RDOMAIN=&_cstRDomain, IDVAR=&_cstIDvar;

      data &ds1;
        set &_cstSourceDS(keep=studyid rdomain usubjid idvar idvarval
                          where=(idvar="&_cstIDvar" and rdomain = "&_cstRDomain"));
      run;

      data _null_;
        set &ds1;
        _csttemp = catx(".","&_cstSourceLib",rdomain);
        call symputx("_cstDSParent",_csttemp);
        stop;
      run;

      %if %sysfunc(exist(&_cstDSParent)) %then %do;
        %let dsid=%sysfunc(open(&_cstDSParent,is));
        %let varnum=%sysfunc(varnum(&dsid,&_cstIDvar));

        %if %eval(&varnum) gt 0 %then %do; %* Variable exists in parent;

          %* if parent domain variable is Numeric, we need to change type of the variable;
          %if %sysfunc(vartype(&dsid,&varnum)) eq N %then %do;
            data &ds1;
              length &_cstIDvar 8;
              set &ds1(keep=studyid usubjid idvar idvarval);
              if not missing(idvarval) then do;
                &_cstIDvar = input(idvarval, ?? BEST.);
              if missing(&_cstIDvar) then
                put "[CSTLOG%str(MESSAGE).&_cstSrcMacro] WAR" "NING: Could not convert IDVARVAL to a numeric value "
                    "rdomain=&_cstRDomain" studyid= usubjid= idvar= idvarval=;
              end;
            run;
          %end;
          %else %do;
            data &ds1;
              length &_cstIDvar $%sysfunc(varlen(&dsid,&varnum));
              set &ds1(keep=studyid usubjid idvar idvarval);
              &_cstIDvar = idvarval;
            run;
          %end;

          proc sort data=&ds1 nodupkey;
            by studyid usubjid &_cstIDvar;
          run;

          proc sort data=&_cstDSParent(keep=studyid usubjid &_cstIDvar) out=&ds2;
            by studyid usubjid &_cstIDvar;
          run;

          %* merge and keep everything from suppxx/co/relrec that does not merge;
          data &ds3(keep=studyid usubjid &_cstIDvar idvar idvarval);
            merge &ds2(in=in1) &ds1(in=in2);
            by studyid usubjid &_cstIDvar;
            if in2 and (not in1); %* keep records that are in Source but not in Parent;
          run;

          data _null_;
            if 0 then set &ds3 nobs=_numobs;
            call symputx("_cstCLRecs",_numobs);
            stop;
          run;

          %if &_cstCLRecs gt 0 %then %do;

            %* Get all rows from the source dataset;
            proc sql noprint;
              create table &ds4 as
              select a.*
              from &_cstSourceDS a, &ds3 b
              where a.studyid=b.studyid and a.usubjid=b.usubjid and
                    a.idvar="&_cstIDvar" and rdomain = "&_cstRDomain" and
                    a.idvarval=b.idvarval;
            quit;

            data work._cstproblems;
              set work._cstproblems &ds4;
            run;

          %end;

        %end; %* IDVAR exists in RDOMAIN;
        %else %do; %* IDVAR does not exist in RDOMAIN;
          data work._cstproblems;
            set work._cstproblems &_cstSourceDS(where=(idvar="&_cstIDvar" and rdomain = "&_cstRDomain"));
          run;
        %end;

      %end; %* RDOMAIN exists;
      %else %do; %* RDOMAIN does not exist;
        data work._cstproblems;
          set work._cstproblems &_cstSourceDS(where=(rdomain = "&_cstRDomain"));
        run;
      %end;

      %* Cleanup;
      %if &_cstDeBug eq 0 %then %do;
        %do k=1 %to 4;
          %if (%sysfunc(exist(&&ds&k))) %then %do;
            proc datasets nolist lib=work;
              delete &&ds&k / memtype=data;
            quit;
            run;
          %end;
        %end;
      %end;

      %let j=%eval(&j+1);
      %let _cstIDvar = %kscan(&_cstIDvars, &j);

    %end; %* end of IDVAR while loop;

    %let i=%eval(&i+1);
    %let _cstRDomain = %kscan(&_cstRDomains, &i);

  %end; %* end of RDOMAIN while loop;

  data work._cstproblems;
    set work._cstproblems &_cstSourceDS(where=(missing(rdomain)));
  run;

  %if &_cstDebug %then %put <<< sdtmcheckutil_recordlookup;

%mend sdtmcheckutil_recordlookup;