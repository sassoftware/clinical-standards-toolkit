%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutilfindfixextdasciichars.sas                                               *;
%*                                                                                *;
%* Identifies and fixes problems in data sets caused by extended ASCII characters.*;
%*                                                                                *;
%* This macro identifies and fixes problems in SAS data sets caused by extended   *;
%* ASCII characters in column values. Extended ASCII characters occur most often  *;
%* when a SAS data set is populated by reading a Microsoft Excel spreadsheet or   *;
%* Word document that contains characters such as "curly" quotation marks and     *;
%* double quotation marks.                                                        *;
%*                                                                                *;
%* NOTE: This macro does not handle double-byte character set (DBCS) data.        *;
%*                                                                                *;
%* This macro uses a SAS format in the macro code to map replacement characters   *;
%* for the extended ASCII characters. SAS supplies a default format mapping for   *;
%* common extended ASCII characters. You should review the mappings, change them, *;
%* or create new mappings. You can supply an external SAS format by specifying a  *;
%* value for the _cstExternalFmt parameter.                                       *;
%*                                                                                *;
%* If an unmapped extended ASCII character is detected, the value appears as      *;
%* either a '?' or '**', or the value specified for the _cstExtFmtOtherValue      *;
%* parameter, in the data set specified in _cstOutputDS. This provides a visual   *;
%* cue that a valid ASCII value is needed to replace the extended ASCII character.*;
%* After a replacement value is determined, that value must be entered as the     *;
%* mapping value to update the SAS format. The code must be resubmitted.          *;
%*                                                                                *;
%* Mapped data sets are created in the _cstWriteToLib directory. The default is   *;
%* WORK, but care is needed not to overwrite any files in the production          *;
%* directory.                                                                     *;
%*                                                                                *;
%* Here are examples:                                                             *;
%*                                                                                *;
%* %cstutilfindfixextdasciichars(_cstDSName=tmp1._all_,                           *;
%*                               _cstGeneratedCodeFile=c:\tmp\findasciicode.sas,  *;
%*                               _cstFindFix=FIND);                               *;
%*                                                                                *;
%* In this example, all data sets (_all_) in the tmp1 library, as well as all     *;
%* columns are checked for extended characters. Any code that is generated when   *;
%* extended characters are found is directed to the c:\temp\findasciicode.sas     *;
%* file. The FIND FIX parameter (_cstFindFix) is set to FIND. This allows you to  *;
%* review any data sets or files prior to applying any fixes. This is the default *;
%* action.                                                                        *;
%*                                                                                *;
%* %cstutilfindfixextdasciichars(_cstDSName=testdat2.ascii,                       *;
%*                               _cstColumnName=comment notes,                    *;
%*                               _cstExternalFmt=asciifmt,                        *;
%*                               _cstGeneratedCodeFile=c:/fixascii/fixdataset.sas,*;
%*                               _cstOutputDS=testdata.all_cstProblems,           *;
%*                               _cstWriteToLib=asciifix,                         *;
%*                               _cstFindFix=fix)                                 *;
%*                                                                                *;
%* In this example, the _cstDSName data set testdat2.ascii and columns comment    *;
%* and notes in the _cstColumnName parameter are examined extended ASCII          *;
%* characters. A numeric external SAS format ASCIIFMT is specified in the         *;
%* _cstExternalFmt parameter. Generated code is directed to the                   *;
%* c:/fixascii/fixdataset.sas file and testdata.all_cstProblems will contain      *;
%* mapping information, if found. Any data set that must be converted are written *;
%* to the asciifix library as specified in the _cstWriteToLib parameter. The      *;
%* _cstFindFix parameter is set to FIX, which causes the macro to submit the code *;
%* generated in the _cstGeneratedCodeFile parameter.                              *;
%*                                                                                *;
%* Notes:                                                                         *;
%*    1. Any problems detected in a specific controlled terminology data set might*;
%*       require identical updates in the current folder.                         *;
%*    2. Any problem detected in the GlobalLibrary also requires correction into  *;
%*       the equivalent !sasroot....standards/ folder hierarchy.                  *;
%*    3. It is recommended that any problems detected also be corrected in any    *;
%*       source input file (for example, the source xls file), given that the     *;
%*       data set might subsequently be recreated incorrectly from that source    *;
%*       file.                                                                    *;
%*    4. For reference, the following sources were used:                          *;
%*            http://www.danshort.com/ASCIImap/                                   *;
%*            http://www.asciitable.com/                                          *;
%*                                                                                *;
%* @macvar _cst_rc: Error detection return code. If 1, an error exists.           *;
%* @macvar _cst_rcmsg: Error return code message text                             *;
%*                                                                                *;
%* @param _cstDSName - required - The source data set to examine for extended     *;
%*            ASCII characters. To include all data sets, specify _ALL_. This     *;
%*            paramter is submitted using <libname>.<dataset> format. The libname *;
%*            must be initialized before running the macro.                       *;
%* @param _cstColumnName - optional - The column to examine. If this parameter is *;
%*            not specified or left blank, all columns specified by the           *;
%*            _cstDSName parameter are scanned. This parameter must be blank if   *;
%*            _cstDSName is set to _ALL_.                                         *;
%* @param _cstExternalFmt - optional - The name of a numeric external SAS format  *;
%*            that contains the extended ASCII characters values and their        *;
%*            replacement values. Refer to the PROC FORMAT statement in the macro *;
%*            for correct form.                                                   *;
%* @param _cstExtFmtOtherValue - optional - The value used in the 'other' clause  *;
%*            of the PROC FORMAT statement that provides a value that alerts you  *;
%*            that an extended ASCII character has not been mapped.               *;
%* @param _cstGeneratedCodeFile - required - The defined output file to which the *;
%*            macro generates SAS code. SAS code is generataed only if extended   *;
%*            ASCII characters are detected. This file can be submitted in a SAS  *;
%*            session.                                                            *;
%* @param _cstOutputDS - required - The data set that contains information about  *;
%*            the data sets and columns that contain extended ASCII characters.   *;
%*            Default: work._cstProblems                                          *;
%* @param _cstRetainOutputDS - optional - Retain the output data set that is      *;
%*            specified by the _cstOutpuDS parameter. Use this if examining       *;
%*            multiple libraries. Appends the new output data set(s) to the       *;
%*            existing  data set.                                                 *;
%*            Default: N                                                          *;
%* @param _cstWriteToLib - optional - The libname in which to write the generated *;
%*            data sets. Libname must be initialized if using the FIX option for  *;
%*            the _cstFindFix parameter.                                          *;
%*            Default: WORK                                                       *;
%* @param _cstFindFix - optional - The method to use to fix extended ASCII        *;
%*            characters.                                                         *;
%*            Identifying and fixing extended ASCII characters is a two-part      *;
%*            process. First, the extended ASCII characters are identified.       *;
%*            Second, the extended ASCII characters are mapped and replacement    *;
%*            values are generated.                                               *;
%*            FIX automatically submits the generated SAS code after the data     *;
%*            set(s) have been examined.                                          *;
%*            FIND does not submit the SAS code and enables you to check the      *;
%*            generated data sets and program code in case changes are required.  *;
%*            If this parameter is blank, the default value is used.              *;
%*            Values: FIND | FIX | blank                                          *;
%*            Default: FIND                                                       *;
%*                                                                                *;
%* @since 1.7                                                                     *;
%* @exposure external                                                             *;

%macro cstutilfindfixextdasciichars(
  _cstDSName=,
  _cstColumnName=, 
  _cstExternalFmt=,
  _cstExtFmtOtherValue=,
  _cstGeneratedCodeFile=,
  _cstOutputDS=work._cstProblems,
  _cstRetainOutputDS=N,
  _cstWriteToLib=work,
  _cstFindFix=FIND)/ des='CST: Find and Fix extended ASCII characters in SAS data sets';

  %**********************************************;
  %* Set parameters that might be uninitialized *;
  %**********************************************;
  %if %length(&_cstOutputDS)=0 %then %let _cstOutputDS=work._cstProblems;
  %if %length(&_cstRetainOutputDS)=0 %then %let _cstRetainOutputDS=N;
  %if %length(&_cstFindFix)=0 %then %let _cstFindFix=FIND;
  %if %length(&_cstWriteToLib)=0 %then %let _cstWriteToLib=work;
  %if %length(&_cstExtFmtOtherValue)=0 %then %let _cstExtFmtOtherValue=**;

  %*****************************;
  %* Set local macro variables *;
  %*****************************;
  %local _cstBTYPE
         _cstColCnt
         _cstColName
         _cstDomainOnly
         _cstDSFlg
         _cstDSLabel
         _cstDSList
         _cstDSListCnt
         _cstDSNameTmp
         _cstDSSortVars
         _cstErrCnt
         _cstFixSetup
         _cstFmtExists
         _cstLibname
         _cstLibPathIn
         _cstRandom
         _cstRecCnt
         _csttemp
         _cstThisMacroRc
         _cstVarList
         _cstVarList2
         _cstVarListCnt
  ;
  
  %global _cst_rc
          _cst_rcmsg
  ;

  %****************************************************;
  %*  Check for missing parameters that are required  *;
  %****************************************************;
  %let _cst_rc=0;
  %let _cst_rcmsg=;
  %let _cstFmtExists=0;
  
  %if (%length(&_cstDSName)=0) or
      (%length(&_cstGeneratedCodeFile)=0) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: One or more REQUIRED parameters (_cstDSName or _cstGeneratedCodeFile) are missing.;
  %end;

  %*****************************************************;
  %*  Check for incorrect _cstFindFix parameter values *;
  %*  Current values are FIND, FIX and blank           *;
  %*****************************************************;
  %if %length(&_cstFindFix) > 0 and ((%upcase(&_cstFindFix) ne FIND) and (%upcase(&_cstFindFix) ne FIX)) %then 
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: Incorrect value for _cstFindFix parameter [&_cstFindFix] must be FIND, FIX or blank.;
  %end;

  %********************************************************************;
  %*  Check that the input libref and data set for _cstDSName exists  *;
  %*  and libname is 8 characters or less.                            *:
  %********************************************************************;
  %let _cstLibname=%upcase(%scan(&_cstDSName,-2,'.'));
  %if &_cstLibname=%str() %then
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: Incorrect parameter value for _cstDSName - must be in the form <libname.dataset>.;
  %end;
  %else 
  %do;
    %if %length(&_cstLibname) gt 8 %then
    %do;
      %let _cst_rc=1;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: _cstDSName (%upcase(&_cstDSName)) contains libref longer than 8 characters.;
    %end;
    %else 
    %do;
      %if (%sysfunc(libref(&_cstLibname))) %then 
      %do;
        %let _cst_rc=1;
        %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The libref parameter in _cstDSName (&_cstLibname) is not assigned.;
      %end;
      %else
      %do;
        %if %kindex(%upcase(&_cstDSName),_ALL_)=0 %then 
        %do;
          %if %sysfunc(exist(&_cstDSName))=0 %then 
          %do;
            %let _cst_rc=1;
            %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The input data set (&_cstDSName) does not exist.;
          %end;
        %end;
      %end;
      %let _cstLibPathIn=%sysfunc(pathname(&_cstLibname));
    %end;
  %end;


  %*************************************************************;
  %*  If _cstDSName = _ALL_ then _cstColumnName must be blank  *;
  %*************************************************************;
  %if %kindex(%upcase(&_cstDSName),_ALL_)>0 %then 
  %do;
    %if %length(&_cstColumnName)>0 %then
    %do;
      %let _cst_rc=1;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: _cstColumnName parameter must be blank if _cstDSName parameter contains _ALL_ (or vice versa).;
    %end;
  %end;
  
  %***********************************************;
  %*  Check that _cstGeneratedCodeFile is valid  *;
  %***********************************************;
  %if %length(&_cstGeneratedCodeFile)>0 %then
  %do;
    data _null_;
      file "&_cstGeneratedCodeFile";
    run;
    %if %eval(&syserr) gt 0 %then 
    %do;
      %let _cst_rc=1;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: The generated code parameter(_cstGeneratedCodeFile = &_cstGeneratedCodeFile) is incorrect. Check that the directory exists.;
    %end;
  %end;
  
  %***************************************************;
  %*  If provided check that _cstExternalFmt exists  *;
  %***************************************************;
  %if %length(&_cstExternalFmt) > 0 %then
  %do;
    proc sql noprint;
      select count(*) into :_cstFmtExists
      from dictionary.formats
      where upcase(fmtname)=upcase("&_cstExternalFmt");
    quit;
    %if &_cstFmtExists = 0 %then
    %do;
      %let _cst_rc=1;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: External format [&_cstExternalFmt] does not exist.;
    %end;
  %end;
  
  %***************************************************************;
  %*  If _cstFindFix=FIX then _cstWriteToLib library must exist  *;
  %*  and _cstWriteToLib must be <= 8 characters                 *;
  %***************************************************************;
  %if %length(&_cstWriteToLib) gt 8 %then
  %do;
    %let _cst_rc=1;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: _cstWriteToLib output libname (%upcase(&_cstWriteToLib)) is longer than 8 characters.;
  %end;
  %else 
  %do;
    %if %upcase(&_cstFindFix)=FIX and %sysfunc(libref(&_cstWriteToLib)) %then
    %do;
      %let _cst_rc=1;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(ERR)OR: _cstFindFix = FIX but _cstWriteToLib output libname (&_cstWriteToLib) is not assigned.;
    %end;
  %end;
  
  %if %eval(&_cst_rc)=1 %then %goto EXIT_MACRO;

  %************************************;
  %* Initialize local macro variables *;
  %************************************;
  %let _cstDSList=;
  %let _cstDSListCnt=1;
  %let _cstRecCnt=0;
  %let _cstThisMacroRC=0;
  %let _cstVarList=;
  %let _cstVarList2=;
  %let _cstVarListCnt=0;
  %let _cstDSNameTmp=;
  %let _cstRandom=;
  %let _cstDSFlg=0;
  %let _cstErrCnt=0;

  %***************************************;
  %*  Generate temporary data set names  *;
  %***************************************;
  %cstutil_getRandomNumber(_cstVarname=_cstRandom);
  %let _csttemp=_cst&_cstRandom;
  %let _cstFixSetup=_fix&_cstRandom;

  %**************************************;
  %* If external format exists use it,  *;
  %* otherwise create temporary format. *;
  %**************************************;
  %if %eval(&_cstFmtExists) %then 
  %do;
    %let _cstBTYPE=&_cstExternalFmt;
  %end;
  %else
  %do;
    %*********************************************************************************************;
    %* Process to do the actual remapping of extended ASCII bytes to acceptable bytes.           *;
    %* The methodology in the value statement below is old=new (ie extended ASCII=remapped ASCII *;
    %* This section may require modification by the user. The mapping below is supplied from SAS *;
    %* and represents SAS' interpretation of the extended ASCII characters.                      *;
    %* 32= blank  34= "  39= '  45= -  60= <  62= >                                              *;
    %*********************************************************************************************;
 
    %let _cstBTYPE=bt&_cstRandom.F;
    %let _cstExtFmtOtherValue=?;
    
    proc format library=work.formats;
      value &_cstBTYPE
        9=32
       10=32
       19=45
       20=45
       24=39
       25=39
       28=34
       29=34
      139=60
      145=39
      146=39
      147=34
      148=34
      150=45
      151=45
      155=62
      other=&_cstExtFmtOtherValue;
    run;
  %end;

  %**************************;
  %* Scan a specific column *;
  %**************************;
  %if %length(&_cstColumnName)>0 %then
  %do;
  
    %let _cstColCnt=%sysfunc(countw(&_cstColumnName));
    %let _cstRecCnt=%cstutilnobs(_cstDataSetName=&_cstDSName);
    %if %upcase(&_cstRetainOutputDS)=N %then %let _cstDSFlg=1;
    
    %if %eval(&_cstRecCnt) > 0 %then
    %do;
      %do _cnt_ = 1 %to &_cstColCnt;

        %let _cstColName=%scan(&_cstColumnName,&_cnt_,%str(' '));

        %put >>>>>;
        %put >>>>> Starting test for: &_cstDSName..&_cstColName;
        %put >>>>>;
      
        %if %eval(%cstutilgetattribute(_cstDataSetName=&_cstDSName,_cstVarName=&_cstColName,_cstAttribute=VARNUM)) %then
        %do;
 
          data work.&_csttemp (keep=_cstDS _cstColumn _cstRecCnt _cstValue _cstRemapValue _cstNote _cstRemapNote _cstPath _cstLib _cstPathOut _cstLibOut);
            set &_cstDSName end=last;
            attrib _cstDS          format=$32.     label='Data set scanned'
                   _cstColumn      format=$32.     label='Column scanned'
                   _cstRecCnt      format=8.       label='Record/Row number'
                   _cstValue       format=8.       label='Extended ASCII value'
                   _cstThisMacroRC format=8.  
                   _cstRemapValue  format=$10.     label='ASCII remap value'
                   _cstNote        format=$80.     label='Note'
                   _cstRemapNote   format=$80.     label='Remap note'
                   _cstLib         format=$8.      label='Input Libname name'
                   _cstPath        format=$2048.   label='Input Libname path'
                   _cstLibOut      format=$8.      label='Output Libname name'
                   _cstPathOut     format=$2048.   label='Output Libname path';
               
            retain _cstDS _cstColumn _cstThisMacroRC;

            if _n_=1 then 
            do;
              _cstDS="&_cstDSName";
              _cstColumn="&_cstColName";
              _cstThisMacroRC=0;
            end;
        
            _cstPath="&_cstLibPathIn";
            _cstLib="&_cstLibname";
            
            %if %upcase(&_cstWriteToLib) ne WORK %then
            %do;
              _cstPathOut=pathname("&_cstWriteToLib");
              _cstLibOut="&_cstWriteToLib";
            %end;
            %else 
            %do;
              _cstPathOut="";
              _cstLibOut="&_cstWriteToLib";
            %end;
              
            %*******************************************************************;
            %* Valid ASCII values are bytes 32 through 127 and 160 through 255 *;
            %*******************************************************************;
            do i=0 to 31,128 to 159;
              xx=indexc(&_cstColName,byte(i));
              if find(&_cstColName,byte(i)) then 
              do;
                _cstValue=i;
                _cstRemapValue=put(i,&_cstBTYPE..);
                if _cstRemapValue="&_cstExtFmtOtherValue" then _cstThisMacroRC=1;
                _cstRecCnt=_n_;
                _cstNote=catx(' ','Invalid character for record',put(_n_,8.),'@ column',put(xx,8.));
                _cstRemapNote=catx(' ','Current extended ASCII value is',i,'Replacement ASCII value is',_cstRemapValue);
                output;
              end;
            end;
            %if &_cstThisMacroRc ne 1 %then
            %do;
              if last then call symputx('_cstThisMacroRC',_cstThisMacroRC);
            %end;
          run;

          %*******************************************************;
          %* Create data set specified in _cstOutputDS parameter *;
          %*******************************************************;
          %if %eval(&_cnt_)=1 and %eval(&_cstDSFlg)=1 %then
          %do;
            data &_cstOutputDS;
              set work.&_csttemp;
            run;
          %end;
          %else 
          %do;
            proc append base=&_cstOutputDS data=work.&_csttemp;
            run;
          %end;            
        %end;
        %else
        %do;
          %put >>>>> Column: &_cstColName does not exist.;
          %let _cstErrCnt=%eval(&_cstErrCnt+1);
          %if %eval(&_cstErrCnt)=%eval(&_cstColCnt) %then 
          %do;
            %let _cstErrCnt=-1;
            %goto CLEANUP;
          %end;
        %end;
      %end;
    %end;
    %else 
    %do;
      %put >>>>> Data set is empty and will not be processed.; 
    %end;
  %end;
  
  %***********************************************;
  %* Scan all (character) columns in a data set  *;
  %***********************************************;
  %else
  %do;
    %let _cstDomainOnly=%scan(&_cstDSName,2,.);
    %if %upcase(&_cstRetainOutputDS)=N %then %let _cstDSFlg=1;
    
    %*******************************************************************;
    %* Allow and process specification of entire libraries using _all_ *;
    %*******************************************************************;
    %if %sysfunc(index(%str(%upcase(&_cstDomainOnly)),%str(_ALL_)))>0 %then
    %do;
      proc sql noprint;
        select catx('.',strip(libname),strip(memname)) into :_cstDSList separated by ' '
        from dictionary.tables
        where libname=upcase(scan("&_cstDSName",1,'.'));
        select count(*) into :_cstDSListCnt
        from dictionary.tables
        where libname=upcase(scan("&_cstDSName",1,'.'));
      quit;
    %end;
    %else 
    %do;
      %let _cstDSList=&_cstDSName;
      %let _cstDSListCnt=1;
    %end;

    %put _cstDSList=&_cstDSList; 

    %do _cnt_=1 %to &_cstDSListCnt;
      %if %length(&_cstDSList)>0 %then %let _cstDSNameTmp=%scan(&_cstDSList,&_cnt_,' ');
      
      %put >>>>>;
      %put >>>>> Starting test for: &_cstDSNameTmp;
      %put >>>>>;
 
      %let _cstRecCnt=%cstutilnobs(_cstDataSetName=&_cstDSNameTmp);
      %if %eval(&_cstRecCnt) > 0 %then
      %do;
  
        proc sql noprint;
          select cats("'",name,"'") into :_cstVarList separated by ' '
          from dictionary.columns
          where libname=upcase(scan("&_cstDSNameTmp",1,'.')) and
                memname=upcase(scan("&_cstDSNameTmp",2,'.')) and
                type='char';
          select name into :_cstVarList2 separated by ' '
          from dictionary.columns
          where libname=upcase(scan("&_cstDSNameTmp",1,'.')) and
                memname=upcase(scan("&_cstDSNameTmp",2,'.')) and
                type='char';
          select count(*) into :_cstVarListCnt
          from dictionary.columns
          where libname=upcase(scan("&_cstDSNameTmp",1,'.')) and
                memname=upcase(scan("&_cstDSNameTmp",2,'.')) and
                type='char';
        quit;
  
        %put >>>>> Variable List 1=&_cstVarList; 
        %put >>>>> Variable List 2=&_cstVarList2; 
        %put >>>>> Variable Count=&_cstVarListCnt; 
        %put >>>>>;

        %if %eval(&_cstVarListCnt) > 0 %then
        %do;
          data work.&_csttemp (keep=_cstDS _cstColumn _cstRecCnt _cstValue _cstRemapValue _cstNote _cstRemapNote _cstLib _cstPath _cstLibOut _cstPathOut);
            set &_cstDSNameTmp end=last;
            attrib _cstDS          format=$32.     label='Data set scanned'
                   _cstColumn      format=$32.     label='Column scanned'
                   _cstRecCnt      format=8.       label='Record/Row number'
                   _cstValue       format=8.       label='Extended ASCII value'
                   _cstThisMacroRC format=8.  
                   _cstRemapValue  format=$10.     label='ASCII remap value'
                   _cstNote        format=$80.     label='Note'
                   _cstRemapNote   format=$80.     label='Remap note'
                   _cstLib         format=$8.      label='Libname name'
                   _cstPath        format=$2048.   label='Libname path'
                   _cstLibOut      format=$8.      label='Output Libname name'
                   _cstPathOut     format=$2048.   label='Output Libname path';
                   
            retain _cstDS _cstColumn _cstThisMacroRC;
        
            _cstPath="&_cstLibPathIn";
            _cstLib="&_cstLibname";

            %if %upcase(&_cstWriteToLib) ne WORK %then
            %do;
              _cstPathOut=pathname("&_cstWriteToLib");
              _cstLibOut="&_cstWriteToLib";
            %end;
            %else 
            %do;
              _cstPathOut="";
              _cstLibOut="&_cstWriteToLib";
            %end;
      
            if _n_=1 then 
            do;
              _cstDS="&_cstDSNameTmp";
              _cstThisMacroRC=0;
            end;        

            array var{&_cstVarListCnt} $32 _temporary_ (&_cstVarList);
            array var2{&_cstVarListCnt} &_cstVarList2;
          
            do i=1 to dim(var);
              _cstColumn=var[i];
              %*******************************************************************;
              %* Valid ASCII values are bytes 32 through 127 and 160 through 255 *;
              %*******************************************************************;
              do j=0 to 31,128 to 159;
                xx=indexc(var2[i],byte(j));
                if find(var2[i],byte(j)) then 
                do;
                  _cstValue=j;
                  _cstRemapValue=put(j,&_cstBTYPE..);
                  if _cstRemapValue="&_cstExtFmtOtherValue" then _cstThisMacroRC=1;
                  _cstRecCnt=_n_;
                  _cstNote=catx(' ','Invalid character for record',put(_n_,8.),'@ column',put(xx,8.));
                  _cstRemapNote=catx(' ','Current extended ASCII value is',j,'Replacement ASCII value is',_cstRemapValue);
                  output;
                end;
              end;
            end;
            %if &_cstThisMacroRc ne 1 %then
            %do;
              if last then call symputx('_cstThisMacroRC',_cstThisMacroRC);
            %end;
          run;
        
          %*******************************************************;
          %* Create data set specified in _cstOutputDS parameter *;
          %*******************************************************;

          %if &_cstDSFlg=1 %then 
          %do;
            data &_cstOutputDS;
              set work.&_csttemp;
            run;
            %let _cstDSFlg=0;
          %end;
          %else
          %do;
            proc append base=&_cstOutputDS data=work.&_csttemp;
            run;
          %end;            
        %end;
      %end;
      %else
      %do;
        %put >>>>> Data set is empty and will not be processed.; 
      %end;      
    %end;
  %end;
  
  %***************************************************************************************************;
  %* The following section generates the remapping code if extended ASCII characters are identified. *; 
  %***************************************************************************************************;

  %let _cstRecCnt=%cstutilnobs(_cstDataSetName=&_cstOutputDS);

  %if %eval(&_cstRecCnt) > 0 %then
  %do;

    proc sort data=&_cstOutputDS out=work.&_cstFixSetup;
      by _cstLib _cstDS _cstRecCnt _cstColumn;
    run;

    filename _cstCode "&_cstGeneratedCodeFile";
  
    data _null_;
    
      set work.&_cstFixSetup end=last;
      by _cstLib _cstDS _cstRecCnt _cstColumn;
      attrib tempvar tempvar2 format=$200.;
      
      file _cstCode;

      if _n_=1 then 
      do;
        put @1 '%macro _cstFixASCII;';
      end;
      
      if first._cstLib then 
      do;
        put @1 '********************************************;';
        put @1 '**********  Initialize libraries  **********;';
        put @1 '********************************************;';
        put @1;
        tempvar=cat('libname ',kstrip(_cstLib),' "',kstrip(_cstPath),'";');
        put @1 tempvar;
        %if %upcase(&_cstWriteToLib) ne WORK %then
        %do;
          tempvar=cat('libname ',kstrip(_cstLibOut),' "',kstrip(_cstPathOut),'";');
          put @1 tempvar;
        %end;
        put @1; 
      end;         
    
      if first._cstDS then
      do;
        %************************************************************************;  
        %* Write to a work file to avoid directly overwriting the existing file *;
        %* Confirm the update prior to a copy to the production location.       *;
        %************************************************************************; 
        put @1 '***********************************************************************************;';
        put @1 '**********  Updating data set' @31 _cstDS @74 '**********;';  
        put @1 '***********************************************************************************;';
        put @1 '%let _cstDSLabel=%cstutilgetattribute(_cstDataSetName=' _cstDS ', _cstAttribute=LABEL);'; 
        put @1 '%let _cstDSSortVars=%cstutilgetattribute(_cstDataSetName=' _cstDS ', _cstAttribute=SORTEDBY);'; 
        tempvar=catt("data &_cstWriteToLib..",scan(kstrip(_cstDS),2,'.'),' %if %length(&_cstDSLabel)>0 %then (label="&_cstDSLabel"); %else;;');
        put;
        put @1;
        put @1 tempvar;
        put @3  'set' @7 _cstDS ';';
      end;
     
      if first._cstRecCnt then
      do;
        tempvar=catx(' ','if _n_=',_cstRecCnt,'then do;');
        put @5 tempvar;
      end;
      tempvar=cats(_cstColumn,'=tranwrd(',_cstColumn,',byte(',_cstValue,'),byte(',put(_cstValue,&_cstBTYPE..),'));');
      put @7 tempvar;
    
      if last._cstRecCnt then
        put @5 'end;';

      if last._cstDS then
      do;
        tempvar2=cats("proc sort data=&_cstWriteToLib..",scan(kstrip(_cstDS),2,'.'),';');
        put @1 'run;';
        put;
        put @1 '%if %length(&_cstDSSortVars)>0 %then';
        put @1 '%do;';
        put @3 tempvar2;
        put @5 'by &_cstDSSortVars;';
        put @3 'run;';
        put @1 '%end;';
        put;
      end;

      if last then 
      do;
        put @1 '%mend;';
        put;
        put @1 '%_cstFixASCII;';
      end;
    run;
  
    %if %eval(&_cstThisMacroRc) = 1 %then
    %do;
      %put *********************************************************************************************************************;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(WAR)NING: Unresolved extended ASCII characters are present; 
      %put        in the data. Refer to &_cstOutputDS for more information.;
      %put [CSTLOG%str(MESSAGE).&sysmacroname] %str(WAR)NING: These unresolved values need to be updated in the ;
      %if %eval(&_cstFmtExists) %then
      %do;
        %put        external format [&_cstExternalFmt] provided to this macro.;
      %end;
      %else
      %do;
        %put        PROC FORMAT statement of this macro.;
      %end;
      %put *********************************************************************************************************************;
    %end;
    %else 
    %do;
      %if %upcase(&_cstFindFix)=FIX %then
      %do;
        %include _cstCode;
      %end;
    %end;
  %end;
  %else
  %do;
    %put ***************************************************************************************************************************;
    %put [CSTLOG%str(MESSAGE).&sysmacroname] NOTE: No extended ASCII characters were found in the data specified for this macro.;
    %put ***************************************************************************************************************************;
    %goto CLEANUP;
  %end;

  %************;
  %* Clean up *;
  %************;
  
  %CLEANUP:

  %if %eval(&_cstErrCnt) ne -1 %then
  %do;
    %cstutil_deleteDataSet(_cstDataSetName=&_csttemp);

    %if %eval(&_cstRecCnt) %then
    %do;
      %cstutil_deleteDataSet(_cstDataSetName=&_cstFixSetup);
    %end;
  %end;
  
  %if %eval(&_cstFmtExists)=0 %then
  %do;
    proc catalog cat=work.formats;
       delete &_cstBTYPE..format;
    quit;
  %end;
  
  %**********;
  %*  Exit  *;
  %**********;
 
  %EXIT_MACRO:
  
  %if %eval(&_cst_rc)=1 %then
  %do;
    %let _cst_rcmsg=%str(ERR)OR detected - please review &sysmacroname log for more information;
  %end;
%mend;