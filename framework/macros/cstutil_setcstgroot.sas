%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_setcstgroot                                                            *;
%*                                                                                *;
%* Sets the global macro variable _cstGRoot.                                      *;
%*                                                                                *;
%* This macro sets the _cstGRoot global macro variable to the location of the     *;
%* SAS Clinical Standards Toolkit sample library as specified by the CSTGLOBALLIB *;
%* system option.                                                                 *;
%*                                                                                *;
%* @history 2014-04-07  Removed SAS 9.3 option.                                   *;
%* @history 2014-06-18  Made sure that this only runs with SAS 9.4 and newer.     *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_setcstgroot(
    ) / des='CST: Set _cstGRoot macro variable';

   %global _cstGRoot;
   %let _cstGRoot=%sysfunc(kcompress(%sysfunc(getoption(CSTGLOBALLIB)),%str(%")));

%mend cstutil_setcstgroot;