%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_getsubjectcount                                                        *;
%*                                                                                *;
%* Populates _cstMetricsCntNumSubj with the count of the number of subjects.      *;
%*                                                                                *;
%* This macro populates the metrics global macro variable _cstMetricsCntNumSubj   *;
%* with the count of the number of subjects. This is a part of metrics processing.*;
%*                                                                                *;
%* @macvar _cstSubjectColumns Standard-specific set of columns that identify a    *;
%*             subject                                                            *;
%* @macvar _cstMetricsCntNumSubj Validation metrics: number of subjects evaluated *;
%*                                                                                *;
%* @param _cstDS - required - The source data set that contains the subject data  *;
%*            of interest.                                                        *;
%* @param _cstSubID - optional - The set of subject identifiers appropriate for   *;
%*            the _cstDS data set.                                                *;
%*             Default: &_cstSubjectColumns (global macro variable)               *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_getsubjectcount(
    _cstDS=,
    _cstSubID=&_cstSubjectColumns
    ) / des="CST: Calculate count of subjects";

  %cstutil_setcstgroot;

  %local
      dsid
      _cstKeysOK
      _cstStr
      _cstsqlStr
      _cstStrCnt
      _sk
  ;

  %let _cstMetricsCntNumSubj=0;

  %if %sysfunc(exist(&_cstDS)) %then
  %do;
    %if %symexist(_cstSubID) %then
    %do;
      %if %length(&_cstSubID) %then
      %do;
        %*****************************************************;
        %* Anticipated _cstSubID examples:                   *;
        %*     STUDYID USUBJID                               *;
        %*     STUDYID  USUBJID                              *;
        %*     STUDYID,USUBJID                               *;
        %*     STUDYID, USUBJID                              *;
        %*     STUDYID,  USUBJID                             *;
        %*                                                   *;
        %* &_cstStr is set to STUDYID USUBJID                *;
        %* &_cstsqlStr is set to STUDYID||USUBJID            *;
        %*****************************************************;

        data _null_;
          length _cstStr _cstsqlStr $200;
          _cstStr = symget('_cstSubID');
          _cstStr=tranwrd(trim(_cstStr),',',' ');
          _cstStr=compbl(_cstStr);
          _cstsqlStr=tranwrd(trim(_cstStr),' ','||');
          call symputx('_cstStr',_cstStr);
          call symputx('_cstsqlStr',_cstsqlStr);
          call symputx('_cstStrCnt',countw(_cstStr,' '));
        run;

        %* Determine if these keys exist in the specified data set *;
        %let dsid = %sysfunc(open(&_cstDS));
        %let _cstKeysOK=1;
        %do _sk = 1 %to &_cstStrCnt;
          %if ^%sysfunc(varnum(&dsid,%SYSFUNC(scan(&_cstStr,&_sk,' ')))) %then
            %let _cstKeysOK=0;
        %end;
        %if &_cstKeysOK=1 %then
        %do;
          proc sql noprint;
            select count(distinct &_cstsqlStr) into :_cstMetricsCntNumSubj from &_cstDS;
          quit;
        %end;
        %* We do not report key inconsistencies for the specified _cstDS *;
        %else
          %let _cstMetricsCntNumSubj=0;
        %let dsid = %sysfunc(close(&dsid));

      %end;
    %end;
  %end;

%mend cstutil_getsubjectcount;


