%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilcompareautocallmacros                                                   *;
%*                                                                                *;
%* Compares two macro autocall libraries.                                         *;
%*                                                                                *;
%* The following results are reported:                                            *;
%*      File missing  (file is in _cstBasePath but not in _cstNewPath)            *;
%*      New file      (file is in _cstNewPath but not in _cstBasePath)            *;
%*      Different macro signature                                                 *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*   1. The macro parameters are defined in keyword-parameter=<value> format.     *;
%*   2. Any changes in default parameter values are not reported.                 *;
%*                                                                                *;
%* @param _cstBasePath - required - The full path to the autocall library to      *;
%*            compare against.                                                    *;
%* @param _cstNewPath - required - The full path to the autocall library to       *;
%*            compare.                                                            *;
%* @param _cstRptType - required - The location to contain the results.           *;
%*            Values: LOG | DATASET | _CSTRESULTSDS                               *;
%*                    LOG:           The SAS log file.                            *;
%*                    DATASET:       The data set that is specified by _cstRptDS. *;
%*                    _CSTRESULTSDS: The Results data set that is specified in    *;
%*                                   the _cstResultsDS global macro variable.     *;
%*            Default: LOG                                                        *;
%* @param _cstRptDS - required when _cstRptType=DATASET - The name of the data    *;
%*            set to contain the results. If _cstRptType=LOG or _CSTRESULTSDS,    *;
%*            this value is ignored.                                              *;
%* @param _cstOverWrite - optional - Overwrite the data set that is specified by  *;
%*             _cstRptDS. If _cstRptType=LOG or _CSTRESULTSDS, this value is      *;
%*            ignored.                                                            *;
%*            Values: Y | N                                                       *;
%*            Default: N                                                          *;
%*            If the value is N and _cstRptDS exists, the results are written to  *;
%*            the SAS log file.                                                   *;
%*                                                                                *;
%* @since  1.7                                                                    *;
%* @exposure external                                                             *;

%macro cstutilcompareautocallmacros(
  _cstBasePath=,
  _cstNewPath=,
  _cstRptType=LOG,
  _cstRptDS=,
  _cstOverwrite=N
  ) / des='CST: Compare autocall libraries';

  %local rc _cstRandom;
    
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);

  %************************;
  %* Parameter checking   *;
  %************************;
  
  %if %length(&_cstBasePath) < 1 or %length(&_cstNewPath) < 1 %then
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstBasePath and _cstNewPath parameter values are required.;
    %goto exit_error;
  %end;
  %let rc = %sysfunc(filename(fileref,&_cstBasePath)) ; 
  %if %sysfunc(fexist(&fileref))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstBasePath does not exist.;
    %goto exit_error;
  %end;
  %let rc = %sysfunc(filename(fileref,&_cstNewPath)) ; 
  %if %sysfunc(fexist(&fileref))=0 %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] &_cstNewPath does not exist.;
    %goto exit_error;
  %end;
  %if %length(&_cstRptType) < 1 %then
    %let _cstRptType=LOG;  
  %else %if %upcase(&_cstRptType) ^= LOG and %upcase(&_cstRptType) ^= DATASET and %upcase(&_cstRptType) ^= _CSTRESULTSDS %then 
  %do;
    %put ERR%STR(OR): [CSTLOG%str(MESSAGE).&sysmacroname] _cstRptType value must be LOG or DATASET or _CSTRESULTSDS.;
    %goto exit_error;
  %end;
  %_cstutilreporting(_cstType=&_cstRptType,_cstDS=&_cstRptDS,_cstOWrite=&_cstOverwrite);


  %_cstutilgetfoldersfiles(_cstRoot=&_cstBasePath, _cstFiletype=SAS, 
    _cstFoldersOut=work.basefolders_&_cstRandom, _cstFilesOut=work.basefiles_&_cstRandom, _cstRecurse=N);
  %_cstutilgetfoldersfiles(_cstRoot=&_cstNewPath, _cstFiletype=SAS, 
  _cstFoldersOut=work.newfolders_&_cstRandom, _cstFilesOut=work.newfiles_&_cstRandom, _cstRecurse=N);

  
  proc sort data=work.basefiles_&_cstRandom(keep=filename rename=(filename=name));
    by name;
  run;
  proc sort data=work.newfiles_&_cstRandom(keep=filename rename=(filename=name));
    by name;
  run;
  
  data work.filediff_&_cstRandom (keep=name condition message)
       work.baseparms_&_cstRandom (keep=name parameter upcased_parm)
       work.newparms_&_cstRandom (keep=name parameter upcased_parm)
       work.filesig_&_cstRandom (keep=name baseSignature newSignature);
    merge work.basefiles_&_cstRandom (in=base)
          work.newfiles_&_cstRandom (in=new);
      by name;
    attrib basefile newfile format=8. 
           line format=$132. 
           parameter upcased_parm format=$80. 
           tempvar format=$200.
           macroStr baseSignature newsignature format=$2000.
           message format=$500.
    ;
    retain endofmacro readingparms readingSig 0 macroStr '';
    if first.name then 
    do;
      endofmacro=0;
      readingparms=0;
      readingSig=0;
      macroStr='';
    end;

    condition=0;
    if base ne new then 
    do;
      if base then 
      do;
        condition=1;
        message=cats("Old macro (", name, ") not found in &_cstNewPath"); 
      end;
      else 
      do;
        condition=2;
        message=cats("New macro (", name, ") not found in &_cstBasePath"); 
      end;
      output work.filediff_&_cstRandom;
    end;
    else
    do;
    
      **************************************;
      * Process _cstBasePath folder first  *;
      **************************************;
      rc=filename('_cstDir',catx('/',"&_cstBasePath",name)) ; 
      tempvar=catx('/',"&_cstBasePath",name);
      
      basefile = fopen('_cstDir','I',132,'V');
      rc=fsep(basefile,'0D','X');  *  Carriage return  *;
      line = '';
      
      do while(fread(basefile)=0 and endofmacro=0);
         rc = fget(basefile,line);
         * Code often tabbed leading to string comparison discrepancies. Reset tabs to blanks. *;
         line=translate(line," ","09"x);

         * This signals the start of the signature/parameter processing.  *;
         if kstrip(line) =: '%macro' then
         do;
           tempvar=kstrip(kscan(line,2,' '));
           if kindex(tempvar,'(')>0 then
             tempvar=ksubstr(tempvar,1,kindex(tempvar,'(')-1);
           if kindexc(tempvar,';') then 
           do;
             readingparms=0;
             baseSignature=kstrip(line);
           end;
           else if not missing(tempvar) and upcase(tempvar) ne upcase(kscan(name,1,'.')) then
           do;
             %if (%symexist(_cstDeBug)=1) %then 
             %do;
               %if &_cstDeBug=1 %then
               %do;
                 tempvar=catx(' ',"[CSTLOG%str(MESSAGE).&sysmacroname] Internal macro",tempvar,"skipped.");
                 put tempvar;
               %end;
             %end;
           end;
           else do;
             readingSig=1;
             readingparms=1;
             if kindexc(line,';') then 
             do;
               readingparms=0;
               baseSignature=line;
             end;
             if kindex(line,'(') then
               macrostr=kstrip(ksubstr(line,kindex(line,'(')));
             else if not missing(kstrip(kscan(line,3,' '))) then
               macrostr=kstrip(ksubstr(line,kindex(line,kstrip(kscan(line,3,' ')))));
           end;
         end;
         else if readingSig=1 then
         do;
           if kindex(line,'(') then
             macrostr=kstrip(ksubstr(line,kindex(line,'(')));
           else
             macroStr=catx(' ',macroStr,line);
           if kindexc(line,';') then readingparms=0;
         end;
         if readingSig=1 and readingparms=0 then endofmacro=1;
      end;
      if missing(baseSignature) then
        baseSignature=catx(' ','%macro',kscan(name,1,'.'),macroStr);
      macrostr=kcompress(macroStr,'()');
    
      rc = fclose(basefile);
      
      * We have the macro signature for this macro  *;
      if ^missing(macroStr) then
      do;
        parmcount=countc(macroStr,'=');
        if kindex(kcompress(upcase(macroStr)),'/DES=') then parmcount=parmcount-1;
        if parmcount=0 then
        do;
          %if (%symexist(_cstDeBug)=1) %then 
          %do;
            %if &_cstDeBug=1 %then
            %do;
              tempvar=catx(' ',"[CSTLOG%str(MESSAGE).&sysmacroname] Macro",name,"has no parameters.");
              put tempvar;
            %end;
          %end;
        end;
        * Parse for parameters  *;
        do i=1 to parmcount;
          parmstart=kindexc(macroStr,'=');
          parmend=kindexc(macroStr,',');
          subline=kscan(macroStr,i,'=');
          parameter=kcompress(kstrip(kscan(macroStr,1,'=')));
          upcased_parm=upcase(parameter);
          * Exclude any descriptions as parameters *;
          output work.baseparms_&_cstRandom;
          if parmend=0 then leave;
          macroStr=ksubstr(macroStr,parmend+1);
        end;
      end;
      if missing(macroStr) then do;
        parameter='';
        upcased_parm='';
      end;
    
      **************************************;
      * Process _cstNewPath folder next    *;
      **************************************;
      endofmacro=0;
      readingparms=0;
      readingSig=0;
      macroStr='';
      
      rc=filename('_cstDir',catx('/',"&_cstNewPath",name)) ; 
      tempvar=catx('/',"&_cstNewPath",name);
      
      newfile = fopen('_cstDir','I',132,'V');
      rc=fsep(newfile,'0D','X');  *  Carriage return  *;
      line = '';
      
      do while(fread(newfile)=0 and endofmacro=0);
         rc = fget(newfile,line);
         * Code often tabbed leading to string comparison discrepancies. Reset tabs to blanks. *;
         line=translate(line," ","09"x);

         * This signals the start of the signature/parameter processing.  *;
         if kstrip(line) =: '%macro' then
         do;
           tempvar=kstrip(kscan(line,2,' '));
           if kindex(tempvar,'(')>0 then
             tempvar=ksubstr(tempvar,1,kindex(tempvar,'(')-1);
           if kindexc(tempvar,';') then 
           do;
             readingparms=0;
             newSignature=kstrip(line);
           end;
           else if not missing(tempvar) and upcase(tempvar) ne upcase(kscan(name,1,'.')) then
           do;
             %if (%symexist(_cstDeBug)=1) %then 
             %do;
               %if &_cstDeBug=1 %then
               %do;
                 tempvar=catx(' ',"[CSTLOG%str(MESSAGE).&sysmacroname] Internal macro",tempvar,"skipped.");
                 put tempvar;
               %end;
             %end;
           end;
           else do;
             readingSig=1;
             readingparms=1;
             if kindexc(line,';') then 
             do;
               readingparms=0;
               newSignature=line;
             end;
             if kindex(line,'(') then
               macrostr=kstrip(ksubstr(line,kindex(line,'(')));
             else if not missing(kstrip(kscan(line,3,' '))) then
               macrostr=kstrip(ksubstr(line,kindex(line,kstrip(kscan(line,3,' ')))));
           end;
         end;
         else if readingSig=1 then
         do;
           if kindex(line,'(') then
             macrostr=kstrip(ksubstr(line,kindex(line,'(')));
           else
             macroStr=catx(' ',macroStr,line);
           if kindexc(line,';') then readingparms=0;
         end;
         if readingSig=1 and readingparms=0 then endofmacro=1;
      end;
      if missing(newSignature) then
        newSignature=catx(' ','%macro',kscan(name,1,'.'),macroStr);
      macrostr=kcompress(macroStr,'()');
    
      rc = fclose(newfile);
      
      * We have the macro signature for this macro  *;
      if ^missing(macroStr) then
      do;
        parmcount=countc(macroStr,'=');
        if kindex(kcompress(upcase(macroStr)),'/DES=') then parmcount=parmcount-1;
        if parmcount=0 then
        do;
          %if (%symexist(_cstDeBug)=1) %then 
          %do;
            %if &_cstDeBug=1 %then
            %do;
              tempvar=catx(' ',"[CSTLOG%str(MESSAGE).&sysmacroname] Macro",name,"has no parameters.");
              put tempvar;
            %end;
          %end;
        end;
        * Parse for parameters  *;
        do i=1 to parmcount;
          parmstart=kindexc(macroStr,'=');
          parmend=kindexc(macroStr,',');
          subline=kscan(macroStr,i,'=');
          parameter=kstrip(kscan(macroStr,1,'='));
          upcased_parm=upcase(parameter);
          * Exclude any descriptions as parameters *;
          output work.newparms_&_cstRandom;
          if parmend=0 then leave;
          macroStr=ksubstr(macroStr,parmend+1);
        end;
      end;
      else do;
        parameter='';
        upcased_parm='';
      end;

      if last.name then
        output work.filesig_&_cstRandom;
    end;
    
  run;

  proc sort data=work.baseparms_&_cstRandom;
    by name upcased_parm;
  run;
  proc sort data=work.newparms_&_cstRandom;
    by name upcased_parm;
  run;
  data work.macrodiffs_&_cstRandom (drop=upcased_parm);
    merge work.baseparms_&_cstRandom (in=base)
          work.newparms_&_cstRandom (in=new);
      by name upcased_parm;
    attrib message format=$500.;
    in_base=base;
    in_new=new;

    if base ne new;  * only keep differences  *;
    if base then 
      message=catx(" ","Previous macro parameter no longer found for:", name);
    if new  then 
      message=catx(" ","New macro parameter detected for:", name);
  run;
  data work.macrodiffs_&_cstRandom;
    merge work.macrodiffs_&_cstRandom (in=diff)
          work.filesig_&_cstRandom;
      by name;
        if diff;
  run;

  %let _cstCnt=%cstutilnobs(_cstDataSetName=work.filediff_&_cstRandom);
  
  %if &_cstCnt>0 %then
  %do;
    %if %upcase(&_cstRptType)=LOG %then
    %do;
      data _null_;
        set work.filediff_&_cstRandom;
          if _n_=1 then 
            put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] The following macros differ between the two macro libraries:";
          put message;
      run;
    %end;
    %else %if %upcase(&_cstRptType)=DATASET %then
    %do;
      data &_cstRptDS;
        set work.filediff_&_cstRandom;
      run;
    %end;
    %else 
    %do;
      data work._cstDifferences_&_cstRandom;
        set work.filediff_&_cstRandom end=last;
        
          %cstutil_resultsdskeep;
          attrib _cstSeqNo format=8. label="Sequence counter for result column"
                 _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
                 _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
                 ;
      
          %cstutil_resultsdsattr;
          keep _cstMsgParm1 _cstMsgParm2;
      
          retain _cstSeqNo 0;
          if _n_=1 then _cstSeqNo=&_cstSeqCnt;
        
          srcdata = "&sysmacroname";
          resultid="CST0200";
          checkid="";
          _cstMsgParm1=message;
          _cstMsgParm2='';
          resultseq=1;
          resultflag=1;
          resultseverity='Info';
          resultdetails='';
          _cst_rc=0;
          actual='';
          keyvalues=cats('Macro name=',name);
          _cstSeqNo+1;
          seqno=_cstSeqNo;
      
          if last then
            call symputx('_cstSeqCnt',_cstSeqNo);
      run;

      %cstutil_appendresultds(_cstErrorDS=work._cstDifferences_&_cstRandom,_cstVersion=1.2,_cstSource=CST,_cstOrderBy=seqno);

      proc datasets lib=work nolist;
        delete _cstDifferences_&_cstRandom;
      quit;

    %end;
  %end;
  %else 
  %do;
    %if %upcase(&_cstRptType)=LOG %then
    %do;
      data _null_;
        put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] All macros were found in each of the two macro libraries.";
      run;
    %end;
    %else %if %upcase(&_cstRptType)=DATASET %then
    %do;
      data &_cstRptDS;
        set work.filediff_&_cstRandom;
      run;
    %end;
    %else %do;
      %cstutil_writeresult(
           _cstResultID=CST0200,_cstResultParm1=All macros were found in each of the two macro libraries,
           _cstSeqNoParm=1,_cstSrcDataParm=&sysmacroname);
    %end;
  %end;

  %let _cstCnt=%cstutilnobs(_cstDataSetName=work.macrodiffs_&_cstRandom);  
  
  %if &_cstCnt>0 %then
  %do;
    %if %upcase(&_cstRptType)=LOG %then
    %do;
      data _null_;
        set work.macrodiffs_&_cstRandom;
          if _n_=1 then 
            put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] The following macros differ between the two macro libraries:";
          put message ;
          if not missing(baseSignature) then put +2 "Base signature: " baseSignature;
          if not missing(newSignature) then put +3 "New signature: " newSignature;
          put;
      run;
    %end;
    %else %if %upcase(&_cstRptType)=DATASET %then
    %do;
      data &_cstRptDS;
        set
      %if %sysfunc(exist(&_cstRptDS)) %then
      %do;
        &_cstRptDS
      %end;
        work.macrodiffs_&_cstRandom;
      run;
    %end;
    %else 
    %do;

      data work._cstDifferences_&_cstRandom;
        set work.macrodiffs_&_cstRandom end=last;
          by name;
      
          %cstutil_resultsdskeep;
          attrib _cstSeqNo format=8. label="Sequence counter for result column"
                 _cstMsgParm1 format=$char200. label="Message parameter value 1 (temp)"
                 _cstMsgParm2 format=$char200. label="Message parameter value 2 (temp)"
                 ;
      
          %cstutil_resultsdsattr;
          keep _cstMsgParm1 _cstMsgParm2;
      
          retain _cstSeqNo 0;
          if _n_=1 then _cstSeqNo=&_cstSeqCnt;
         
          srcdata = "&sysmacroname";
          resultid="CST0200";
          checkid="";
          _cstMsgParm1=message;
          _cstMsgParm2='';
          resultseq=1;
          resultflag=1;
          resultseverity='Info';
          resultdetails='';
          _cst_rc=0;
          actual=parameter;
          keyvalues=cats('Macro name=',name);
          _cstSeqNo+1;
          seqno=_cstSeqNo;

          if last then
            call symputx('_cstSeqCnt',_cstSeqNo);
      run;
 
      %cstutil_appendresultds(_cstErrorDS=work._cstDifferences_&_cstRandom,_cstVersion=1.2,_cstSource=CST,_cstOrderBy=seqno);

      proc datasets lib=work nolist;
        delete _cstDifferences_&_cstRandom;
      quit;

    %end;
  %end;
  %else 
  %do;
    %if %upcase(&_cstRptType)=LOG %then
    %do;
      data _null_;
        put "NOTE: [CSTLOG%str(MESSAGE).&sysmacroname] No macro signature differences were detected between the two macro libraries.";
      run;
    %end;
    %else %if %upcase(&_cstRptType)=DATASET %then
    %do;
      data &_cstRptDS;
        set
      %if %sysfunc(exist(&_cstRptDS)) %then
      %do;
        &_cstRptDS
      %end;
        work.macrodiffs_&_cstRandom;
      run;
    %end;
    %else 
    %do;
      %cstutil_writeresult(
           _cstResultID=CST0200,_cstResultParm1=No macro signature differences were detected between the two macro libraries,
           _cstSeqNoParm=1,_cstSrcDataParm=&sysmacroname);
    %end;
  %end;

  %if ^%symexist(_cstDeBug) %then
    %let _cstDeBug=0;
  %if &_cstDeBug<1 %then
  %do;
    %cstutil_deleteDataSet(_cstDataSetName=work.basefiles_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.basefolders_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.newfiles_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.newfolders_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.macrodiffs_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.filediff_&_cstRandom); 
    %cstutil_deleteDataSet(_cstDataSetName=work.filesig_&_cstRandom); 
    %cstutil_deleteDataSet(_cstDataSetName=work.baseparms_&_cstRandom);
    %cstutil_deleteDataSet(_cstDataSetName=work.newparms_&_cstRandom); 
  %end;

%exit_error:

%mend cstutilcompareautocallmacros;
