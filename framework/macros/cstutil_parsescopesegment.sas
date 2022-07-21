%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_parsescopesegment                                                      *;
%*                                                                                *;
%* Parses validation check metadata columns to handle extended values.            *;
%*                                                                                *;
%* This macro parses validation check metadata columns tableScope and columnScope *;
%* to handle extended values, such as <libref>.<table>.<column>. It also handles  *;
%* wildcarding to build a logical SAS code string to subset _cstTableMetadata and *;
%* _cstColumnMetadata. This macro is currently called only by the                 *;
%* cstutil_parsecolumnscope() and cstutil_parsetablescope() macros.               *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstParseLengthOverride Validation: Override requirement limiting      *;
%*            *scope segment length                                               *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstResultSeq Results: Unique invocation of check                      *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstTString Constructed string to subset column and table metadata     *;
%*                                                                                *;
%* @param _cstPart - required - The part of the tableScope or columnScope string  *;
%*            to interpret. The expected value is either the SAS libref, the      *;
%*            table name, or the column name, often passed as a macro variable.   *;
%*            NOTE: tableScope and columnScope often include wildcard characters. *;
%* @param _cstVarName - required - The column name in either _csttablemetadata or *;
%*            _cstcolumnmetadata.  Typical values: sasref, a table, or column.    *;
%* @param _cstMessageID - optional - The SAS Clinical Standards Toolkit message ID*;
%*            to report a string that cannot be interpretted (such as a bad SAS   *;
%*            name or a wildcard in the middle of the string).                    *;
%*            Default: CST0004                                                    *;
%* @param _cstLengthOverride - optional - Ignore the length of the _cstVarName    *;
%*            when building the WHERE clause against the work._csttablemetadata   *;
%*            data set. (This parameter is used only by cstutil_parsetablescope). *;
%*            This enables the interpretation of a tableScope value such as       *;
%*            **DATA to mean ANY table ending in DATA, regardless of the length   *;
%*            of the table name.                                                  *;
%*            Values:  Y | N                                                      *;
%*            Default: N                                                          *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_parsescopesegment(
    _cstPart=,
    _cstVarName=,
    _cstMessageID=CST0004,
    _cstLengthOverride=N
    ) / des ='CST: Parse tableScope or columnScope segment';

  %cstutil_setcstgroot;

  %local
      _cstPoundCnt
      _cstPrefix
      _cstPrefix2
      _cstStartsWith
      _cstSuffix
      _cstSuffix2
  ;

  %let _cstStartsWith=^;

  %if &_cstDebug %then
  %do;
    %put cstutil_parsescopesegment >>>;
    %put _cstPart=%str(&_cstPart);
    %put _cstVarName=&_cstVarName;
  %end;

  %if "&_cstPart"="**" or %upcase("&_cstPart")="_ALL_" %then
  %do;
    %let _cstTString=%str(&_cstVarName ne '');
  %end;
  %else %if %upcase("&_cstPart")="_NA_" %then
  %do;
    %let _cstTString=%str();
  %end;

  %else %if %sysfunc(index(%str(&_cstPart),%str(##)))>0 %then
  %do;
    %let _cstPrefix=%sysfunc(scan(&_cstPart,1,'##'));
    %if %sysfunc(index(%str(&_cstPrefix),%str(*)))>0 %then
    %do;
      %if %sysfunc(index(%str(&_cstPrefix),%str(*)))=1 %then
      %do;
        %let _cstStartsWith=;
        %let _cstPrefix=%sysfunc(compress(%str(&_cstPrefix),%str(*)));
      %end;
      %else
        %let _cstPrefix=;
    %end;
    %let _cstSuffix=%sysfunc(scan(&_cstPart,2,'##'));
    %let _cstPoundCnt = %SYSFUNC(countc(&_cstPart,'#'));
    
    %if &_cstPoundCnt>2 %then
    %do;
      %let _cstSuffix2=%sysfunc(substr(&_cstPart,%sysfunc(index(&_cstPart,##))+2));
      %let _cstPrefix2=%sysfunc(scan(&_cstSuffix2,1,'#'));
      %let _cstSuffix2=%sysfunc(scan(&_cstSuffix2,2,'#'));
      %if &_cstLengthOverride=Y %then
      %do;
        %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstPrefix2(\d)&_cstSuffix2\b/i"), &_cstVarName));
      %end;
      %else
      %do;
        %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstPrefix2(\d)&_cstSuffix2\b/i"), &_cstVarName) and length(&_cstVarName) = length("&_cstPart"));
      %end;
      %if %symexist(_cstParseLengthOverride) %then
      %do;
        %if &_cstParseLengthOverride %then
          %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstPrefix2(\d)&_cstSuffix2\b/i"), &_cstVarName));
      %end;
    %end;
    %else
    %do;
      %if &_cstLengthOverride=Y %then
      %do;
        %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstSuffix\b/i"), &_cstVarName));
      %end;
      %else
      %do;
        %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstSuffix\b/i"), &_cstVarName) and length(&_cstVarName) = length("&_cstPart"));
      %end;
      %if %symexist(_cstParseLengthOverride) %then
      %do;
        %if &_cstParseLengthOverride %then
          %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d\d)&_cstSuffix\b/i"), &_cstVarName));
      %end;
    %end;
  %end;
  %else %if %sysfunc(index(%str(&_cstPart),%str(#)))>0 %then
  %do;
    %let _cstPrefix=%sysfunc(scan(&_cstPart,1,'#'));
    %if %sysfunc(index(%str(&_cstPrefix),%str(*)))>0 %then
    %do;
      %if %sysfunc(index(%str(&_cstPrefix),%str(*)))=1 %then
      %do;
        %let _cstStartsWith=;
        %let _cstPrefix=%sysfunc(compress(%str(&_cstPrefix),%str(*)));
      %end;
      %else
        %let _cstPrefix=;
    %end;
    %let _cstSuffix=%sysfunc(scan(&_cstPart,2,'#'));
    %if &_cstLengthOverride=Y %then
    %do;
      %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d)&_cstSuffix\b/i"), &_cstVarName));
    %end;
    %else
    %do;
      %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d)&_cstSuffix\b/i"), &_cstVarName) and length(&_cstVarName) = length("&_cstPart"));
    %end;
    %if %symexist(_cstParseLengthOverride) %then
    %do;
      %if &_cstParseLengthOverride %then
        %let _cstTString=%str(prxmatch(prxparse("/&_cstStartsWith.&_cstPrefix(\d)&_cstSuffix\b/i"), &_cstVarName));
    %end;
  %end;

  %else %if %sysfunc(indexc(%str(&_cstPart),%str(**)))>0 %then
  %do;
    %if %sysfunc(indexc(%str(&_cstPart),%str(**)))=1 %then
    %do;
      %if &_cstLengthOverride=Y %then
      %do;
        %let _cstTString=%str(strip(reverse(upcase(&_cstVarName))) =: upcase(reverse(compress("&_cstPart",'*'))));
      %end;
      %else
      %do;
        %let _cstTString=%str(strip(reverse(upcase(&_cstVarName))) =: upcase(reverse(compress("&_cstPart",'*'))) and length(&_cstVarName) = length("&_cstPart"));
      %end;
      %if %symexist(_cstParseLengthOverride) %then
      %do;
        %if &_cstParseLengthOverride %then
          %let _cstTString=%str(strip(reverse(upcase(&_cstVarName))) =: upcase(reverse(compress("&_cstPart",'*'))));
      %end;
    %end;
    %else %if %sysfunc(indexc(%sysfunc(reverse(%str(&_cstPart))),%str(**)))=1 %then
    %do;
      %let _cstTString=%str(upcase(&_cstVarName) =: upcase(compress("&_cstPart",'*')));
    %end;
    %else %if %sysfunc(indexc(%str(&_cstPart),%str(**)))>0 %then
    %do;
      %let _cstPrefix=%sysfunc(scan(&_cstPart,1,'**'));
      %let _cstSuffix=%sysfunc(scan(&_cstPart,2,'**'));
      %if &_cstLengthOverride=Y %then
      %do;
        %let _cstTString=%str(strip(upcase(&_cstVarName)) =: upcase("&_cstPrefix") and
                              strip(reverse(upcase(&_cstVarName))) =: upcase(reverse("&_cstSuffix")));
      %end;
      %else
      %do;
        %let _cstTString=%str(strip(upcase(&_cstVarName)) =: upcase("&_cstPrefix") and
                              strip(reverse(upcase(&_cstVarName))) =: upcase(reverse("&_cstSuffix")) and
                              length(&_cstVarName) = length("&_cstPart"));
      %end;
      %if %symexist(_cstParseLengthOverride) %then
      %do;
        %if &_cstParseLengthOverride %then
          %let _cstTString=%str(strip(upcase(&_cstVarName)) =: upcase("&_cstPrefix") and
                                strip(reverse(upcase(&_cstVarName))) =: upcase(reverse("&_cstSuffix")));
      %end;
    %end;

  %end;

  %else %if %sysfunc(nvalid(%str(&_cstPart)))=1 %then
  %do;
    %let _cstTString=%str(upcase(&_cstVarName) = upcase("&_cstPart"));
  %end;
  %else
  %do;
    %* Unrecognized value, such as bad SAS name or wildcarding in middle of string  *;
    %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
    %let _cst_rc=0;
    %cstutil_writeresult(
                  _cstResultID=&_cstMessageID
                  ,_cstValCheckID=&_cstMessageID
                  ,_cstResultParm1=
                  ,_cstResultParm2=
                  ,_cstResultSeqParm=&_cstResultSeq
                  ,_cstSeqNoParm=&_cstSeqCnt
                  ,_cstSrcDataParm=&sysmacroname
                  ,_cstResultFlagParm=-1
                  ,_cstRCParm=&_cst_rc
                  ,_cstActualParm=&_cstPart
                  ,_cstKeyValuesParm=
                  ,_cstResultsDSParm=&_cstResultsDS
                  );
  %end;


  %if &_cstDebug %then
  %do;
    %put <<< cstutil_parsescopesegment;
    %put _cstTString=&_cstTString;
  %end;

%mend cstutil_parsescopesegment;

