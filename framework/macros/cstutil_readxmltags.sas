%* Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   *;
%* SPDX-License-Identifier: Apache-2.0                                            *;
%*                                                                                *;
%* cstutil_readxmltags                                                            *;
%*                                                                                *;
%* Creates data sets of element and attribute names from an XML file.             *;
%*                                                                                *;
%* This macro is a proof of concept. This macro reads the element tags and        *;
%* attributes of an XML file. It then identifies the tags and elements that the   *;
%* SAS Clinical Standards Toolkit does not currently handle using the CDISC ODM   *;
%* odm_read macro.                                                                *;
%*                                                                                *;
%* This macro relies on a defined set of XSLT modules, metadata that specifies a  *;
%* SAS representation of ODM, and a SAS XML map file that reads a derived cubexml *;
%* file. Each of these makes assumptions about the XML content to read.           *;
%*                                                                                *;
%* Assumptions:                                                                   *;
%*             1. The XML file has been defined with a SAS fileref.               *;
%*             2. ODM reference metadata is available as defined in SASReferences.*;
%*                                                                                *;
%* Limitations:                                                                   *;
%*             1. The code does not work on a continuous-stream (no line returns) *;
%*                XML file.                                                       *;
%*             2. The code might not work well on multi-element rows such as      *;
%*                 <Study><MetaDataVersion OID=..><...>. (Untested)               *;
%*             3. The code might not handle PCDATA... (Untested)                  *;
%*                                                                                *;
%* @macvar _cstDebug Turns debugging on or off for the session                    *;
%* @macvar _cstResultsDS Results data set                                         *;
%* @macvar _cstSeqCnt Results: Sequence number within _cstResultSeq               *;
%* @macvar _cstStandard Name of a standard registered to the SAS Clinical         *;
%*             Standards Toolkit                                                  *;
%* @macvar _cstStandardVersion Version of the standard referenced in _cstStandard *;
%* @macvar _cstLRECL Logical record length setting for filename statement         *;
%*                                                                                *;
%* @param _cstXMLFilename - required - The fileref for input XML file.            *;
%* @param _cstXMLReporting - required - The method to report the results:         *;
%*            Dataset: The following two parameters are referenced.               *;
%*            Results: The differences that are detected are reported in the      *;
%*                     process Results data set (as defined by &_cstResultsDS).   *;
%*            Values: Dataset | Results                                           *;
%*            Default: Results                                                    *;
%* @param _cstXMLElementDS - conditional - The libref.dataset for file elements.  *;
%*            Used only if _cstXMLReporting=Dataset.                              *;
%*            Default: work.cstodmelements                                        *;
%* @param _cstXMLAttrDS - conditional - The libref.dataset for file attributes.   *;
%*            Used only if _cstXMLReporting=Dataset.                              *;
%*            Default: work.cstodmattributes                                      *;
%*                                                                                *;
%* @since  1.4                                                                    *;
%* @exposure external                                                             *;

%macro cstutil_readxmltags(
    _cstXMLFilename=inxml,
    _cstXMLReporting=Results,
    _cstXMLElementDS=work.cstodmelements,
    _cstXMLAttrDS=work.cstodmattributes
    ) / des='CST: Parse xml for elements and attributes';

%local
  _cstDataRecords
  _cstHashLib
  _cstHashDS
  _cstMsgDir
  _cstMsgMem
  _cstODMAttrDS
  _cstODMElementDS
  _cstODMMetaDataLibrary
  _cstRefColumnDS
  _cstRefLib
  _cstRefTableDS
  _cstSrcData
  _cstTemp
  _cstUseResults
;

%let _cstODMAttrDS=;
%let _cstODMElementDS=;
%let _cstODMMetaDataLibrary=;
%let _cstRefColumnDS=;
%let _cstRefLib=;
%let _cstRefTableDS=;
%let _cstSrcData=&sysmacroname;
%let _cstUseResults=0;

%if %upcase(&_cstXMLReporting) ne RESULTS and %upcase(&_cstXMLReporting) ne DATASET %then
%do;
  %put Task aborted, invalid value for _cstXMLReporting parameter.  Value entered is &_cstXMLReporting;
  %goto exit_error;
%end;

%if %sysfunc(upcase(&_cstXMLReporting))=RESULTS %then
%do;
  %if %symexist(_cstResultsDS) %then
  %do;
    %if %length(&_cstResultsDS) > 0 and %sysfunc(exist(&_cstResultsDS)) %then
    %do;
      %let _cstUseResults=1;
    %end;
  %end;
%end;

%if %length(&_cstXMLFilename) < 1 %then
%do;
  %if &_cstUseResults %then
      %cstutil_writeresult(
                _cstResultId=CST0005
                ,_cstResultParm1=CSTUTIL_READXMLTAGS
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
  %else
    %put Task aborted, _cstXMLFilename parameter must be provided in call to cstutil_readxmltags;
  %goto exit_error;
%end;

* Stop processing if the XML file does not exist ;

%if ((%sysfunc(fexist(&_cstXMLFilename)))=0) %then %do;
   %cstutil_writeresult(
                _cstResultId=CST0008
                ,_cstResultParm1=%sysfunc(pathname(&_cstXMLFilename))
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=CSTUTIL_READXMLTAGS
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
  %goto exit_error;
%end;

%* Stop processing if the reference metadata is not available                                        *;
%* Reference metadata is used to identify known/expected tables (elements) and columns (attributes)  *;

%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=table,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefTableDS);
%cstutil_getsasreference(_cstSASRefType=referencemetadata,_cstSASRefSubtype=column,_cstSASRefsasref=_cstRefLib,
        _cstSASRefmember=_cstRefColumnDS);

%* Get the libref of the standardmetadata;
%cstutil_getSASReference(_cstStandard=%upcase(&_cstStandard),_cstStandardVersion=&_cstStandardVersion,_cstSASRefType=standardmetadata,
        _cstSASRefSubtype=element, _cstSASRefsasref=_cstODMMetaDataLibrary, _cstSASRefmember=_cstODMElementDS);
%cstutil_getSASReference(_cstStandard=%upcase(&_cstStandard),_cstStandardVersion=&_cstStandardVersion,_cstSASRefType=standardmetadata,
        _cstSASRefSubtype=attribute, _cstSASRefsasref=_cstODMMetaDataLibrary, _cstSASRefmember=_cstODMAttrDS);



%if %length(&_cstRefLib)<1 or %length(&_cstRefTableDS)<1 or %length(&_cstRefColumnDS)<1 %then
%do;
   %cstutil_writeresult(
                _cstResultId=CST0084
                ,_cstResultParm1=referencemetadata
                ,_cstResultParm2=this request
                ,_cstResultSeqParm=1
                ,_cstSeqNoParm=1
                ,_cstSrcDataParm=CSTUTIL_READXMLTAGS
                ,_cstResultFlagParm=1
                ,_cstRCParm=1
                ,_cstResultsDSParm=&_cstResultsDS
                );
  %goto exit_error;
%end;

data _null_;
  infile &_cstXMLFilename length=reclen pad missover recfm=v &_cstLRECL;
  input line $varying32767. reclen;
  attrib temp_str format=$1024.
         activeElements format=$1024.
         containers format=$1024.
         parent format=$128.
         container format=$128.
         element format=$128.
         attribute format=$128.;
  retain tagName attrName endTag1 endTag2 containerName parent activeElements containers;

  if _n_=1 then do;
    tagName=prxparse('/<\w+(:)?\w+/');    *  find tag starting with < and check for optional : (colon) *;
    attrName=prxparse('/\S+="/');         *  find attribute using www=  *;
    endTag1=prxparse('/\/>/');            *  find end tag />            *;
    endTag2=prxparse('/\<\//');           *  find end tag </            *;
    containerName=prxparse('/<\w+>/');    *  find container <www>       *;
    declare hash elements(ordered: 'a');
    rc=elements.defineKey('element');
    rc=elements.defineDone();
    declare hash attributes(ordered: 'a');
    rc=attributes.defineKey('element', 'parent', 'attribute');
    rc=attributes.defineDone();
  end;

  do until(position=0);
    * prxsubstr looks for pattern xxx (eg tagName) in line - returning tag position and length *;
    call prxsubstr(tagName, line, position, length);
    call prxsubstr(endTag1, line, endposition, endlength);
    call prxsubstr(containerName, line, cpos, clen);
    if position ^= 0 then do;
      temp_str=substr(line,position);
      * Found an element *;
      element = compress(substr(line, position+1, length),'>/');
      activeElements=catx(' ',activeElements,element);
      if endposition ^= 0 then
      do;
        xTag=indexw(activeElements,element);
        * Found an end tag for an element - remove from activeElements stack *;
        if xTag then
          activeElements=substr(activeElements,1,xTag-1);
      end;
      else if cpos ^= 0 then
      do;
        * Found a container - add if unique *;
        container = compress(substr(line, position+1, length),'>/');
        if indexw(containers,container)=0 then
          containers=catx(' ',containers,container);
      end;
      rc=elements.add();
      line=substr(line,length+position);
      do until(aposition=0);
        * Look for pattern attrName in temp_str - returning attribute position and length *;
        call prxsubstr(attrName, temp_str, aposition, alength);
        if aposition ^= 0 then do;
          * Found an attribute *;
          attribute=substr(temp_str, aposition,alength-2);
          rc=attributes.add();
          temp_str=substr(temp_str,alength+aposition);
        end;
      end;
    end;
  end;

  * Look to see if line is a closing tag like </xxx>  *;
  call prxsubstr(endTag2, line, endposition, endlength);
  if endposition ^= 0 then do;
      xTag=indexw(activeElements,compress(substr(line, endposition+2),'>'));
      * Found an end tag for an element - remove from activeElements stack *;
      if xTag>1 then
        activeElements=substr(activeElements,1,xTag-1);
  end;

  elementCnt=countw(activeElements,' ');
  * Get the last element added to the stack as the parent *;
  if elementCnt>0 then
    parent = scan(activeElements,elementCnt,' ');
  * Check to see if it is a container.  If it is, set the preceding element as the parent *;
  if indexw(containers,parent) then
    parent = scan(activeElements,elementCnt-1,'');

  * Write out current values from the two hashs *;
  if line =: '</ODM' then
  do;
    attributes.output (dataset: "&_cstXMLAttrDS") ;
    elements.output (dataset: "&_cstXMLElementDS") ;
  end;
run;

******************************************************;
* Create data set containing elements defined in the *;
* XML file but do not exist in the base ODM Model    *;
******************************************************;
proc sql noprint;
  create table work._cstProblems as
  select *, 1 as _cstError from work.elements ele
  where not exists (select * from &_cstODMMetaDataLibrary..&_cstODMElementDS
                    where element=ele.element);
quit;

%let _cstDataRecords=0;

%if %sysfunc(exist(work._cstproblems)) %then
%do;
  data _null_;
    if 0 then set work._cstproblems nobs=_numobs;
    call symputx('_cstDataRecords',_numobs);
    stop;
  run;
%end;

%let _cstHashLib=%scan(&_cstXMLElementDS,1,.);
%let _cstHashDS=%scan(&_cstXMLElementDS,2,.);

%**************************************;
%* One or more errors were found  *;
%**************************************;

%if &_cstDataRecords %then
%do;
  %if %sysfunc(upcase(&_cstXMLReporting))=DATASET %then
  %do;
    %****************************************************************;
  %* Bypass the ResultsDS and output individual Elements data set *;
    %****************************************************************;
    data &_cstXMLElementDS;
      set work._cstProblems;
    run;
        %let _cstSrcData=&sysmacroname;
  %cstutil_writeresult(
            _cstResultId=CST0200
           ,_cstResultParm1=Data set &_cstXMLElementDS has been created
           ,_cstResultParm2=
           ,_cstResultSeqParm=1
           ,_cstSeqNoParm=1
           ,_cstSrcDataParm=&_cstSrcData
           ,_cstResultFlagParm=0
           ,_cstRCParm=0
           ,_cstResultsDSParm=&_cstResultsDS
           );
  %end;
  %else
  %do;
    %********************;
  %* Delete Hash File *;
    %********************;
    proc datasets nolist lib=&_cstHashLib;
      delete &_cstHashDS / mt=data;
    quit;
    %****************************************;
    %* Create a temporary results data set. *;
    %****************************************;
    %local _cstTemp;

    data _null_;
      attrib _cstTemp label="Text string field for file names"  format=$char12.;
             _cstTemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstTemp',_cstTemp);
    run;

    %******************************************************;
    %* Add the records to the temporary results data set. *;
    %******************************************************;
    data &_cstTemp (label='Work error data set');
      %cstutil_resultsdskeep;
      set work._cstproblems end=last;
      attrib _cstSeqNo format=8. label="Sequence counter for result column";
      keep _cstMsgParm1 _cstMsgParm2;
      retain _cstSeqNo 0 resultid checkid resultseq resultflag _cst_rc;
      %***********************************;
      %* Set results data set attributes *;
      %***********************************;
      %cstutil_resultsdsattr;
      retain message resultseverity resultdetails '';
      if _n_=1 then
      do;
        _cstSeqNo=0;
        resultid="ODM0900";
        checkid="ODM0900";
        resultseq=1;
        resultflag=1;
       _cst_rc=0;
     end;
     keyvalues='';
     _cstMsgParm1='';
     _cstMsgParm2='';
     srcdata = pathname("&_cstXMLFileName");
     _cstSeqNo+1;
     seqno=_cstSeqNo;
     actual="Element = "||strip(left(element));
    run;

    %if (&syserr gt 4) %then
    %do;
      %*****************************;
      %* Check failed - SAS error  *;
      %*****************************;
      ******************************************************************************************;
      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      ******************************************************************************************;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %*******************************************************************;
    %* Parameters passed are check-level -- not record-level -- values *;
    %*******************************************************************;

    %cstutil_appendresultds(_cstErrorDS=&_cstTemp
                           ,_cstVersion=&_cstStandardVersion
                           ,_cstSource=SAS
                           ,_cstStdRef=CDISC-ODM
                           ,_cstOrderby=%str(resultid, checkid, resultseq, seqno);
                           );

    proc datasets lib=work nolist;
      delete &_cstTemp;
    quit;
  %end;
%end;
%else
%do;
  %********************;
  * Delete Hash File *;
  %********************;
  proc datasets nolist lib=&_cstHashLib;
    delete &_cstHashDS / mt=data;
  quit;
  %**************************************;
  %* No errors detected in source data  *;
  %**************************************;
  %let _cst_MsgID=CST0100;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cst_rc=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %cstutil_writeresult(_cstResultID=&_cst_MsgID
                      ,_cstValCheckID=&_cst_MsgID
                      ,_cstResultParm1=&_cst_MsgParm1
                      ,_cstResultParm2=&_cst_MsgParm2
                      ,_cstResultSeqParm=1
                      ,_cstSeqNoParm=&_cstSeqCnt
                      ,_cstSrcDataParm=&_cstXMLFileName
                      ,_cstResultFlagParm=0
                      ,_cstRCParm=&_cst_rc
                      ,_cstActualParm=
                      ,_cstKeyValuesParm=
                      ,_cstResultsDSParm=&_cstResultsDS
                      );
%end;

********************************************************;
* Create data set containing attributes defined in the *;
* XML file but do not exist in the base ODM Model      *;
********************************************************;
proc sql noprint;
  create table work._cstProblems as
  select *, 1 as _cstError from work.attributes att
  where not exists (select * from &_cstODMMetaDataLibrary..&_cstODMAttrDS
                    where element=att.element and attribute=att.attribute and parent=att.parent)
  order by parent, element, attribute;
quit;

%let _cstDataRecords=0;

%if %sysfunc(exist(work._cstproblems)) %then
%do;
  data _null_;
    if 0 then set work._cstproblems nobs=_numobs;
    call symputx('_cstDataRecords',_numobs);
    stop;
  run;
%end;

%let _cstHashLib=%scan(&_cstXMLAttrDS,1,.);
%let _cstHashDS=%scan(&_cstXMLAttrDS,2,.);

%**************************************;
%* One or more errors were found  *;
%**************************************;

%if &_cstDataRecords %then
%do;
  %if %sysfunc(upcase(&_cstXMLReporting))=DATASET %then
  %do;
    %******************************************************************;
  %* Bypass the ResultsDS and output individual Attributes data set *;
    %******************************************************************;
    data &_cstXMLAttrDS;
      set work._cstProblems;
    run;
        %let _cstSrcData=&sysmacroname;
  %cstutil_writeresult(
            _cstResultId=CST0200
           ,_cstResultParm1=Data set &_cstXMLAttrDS has been created
           ,_cstResultParm2=
           ,_cstResultSeqParm=1
           ,_cstSeqNoParm=1
           ,_cstSrcDataParm=&_cstSrcData
           ,_cstResultFlagParm=0
           ,_cstRCParm=0
           ,_cstResultsDSParm=&_cstResultsDS
           );
  %end;
  %else
  %do;
    %********************;
  %* Delete Hash File *;
    %********************;
  %let _cstHashLib=%scan(&_cstXMLAttrDS,1,.);
  %let _cstHashDS=%scan(&_cstXMLAttrDS,2,.);
    proc datasets nolist lib=&_cstHashLib;
      delete &_cstHashDS / mt=data;
    quit;
    %****************************************;
    %* Create a temporary results data set. *;
    %****************************************;
    %local _cstTemp;

    data _null_;
      attrib _cstTemp label="Text string field for file names"  format=$char12.;
             _cstTemp = "_cst" || putn(ranuni(0)*1000000, 'z7.');
      call symputx('_cstTemp',_cstTemp);
    run;

    %******************************************************;
    %* Add the records to the temporary results data set. *;
    %******************************************************;
    data &_cstTemp (label='Work error data set');
      %cstutil_resultsdskeep;
      set work._cstproblems end=last;
      attrib _cstSeqNo format=8. label="Sequence counter for result column";
      keep _cstMsgParm1 _cstMsgParm2;
      retain _cstSeqNo 0 resultid checkid resultseq resultflag _cst_rc;
      %***********************************;
      %* Set results data set attributes *;
      %***********************************;
      %cstutil_resultsdsattr;
      retain message resultseverity resultdetails '';
      if _n_=1 then
      do;
        _cstSeqNo=0;
        resultid="ODM0901";
        checkid="ODM0901";
        resultseq=1;
        resultflag=1;
       _cst_rc=0;
     end;
     keyvalues='';
     _cstMsgParm1='';
     _cstMsgParm2='';
     srcdata =pathname("&_cstXMLFileName");
     _cstSeqNo+1;
     seqno=_cstSeqNo;
     actual="Parent = "||strip(left(parent))||" Element = "||strip(left(element))||" Attribute = "||strip(left(attribute));
    run;

    %if (&syserr gt 4) %then
    %do;
      %*****************************;
      %* Check failed - SAS error  *;
      %*****************************;
      ******************************************************************************************;
      * Reset SAS options to accomodate syntax-only checking that occurs with batch processing *;
      ******************************************************************************************;
      options nosyntaxcheck obs=max replace;

      %let _cst_MsgID=CST0050;
      %let _cst_MsgParm1=;
      %let _cst_MsgParm2=;
      %let _cst_rc=0;
      %let _cstResultFlag=-1;
      %let _cstexit_error=1;
      %goto exit_error;
    %end;

    %*******************************************************************;
    %* Parameters passed are check-level -- not record-level -- values *;
    %*******************************************************************;

    %cstutil_appendresultds(_cstErrorDS=&_cstTemp
                           ,_cstVersion=&_cstStandardVersion
                           ,_cstSource=SAS
                           ,_cstStdRef=CDISC-ODM
                           ,_cstOrderby=%str(resultid, checkid, resultseq, seqno);
                           );

    proc datasets lib=work nolist;
      delete &_cstTemp;
    quit;

  %end;
%end;
%else
%do;
  %********************;
  * Delete Hash File *;
  %********************;
  proc datasets nolist lib=&_cstHashLib;
    delete &_cstHashDS / mt=data;
  quit;
  %**************************************;
  %* No errors detected in source data  *;
  %**************************************;
  %let _cst_MsgID=CST0100;
  %let _cst_MsgParm1=;
  %let _cst_MsgParm2=;
  %let _cst_rc=0;
  %let _cstSeqCnt=%eval(&_cstSeqCnt+1);
  %let _cstSrcData=&sysmacroname;
  %cstutil_writeresult(_cstResultID=&_cst_MsgID
                      ,_cstValCheckID=
                      ,_cstResultParm1=&_cst_MsgParm1
                      ,_cstResultParm2=&_cst_MsgParm2
                      ,_cstResultSeqParm=1
                      ,_cstSeqNoParm=&_cstSeqCnt
                      ,_cstSrcDataParm=&_cstSrcData
                      ,_cstResultFlagParm=0
                      ,_cstRCParm=&_cst_rc
                      ,_cstActualParm=
                      ,_cstKeyValuesParm=
                      ,_cstResultsDSParm=&_cstResultsDS
                      );
%end;

%exit_error:

%* Persist the results if specified in sasreferences  *;
%cstutil_saveresults();

%if &_cstDebug=0 %then
%do;
  %if &_cstUseResults %then
  %do;
    %local _cstMsgDir _cstMsgMem;
    %if (%sysfunc(exist(&_cstXMLAttrDS))) %then %do;
      %if %eval(%index(&_cstXMLAttrDS,.)>0) %then
      %do;
        %let _cstMsgDir=%scan(&_cstXMLAttrDS,1,.);
        %let _cstMsgMem=%scan(&_cstXMLAttrDS,2,.);
      %end;
      %else
      %do;
        %let _cstMsgDir=work;
        %let _cstMsgMem=&_cstXMLAttrDS;
      %end;
      proc datasets nolist lib=&_cstMsgDir;
        delete &_cstMsgMem / mt=data;
      quit;
    %end;
    %if (%sysfunc(exist(&_cstXMLElementDS))) %then %do;
      %if %eval(%index(&_cstXMLElementDS,.)>0) %then
      %do;
        %let _cstMsgDir=%scan(&_cstXMLElementDS,1,.);
        %let _cstMsgMem=%scan(&_cstXMLElementDS,2,.);
      %end;
      %else
      %do;
        %let _cstMsgDir=work;
        %let _cstMsgMem=&_cstXMLElementDS;
      %end;
      proc datasets nolist lib=&_cstMsgDir;
        delete &_cstMsgMem / mt=data;
      quit;
    %end;
  %end;
%end;

%mend cstutil_readxmltags;
