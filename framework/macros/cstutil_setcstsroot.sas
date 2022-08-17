%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_setcstsroot                                                            *;
%*                                                                                *;
%* Sets the global macro variable _cstSRoot.                                      *;
%*                                                                                *;
%* This macro sets the _cstSRoot global macro variable to the location of the     *;
%* SAS Clinical Standards Toolkit sample library as specified by the CSTSAMPLELIB *;
%* system option.                                                                 *;
%*                                                                                *;
%* @history 2014-04-07  Removed SAS 9.3 option.                                   *;
%* @history 2014-06-18  Made sure that this only runs with SAS 9.4 and newer.     *;
%*                                                                                *;
%* @since  1.5                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_setcstsroot(
    ) / des='CST: Set _cstSRoot macro variable';

   %global _cstSRoot;
   %let _cstSRoot=%sysfunc(kcompress(%sysfunc(getoption(CSTSAMPLELIB)),%str(%")));

%mend cstutil_setcstsroot;
