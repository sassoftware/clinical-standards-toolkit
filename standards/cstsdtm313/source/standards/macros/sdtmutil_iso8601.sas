%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* sdtmutil_iso8601                                                               *;
%*                                                                                *;
%* Verifies that a string is in a valid ISO 8601 format.                          *;
%*                                                                                *;
%* The verification includes tests that are specific to SDTM and clinical trials  *;
%* data in general.                                                               *;
%*                                                                                *;
%* This macro must be called from within a DATA step. It can be called more than  *;
%* once within a single DATA step.                                                *;
%*                                                                                *;
%* Returns the following as SAS data set variables. You are expected to copy any  *;
%* values you want to keep. All variables are automatically cleared at the end of *;
%* the current data set.                                                          *;
%* These are the data set variables that are returned:                            *;
%*   1. _cstISOisValid - numeric                                                  *;
%*        The binary flag that denotes whether or not the ISO string is a valid   *;
%*        ISO 8601 string.                                                        *;
%*          0=String is invalid                                                   *;
%*          1=String is valid.                                                    *;
%*   2. _cstISOrc - numeric                                                       *;
%*        The return code.  A value of 0 indicates that no problems were found.   *;
%*        Any other value is a coding error number.                               *;
%*   3. _cstISOmsg - string                                                       *;
%*        The meesage that describes the validity of the input string.            *;
%*   4. _cstISOinfo - string                                                      *;
%*        An informational message that specifies additional details about the    *;
%*        string.                                                                 *;
%*   5. _cstISOtype - string                                                      *;
%*        The type of ISO 8601 string that _cstString contains.                   *;
%*                                                                                *;
%* @macvar _cstMaxISOStringLength Maximun length of the ISO String (64)           *;
%* @macvar _cstISOParseCharList String used to parse the value of _csString for   *;
%*             numeric parts                                                      *;
%*                                                                                *;
%* @param _cstString - required - The name of the SAS data set variable to check. *;
%*                                                                                *;
%* @since 1.3                                                                     *;
%* @exposure internal                                                             *;

%macro sdtmutil_iso8601(
    _cstString=
    ) / des='CST: Verify string is a valid ISO-8601 value';

  %if (not %symexist(_cstMaxISOStringLength)) %then %do;
    %global _cstMaxISOStringLength;
    %* Longest valid format is YYYY-MM-DDThh:mm:ss.fffff+hh:mm/YYYY-MM-DDThh:mm:ss.fffff+hh:mm *;
    %let _cstMaxISOStringLength=64;
  %end;

  %if (not %symexist(_cstISOParseCharList)) %then %do;
    %global _cstISOParseCharList;
    %* String used to parse the string for numeric parts *;
    %let _cstISOParseCharList=%str(+-Tt:xXPYMDHSWRpymdhswr/);
  %end;

  %if %length(&_cstString.)=0 %then
  %do;
    * There was a problem calling the macro, so cannot go on. *;
    _cstISOisValid=0;
    _cstISOrc=002;
    _cstISOtype="";
    _cstISOmsg=cat("[", put(_cstISOrc, z3.), "] Illegal call to &sysmacroname.");
    _cstISOinfo="Macro input parameter (cstString) is empty";
    putlog "ERROR: " _cstISOmsg;
    %return;
  %end;

  if _n_=1 then
  do;
    attrib _cstISOisValid           length=8    label="CST: &sysmacroname. Is the value a valid ISO8601 string? (0=Not Valid, 1=Valid)";
    attrib _cstISOrc                length=8    label="CST: &sysmacroname. Return Code (0=No problems found)";
    attrib _cstISOmsg               length=$200 label="CST: &sysmacroname. Return Message";
    attrib _cstISOinfo              length=$200 label="CST: &sysmacroname. Additional information about data.";
    attrib _cstISOtype              length=$40  label="CST: &sysmacroname. Return Type of ISO-8601 String.";

    * Used internally by ISO 8601 macros. *;
    attrib _cstISOString           length=$&_cstMaxISOStringLength. label="CST: &sysmacroname. Internal ISO 8601 String.";
    attrib _cstISOEntityExtended   length=$&_cstMaxISOStringLength. label="CST: &sysmacroname. Internal SAS ISO 8601 Entity ($N8601E.)";
    attrib _cstISOEntityBasic      length=$&_cstMaxISOStringLength. label="CST: &sysmacroname. Internal SAS ISO 8601 Entity ($N8601B.)";

    attrib _cstISOTemp1            length=$&_cstMaxISOStringLength. label="CST: Temporary String";
    attrib _cstISOTemp2            length=$&_cstMaxISOStringLength. label="CST: Temporary String";
    attrib _cstISOIter             length=8                         label="CST: Temporary Iterator";

    %if _cstDebug=0 %then
    %do;
      drop _cstISOisValid _cstISOrc _cstISOmsg _cstISOinfo _cstISOtype _cstISOString _cstISOEntityExtended _cstISOEntityBasic _cstISOtemp1 _cstISOIter;
    %end;
  end;

  call missing(_cstISOisValid, _cstISOrc, _cstISOmsg, _cstISOinfo, _cstISOtype, _cstString, _cstISOEntityExtended, _cstISOEntityBasic, _cstISOtemp1, _cstISOIter);

  * Check the value *;
  _cstISOString=&_cstString.;

  _cstISOisValid=0;
  _cstISOrc=000;

  _cstISOString=upcase(ktrim(_cstISOString));

  * Determine the type of string we are dealing with. *;
  if (missing(_cstISOString) or _cstISOString in ('-----T-:-:-', '-----',
                                                  'X-X-XTX:X:X', 'X-X-X', 'XXXX-XX-XXTXX:XX:XX',
                                                  'XXXX-XX-XX', 'XX-XX-XX') ) then
  do;
    _cstISOisValid=1;
    _cstISOrc=000;
    _cstISOtype="empty";
    _cstISOinfo=catx(' ', _cstISOinfo, 'String is empty');
  end;

  else if (kindex(substr(_cstISOString, 1, 2), 'R')) then
  do;
    _cstISOisValid=0;
    _cstISOrc=110;
    _cstISOtype="recurrence";
    _cstISOinfo=catx(' ', _cstISOinfo, 'ISO 8601 recurrence type is not supported.');
  end;

  else if (kindex(substr(_cstISOString, 1, 1), '+')) then
  do;
    _cstISOisValid=0;
    _cstISOrc=111;
    _cstISOtype="extended datetime";
    _cstISOinfo=catx(' ', _cstISOinfo, 'ISO 8601 extended type is not supported.');
    _cstISOinfo=catx(' ', _cstISOinfo, 'String cannot begin with a plus sign.');
  end;

  else if (kindex(kstrip(_cstISOString), ' ')) then
  do;
    _cstISOisValid=0;
    _cstISOrc=112;
    _cstISOtype="invalid";
    _cstISOinfo=catx(' ', _cstISOinfo, 'String cannot contain embedded spaces.');
  end;

  else if (anydigit(_cstISOString)=0) then
  do;
    _cstISOisValid=0;
    _cstISOrc=113;
    _cstISOtype="invalid";
    _cstISOinfo=catx(' ', _cstISOinfo, 'String does not contain any digits.');
  end;

  else if (^missing(kcompress(_cstISOString, "T:,.-+Z/PYMDHMSWR0123456789X"))) then
  do;
    _cstISOisValid=0;
    _cstISOrc=114;
    _cstISOtype="invalid";
    _cstISOinfo=catx(' ', _cstISOinfo, 'String contains one or more invalid characters:',
                     quote(kcompress(ktrim(&_cstString.), "Tt:,.-+Zz/PpYyMmDdHhMmSsWwRr0123456789Xx")));
  end;

  else if (kindex(_cstISOString, '/')) then
  do;
    _cstISOtype="interval";
    _cstISOEntityBasic=input(_cstISOString, ?? $N8601B.);
    _cstISOEntityExtended=input(_cstISOString, ?? $N8601E.);
    if not missing(_cstISOEntityExtended) /* or not missing(_cstISOEntityBasic) */ then
    do;
      _cstISOisValid=1;
      _cstISOrc=000;
      _cstISOinfo=catx(' ', _cstISOinfo, 'OK');
    end;
    else
    do;
      _cstISOisValid=0;
      _cstISOrc=115;
      _cstISOinfo=catx(' ', _cstISOinfo, 'Unable to parse.');
    end;
  end;

  else if (kindex(substr(_cstISOString, 1, 2), 'P')) then
  do;
    _cstISOtype="duration";
    _cstISOEntityBasic=input(_cstISOString, ?? $N8601B.);
    _cstISOEntityExtended=input(_cstISOString, ?? $N8601E.);

    if not missing(_cstISOEntityExtended) or not missing(_cstISOEntityBasic) then
    do;
      * Some additional checks to filter out strings that are valid for SAS informats, but not for SDTM *;
      * Make sure the value extended or PYMDTHMS format (not basic)                                     *;
      if (countc(_cstISOString, 'YMDSHW', 'i')=0)
          & (kindexc(substr(_cstISOString, 2), '-:')=0)
          & (prxmatch(prxparse('/P\d\d\d\d$/'), kstrip(_cstISOString))=0) then
      do;
        _cstISOisValid=0;
        _cstISOrc=116;
        _cstISOinfo=catx(' ', _cstISOinfo, 'Strings must be in delimited (extended) format.');
      end;
      else
      do;
        * If got this far, it must be valid *;
        _cstISOisValid=1;
        _cstISOrc=000;
        _cstISOinfo=catx(' ', _cstISOinfo, 'OK');
      end;
    end;
    else
    do;
      _cstISOisValid=0;
      _cstISOrc=117;
      _cstISOinfo=catx(' ', _cstISOinfo, 'Unable to parse.');
    end;
  end;

  else
  do;
    * Assume datetime or date (CDISC SDTM requires that times have dates, even if missing) *;
    _cstISOType=ifc(kindex(_cstISOString, 'T'), 'datetime', 'date');
    * Let the SAS ISO 8601 informats handle the details *;
    _cstISOEntityExtended=input(_cstISOString, ?? $N8601E.);
    if not missing(_cstISOEntityExtended) then
    do;
      * Run additional checks to filter out strings that are valid for SAS informats, but not for SDTM *;
      if (prxmatch(prxparse('/^[\+\-]?(\d{4,4}|\-|[Xx]{1,4})/'), _cstISOString)=0) then
      do;
        _cstISOisValid=0;
        _cstISOrc=118;
        _cstISOinfo=catx(' ', _cstISOinfo, 'Year must be in YYYY format.');
      end;

      else if (_cstISOType='datetime') then
      do;
        if (kindex(_cstISOString, 'T') < 6) then
        do;
          _cstISOisValid=0;
          _cstISOrc=119;
          _cstISOinfo=catx(' ', _cstISOinfo, 'Time must be prefixed by a date, even if values are missing.');
        end;
        else if (countc(substr(_cstISOString, 1, kindex(_cstISOString, 'T')), '-', 'i') < 2) then
        do;
          _cstISOisValid=0;
          _cstISOrc=120;
          _cstISOinfo=catx(' ', _cstISOinfo, 'Time must be prefixed by a fully qualified date, even if values are missing.');
        end;
      end;

      * Are the numeric values the correct length (for date and datetimes, they must be *;
      * two digits, except for year (four digits) and decimal places.                   *;
      _cstISOIter=1;
      _cstISOTemp1=kscan(_cstISOString, _cstISOIter, "&_cstISOParseCharList.");
      do while (not missing(_cstISOTemp1) and _cstISORC=0);
        * Disreguard decimal places, which can be either dot or comma delimited. *;
        _cstISOTemp2=kscan(_cstISOTemp1, 1, ',.');
        if (length(_cstISOTemp2)^=2 and length(_cstISOTemp2)^=4) or not prxmatch(prxparse('/\d\d/'), _cstISOTemp2) then
        do;
          _cstISOisValid=0;
          _cstISORC=121;
          _cstISOinfo=catx(' ', _cstISOinfo, 'Year must have exactly four digits.  All non-year values must be exactly two digits.',
                           '(bad value=' || ktrim(_cstISOTemp2) || ')');
        end;
        _cstISOIter = _cstISOIter + 1;
        _cstISOTemp1=kscan(_cstISOString, _cstISOIter, "&_cstISOParseCharList.");
      end;

      if _cstISORC = 0 then
      do;
        * If got this far, it must be valid *;
        _cstISOisValid=1;
        _cstISOrc=000;
        _cstISOinfo=catx(' ', _cstISOinfo, 'OK');
      end;
    end;
    else
    do;
      _cstISOisValid=0;
      _cstISOrc=101;
      _cstISOinfo=catx(' ', _cstISOinfo, 'Unable to parse.');
    end;
  end;

  *-----------------------------------------------------------------------------------------*;

  * Clean up the returned values *;
  if _cstISOisValid=. then
  do;
            _cstISOisValid=0;
            _cstISOrc=100;
            _cstISOInfo=catx(' ', _cstISOInfo, 'Unknown error');
  end;

  * Assign the return message *;
  if _cstISOisValid=1 then
  do;
            _cstISOmsg='String complies with ISO 8601.';
  end;
  else
  do;
            _cstISOmsg='String does not comply with ISO 8601.';
  end;
  _cstISOMsg = kstrip(_cstISOMsg);
  _cstISOInfo= kstrip(_cstISOINFO);

  call missing(_cstISOEntityExtended, _cstISOEntityBasic, _cstISOtemp1);

%mend sdtmutil_iso8601;