%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_getcstversion                                                          *;
%*                                                                                *;
%* Returns the SAS Clinical Standards Toolkit product version.                    *;
%*                                                                                *;
%* The return value can be a product version, such as 1.2 or 1.4, or null. A null *;
%* value indicates that an error occurred while retrieving the version number.    *;
%* (The log file contains more information.)                                      *;
%*                                                                                *;
%* Use:  %put CST version: %cstutil_getcstversion                                 *;
%*                                                                                *;
%* @since  1.5                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_getcstversion(
    ) / des ='CST: Get product version';

%local _cstGlobalMDLib _cstFolder _cstTable _cstColumn _cstWhere _cstVersion
       _cstFID _cstVpos _cstObs _cstVar _cstRC _cstReturn;

  %let _cstGlobalMDLib=_cst%sysevalf(%sysfunc(ranuni(0))*10000,floor);
  %let _cstFolder=metadata;
  %let _cstTable=Standards;
  %let _cstColumn=productrevision;
  %let _cstWhere=%str(standard="CST-FRAMEWORK" );
  %let _cstReturn=;

  %cstutil_setcstgroot

  %* Assign libname;
  %let _cstRC=%sysfunc( libname( &_cstGlobalMDLib, &_cstGRoot/&_cstFolder));
  %if %sysfunc(libref(&_cstGlobalMDLib))
    %then %do;
       %put %sysfunc(sysmsg());
       %put %str(Library &_cstGlobalMDLib (&_cstGRoot/&_cstFolder)) not assigned;
       %let _cstRC=%sysfunc(libname(&_cstGlobalMDLib, ""));
    %end;
    %else %do;

      %* Open data set;
      %let _cstFID = %sysfunc(open(&_cstGlobalMDLib..&_cstTable(where=(&_cstWhere)), is)) ;
      %if (&_cstFID = 0) %then %do;
       %put %sysfunc(sysmsg());
      %end;
      %else %do;
        %let _cstVpos = %SysFunc( VarNum( &_cstFID, &_cstColumn)) ;
        %if &_cstVpos %then %do;
          %let _cstObs= %sysfunc( attrn( &_cstFID, nobs ));
          %let _cstVar= %sysfunc( varnum( &_cstFID, &_cstColumn));
          %do %while ( %sysfunc( fetch( &_cstFID)) ne -1 );
             %let _cstReturn= %sysfunc( getvarc(&_cstFID, &_cstVar ));
          %end;
        %end ;
        %else %do;
          %* &_cstColumn does not exist in data set  &_cstGlobalMDLib..&_cstTable. ;
          %let _cstReturn=1.2;
        %end;

        %* Close data set and de-assign libname;
        %if %sysfunc(close(&_cstFID)) %then %put %sysfunc(sysmsg());
        %if %sysfunc(libname(&_cstGlobalMDLib)) %then  %put %sysfunc(sysmsg());
      %end;

    %end;

      %*;&_cstReturn%*;  %* 'function' return value ;

%mend cstutil_getcstversion;
