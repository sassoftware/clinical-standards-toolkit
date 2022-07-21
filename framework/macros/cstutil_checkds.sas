%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_checkDS                                                                *;
%*                                                                                *;
%* Validates a data set structure against a template data set structure.          *;
%*                                                                                *;
%* This macro validates the structure of a data set against the structure of the  *;
%* template data set that is provided with a standard.                            *;
%*                                                                                *;
%* @macvar _cst_rc Task error status                                              *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstGRoot Root path of the global standards library                    *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%*                                                                                *;
%* @param _cstDSname - required - The two-level name of the data set to validate. *;
%* @param _cstType - required - The type of data set to create. This value comes  *;
%*            from the TYPE column in the SASReferences file for the              *;
%*            standard-version combination.                                       *;
%* @param _cstSubType - optional - This value comes from the SUBTYPE column in    *;
%*            the SASReferences file for the standard-version combination. If the *;
%*            type has no subtypes, this value can be omitted. Otherwise, it must *;
%*            be specified.                                                       *;
%* @param _cstStandard - optional - The name of the data standard to validate     *;
%*            against. By default, all standards are included.                    *;
%* @param _cstStandardVersion - optional - The version of the data standard to    *;
%*            validate against. By default, all standardVersions are included.    *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_checkds(
    _cstdsname=,
    _csttype=,
    _cstsubtype=,
    _cststandard=*,
    _cststandardversion=*
    ) / des='CST: Validates the structure and content of CST data sets';

%cstutil_setcstgroot;

%local
  _chk_Random
  _cstControlLib
  _cstLookupHasRows
  _cstMsgDir
  _cstMsgMem
  _cstNeedToDeleteMsgs
  _cstRandom
  _cstsasrefs
  _cstTemplateLib
  _ds1
  _results
  anyobs
  col
  d
  dsCols
  dsid
  dsid1
  dsidrc
  lookup
  memname
  notNullColNum
  nullcols
  numcol
  numrefcol
  path
  refcol
  t
  template
  templtTable
  whr1
;
%* initialize returncode.  Note _cst_rc=1 if this macro finds errors;
%let _cst_rc=0;

%if %symexist(_cstResultsDS) %then %let _results=&_cstResultsDS;
%else %do;
  %put "ERROR: Location for Results Dataset is undefined.  Please set the &cstResultsDS macro variable and try again.";
  %let _cst_rc=1;
  %goto exit;
%end;

%if %sysfunc(exist(&_results)) ne 1 %then %do;
  %cst_createDS( _cstStandard=CST-FRAMEWORK, _cstType=results, _cstSubType=results, _cstOutputDS=&_results);
%end;
%let _cstResultsDS=&_results;

%* Create a temporary messages data set if required;
%cstutil_createTempMessages(_cstCreationFlag=_cstNeedToDeleteMsgs);

%if("&_cstdsname"="" or "&_cstType"="" ) %then %do;
%************macro parms not defined ************ *;
    %cstutil_writeresult(
                  _cstResultid=CST0005
                  ,_cstValCheckid=CST0005
                  ,_cstResultparm1=cstUtil_checkDS
                  ,_cstResultparm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcdataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                  %let _cst_rc=1;
   %goto exit;
%end;
%if %sysfunc(exist(&_cstdsname))=0 %then %do;
   %*********print error, dataset does not exist *******;
   %cstutil_writeresult(
                  _cstResultID=CST0008
                  ,_cstValCheckID=CST0008
                  ,_cstResultParm1=&_cstdsname
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
             %let _cst_rc=1;
   %goto exit;
%end;
%else %do;
    %let dsid=%sysfunc(open(&_cstdsname,i));
    %if (&dsid = 0) %then %do;
        %********print error, cannot open dataset *******;
           %cstutil_writeresult(
                  _cstResultID=CST0111
                  ,_cstValCheckID=CST0111
                  ,_cstResultParm1=&_cstdsname
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
            %let _cst_rc=1;
        %goto exit;
    %end;
    %let anyobs=%sysfunc(attrn(&dsid,ANY));
     %if &anyobs le 0 %then %do;
        %********print error, dataset does not have any obs *******;
        %cstutil_writeresult(
                  _cstResultID=CST0112
                  ,_cstValCheckID=CST0112
                  ,_cstResultParm1=&_cstdsname
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=1;
        %let dsidrc=%sysfunc(close(&dsid));
        %goto exit;
    %end;
    %let dsidrc=%sysfunc(close(&dsid));
%end;

%*  dataset exists and has some records *;

  %* assign the library to the control area that contains the registration data sets;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _chk_Random=a&_cstRandom;
  %let _cstControlLib=_ctl&_cstRandom;
  libname &_cstControlLib "&_cstGRoot./metadata";
  %if %sysfunc(libref(&_cstControlLib))^=0 %then %do;
        %cstutil_writeresult(
                  _cstResultID=CST0075
                  ,_cstValCheckID=CST0075
                  ,_cstResultParm1=&_cstControlLib
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=1;
            %goto exit;
  %end;
 %* assumes standardSASReferences must not have more than one memname record
    registered for a given table. This retrieves the path of the template *;
    proc sql noprint;
      select path, memname into :path, :memname
      from &_cstControlLib..standardsasreferences
      where (upcase(strip(type))=upcase(strip("&_cstType")))
    and ( upcase(strip(subtype))=upcase(strip("&_cstSubtype")) or strip("&_cstSubtype")="");
    quit;

  %if %sysfunc(symexist(memname)) eq 1 %then %do;
  data _null_;
  %* pull of first part of table name(remove .sas7bdat);
  attrib templtTable length=$200;
    templtTable=strip(scan("&memname",1));
  call symput('templtTable',templtTable);
    run;
  %end;


    %if %sysfunc(symexist(path)) eq 0 %then %do;

    %cstutil_writeresult(
                  _cstResultID=CST0117
                  ,_cstValCheckID=CST0117
                  ,_cstResultParm1=&_cstType
                  ,_cstResultParm2=&_cstSubtype
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=1;
            %goto exit;
      %end;


  %* assign the library to the control area that contains the registration data sets;
  * %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _cstTemplateLib=_cst&_cstRandom;
   libname &_cstTemplateLib %sysfunc(kstrip("&path"));
   %if %sysfunc(libref(&_cstTemplateLib))^=0 %then %do;
        %let t=%sysfunc(strip(&_cstTemplateLib));
        %cstutil_writeresult(
                  _cstResultID=CST0075
                  ,_cstValCheckID=CST0075
                  ,_cstResultParm1=&t
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=1;
            %goto exit;
  %end;
%* dump contents of template table, compare it to the dataset passed in *;
    proc datasets nolist nodetails;
     contents data=&_cstTemplateLib..&templtTable
              out=t1&_cstRandom(keep=name type length) nodetails noprint  ;
     contents data=&_cstdsname
              out=d1&_cstRandom(keep=name type length) nodetails noprint  ;
    quit;

    %* this will keep only those records that are in the dataset passed in that are not in template dataset *;
    proc sql noprint;
        select upcase(name), type, length from d1&_cstRandom
        except
        select upcase(name), type, length from t1&_cstRandom ;
    quit;
    %if %sysfunc(exist( work.d1&_cstRandom)) %then %do;
      proc datasets nolist; delete d1&_cstRandom; quit;
    %end;
    %if %sysfunc(exist( work.t1&_cstRandom)) %then %do;
      proc datasets nolist; delete t1&_cstRandom; quit;
    %end;

    %if &sqlobs^=0 %then %do;
        %*******differences found in the dataset structure*********;
        %let template=%sysfunc(kstrip(&path))/%sysfunc(strip(&templtTable));
    %let d=%sysfunc(strip(&_cstdsname));
                %cstutil_writeresult(
                  _cstResultID=CST0125
                  ,_cstValCheckID=CST0125
                  ,_cstResultParm1=&d
                  ,_cstResultParm2=&template
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=1
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=1;
        %goto exit;
    %end;


%if "&_cststandard"="*" and "&_cststandardversion"="*"  %then %let whr1=upcase(strip(type))="CSTMETADATA" and upcase(strip(subtype))="LOOKUP";
%else %if "&_cststandard"="*" and "&_cststandardversion"^="*"  %then %let whr1=upcase(strip(standardversion))=upcase(strip("&_cststandardversion")) and upcase(strip(type))="CSTMETADATA" and upcase(strip(subtype))="LOOKUP";
%else %if "&_cststandard"^="*" and "&_cststandardversion"="*"  %then %let whr1= upcase(standard) = upcase(strip("&_cststandard")) and upcase(strip(type))="CSTMETADATA" and upcase(strip(subtype))="LOOKUP";
%else %let whr1=upcase(strip(standard)) = upcase(strip("&_cststandard")) and upcase(strip(standardversion))=upcase(strip("&_cststandardversion")) and upcase(strip(type))="CSTMETADATA" and upcase(strip(subtype))="LOOKUP";

  %* dataset matches the structure now check content against lookup values *;
  %* look in standardSASReferences dataset for the lookup table for this standard and version *;
    proc sql noprint;
    create table _lo&_cstRandom as
    select path, memname, order
      from &_cstControlLib..standardsasreferences
      where  &whr1
        order by order;
    quit;

  %* if no lookup table found then skip this step *;
    %if &sqlobs=0 %then %do;
        %*******lookup table not registered for &_cststandard &_cststandardversion*********;
                %cstutil_writeresult(
                  _cstResultID=CST0114
                  ,_cstValCheckID=CST0114
                  ,_cstResultParm1=&_cstStandard
                  ,_cstResultParm2=&_cstStandardVersion
                  ,_cstResultSeqParm=1
                  ,_cstSeqNoParm=1
                  ,_cstSrcDataParm=CSTUTIL_CHECKDS
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=0
                  ,_cstActualParm=
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_results
                  );
                %let _cst_rc=0;

        %goto exit;
    %end;

      %* assign the libnames to the lookup table(s) *;
      %* build the string of tables to use in SET statement *;
  %* load the list of lookup tables into macro variable lookup *;
    data _null_;
    length lookup $2000 libref $32;
    retain lookup ;
    set _lo&_cstRandom end=last;
    libref='_l'||strip(put(_n_, best.))||strip("&_cstRandom");
    path=resolve(path);
    rc=libname(libref,path);
    %* remove the .sas7bdat from the dataset name if it is there;
    f=find(memname,'.sas7bdat');
    if f>0 then do;
        b=upcase(substr(memname,1,f-1)) || upcase(substr(memname,(f+length('.sas7bdat'))));
    end;
    else b=upcase(memname);
    name=trim(libref)||'.'||b;
  if exist(name) then
        lookup=strip(lookup)||' '||strip(libref)||'.'||strip(b) ;
    if last then do;
        call symput('lookup',lookup);
    end;
    run;

    data _l1&_cstRandom;
    set &lookup end=eof;
    if upcase(table)=upcase("&templttable") ;
    run;

    %* check that there are rows in the lookup table and drop out if not;
    proc sql noprint;
       select count(column) into :_cstLookupHasRows
       from &lookup;
       quit;
    run;

    %let _cstLookupHasRows=&_cstLookupHasRows;

    %if (&_cstLookupHasRows=0) %then %do;
      %cstutil_writeresult(
      _cstResultID=CST0123
      ,_cstValCheckID=CST0123
      ,_cstResultParm1=&_cstStandard
      ,_cstResultParm2=&_cstStandardVersion
      ,_cstResultSeqParm=1
      ,_cstSeqNoParm=1
      ,_cstSrcDataParm=CSTUTIL_CHECKDS
      ,_cstResultFlagParm=0
      ,_cstRCParm=0
      ,_cstActualParm=
      ,_cstKeyValuesParm=
      ,_cstResultsDSParm=&_results
      );
    %let _cst_rc=0;
      %goto exit;
    %end;

    %* clear out lookup librefs *;
    data _null_;
    set _lo&_cstRandom end=last;
    libref='_l'||strip(put(_n_, best.))||strip("&_cstRandom");
    rc=libname(libref);
    run;

    proc datasets nolist nodetails; delete _lo&_cstRandom; quit;

    %* get list of columns to be checked, only keep one row per column in the lookup table *;
    proc sort data=_l1&_cstRandom out=_lc&_cstRandom nodupkey;
        by column ;
    run;

  %* run proc contents on dataset passed in *;
    %let _ds1=dsc&_cstRandom;
    proc datasets nolist nodetails;
     contents data=&_cstdsname
              out=&_ds1(keep=name) nodetails noprint  ;
              quit;

    proc sort data=&_ds1 out=&_ds1(rename=(name=column)); by name; run;

%* only keep those columns which have lookup values shipped with the standard *;
    data ctc&_cstRandom;
    merge _lc&_cstRandom(in=a) &_ds1(in=b);
    by column;
    if a=1 and b=1 then output;
    run;
%* load the list of columns to check into macro variable col *;
    data _null_;
    length col $2000;
    retain col ;
    set ctc&_cstRandom end=last;
    col=strip(column)||' ' ||strip(col);
    if last then do;
        col='"'||strip(col)||'"';
        call symput('col',col);
    end;
    run;

%* load the number of columns to check into macro variable numcol *;
data _null_;
 numcol=count(&col,' ')+1;
 call symput('numcol',put(numcol, best.));
 run;
%* seperate out which lookup columns have a dependancy on the refcolumn in the lookup table *;
proc sort data=_l1&_cstRandom(where=(refcolumn ne '')) out=_r&_cstRandom  ;
by table  column refcolumn;
run;
%* initialize refcol macro var;
%let refcol="";
%* load the list of columns which have a dependancy on a reference column into macro variable refcol *;
data _null_;
length refcol $2000;
retain refcol  ;
set _r&_cstRandom  end=last;
by refcolumn;
  if first.refcolumn
     then refcol=strip(refcolumn)||' ' ||strip(refcol);
  if last then do;
    refcol='"' || strip(refcol) || '"';
    l=length(refcol);
    call symput('refcol',refcol);
  end;
run;

%* load the number of columns which depend on a refcolumn into macro variable numrefcol *;

data _null_;
 if &refcol="" then call symput('numrefcol','0');
 else do;
 numrefcol=count(&refcol,' ')+1;
 call symput('numrefcol',put(numrefcol, best.));
 end;
 run;

 %* seperate out which columns should not have a null value *;
    proc sql noprint;
        select unique column
         into :nullcols separated by ' '
         from _l1&_cstRandom
        where upcase(nonnull)='Y' and upcase(table)=upcase(strip("&templtTable")) ;
    quit;
    data _null_;
        numcol=count("&nullcols",' ')+1;
        call symput('notNullColNum',put(numcol, best.));
    run;

%* sort the lookuptable *;
proc sort data=_l1&_cstRandom(keep=column value refcolumn refvalue ) out=_l2&_cstRandom;
by column value refcolumn refvalue;
run;
data _l2&_cstRandom(drop=refvalue);
  set _l2&_cstRandom;
  value=upcase(strip(value));
  run;

%macro chkvals();
    %* create dataset for each column with values to be checked *;
    %do cols=1 %to &numcol;
        %let dsCols=%scan(%sysfunc(compress(&col,'"')),&cols);
        data _&dsCols(drop=&dsCols);
        length column $32 value $200;
        set &_cstdsname(keep=&dsCols %sysfunc(compress(&refcol,'"')));
        rownum=_n_;
        column="&dsCols";
        value=UPCASE(&dsCols);
        run;
        proc sort data=_&dsCols; by column value; run;
    %end;

%* seperate out which columns should not have a null value *;
    %do cols=1 %to &notNullColNum;
        %let dsCols=%scan(&nullcols,&cols);
     %if %sysfunc(exist(_&dscols)) %then %do;
        proc sql noprint;
            create table _nu&_cstRandom as
            select * from _&dsCols
        where value is missing;
        quit;

        %if &sqlobs>0 %then %do;
            %***********write these records out to the results as errors **************/;
            %put "ERROR: Value for column, &dscols contains missing values";

            data _e1&_cstRandom (label='Work error data set');
                %cstutil_resultsdskeep;
                set work._nu&_cstRandom end=last;
        keep _cstmsgParm1 _cstmsgParm2;
                    *retain SeqNo 0 _cstResultID _cstValCheckID _cstResultSeqParm _cstResultFlagParm _cstRCParm ;
         retain SeqNo 0 resultid checkid resultflag _cst_rc resultseq;

            * Set results data set attributes *;
                %cstutil_resultsdsattr;
            if _n_=1 then
            do;
              resultseq=_n_;
          seqno=_n_;
                    ResultID="CST0115";
                    CheckID="CST0115";
                    ResultFlag=1;
                    _cst_RC=0;

            end;
            _cstmsgParm2= "&_cstdsname";
            _cstMsgParm1=strip(column)|| " row " ||strip(rownum);
            SrcData = table;
            SeqNo+1;
          Actual='';
            if last then
                call symputx('_cstSeqCnt',SeqNo);
            run;

            %* create work dataset with all errors, then call append *;
            %cstutil_appendresultds(
                          _cstErrorDS=work._e1&_cstRandom
                         ,_cstSource=CST
                         ,_cstStdRef=
       ,_cstVersion=&_cstStandardVersion
                                  );
            %let _cst_rc=1;
        %end;
     %end;
    %end;

%do cols=1 %to &numcol;
    %let dsCols=%scan(%sysfunc(compress(&col,'"')),&cols);
  proc sort data=_l2&_cstRandom;
  by column value;
  run;

  proc sort data=_&dscols out=_o&dscols nodupkey;
  by column value ;
  run;

    %* merge in the refcolumn with the column to be checked *;

    data _&dsCols;
    merge _o&dsCols(in=a) _l2&_cstRandom(in=b keep=column refcolumn value);
    by column value;
  VALUE=UPCASE(STRIP(VALUE));
    if a=1  ;
    run;
  %* remove dups from dataset;
  proc sort data=_&dscols nodupkey; by column value refcolumn; run;
  proc sort data=_l2&_cstrandom; by column value; run;

  %* check to see if missing values are allowed for Value field for this column;
  data _m&dscols.&cols(drop=f hasval);
  set _&dscols;
  if value='' then do;
    f=find("&nullcols","&dscols", 'i');
    if f=0 then hasval=1;
    else hasval=0;
  end;
  else hasval=1;
  if hasval=0 then output;
  run;

    %* pull out records not found in the lookup table *;
    data _&dsCols.&cols;
    merge _l2&_cstRandom(in=a) _&dsCols(in=b where=(value ne ''));
    by column value;
  if (a^=1 and b=1 )then output ;
    run;

  %* now we have list of bad records, go back to original dataset and
    pull out all records with the bad column/value pair and pick up rownum for error message;
  data _&dscols.&cols;
  merge _&dscols.&cols(keep=in=a) _o&dsCols(in=b);
  by column value;
  if a=1 and b=1 then output;
  run;

  proc append  base=_&dscols.&cols data=_m&dscols.&cols force;run;

    %* check to see if there are any invalid records in previous step *;
    %* if so, then run thru another check to check the refcolumn value *;
    %if %sysfunc(exist(_&dsCols.&cols))=1 %then %do;
        %let dsid=%sysfunc(open(_&dsCols.&cols,i));
        %if (&dsid >0 ) %then %do;
            %let anyobs=%sysfunc(attrn(&dsid,ANY));
            %if &anyobs > 0 %then %do;
                %* check the records which were not found for the refcolumn values *;
                data _&dsCols.&cols.a;
                set _&dsCols.&cols;
                if value='' and refcolumn ne '' then do;
                    column=refcolumn;
                end;
                run;
                proc sort ; by column value; run;
                data _&dsCols.&cols.notfound;
                merge _l2&_cstRandom(in=a) _&dsCols.&cols.a(in=b);
                by column value;
                if a^=1 and b=1 then  output ;
                run;

                %if %sysfunc(exist(_&dsCols.&cols))=1 %then %do;
                    %let dsid1=%sysfunc(open(_&dsCols.&cols,i));
                    %if (&dsid1 >0) %then %do;
                    %let anyobs=%sysfunc(attrn(&dsid1,ANY));
                    %if &anyobs > 0 %then %do;
                /***********write these records out to the results as errors **************/
                data _e2&_cstRandom (label='Work error data set');
                    %cstutil_resultsdskeep;
                    set _&dsCols.&cols.notfound end=last;
                 keep _cstmsgParm1 _cstmsgParm2;
                    *retain SeqNo 0 _cstResultID _cstValCheckID _cstResultSeqParm _cstResultFlagParm _cstRCParm ;
         retain SeqNo 0 resultid checkid resultflag _cst_rc resultseq;
                * Set results data set attributes *;
                    %cstutil_resultsdsattr;

                if _n_=1 then
                do;
                    resultseq=_n_;
          seqno=_n_;
                    ResultID="CST0116";
                    CheckID="CST0116";
                    ResultFlag=1;
                    _cst_RC=0;
                end;
        _cstmsgParm2="&_cstdsname";
                _cstMsgParm1=strip(column) || " row " || strip(rownum);
                Actual=value;
                SrcData =column;
                SeqNo+1;
                if last then
                    call symputx('_cstSeqCnt',SeqNo);
                run;
              %* create work dataset with all errors, then call append *;
              %cstutil_appendresultds(
                          _cstErrorDS=work._e2&_cstRandom
                         ,_cstSource=CST
                         ,_cstStdRef=
                   ,_cstVersion=&_cstStandardVersion
                         );
              %let _cst_rc=1;
                %end; %* errs found anyobs;
              %end; %* errs found open;
        %let dsidrc=%sysfunc(close(&dsid1));
             %end; %* errs found exists;

            %end; %*anyobs *;
        %end; %* invalid records dataset data open *;
    %let dsidrc=%sysfunc(close(&dsid));
    %end; %* invalid records dataset exists *;

    %if %sysfunc(exist( work._&dscols)) %then %do;
      proc datasets nolist; delete _&dscols; quit;
    %end;
    %if %sysfunc(exist( work._&dscols.&cols)) %then %do;
      proc datasets nolist; delete _&dscols.&cols; quit;
    %end;
    %if %sysfunc(exist( work._&dscols.&cols.a)) %then %do;
      proc datasets nolist; delete _&dscols.&cols.a; quit;
    %end;
    %if %sysfunc(exist( work._&dsCols.&cols.notfound)) %then %do;
      proc datasets nolist; delete _&dsCols.&cols.notfound; quit;
    %end;
  %if %sysfunc(exist( work._m&dscols.&cols)) %then %do;
      proc datasets nolist; delete _m&dscols.&cols; quit;
    %end;
    %if %sysfunc(exist( work._o&dscols)) %then %do;
      proc datasets nolist; delete _o&dscols; quit;
    %end;

    %if %sysfunc(exist(_&dsCols.&cols.notfound))=1 %then %do;
        %let dsid=%sysfunc(open(_&dsCols.&cols.notfound,i));
        %if (&dsid >0) %then %do;
            %let anyobs=%sysfunc(attrn(&dsid,ANY));
            %if &anyobs>0 %then %do;
                proc datasets nolist nodetails; delete _&dsCols.&cols.notfound; quit;
            %end;
        %end;
    %let dsidrc=%sysfunc(close(&dsid));
    %end;

%end; %* 1 to numcols loop *;

%mend;

%chkvals();

 %goto exit;

 %exit:

 %if %symexist(_chk_Random) %then %do;

   %if %sysfunc(exist( work.d1&_cstRandom)) %then %do;
     proc datasets nolist; delete d1&_cstRandom; quit;
   %end;

   %if %sysfunc(exist( work.t1&_cstRandom)) %then %do;
     proc datasets nolist; delete t1&_cstRandom; quit;
   %end;

   %if %sysfunc(exist( work._lc&_cstRandom)) %then %do;
     proc datasets nolist; delete _lc&_cstRandom; quit;
   %end;

   %if %symexist(_cstControlLib) %then %do;
     %if %sysfunc(libref(&_cstControlLib))=0 %then
     libname &_cstControlLib clear;;
   %end;

   %if %symexist(_cstTemplateLib) %then %do;
     %if %sysfunc(libref(&_cstTemplateLib))=0 %then
     libname &_cstTemplateLib clear;;
   %end;

   %if %sysfunc(exist( work.ctc&_cstRandom)) %then %do;
     proc datasets nolist; delete ctc&_cstRandom; quit;
   %end;

   %if %symexist(_ds1) %then %do;
     %if %sysfunc(exist( work.&_ds1)) %then %do;
       proc datasets nolist; delete &_ds1; quit;
     %end;
   %end;

   %if %sysfunc(exist( work._lo&_cstRandom)) %then %do;
     proc datasets nolist; delete _lo&_cstRandom; quit;
   %end;

   %if %sysfunc(exist( work._l1&_cstRandom)) %then %do;
     proc datasets nolist; delete _l1&_cstRandom; quit;
   %end;

   %if %sysfunc(exist( work._l2&_cstRandom)) %then %do;
     proc datasets nolist; delete _l2&_cstRandom; quit;
   %end;

   %if %sysfunc(exist( work._r&_cstRandom)) %then %do;
     proc datasets nolist; delete _r&_cstRandom; quit;
   %end;

   %if %sysfunc(exist(work._e1&_cstRandom)) %then %do;
     proc datasets nolist; delete _e1&_cstRandom; quit;
   %end;

   %if %sysfunc(exist(work._e2&_cstRandom)) %then %do;
     proc datasets nolist; delete _e2&_cstRandom; quit;
   %end;

   %if %sysfunc(exist(work._nu&_cstRandom)) %then %do;
     proc datasets nolist; delete _nu&_cstRandom; quit;
   %end;

   %* Delete the temporary messages data set if it was created here;
   %if (&_cstNeedToDeleteMsgs=1) %then %do;
     %if %eval(%index(&_cstMessages,.)>0) %then %do;
       %let _cstMsgDir=%scan(&_cstMessages,1,.);
       %let _cstMsgMem=%scan(&_cstMessages,2,.);
     %end;
     %else %do;
       %let _cstMsgDir=work;
       %let _cstMsgMem=&_cstMessages;
     %end;
     proc datasets nolist lib=&_cstMsgDir;
       delete &_cstMsgMem / mt=data;
       quit;
     run;
   %end;

 %end;

 %return;

%mend cstutil_checkDS;