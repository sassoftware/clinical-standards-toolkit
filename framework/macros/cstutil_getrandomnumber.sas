%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_getRandomNumber                                                        *;
%*                                                                                *;
%* Returns a four-digit random number that can be used in work data set names.    *;
%*                                                                                *;
%* @param _cstVarname - required - The name of the macro variable to set with     *;
%*            the four-digit number.                                              *;
%*                                                                                *;
%* @since  1.2                                                                    *;
%* @exposure internal                                                             *;

%macro cstutil_getRandomNumber(
    _cstVarname=
    ) / des ='CST: Get random number';

   %local random;
   %let random=%sysfunc(ranuni(0));
   %let random=%sysevalf(&random*10000,floor);

   %let &_cstVarName=%sysfunc(putn(&random,z4.));

%mend cstutil_getRandomNumber;
