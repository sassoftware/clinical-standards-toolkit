%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_reporttabledata                                                        *;
%*                                                                                *;
%* Supports table (domain) reporting by expanding process results.                *;
%*                                                                                *;
%* This macro creates work._cstrptresultsdom, which represents work._cstrptresults*;
%* that is expanded to include records for each table applicable to the original  *;
%* reported result.                                                               *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. Applicable only to Report2 and CDISC standards that report table-level    *;
%*      results (for example, CDISC SDTM and CDISC ADAM).                         *;
%*   2. Includes a call to a CDISC SDTM- (or ADaM-) specific macro that is known  *;
%*      or found only in the standard-specific autocall path.                     *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstRptControl Run-time validation control (check) data set            *;
%* @macvar _cstRptResultsDS Results data set created by a SAS Clinical Standards  *;
%*             Toolkit process                                                    *;
%* @macvar _cstSrcMetadataDS Source table metadata                                *;
%* @macvar _cstTableChecksDset Data set that specifies a list of tables for each  *;
%*             check                                                              *;
%* @macvar _cstTableChecksCode Macro to build _cstTableChecksDset                 *;
%* @macvar _cstTableSubset Subset Results data set by source data set (for        *;
%*             example, DM)                                                       *;
%* @macvar _cstUniqueTables List of unique tables for which results were found    *;
%*              in the Results data set. The list is space-delimited.             *;
%* @macvar _cstUniqueTablesCnt Count of tables in _cstUniqueTables                *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_reporttabledata(
    ) / des='CST: Reporting results for tables';

  %local
    _cstError
    _cstGroupName
  ;

  %let _cstError=0;

  **********************************************************************************;
  * Get non-process related records from the results data set.                     *;
  **********************************************************************************;

  proc sort data=&_cstRptResultsDS (where=(checkid ne '')) out=work._cstrptresults;
    by checkid resultseq seqno;
  run;

  * Identify those checks that failed to run, so that we can report this for   *;
  *  each table targeted by each check.                                        *;
  data work._cstfailedchecks;
    set work._cstrptresults (where=(resultflag < 0));
      by checkid;
    if last.checkid;
  run;

  **********************************************************************************;
  * Report 2 relies on a data set that identifies all the target tables for each   *;
  *  checkid.  This data set may have been created at some earlier point (e.g.     *;
  *  the refcntl.validation_domainsbycheck provided in the Global Library),        *;
  *  it may have been created earlier in this SAS session (as work._csttablelist)  *;
  *  or it will be created in processing that follows.  Creation of this data set  *;
  *  may take a significant amount of time, so use of a previously created file    *;
  *  is preferred/recommended and built into the code logic.                       *;
  **********************************************************************************;

  %if %length(&_cstTableChecksDset)>0 %then
  %do;
    %if %sysfunc(exist(&_cstTableChecksDset)) %then
    %do;
      %* create work._csttablelist from &_cstTableChecksDset  *;

      * This is a critical step in the processing logic.                           *;
      * At this point, work._csttablelist may contain all possible tables          *;
      *  (based on an assumption that _cstTableChecksDset has been built from      *;
      *  the reference_tables metadata associated with the standard of interest)   *;
      *  that apply to the checks run to create the current results data set.      *;
      * However, these checks may have been run on only some of these tables as    *;
      *  defined in the source data and source metadata.  So work._csttablelist    *;
      *  may need to be subset further to account for this.                        *;
      * We will use the srcmeta.source_tables (or equivalent) to subset.           *;

      %cst_getRegisteredStandards(_cstOutputDS=work._cststdtables);
      
      data _null_;
        set work._cststdtables (where=(standard="&_cstStandard" and standardversion="&_cstStandardVersion"));
          call symputx('_cstGroupName',groupname);
      run;

      %cstutil_deleteDataSet(_cstDataSetName=work._cststdtables);
      
      %* Special processing is required for ADaM with regard to BDS tables *;
      %if %upcase(&_cstGroupName)=ADAM %then
      %do;
        proc sql noprint;
          create table work._cstinittablelist as
            select checks.standard, checks.standardversion, checks.checkid, checks.usesourcemetadata,
                   tabs.table, tabs.class, tabs.checksource, tabs.resultseq, 
                   tabs.table as newtable format=$32.
              from
              &_cstRptControl (keep=checkid checksource standard standardversion usesourcemetadata) checks
                left join
              &_cstTableChecksDset tabs
            on checks.checkid=tabs.checkid and checks.checksource=tabs.checksource and checks.standardversion=tabs.standardversion
          order by table, checkid, resultseq;
        quit;

        data work._cstsrcDS (keep=table newtable)
             work._cstspecialDS (keep=table newtable)
             work._cstbds (keep=table newtable class);
          merge work._cstinittablelist (in=alltabs)
                &_cstSrcMetadataDS (in=srctabs keep=standard standardversion table class) end=last;
             by table;
          attrib newtable format=$32.
                 allbds format=$500.;
          retain allbds;

          newtable= table;
          if (srctabs and alltabs) then
          do;
            if first.table then output work._cstsrcDS;
          end;
          else
          do;
            if class='BDS' and table ne 'BDS' and first.table then 
            do;
              allbds = catx(' ',allbds,table);
              newtable=class;
              output work._cstbds;
            end;
            else
            do;
              if srctabs or usesourcemetadata ne 'Y' then
                output work._cstspecialDS;
            end;
          end;
          if last then
            call symputx('_cstAllBDS',allbds);
        run;

        data work._cstsubtablelist1 (drop=usesourcemetadata newtable);
          merge work._cstinittablelist (in=alltabs)
                work._cstsrcDS (in=srctabs)
                work._cstspecialDS (in=spectabs);
            by newtable;
          if not missing(checkid) and (srctabs or spectabs) then output;
        run;

        data work._cstsubtablelist2 (drop=usesourcemetadata newtable i);
          set work._cstinittablelist (in=alltabs where=(upcase(table)='BDS'));

          if not missing(checkid) then
          do;
            do i = 1 to countw("&_cstAllBDS",' ');
              table=scan("&_cstAllBDS",i,' ');
              output;
            end;
          end;
        run;
      
        data work._csttablelist;
          set work._cstsubtablelist1
              work._cstsubtablelist2;
        run;
        
        %cstutil_deleteDataSet(_cstDataSetName=work._cstinittablelist);
        %cstutil_deleteDataSet(_cstDataSetName=work._cstbds);
        %cstutil_deleteDataSet(_cstDataSetName=work._cstsubtablelist1);
        %cstutil_deleteDataSet(_cstDataSetName=work._cstsubtablelist2);
      %end;
      %else
      %do;
        proc sql noprint;
          create table work._csttablelist as
            select tabs.*, usesourcemetadata ,
                   case when upcase(substr(table,1,4))='SUPP' then 'SUPP'
                        when upcase(substr(table,1,2))='QS' then 'QS'
                        when upcase(substr(table,1,2))='FA' then 'FA'
                        else table
                   end as newtable format=$32.
              from
              &_cstRptControl (keep=checkid checksource standardversion usesourcemetadata) checks
                left join
              &_cstTableChecksDset tabs
            on checks.checkid=tabs.checkid and checks.checksource=tabs.checksource and checks.standardversion=tabs.standardversion
          order by table, checkid, resultseq;
        quit;

        data work._cstsrcDS (keep=table newtable)
             work._cstspecialDS (keep=table newtable);
          merge work._csttablelist (in=alltabs)
                &_cstSrcMetadataDS (in=srctabs keep=table);
             by table;
          attrib newtable format=$32.;
          newtable= table;
          if (srctabs and alltabs) then
          do;
            if first.table then output work._cstsrcDS;
            * keep a generic record around in case there are other SUPP** data sets  *;
            if upcase(table) in ('SUPPQUAL','QS','FA') then
            do;
              if upcase(substr(table,1,4))='SUPP' then newtable='SUPP';
              else if upcase(substr(table,1,2))='QS' then newtable='QS';
              else if upcase(substr(table,1,2))='FA' then newtable='FA';
              output work._cstspecialDS;
            end;
          end;
          else
          do;
            if upcase(substr(table,1,4))='SUPP' then newtable='SUPP';
            else if upcase(substr(table,1,2))='QS' then newtable='QS';
            else if upcase(substr(table,1,2))='FA' then newtable='FA';
            if in_src or usesourcemetadata ne 'Y' then
              output work._cstspecialDS;
          end;
        run;

        data work._csttablelist (drop=usesourcemetadata newtable);
          merge work._csttablelist (in=alltabs)
                work._cstsrcDS (in=srctabs)
                work._cstspecialDS (in=spectabs);
            by newtable;
          if (srctabs or spectabs) and checkid ne '';
        run;
      %end;
        
      
      proc sort data=work._csttablelist;
        by checkid resultseq table;
      run;

      %cstutil_deleteDataSet(_cstDataSetName=work._cstsrcDS);
      %cstutil_deleteDataSet(_cstDataSetName=work._cstspecialDS);

    %end;
    %else
      %let _cstError=1;
  %end;

  %*****************************************************************************************;
  %* Run the user-specified code ONCE (assuming _cstkeeptablechecklist has been set to Y)  *;
  %*  to create work._csttablelist.                                                        *;
  %*                                                                                       *;
  %* Note the use of _cstTableChecksCode is an attempt to generalize this report for use   *;
  %*  across standards, but assumes any standard-specific code uses the same set of        *;
  %*  parameters:                                                                          *;
  %*    _cstCheckDS - the set of CST validation checks (required)                          *;
  %*    _cstWhereClause - any valid where clause applied to the _cstCheckDS (optional)     *;
  %*    _cstOutputDS - the data set to-be-created (required)                               *;
  %*****************************************************************************************;

  %else %if ^%sysfunc(exist(work._csttablelist)) %then
  %do;
    %if %length(&_cstTableChecksCode)>0 %then
      %&_cstTableChecksCode(_cstCheckDS=&_cstRptControl,_cstWhereClause=,_cstOutputDS=work._csttablelist);
    %else
      %let _cstError=1;
  %end;

  %if ^%sysfunc(exist(work._csttablelist)) %then
    %let _cstError=1;

  %if &_cstError=0 %then
  %do;

    %if %length(&_cstTableSubset)>0 and %upcase(&_cstTableSubset) ne _ALL_ %then
    %do;
      data work._csttablelist;
        set work._csttablelist (where=(upcase(table)=upcase("&_cstTableSubset")));
      run;
    %end;

    * Identify the unique checks, based on what has been written to the results  *;
    *  data set                                                                  *;
    proc sql noprint;
        select distinct table into :_cstUniqueTables separated by ' '
          from work._csttablelist;
        select count(distinct table) into :_cstUniqueTablesCnt
          from work._csttablelist;
    quit;

    %if &_cstDebug=1 %then
    %do;
      %put cstutil_reporttabledata _cstUniqueTables = &_cstUniqueTables;
      %put cstutil_reporttabledata _cstUniqueTablesCnt = &_cstUniqueTablesCnt;
    %end;

    * This section attempts to parse the results.srcdata column                  *;
    data work._cstrptresultsdom (drop=_cstanydot i
      %if %length(&_cstTableSubset)>0 and %upcase(&_cstTableSubset) ne _ALL_ %then
      %do;
             where=(upcase(table)=upcase("&_cstTableSubset"))
      %end;
             );
      set work._cstrptresults;

       attrib table format=$32.;
      _cstanydot = index(srcdata,'.');
      if _cstanydot > 0 then
      do;
        table = scan(srcdata,2,'.');
        _cstanydot = indexc(table,' ([.-+=$%,<>/\)]');
        if _cstanydot > 0 then
          table = substr(table,1,_cstanydot-1);

        if upcase(table) =: "_CST" then
        do;
          do i=1 to &_cstUniqueTablesCnt;
            table=scan("&_cstUniqueTables",i);
            output;
          end;
        end;
        else
           output;
      end;
      else
      do;
          table=srcdata;
          output;
      end;
    run;

    * Now modify these results based on what was actually run                    *;
    proc sort data=work._csttablelist;
      by checkid resultseq table;
    run;
    data work._csttablelist;
      merge work._csttablelist (in=tl)
            work._cstfailedchecks (in=fc);
        by checkid;
      if fc then failed=1;
      else failed=0;
      if tl;
    run;

    proc sort data=work._cstrptresultsdom;
      by checkid resultseq table;
    run;

    * This data step modifies the current results to add records where needed.   *;
    data work._cstrptresultsdom;
      merge work._csttablelist (in=dom)
            work._cstrptresultsdom (in=res)
            ;
        by checkid resultseq table;
      if dom then
      do;
        * We have a matching result record for this table - so keep it           *;
        if res then
          output;
        else do;
          * No result record for this table.  Why?                               *;
          *  (1) Check never ran (output result record indicating failure)       *;
          *  (2) Code generally does not report absence of error, so output a    *;
          *       record to that effect.                                         *;
          if failed then
            output;
          else do;
            srcdata=cats(table,' [Derived]');
            message="No errors detected in source data";
            resultseverity="Info";
            resultid="CST0100";
            seqno=1;
            resultflag=0;
            _cst_rc=0;
            output;
          end;
        end;
      end;
      else
      do;
        if failed=0 then
          put "Result record found without a matching table: " checkid= srcdata= message=;
      end;
    run;

  %end;

  proc datasets nolist lib=work;
    delete _cstrptresults _cstfailedchecks;
  quit;

%mend cstutil_reporttabledata;
