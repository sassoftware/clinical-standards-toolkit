%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_cleanupcstsession                                                      *;
%*                                                                                *;
%* Cleans up after a SAS Clinical Standards Toolkit session.                      *;
%*                                                                                *;
%* The cleanup includes removing any process-level SAS files and clearing the     *;
%* work.sasmacr catalog.                                                          *;
%*                                                                                *;
%* This macro is most often used at the end of a SAS Clinical Standards Toolkit   *;
%* driver program, such as validate_data. This macro should be called where a     *;
%* DATA step or PROC is allowed.                                                  *;
%*                                                                                *;
%* @macvar _cstDeBug Turns debugging on or off for the session                    *;
%* @macvar _cstSASRefs Run-time SASReferences data set derived in process setup   *;
%* @macvar _cstMessages Cross-standard work messages data set                     *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstMetricsDS Data set used to accumulate metrics for a validation     *;
%*             process                                                            *;
%* @macvar _cstInitSASAutos Initial SASautos setting                              *;
%*                                                                                *;
%* @param _cstClearCompiledMacros - optional - Remove all compiled macros from    *;
%*            the work.sasmacr catalog. 0=No, 1=Yes.                              *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstClearLibRefs - optional - Deallocate all librefs and filerefs that  *;
%*            were set, based on the SASReferences content. 0=No, 1=Yes.          *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstResetSASAutos - optional - Reset the autocall search path to its    *;
%*            initial state. 0=No, 1=Yes.                                         *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstResetCmpLib - optional - Reset the compiled library path to its     *;
%*            initial state. 0=No, 1=Yes.                                         *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstResetFmtSearch - optional - Reset the format search path to its     *;
%*            initial state. 0=No, 1=Yes.                                         *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstResetSASOptions - optional - Reset the SAS options to their initial *;
%*            states. 0=No, 1=Yes.                                                *;
%*            Values:  0 | 1                                                      *;
%*            Default: 1                                                          *;
%* @param _cstDeleteFiles - optional - Delete all SAS Clinical Standards Toolkit  *;
%*            work files and catalogs. 0=No, 1=Yes.                               *;
%*            NOTE: If _cstDebug=1, files are NOT deleted, even when              *;
%*            _cstDeleteFiles=1.                                                  *;
%*            Values:  0 | 1                                                      *;
%*            Default: 1                                                          *;
%* @param _cstDeleteGlobalMacroVars - optional - Delete all SAS Clinical Standards*;
%*            Toolkit global macro variables that were set, based on the property *;
%*            filename/value pairs. 0=No, 1=Yes.                                  *;
%*            Values:  0 | 1                                                      *;
%*            Default: 0                                                          *;
%* @param _cstStd - optional - Limit cleanup to records for this standard (in     *;
%*            combination with _cstStdVer)                                        *;
%* @param _cstStdVer - optional - Limit cleanup to records for this               *;
%*            standardversion (in combination with _cstStd)                       *;
%*                                                                                *;
%* @since 1.2                                                                     *;
%* @exposure internal                                                             *;

%macro cstutil_cleanupcstsession(
    _cstClearCompiledMacros=0,
    _cstClearLibRefs=0,
    _cstResetSASAutos=0,
    _cstResetCmpLib=0,
    _cstResetFmtSearch=0,
    _cstResetSASOptions=1,
    _cstDeleteFiles=1,
    _cstDeleteGlobalMacroVars=0,
    _cstStd=,
    _cstStdVer=
    ) / des='CST: Cleanup Toolkit session';

  %cstutil_setcstgroot;

  %local
    _cstAnyProb
    _cstResultsLib
    _cstTempDS
    _cstTempLib
  ;

  %* Clear the work macro catalog  *;
  %if &_cstClearCompiledMacros=1 %then
  %do;

    * Clear the work macro catalog regardless of debug status              *;
    * Following attempt to clear macros causes a SAS error when, in the    *;
    *  same session, user attempts to reuse macros in the autocall path.   *;
    *  This is entered into DevTrack as TK241.                             *;
    proc catalog c=work.sasmacr kill force;
    quit;

  %end;

  %* Reset autocall path  *;
  %if &_cstResetSASAutos=1 %then
  %do;

    %if %symexist(_cstInitSASAutos) %then
    %do;
      options sasautos=&_cstInitSASAutos;
      %put NOTE: SASAutos reset to &_cstInitSASAutos;
    %end;
    %else
    %do;
      options sasautos=("%sysget(CSTHOME)/macros", sasautos);
      %put NOTE: SASAutos reset to ("%sysget(CSTHOME)/macros", sasautos);
    %end;

  %end;

  %* Reset compiled library path  *;
  %if &_cstResetCmpLib=1 %then
  %do;

    %if %symexist(_cstInitCmplib) %then
    %do;
      options cmplib=&_cstInitCmplib;
      %put NOTE: Compiled library path reset to &_cstInitCmplib;
    %end;
    %else
    %do;
      options cmplib='';
      %put NOTE: Compiled library path reset to missing;
    %end;

  %end;

  %* Clear the session librefs and filerefs  *;
  %if &_cstClearLibRefs=1 %then
  %do;

    %if %sysfunc(exist(&_cstSASRefs)) %then
    %do;
      proc sort data=&_cstSASRefs;
        by sasref reftype;
      run;

      * Keep a single instance only of each libref and sasref *;
      data work._cstcleanuprefs;

  %if %length(&_cstStd)>0 and %length(&_cstStdVer)>0 %then
  %do;
        set &_cstSASRefs (keep=standard standardversion sasref reftype type 
                          where=(upcase(sasref) ne 'WORK' and (upcase(standard)=upcase("&_cstStd") and  
               upcase(standardversion)=upcase("&_cstStdVer"))));
  %end;
  %else
  %do;
        set &_cstSASRefs (keep=sasref reftype type where=(upcase(sasref) ne 'WORK'));
  %end;
  
        by sasref reftype;
        if first.reftype;
      run;

      data _null_;
        set work._cstcleanuprefs;

          attrib _cstCurrentPath format=$2000. label="Current path";

          select(upcase(reftype));
            when('FILEREF')
            do;
              _cstCurrentPath = pathname(sasref,'F');
              if _cstCurrentPath ne '' then
              do;
                * Additional processing is required to handle  *;
                * the clearing of any autocall filerefs.       *;
                select(upcase(type));
                  when('AUTOCALL')
                  do;
                    %* SAS requires the following steps to clear an autocall fileref  *;
                    %*  (1) reset the autocall path to exclude the fileref            *;
                    %*  (2) invoke a macro from the new autocall path                 *;
                    %*  (3) clear the fileref                                         *;
                    %* However, this will not work in the current code context, as    *;
                    %*  use of the current macro from anywhere in the active          *;
                    %*  autocall path prevents use of filename xxx clear;             *;

                    call execute('%put NOTE: The autocall fileref ' || strip(sasref) || ' remains allocated.');
                  end;
                  otherwise
                    call execute('filename ' || sasref || ';');
                end;
              end;
            end;
            when('LIBREF')
            do;
              _cstCurrentPath = pathname(sasref,'L');
              if _cstCurrentPath ne '' then
                call execute('libname ' || sasref || ';');
            end;
            otherwise;
          end;
      run;

      proc datasets lib=work nolist;
        delete _cstcleanuprefs  / memtype=data;
      quit;
    %end;

  %end;

  %* Reset format search path  *;
  %if &_cstResetFmtSearch=1 %then
  %do;

    %if %sysfunc(exist(work._cstsessionoptions)) %then
    %do;
      data _null_;
        set work._cstsessionoptions (where=(upcase(optname)="FMTSEARCH"));
          call execute('options fmtsearch = ' ||  strip(optvalue) || ';');
      run;
    %end;

  %end;

  %* Reset SAS options  *;
  %if &_cstResetSASOptions=1 %then
  %do;

    %if %sysfunc(exist(work._cstsessionoptions)) %then
    %do;
      proc optLoad data=work._cstsessionoptions;
      run;
    %end;

  %end;

  %let _cstTempLib=;
  %let _cstTempDS=;
  %let _cstAnyProb=0;

  %* Delete work files only if no debugging enabled  *;
  %if &_cstDeleteFiles=1 %then
  %do;
    %if &_cstDebug=0 %then
    %do;
      %if %sysfunc(exist(&_cstResultsDS)) %then
      %do;
        %* Delete the work results data set  *;
        %if %sysfunc(indexc(&_cstResultsDS,'.')) %then
        %do;
          %let _cstTempLib=%SYSFUNC(scan(&_cstResultsDS,1,'.'));
          %let _cstTempDS=%SYSFUNC(scan(&_cstResultsDS,2,'.'));
        %end;
        %else
        %do;
          %let _cstTempLib=work;
         %let _cstTempDS=&_cstResultsDS;
        %end;

        %let _cstResultsLib=work;
        data _null_;
          set &_cstSASrefs (where=(upcase(type)='RESULTS'));

          call symputx('_cstResultsLib',sasref);
        run;
        
        * We will not delete the results data set if any problem was reported *;
        data _null_;
          set &_cstResultsDS end=last;
            attrib anyProb format=8.;
            retain anyProb 0;
            if _cst_rc ne 0 then
              anyProb=1;
            if anyProb or last then do;
              call symputx('_cstAnyProb',anyProb);
              stop;
            end;
        run;

        %if &_cstAnyProb=0 and
            (%quote(%sysfunc(pathname(&_cstTempLib))) ^= %quote(%sysfunc(pathname(&_cstResultsLib)))) and
            (%quote(%sysfunc(pathname(&_cstTempLib))) = %quote(%sysfunc(pathname(WORK)))) %then
        %do;
          proc datasets lib=&_cstTempLib nolist;
            delete &_cstTempDS / memtype=data;
          quit;
        %end;
      %end;

      %if %symexist(_cstMetricsDS) %then
      %do;
        %if %sysfunc(exist(&_cstMetricsDS)) %then
        %do;
          %* Delete the work metrics data set  *;
          %if %sysfunc(indexc(&_cstMetricsDS,'.')) %then
          %do;
            %let _cstTempLib=%SYSFUNC(scan(&_cstMetricsDS,1,'.'));
            %let _cstTempDS=%SYSFUNC(scan(&_cstMetricsDS,2,'.'));
          %end;
          %else
          %do;
            %let _cstTempLib=work;
            %let _cstTempDS=&_cstMetricsDS;
          %end;

          %let _cstResultsLib=work;
          data _null_;
            set &_cstSASrefs (where=(upcase(type)='RESULTS'));

            call symputx('_cstResultsLib',sasref);
          run;

          %if &_cstAnyProb=0 and
              (%quote(%sysfunc(pathname(&_cstTempLib))) ^= %quote(%sysfunc(pathname(&_cstResultsLib)))) and
              (%quote(%sysfunc(pathname(&_cstTempLib))) = %quote(%sysfunc(pathname(WORK)))) %then
          %do;
            proc datasets lib=&_cstTempLib nolist;
              delete &_cstTempDS / memtype=data;
            quit;
          %end;
        %end;
      %end;

      %* Delete the work messages data set  *;
      %if %sysfunc(indexc(&_cstmessages,'.')) %then
      %do;
        %let _cstTempLib=%SYSFUNC(scan(&_cstmessages,1,'.'));
        %let _cstTempDS=%SYSFUNC(scan(&_cstmessages,2,'.'));
      %end;
      %else
      %do;
        %let _cstTempLib=work;
        %let _cstTempDS=&_cstmessages;
      %end;

      %if %length(%sysfunc(pathname(&_cstTempLib,'L')))>0 %then
      %do;
        proc datasets lib=&_cstTempLib nolist;
          delete &_cstTempDS / memtype=data;
        quit;
      %end;

      %* Delete the work sasreferences data set  *;
      %if %sysfunc(indexc(&_cstsasrefs,'.')) %then
      %do;
        %let _cstTempLib=%SYSFUNC(scan(&_cstsasrefs,1,'.'));
        %let _cstTempDS=%SYSFUNC(scan(&_cstsasrefs,2,'.'));
      %end;
      %else
      %do;
        %let _cstTempLib=work;
        %let _cstTempDS=&_cstsasrefs;
      %end;

      %if %length(%sysfunc(pathname(&_cstTempLib,'L')))>0 %then
      %do;
        proc datasets lib=&_cstTempLib nolist;
          delete &_cstTempDS  / memtype=data;
        quit;
      %end;

      %if %sysfunc(exist(work._cstsessionoptions)) %then
      %do;
        proc datasets lib=work nolist;
          delete _cstsessionoptions  / memtype=data;
        quit;
      %end;

    %end;
  %end;

  %* Delete any global macro variables set in the session  *;
  %if &_cstDeleteGlobalMacroVars=1 %then
  %do;

    data work._cstglobalmvars;
      set sashelp.vmacro (where=(lowcase(name) =: "_cst" and scope="GLOBAL"));
    run;

    data _null_;
      set work._cstglobalmvars;
      if _n_ = 1 then
      do;
        put "NOTE: Deleting the following macro variables:";
      end;
      put "NOTE: " +5 name 32.;
      call execute('%symdel '||trim(left(name))||';');
    run;

    proc datasets lib=work nolist;
      delete _cstglobalmvars  / memtype=data;
    quit;

  %end;

%mend cstutil_cleanupcstsession;