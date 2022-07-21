%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_createsublists                                                         *;
%*                                                                                *;
%* Creates work._cstsublists that has interpreted validation check metadata.      *;
%*                                                                                *;
%* This macro creates the work._cstsublists data set that has interpreted         *;
%* validation check metadata as specified in the columnScope column in the        *;
%* expected form of [var1][var2].                                                 *;
%*                                                                                *;
%* This macro is called directly only as a validation check metadata codelogic    *;
%* value. This macro is NOT always called for the derivation of work._cstsublists.*;
%*                                                                                *;
%* Required file inputs:                                                          *;
%*   work._cstcolumnmetadata                                                      *;
%*   work._csttablemetadata                                                       *;
%*                                                                                *;
%* @macvar _cstColumnScope Column scope as defined in validation check metadata   *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%*                                                                                *;
%* @param _cstSupplementalVar - optional - Specifies an additional variable       *;
%*            that must be present for the derived work._cstsublists to be        *;
%*            valid. If the additional variable is NOT present, the records for   *;
%*            the specific data set are deleted from work._cstsublists.           *;
%*                                                                                *;
%* @since 1.4                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_createsublists(_cstSupplementalVar=
    ) / des ="CST: Create sublists from columnscope";

  %local
    _cstAllTables
    _cstErr
    _cstMsg
    _cstPrxStr1
    _cstPrxStr2
    _cstPrxIndex1
    _cstPrxIndex2
    _cstSubCnt1
    _cstSubCnt2
    _cstTable
    _cstTableName
    _cstTableSASRef
    _cstVarExists
    _cstWildCardCnt1
    _cstWildCardCnt2
  ;

  %let _cstErr=0;
  %let _cstMsg=;
  %let _cstPrxStr1=;
  %let _cstPrxStr2=;
  %let _cstPrxIndex1=0;
  %let _cstPrxIndex2=0;
  %let _cstWildCardCnt1=0;
  %let _cstWildCardCnt2=0;

  data _null_;
    attrib CSStr1 format=$40.
           CSStr2 format=$40.
           fullCS format=$80.
           cstMsg format=$80.;
    cstErr=0;
    cstMsg='';
    fullCS=symget('_cstColumnScope');

    if countc(fullCS,'[]') ne 4 then do;
      cstErr=1;
      cstMsg='Columnscope does not contain two sublists';
    end;

    CSStr1=tranwrd(scan(fullCS,1,'['),']','');
    CSStr2=tranwrd(scan(fullCS,2,'['),']','');
    wcCnt1=countc(CSStr1,'#');
    if wcCnt1>2 then
    do;
      cstErr=1;
      cstMsg="Unsupported wildcard syntax found in &_cstColumnScope";
    end;
    wcCnt2=countc(CSStr2,'#');
    call symputx('_cstPrxIndex1',indexc(CSStr1,'#'));
    call symputx('_cstPrxIndex2',indexc(CSStr2,'#'));

    if wcCnt2>2 then
    do;
      cstErr=1;
      cstMsg="Unsupported wildcard syntax found in &_cstColumnScope";
    end;
    call symputx('_cstErr',cstErr);
    call symputx('_cstMsg',cstMsg);
    call symputx('_cstWildCardCnt1',wcCnt1);
    call symputx('_cstWildCardCnt2',wcCnt2);
  run;

  %if &_cstErr %then
  %do;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %cstutil_writeresult(
                _cstResultID=CST0202
                ,_cstResultParm1=&_cstMsg
                ,_cstResultParm2=
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=&_cstSeqCnt
                ,_cstSrcDataParm=&sysmacroname
                ,_cstResultFlagParm=-1
                ,_cstRCParm=0
                );
  %end;
  %else
  %do;

    * Read the work._cstcolumnmetadata data set as built by the cstutil_buildcollist macro *;
    proc sql noprint;
      create table work._cstsublists as
        select coalesce(sub1.sasref,sub2.sasref) as sasref,
               coalesce(sub1.table,sub2.table) as table,
               strip(sub1.sasref) || '.' || strip(sub1.table) as _cstDSName1,
               sub1.column as _cstColumn1,
               _cstSubOrder1,
               strip(sub2.sasref) || '.' || strip(sub2.table) as _cstDSName2,
               sub2.column as _cstColumn2,
               _cstSubOrder2,
               coalesce(sub1._cstSubOrder1,sub2._cstSubOrder2) as suborder
        from work._cstcolumnmetadata (rename=(suborder=_cstSubOrder1) where=(sublist=1)) sub1
                full join
             work._cstcolumnmetadata (rename=(suborder=_cstSubOrder2) where=(sublist=2)) sub2
                on ((sub1.column=sub2.column) or
                   (sub1.column ne sub2.column and sub1._cstSubOrder1 = sub2._cstSubOrder2)

%if &_cstPrxIndex1>0 %then
%do;
                    and
                    substr(sub1.column,&_cstPrxIndex1,&_cstWildCardCnt1) =
                    substr(sub2.column,&_cstPrxIndex2,&_cstWildCardCnt2)
%end;
                    );
        select count(*) into :_cstSubCnt1 from work._cstsublists (where=(_cstSubOrder1 ne .));
        select count(*) into :_cstSubCnt2 from work._cstsublists (where=(_cstSubOrder2 ne .));
    quit;
    
    %* Adjust the contents of work._cstsublists if any required supplemental variable is not found *;
    %if %length(&_cstSupplementalVar)>0 %then
    %do;
      data _null_;
        set work._csttablemetadata (keep=sasref table) end=last;
          attrib alltables format=$2000.;
          retain alltables;
          
          if _n_=1 then alltables =cats(sasref,'.',table);
          else alltables=catx(' ',strip(alltables),cats(sasref,'.',table));
          if last then
            call symputx('_cstAllTables',alltables);
      run;
      %do _tab_=1 %to %SYSFUNC(countw(&_cstAllTables,' '));
        %let _cstTable=%scan(&_cstAllTables,&_tab_,' ');
        %let _cstTableSASRef=%scan(&_cstTable,1,'.');
        %let _cstTableName=%scan(&_cstTable,2,'.');

        %let _cstVarExists=0;
        
        data _null_;
          dsid=open("&_cstTable");
    if dsid ne 0 then
      if varnum(dsid,"&_cstSupplementalVar")>0 then
        call symputx('_cstVarExists',1);
    rc=close(dsid);
        run;
        
        data work._cstsublists; 
          set work._cstsublists;
           if sasref="&_cstTableSASRef" and table="&_cstTableName" and input(symget('_cstVarExists'),8.)=0 then 
           do;
             call symputx('_cstErr',1);
             * Delete all records for this table from the data set  *;
             delete;
           end;
        run;
        %if &_cstErr %then
        %do;
          %let _cstError=2;  %* Initialized in and returned to calling macro *;
          %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
          %cstutil_writeresult(
                   _cstResultID=CST0021,
                  _cstValCheckID=&_cstCheckID,
                  _cstResultParm1=&_cstTable,
                  _cstResultParm2=&_cstSupplementalVar,
                  _cstResultSeqParm=1,
                  _cstSeqNoParm=&_cstSeqCnt,
                  _cstSrcDataParm=CSTUTIL_CREATESUBLISTS,
                  _cstResultFlagParm=-1,
                  _cstRCParm=0,
                  _cstResultsDSParm=&_cstResultsDS
          );
        %end;
        %let _cstErr=0;
      %end;
    %end;
    
  %end;

%mend cstutil_createsublists;
