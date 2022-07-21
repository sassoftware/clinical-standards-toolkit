<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xmlns:def="http://www.cdisc.org/ns/def/v1.0"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xml:lang="en"
  exclude-result-prefixes="def xlink odm xsi">
  <xsl:output method="html" indent="yes" encoding="utf-8"
    doctype-system="http://www.w3.org/TR/html4/strict.dtd" 
    doctype-public="-//W3C//DTD HTML 4.01//EN"
    version="4.0" 
  />
  
  <!-- ****************************************************************************************************** -->
  <!-- File:   define-v1-updated-html.xsl                                                                     -->
  <!-- Date:   2012-08-24                                                                                     -->
  <!-- Description: This stylesheet works with the defineXML 1.0 specification.                               -->
  <!-- This document is compliant with XSLT Version 1.0 specification (1999).                                 -->
  <!-- Author: CDISC XML Technologies Team                                                                    -->
  <!--  Changes:                                                                                              -->
  <!--       2014-09-03: Fixed issue with case sensitivety of ItemGroupDef/@Purpose                           -->
  <!--       2014-09-03: Removed - unofficial - ADaM Results Metadata                                         -->
  <!-- ****************************************************************************************************** -->
  <xsl:variable name="g_stylesheetVersion" select="'2014-09-03'"/>
  <!-- ****************************************************************************************************** -->

  <!--
			Global Variables
		-->

  <!-- XSLT 1.0 does not support the function 'upper-case()' 
    so we need to use the 'translate() function, which uses the variables $g_lowercase and $uppercase.
    Remark that this is not a XSLT problem, but a problem that browsers like IE do still not support XSLT 2.0 yet -->
  <xsl:variable name="g_lowercase" select="'abcdefghijklmnopqrstuvwxyz'" />
  <xsl:variable name="g_uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />
  
  <xsl:variable name="g_xndMetaDataVersion" select="/odm:ODM/odm:Study[1]/odm:MetaDataVersion[1]"/>
  <xsl:variable name="g_seqItemGroupDefs" select="$g_xndMetaDataVersion/odm:ItemGroupDef"/>

  <xsl:variable name="g_StandardName" select="$g_xndMetaDataVersion/@def:StandardName"/>
  <xsl:variable name="g_StandardVersion" select="$g_xndMetaDataVersion/@def:StandardVersion"/>

  <!--We need to be able to distuinguish bewteen Tabulation and Analysis datasets -->  
  <xsl:variable name="g_nItemGroupDefs" select="count($g_seqItemGroupDefs)"/>
  <xsl:variable name="g_nItemGroupDefsAnalysis" select="count($g_seqItemGroupDefs[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS'])"/>
  <xsl:variable name="g_nItemGroupDefsTabulation" select="count($g_seqItemGroupDefs[translate(@Purpose,$g_lowercase,$g_uppercase)='TABULATION'])"/>
  <xsl:variable name="g_ItemGroupDefPurpose">
    <xsl:choose>
      <xsl:when test="($g_nItemGroupDefsAnalysis = $g_nItemGroupDefs) or ($g_nItemGroupDefsTabulation = $g_nItemGroupDefs)">
        <xsl:choose>
          <xsl:when test="($g_nItemGroupDefsTabulation = $g_nItemGroupDefs)">
            <xsl:text>Tabulation</xsl:text>
          </xsl:when>
          <xsl:when test="($g_nItemGroupDefsAnalysis = $g_nItemGroupDefs)">
            <xsl:text>Analysis</xsl:text>
          </xsl:when>
          <xsl:otherwise />
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text></xsl:text>
      </xsl:otherwise>
    </xsl:choose>  
  </xsl:variable>

  <!-- ***************************************************************** -->
  <!-- Create the HTML Header                                            -->
  <!-- ***************************************************************** -->
  <xsl:template match="/">
    <html>
      <head>
        <meta http-equiv="Content-Script-Type" content="text/javascript"/>
        <meta http-equiv="Content-Style-Type" content="text/css"/>
        <title> Study <xsl:value-of select="/odm:ODM/odm:Study/odm:GlobalVariables/odm:StudyName"/>, Data Definitions</title>

        <xsl:call-template name="GenerateJavaScript"/>
        <xsl:call-template name="GenerateCSS"/>

      </head>
      <body onload="reset_menus();">
        <xsl:apply-templates/>
      </body>
    </html>
  </xsl:template>


  <xsl:template match="/odm:ODM/odm:Study/odm:GlobalVariables"/>
  <xsl:template match="/odm:ODM/odm:Study/odm:MetaDataVersion">

<div id="menu">  

  <span class="standard">
    <xsl:value-of select="$g_StandardName"/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="$g_StandardVersion"/>
  </span>

  <ul class="hmenu">
   
    <!-- **************************************************** -->
    <!-- **************  Annotated CRF    ******************* -->
    <!-- **************************************************** -->

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:AnnotatedCRF">
      <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:AnnotatedCRF/def:DocumentRef">
        <li class="hmenu-item">
          <span class="hmenu-bullet">+</span>
          <xsl:variable name="leafIDs" select="@leafID"/>
          <xsl:variable name="leaf" select="../../def:leaf[@ID=$leafIDs]"/>
          <a class="tocItem">
            <xsl:attribute name="href"><xsl:value-of select="$leaf/@xlink:href"/></xsl:attribute>
            <xsl:value-of select="$leaf/def:title"/>
          </a> 
        </li>
      </xsl:for-each>
    </xsl:if>
    <!-- **************************************************** -->
    <!-- **************  Supplemental Doc ******************* -->
    <!-- **************************************************** -->

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:SupplementalDoc">
      <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:SupplementalDoc/def:DocumentRef">
        <li class="hmenu-item">
          <span class="hmenu-bullet">+</span>
          <xsl:variable name="leafIDs" select="@leafID"/>
          <xsl:variable name="leaf" select="../../def:leaf[@ID=$leafIDs]"/>
          <a class="tocItem">
            <xsl:attribute name="href"><xsl:value-of select="$leaf/@xlink:href"/></xsl:attribute>
            <xsl:value-of select="$leaf/def:title"/>
          </a> 
        </li>
      </xsl:for-each>
    </xsl:if>

    <!-- **************************************************** -->
    <!-- ************** Analysis Datasets ******************* -->
    <!-- **************************************************** -->
    
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
      <li class="hmenu-submenu" >
        <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>
        <a class="tocItem" href="#Analysis_Datasets_Table" >Analysis Datasets</a>
        <ul> 
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
            <li class="hmenu-item">
              <span class="hmenu-bullet">-</span>
              <a class="tocItem">
                <xsl:attribute name="href">#IG.<xsl:value-of select="@OID"/></xsl:attribute>
                <xsl:choose>
                  <xsl:when test="@SASDatasetName">
                    <xsl:value-of select="concat(@def:Label, ' (', @SASDatasetName, ') ')"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="concat(@def:Label, ' (', @Name, ') ')"/>
                  </xsl:otherwise>
                </xsl:choose>
              </a>             
            </li>
          </xsl:for-each>
        </ul>
      </li>
    </xsl:if>
    
    <!-- **************************************************** -->
    <!-- ************** SDTM/SEND Datasets ****************** -->
    <!-- **************************************************** -->
    
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
      <li class="hmenu-submenu" >
        <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>
        <a class="tocItem" href="#SDTM_Datasets_Table" >SDTM Datasets</a>
        <ul> 
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
            <li class="hmenu-item">
              <span class="hmenu-bullet">-</span>
              <a class="tocItem">
                <xsl:attribute name="href">#IG.<xsl:value-of select="@OID"/></xsl:attribute>
                <xsl:choose>
                  <xsl:when test="@SASDatasetName">
                    <xsl:value-of select="concat(@def:Label, ' (', @SASDatasetName, ') ')"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="concat(@def:Label, ' (', @Name, ') ')"/>
                  </xsl:otherwise>
                </xsl:choose>
              </a>             
            </li>
          </xsl:for-each>
        </ul>
      </li>
    </xsl:if>
    
    <!-- **************************************************** -->
    <!-- **************** Parameter Lists ******************* -->
    <!-- **************************************************** -->
    
    <xsl:if  test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ValueListDef">
      <li class="hmenu-submenu" >
        <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>

        <xsl:choose>
          <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
            <a class="tocItem" href="#valuemeta">Parameter Value Level Metadata</a>
          </xsl:when>
          <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
            <a class="tocItem" href="#valuemeta">Value Level Metadata</a>
          </xsl:when>
          <xsl:otherwise>
            <a class="tocItem" href="#valuemeta">Value Level Metadata</a>
          </xsl:otherwise>
        </xsl:choose>  

        <ul>
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ValueListDef">
            <li class="hmenu-item">
              <span class="hmenu-bullet">-</span>
             <!--  <a class="tocItem">--> 

              <xsl:variable name="valueListDefOID" select="@OID"/>          
              <xsl:variable name="valueListRef" select="//odm:ItemDef/def:ValueListRef[@ValueListOID=$valueListDefOID]"/>
              <xsl:variable name="itemDefOID" select="$valueListRef/../@OID"/>
              
              <xsl:element name="a">
                  
                  <xsl:choose>
                    <xsl:when test="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name">
                      <xsl:attribute name="class">tocItem</xsl:attribute>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:attribute name="class">tocItem level2</xsl:attribute>
                    </xsl:otherwise>
                  </xsl:choose>
                  
                <xsl:attribute name="href">#VL.<xsl:value-of select="@OID"/></xsl:attribute>
                
                <xsl:choose>
                  <xsl:when test="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name">
                    <xsl:value-of select="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name"/> [<xsl:value-of select="$valueListRef/../@Name"/>]
                   </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="//odm:ItemRef[@ItemOID=$itemDefOID]/../@OID"/> [<xsl:value-of select="$valueListRef/../@Name"/>]
                  </xsl:otherwise>
                </xsl:choose>
 
              </xsl:element>
            </li>
          </xsl:for-each>
        </ul>
      </li>
    </xsl:if> 
    
    <!-- **************************************************** -->
    <!-- ******************** Code Lists ******************** -->
    <!-- **************************************************** -->
    
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:CodeListItem]">
      <li class="hmenu-submenu" >
        <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>
        <a class="tocItem" href="#decodelist">Controlled Terms</a>
        <ul>
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:CodeListItem]">
            <li class="hmenu-item">
              <span class="hmenu-bullet">-</span>
              <a class="tocItem">              
                <xsl:attribute name="href">#CL.<xsl:value-of select="@OID"/></xsl:attribute>
                <xsl:value-of select="@Name"/>
              </a>        
            </li>      
          </xsl:for-each>
        </ul>
      </li>
    </xsl:if>

  <!-- **************************************************** -->
  <!-- ************** External Dictionaries *************** -->
  <!-- **************************************************** -->
  <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:ExternalCodeList]">
    <li class="hmenu-submenu" >
      <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>
      <a class="tocItem" href="#externaldictionary">External Dictionaries</a>
      <ul>
        <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:ExternalCodeList]">
          <li class="hmenu-item">
            <span class="hmenu-bullet">-</span>
            <a class="tocItem">
              <xsl:attribute name="href">#CL.<xsl:value-of select="@OID"/></xsl:attribute>
              <xsl:value-of select="@Name"/>
            </a>
          </li>
        </xsl:for-each>
      </ul>
    </li>
  </xsl:if>
  
  <!-- **************************************************** -->
  <!-- ****************** Derivations ********************* -->
  <!-- **************************************************** -->
  
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod">
    <li class="hmenu-submenu" >
      <span class="hmenu-bullet" onclick="toggle_submenu(this);">+</span>
      <a class="tocItem" href="#compmethod">
        <xsl:choose>
          <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">Analysis Derivations</xsl:when>
          <xsl:otherwise>Computational Algorithms</xsl:otherwise>
        </xsl:choose>
      </a>
      <ul>    
        <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod">
          <li class="hmenu-item">
            <span class="hmenu-bullet">-</span>
            <a class="tocItem">
              <xsl:attribute name="href">#<xsl:value-of select="@OID"/></xsl:attribute>
              <xsl:value-of select="@OID"/>     
            </a>
          </li>
        </xsl:for-each>
      </ul>
    </li>
  </xsl:if> 
  
<!-- end of menu -->
  </ul>
</div>

<div id="main">


  <div class="docinfo">
    <xsl:call-template name="DocGenerationDate"/>
    <xsl:call-template name="StylesheetDate"/> 
  </div>    

    <!-- Display a red banner in case this file does not contain only Tabulation datasets or Analysis datasets -->
    <xsl:if test="(($g_nItemGroupDefsTabulation &lt; $g_nItemGroupDefs) and ($g_nItemGroupDefsAnalysis &lt; $g_nItemGroupDefs)) or 
      (($g_nItemGroupDefsTabulation &gt; 0) and ($g_nItemGroupDefsAnalysis &gt; 0))">
      <span class="error">It is expected that all ItemGroups have Purpose='Tabulation' or all ItemGroups have Purpose='Analysis'.</span>
      <br />
    </xsl:if>


    <!-- ***************************************************************** -->
    <!-- Create the ADaM Data Definition Tables                            -->
    <!-- ***************************************************************** -->
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">

      <fieldset id="Analysis_Datasets_Table" style="page-break-after: always;">
        <legend>ADaM Datasets for Study <xsl:value-of
            select="/odm:ODM/odm:Study/odm:GlobalVariables/odm:StudyName"/></legend>

        <table>
          <tr class="header">
            <th scope="col">Dataset</th>
            <th scope="col">Description</th>
            <th scope="col">Class</th>
            <th scope="col">Structure</th>
            <th scope="col">Purpose</th>
            <th scope="col">Keys</th>
            <th scope="col">Location</th>
            <th scope="col">Documentation</th>
          </tr>
          <xsl:for-each select="./odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
            <xsl:call-template name="ItemGroupDefADaM">
              <xsl:with-param name="rowNum" select="position()"/>
            </xsl:call-template>
          </xsl:for-each>
        </table>
      </fieldset>

      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>

    <!-- ***************************************************************** -->
    <!-- Create the SDTM Data Definition Tables                            -->
    <!-- ***************************************************************** -->

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">

      <fieldset id="SDTM_Datasets_Table" style="page-break-after: always;">
        <legend>SDTM Datasets for Study <xsl:value-of
            select="/odm:ODM/odm:Study/odm:GlobalVariables/odm:StudyName"/></legend>

        <table>
          <tr class="header">
            <th scope="col">Dataset</th>
            <th scope="col">Description</th>
            <th scope="col">Class</th>
            <th scope="col">Structure</th>
            <th scope="col">Purpose</th>
            <th scope="col">Keys</th>
            <th scope="col">Location</th>
          </tr>
          <xsl:for-each select="./odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
            <xsl:call-template name="ItemGroupDefSDTM"/>
          </xsl:for-each>
        </table>

      </fieldset>

      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>


    <!-- ***************************************************************** -->
    <!-- Detail for the ADaM Data Definition Tables                        -->
    <!-- ***************************************************************** -->

    <xsl:for-each select="./odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
      <xsl:call-template name="ItemRefADaM"/>
      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>
    </xsl:for-each>

    <!-- ***************************************************************** -->
    <!-- Detail for the SDTM Data Definition Tables                        -->
    <!-- ***************************************************************** -->

    <xsl:for-each select="./odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
      <xsl:call-template name="ItemRefSDTM"/>
      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>
    </xsl:for-each>

    <!-- ***************************************************************** -->
    <!-- Create the Parameter Lists                                        -->
    <!-- ***************************************************************** -->
    <xsl:call-template name="ParameterList"/>

    <!-- ***************************************************************** -->
    <!-- Create the Code Lists, Enumerated Items and External Dictionaries -->
    <!-- ***************************************************************** -->
    <xsl:call-template name="AppendixDecodeList"/>

    <!-- ***************************************************************** -->
    <!-- Create the Derivations                                            -->
    <!-- ***************************************************************** -->
    <xsl:call-template name="AppendixComputationMethod"/>

<!-- end of main -->
</div>

  </xsl:template>

  <!-- ****************************************************  -->
  <!-- Template: ItemGroupDefADaM                            -->
  <!-- ****************************************************  -->
  <xsl:template name="ItemGroupDefADaM">
    <xsl:param name="rowNum"/>

    <xsl:element name="tr">

      <xsl:call-template name="rowClass">
        <xsl:with-param name="rowNum" select="position()"/>
      </xsl:call-template>

      <!-- Create an anchor -->
      <xsl:attribute name="id">
        <xsl:value-of select="@OID"/>
      </xsl:attribute>
      
      <td>
        <xsl:value-of select="@Name"/>
      </td>

      <!-- ************************************************************* -->
      <!-- Link each XPT to its corresponding section in the define      -->
      <!-- ************************************************************* -->
      <td>
        <a>
          <xsl:attribute name="href">#IG.<xsl:value-of select="@OID"/>
          </xsl:attribute>
          <xsl:value-of select="@def:Label"/>
        </a>
      </td>

      <td><xsl:value-of select="@def:Class"/></td> 
      <td><xsl:value-of select="@def:Structure"/></td>
      <td><xsl:value-of select="@Purpose"/></td>
      <td><xsl:value-of select="@def:DomainKeys"/></td>

      <!-- ************************************************ -->
      <!-- Link each XPT to its corresponding archive file  -->
      <!-- ************************************************ -->
      <td>
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="def:leaf/@xlink:href"/>
          </xsl:attribute>
          <xsl:value-of select="def:leaf/def:title"/>
        </a>
      </td>

      <td><xsl:value-of select="@Comment"/></td> 

    </xsl:element>
  </xsl:template>


  <!-- **************************************************** -->
  <!-- Template: ItemGroupDefSDTM                           -->
  <!-- **************************************************** -->

  <xsl:template name="ItemGroupDefSDTM">
    <xsl:param name="rowNum"/>

    <xsl:element name="tr">

      <xsl:call-template name="rowClass">
        <xsl:with-param name="rowNum" select="position()"/>
      </xsl:call-template>

      <!-- Create an anchor -->
      <xsl:attribute name="id">
        <xsl:value-of select="@OID"/>
      </xsl:attribute>
      
      <td>
        <xsl:value-of select="@Name"/>
      </td>

      <!-- ********************************************************* -->
      <!-- Link each XPT to its corresponding section in the define  -->
      <!-- ********************************************************* -->
      <td>
        <a>
          <xsl:attribute name="href">#IG.<xsl:value-of select="@OID"/></xsl:attribute>
          <xsl:value-of select="@def:Label"/>
        </a>
      </td>

      <td><xsl:value-of select="@def:Class"/></td>
      <td><xsl:value-of select="@def:Structure"/></td>
      <td><xsl:value-of select="@Purpose"/></td>
      <td><xsl:value-of select="@def:DomainKeys"/></td>

      <!-- ************************************************ -->
      <!-- Link each XPT to its corresponding archive file  -->
      <!-- ************************************************ -->
      <td>
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="def:leaf/@xlink:href"/>
          </xsl:attribute>
          <xsl:value-of select="def:leaf/def:title"/>
        </a>
      </td>

    </xsl:element>
  </xsl:template>



  <!-- **************************************************** -->
  <!-- Template: ItemRefADaM                                -->
  <!-- **************************************************** -->
  <xsl:template name="ItemRefADaM">

    <xsl:element name="fieldset">
      <!-- page break after -->
      <xsl:attribute name="style">
        <xsl:text>page-break-after: always;</xsl:text>
      </xsl:attribute>

      <xsl:attribute name="id">IG.<xsl:value-of select="@OID"/></xsl:attribute>

      <!-- set the fieldset legend (title) -->
      <xsl:element name="legend">
 
        <xsl:choose>
          <xsl:when test="@SASDatasetName">
            <xsl:value-of select="concat(@def:Label, ' (', @SASDatasetName, ') ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat(@def:Label, ' (', @Name, ') ')"/>
          </xsl:otherwise>
        </xsl:choose>
        
        <a><xsl:attribute name="href">
        <xsl:value-of select="def:leaf/@xlink:href"/>
        </xsl:attribute>
        <xsl:value-of select="def:leaf/def:title"/></a>
      </xsl:element>



      <table>

        <!-- Output the column headers -->
        <tr class="header">
          <th scope="col">Variable</th>
          <th scope="col">Label</th>
          <th scope="col">Type</th>
          <th scope="col">Length</th>
          <th scope="col">Display Format</th>
          <th scope="col">Code List / Controlled Terms</th>
          <th scope="col">Source/Derivation/Comments</th> 
          <!--  <th scope="col">Origin</th>
                <th scope="col">Role</th>   
                <th scope="col">Comments</th> 
          --> 
        </tr>
        <!-- Get the individual data points -->
        <xsl:for-each select="./odm:ItemRef">
          <xsl:variable name="itemRef" select="."/>
          <xsl:variable name="itemDefOid" select="@ItemOID"/>
          <xsl:variable name="itemDef" select="../../odm:ItemDef[@OID=$itemDefOid]"/>

          <xsl:element name="tr">

            <!-- Create an anchor -->
            <xsl:attribute name="id">
              <xsl:value-of select="$itemDef/@OID"/>
            </xsl:attribute>
            
            <xsl:call-template name="rowClass">
              <xsl:with-param name="rowNum" select="position()"/>
            </xsl:call-template>

            <!-- Hypertext link only those variables that have a value list -->
            <td>
              <xsl:choose>
                <xsl:when test="$itemDef/def:ValueListRef/@ValueListOID!=''">
                  <a>
                    <xsl:attribute name="href">#VL.<xsl:value-of select="$itemDef/def:ValueListRef/@ValueListOID"/>
                    </xsl:attribute>
                    <xsl:value-of select="$itemDef/@Name"/>
                  </a>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/@Name"/>
                </xsl:otherwise>
              </xsl:choose>
            </td>
            <td><xsl:value-of select="$itemDef/@def:Label"/></td>
            <td class="datatype"><xsl:value-of select="$itemDef/@DataType"/></td>
            <td class="number"><xsl:value-of select="$itemDef/@Length"/></td>
            <td class="number"><xsl:value-of select="$itemDef/@def:DisplayFormat"/></td>
            <!-- *************************************************** -->
            <!-- Hypertext Link to the Decode Appendix               -->
            <!-- *************************************************** -->
            <td>
              <xsl:variable name="CODE" select="$itemDef/odm:CodeListRef/@CodeListOID"/>
              <xsl:variable name="CodeListDef"
                select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]"/>
              <xsl:choose>
                <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]">
                  <a>
                    <xsl:attribute name="href">#CL.<xsl:value-of select="$CodeListDef/@OID"/>
                    </xsl:attribute>
                    <xsl:value-of select="$CodeListDef/@Name"/>
                  </a>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/odm:CodeListRef/@CodeListOID"/>
                </xsl:otherwise>
              </xsl:choose>
              
              <!-- when the variable is a -DTC variable 
                   print 'ISO8601' in this column -->
              <xsl:if test="substring($itemDef/@Name,string-length($itemDef/@Name)-2,string-length($itemDef/@Name)) = 'DTC'">ISO8601</xsl:if>
              
            </td>

            <!-- *************************************************** -->
            <!-- Hypertext Link to the Derivation                    -->
            <!-- *************************************************** -->
            <td>
              <xsl:choose>
                <xsl:when test="$itemDef/@def:ComputationMethodOID!=''">
                  <xsl:variable name="methodOID" select="$itemDef/@def:ComputationMethodOID"/>
                  <xsl:variable name="method"
                    select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod[@OID=$methodOID]"/>
                  See Derivation: <a>
                    <xsl:attribute name="href">#<xsl:value-of select="$itemDef/@def:ComputationMethodOID"/>
                    </xsl:attribute>
                    <xsl:value-of select="$method/@OID"/>
                  </a>: <br />
                	<xsl:value-of select="$method"/>
                	
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/@Comment"/> 
                </xsl:otherwise>
              </xsl:choose>
              
            </td>

          </xsl:element>
        </xsl:for-each>
      </table>
    </xsl:element>
  </xsl:template>

  <!-- **************************************************** -->
  <!-- Template: ItemRefSDTM                                -->
  <!-- **************************************************** -->
  <xsl:template name="ItemRefSDTM">

    <xsl:element name="fieldset">
      <!-- page break after -->
      <xsl:attribute name="style">
        <xsl:text>page-break-after: always;</xsl:text>
      </xsl:attribute>

      <xsl:attribute name="id">IG.<xsl:value-of select="@OID"/></xsl:attribute>

      <!-- set the fieldset legend (title) -->
      <xsl:element name="legend">

        <xsl:choose>
          <xsl:when test="@SASDatasetName">
            <xsl:value-of select="concat(@def:Label, ' (', @SASDatasetName, ') ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat(@def:Label, ' (', @Name, ') ')"/>
          </xsl:otherwise>
        </xsl:choose>
        
        <a><xsl:attribute name="href">
          <xsl:value-of select="def:leaf/@xlink:href"/>
        </xsl:attribute>
          <xsl:value-of select="def:leaf/def:title"/></a>
        
      </xsl:element>
      <table>

        <!-- Output the column headers -->
        <tr class="header">
          <th scope="col">Variable</th>
          <th scope="col">Label</th>
          <th scope="col">Key</th>
          <th scope="col">Type</th>
          <th scope="col">Length</th>
          <th scope="col">Code List / Controlled Terms</th>
          <th scope="col">Origin</th>
          <th scope="col">Role</th>
          <th scope="col">Source/Derivation/Comments</th>
        </tr>
        <!-- Get the individual data points -->
        <xsl:for-each select="./odm:ItemRef">
          <xsl:variable name="itemRef" select="."/>
          <xsl:variable name="itemDefOid" select="@ItemOID"/>
          <xsl:variable name="itemDef" select="../../odm:ItemDef[@OID=$itemDefOid]"/>

          <xsl:element name="tr">

            <xsl:call-template name="rowClass">
              <xsl:with-param name="rowNum" select="position()"/>
            </xsl:call-template>

            <td>
              <xsl:choose>
                <xsl:when test="$itemDef/def:ValueListRef/@ValueListOID!=''">
                  <a>
                    <xsl:attribute name="href">#VL.<xsl:value-of select="$itemDef/def:ValueListRef/@ValueListOID"/>
                    </xsl:attribute>
                    <xsl:value-of select="$itemDef/@Name"/>
                  </a>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/@Name"/>
                </xsl:otherwise>
              </xsl:choose>
            </td>


            <td><xsl:value-of select="$itemDef/@def:Label"/></td>
            <td class="number"><xsl:value-of select="@KeySequence"/></td>
            <td class="datatype"><xsl:value-of select="$itemDef/@DataType"/></td>
            <td class="number"><xsl:value-of select="$itemDef/@Length"/></td>

            <!-- *************************************************** -->
            <!-- Hypertext Link to the Decode Appendix               -->
            <!-- *************************************************** -->
            <td>
              <xsl:variable name="CODE" select="$itemDef/odm:CodeListRef/@CodeListOID"/>
              <xsl:variable name="CodeListDef"
                select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]"/>
              <xsl:choose>
                <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]">
                  <a>
                    <xsl:attribute name="href">#CL.<xsl:value-of select="$CodeListDef/@OID"/>
                    </xsl:attribute>
                    <xsl:value-of select="$CodeListDef/@Name"/>
                  </a>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/odm:CodeListRef/@CodeListOID"/>
                </xsl:otherwise>
              </xsl:choose>
              <!-- when the datatype is 'date', 'time' or 'datetime' 
                   or it is a -DUR (duration) variable, print 'ISO8601' in this column -->
              <xsl:if test="$itemDef/@DataType='date' or $itemDef/@DataType='time' or $itemDef/@DataType='datetime' or substring($itemDef/@Name,string-length($itemDef/@Name)-2,string-length($itemDef/@Name)) = 'DUR'">ISO8601</xsl:if>
              
              
            </td>


            <!-- *************************************************** -->
            <!-- Origin Column                                       -->
            <!-- *************************************************** -->
            <!-- 
            <td>
              <xsl:value-of select="$itemDef/@Origin"/> </td>
            -->
            
            <!-- *************************************************** -->
            <!-- Origin Column for ItemDefs                          -->
            <!-- *************************************************** -->
            <td>
              <!-- translate the value of the origin attribute to uppercase 
              in order to see whether it contains the wording "CRF Page" or "CRF Pages" case-insensitive -->
              <xsl:variable name="ORIGIN_UPPERCASE" select="translate($itemDef/@Origin,$g_lowercase,$g_uppercase)"/>
              <xsl:choose>  
                <!-- create a set of hyperlinks to CRF pages -->
                <!-- This uses a new mechanism checking whether the value of @Origin contains either 'CRF Page' 
                or 'CRF Pages' (case-insensitive) and then translates all numbers found into a hyperlink -->
                <xsl:when test="contains($ORIGIN_UPPERCASE,'CRF PAGES') or contains($ORIGIN_UPPERCASE,'CRF PAGE')">
                  <xsl:call-template name="crfpagenumberstohyperlinks">
                    <xsl:with-param name="ORIGINSTRING" select="$itemDef/@Origin"/>
                    <xsl:with-param name="SEPARATOR" select="' '"/>
                  </xsl:call-template>
                </xsl:when>
                <!-- all other cases, just print the content from the 'Origin' attribute -->
                <xsl:otherwise>
                  <xsl:value-of select="$itemDef/@Origin"/>
                </xsl:otherwise>
              </xsl:choose> 
            </td>
            

            <!-- *************************************************** -->
            <!-- Role Column                                         -->
            <!-- *************************************************** -->
            <td><xsl:value-of select="@Role"/></td>

            
              <!-- *************************************************** -->
              <!-- Hypertext Link to the Derivation                    -->
              <!-- *************************************************** -->
              <td>
                <xsl:choose>
                  <xsl:when test="$itemDef/@def:ComputationMethodOID!=''">
                    <xsl:variable name="methodOID" select="$itemDef/@def:ComputationMethodOID"/>
                    <xsl:variable name="method"
                      select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod[@OID=$methodOID]"/>
                    See Derivation: <a>
                      <xsl:attribute name="href">#<xsl:value-of select="$itemDef/@def:ComputationMethodOID"/>
                      </xsl:attribute>
                      <xsl:value-of select="$method/@OID"/>
                    </a>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$itemDef/@Comment"/> 
                  </xsl:otherwise>
                </xsl:choose>
                
            </td>
          </xsl:element>
        </xsl:for-each>
      </table>
    </xsl:element>
  </xsl:template>


  <!-- *************************************************************** -->
  <!-- Template: ParameterList                                         -->
  <!-- *************************************************************** -->
  <xsl:template name="ParameterList">

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ValueListDef">
      <div id="valuemeta">

      <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ValueListDef">

         <xsl:element name="fieldset">
          <!-- page break after -->
          <xsl:attribute name="style">
            <xsl:text>page-break-after: always;</xsl:text>
          </xsl:attribute>

          <xsl:variable name="valueListDefOID" select="@OID"/>
          <xsl:variable name="valueListRef"
            select="//odm:ItemDef/def:ValueListRef[@ValueListOID=$valueListDefOID]"/>
          <xsl:variable name="itemDefOID" select="$valueListRef/../@OID"/>

          <xsl:attribute name="id">VL.<xsl:value-of select="@OID"/></xsl:attribute>
          
          <!-- set the fieldset legend (title) -->
          <xsl:element name="legend"> 
            <xsl:choose>
              <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
                Parameter Value List -
              </xsl:when>
              <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='TABULATION']">
                ValueLevel Metadata -
              </xsl:when>
              <xsl:otherwise>
                Value List -
              </xsl:otherwise>
            </xsl:choose>  
            
            <xsl:choose>
              <xsl:when test="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name">
                <xsl:value-of select="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name"/> [<xsl:value-of select="$valueListRef/../@Name"/>]
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="//odm:ItemRef[@ItemOID=$itemDefOID]/../@OID"/> [<xsl:value-of select="$valueListRef/../@Name"/>]
              </xsl:otherwise>
            </xsl:choose>

          </xsl:element>

          <table>

            <tr class="header">
              <th scope="col">Source Variable</th>

              <xsl:choose>
                <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
                  <th scope="col">Where PARAMCD=</th>
                  <th scope="col">Where PARAM=</th>
                </xsl:when>
                <xsl:otherwise>
                  <th scope="col">Value</th>
                  <th scope="col">Label</th>
                </xsl:otherwise>
              </xsl:choose>  

              <th scope="col">Type</th>
              <th scope="col">Length</th>
              <xsl:if
                test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
                <th scope="col">Display Format</th>
              </xsl:if>
              <th scope="col">Code List / Controlled Term</th>
              <xsl:if
                test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
                <th scope="col">Origin</th>
              </xsl:if>
              <th scope="col">Source/Derivation/Comments</th>

            </tr>
            <!-- Get the individual data points -->
            <xsl:for-each select="./odm:ItemRef">

              <xsl:variable name="itemRef" select="."/>
              <xsl:variable name="valueListDefMethodOID" select="$itemRef/@def:ComputationMethodOID"/>
              <xsl:variable name="valueListDefItemOID" select="@ItemOID"/>

              <xsl:variable name="methodDef"
                select="../../def:ComputationMethod[@OID=$valueListDefMethodOID]"/>

              <xsl:variable name="parentDef" select="../../odm:ItemDef[@OID=$valueListDefItemOID]"/>
              <xsl:variable name="codelist"
                select="../../odm:CodeList[@OID=$parentDef/odm:CodeListRef/@CodeListOID]"/>

              <xsl:element name="tr">

                <xsl:call-template name="rowClass">
                  <xsl:with-param name="rowNum" select="position()"/> 
                </xsl:call-template>

                <td>
                  <!-- 
                  <xsl:value-of select="$itemRef/@OrderNumber"/>
                   -->
                  <xsl:choose>
                    <xsl:when test="//odm:ItemRef[@ItemOID=$itemDefOID]/../@Name">
                      <xsl:value-of select="$valueListRef/../@Name"/>
                    </xsl:when>
                    <xsl:otherwise>
                      [<xsl:value-of select="$valueListRef/../@Name"/>]
                    </xsl:otherwise>
                  </xsl:choose>
                </td>
 
                <!-- Hypertext link only those variables that have a value list -->
                <td>
                  <xsl:choose>
                    <xsl:when test="$parentDef/def:ValueListRef/@ValueListOID!=''">
                      <a>
                        <xsl:attribute name="href">#VL.<xsl:value-of select="$parentDef/def:ValueListRef/@ValueListOID"/>
                        </xsl:attribute>
                        <xsl:value-of select="$parentDef/@Name"/>
                      </a>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="$parentDef/@Name"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </td>
                <!-- 
                <td>
                  <xsl:value-of select="$parentDef/@Name"/>
                </td>
                 -->
                <td><xsl:value-of select="$parentDef/@def:Label"/></td>

                <td class="datatype"><xsl:value-of select="$parentDef/@DataType"/></td>
                <td class="number"><xsl:value-of select="$parentDef/@Length"/></td>

                <xsl:if
                  test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
                  <td class="number"><xsl:value-of select="$parentDef/@def:DisplayFormat"/></td>
                </xsl:if>

                <td>
                 <xsl:variable name="CODE" select="$parentDef/odm:CodeListRef/@CodeListOID"/>
                 <xsl:variable name="CodeListDef"
                   select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]"/>
                 <xsl:choose>
                   <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[@OID=$CODE]">
                     <a>
                       <xsl:attribute name="href">#CL.<xsl:value-of select="$CodeListDef/@OID"/>
                       </xsl:attribute>
                       <xsl:value-of select="$CodeListDef/@Name"/>
                     </a>
                   </xsl:when>
                   <xsl:otherwise>
                     <xsl:value-of select="$parentDef/odm:CodeListRef/@CodeListOID"/>
                   </xsl:otherwise>
                 </xsl:choose>
                  
                  <!-- when the datatype is 'date', 'time' or 'datetime' 
                       or it is a -DUR (duration) variable, print 'ISO8601' in this column -->
                  <!--  
                  <xsl:if test="$parentDef/@DataType='date' or $parentDef/@DataType='time' or $parentDef/@DataType='datetime' 
                                or substring($parentDef/@Name,string-length($parentDef/@Name)-2,string-length($parentDef/@Name)) = 'DUR'">ISO8601</xsl:if>
                  -->
                  
                </td>

                <xsl:if
                  test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)!='ANALYSIS']">
                  <!-- 
                    <td><xsl:value-of select="$parentDef/@Origin"/></td>
                     -->
                  
                  <!-- *************************************************** -->
                  <!-- Origin Column for ValueDefs                         -->
                  <!-- *************************************************** -->
                  <td>
                    <xsl:variable name="ORIGIN_UPPERCASE" select="translate($parentDef/@Origin,$g_lowercase,$g_uppercase)"/>
                    <xsl:choose>  
                      <!-- create a set of hyperlinks to CRF pages -->
                      <!-- This uses a new mechanism checking whether the value of @Origin contains either 'CRF Page' 
                    or 'CRF Pages' (case-insensitive) and then translates all numbers found into a hyperlink -->
                      <xsl:when test="contains($ORIGIN_UPPERCASE,'CRF PAGES') or contains($ORIGIN_UPPERCASE,'CRF PAGE')">
                        <xsl:call-template name="crfpagenumberstohyperlinks">
                          <xsl:with-param name="ORIGINSTRING" select="$parentDef/@Origin"/>
                          <xsl:with-param name="SEPARATOR" select="' '"/>
                        </xsl:call-template>
                      </xsl:when>
                      <!-- all other cases, just print the content from the 'Origin' attribute -->
                      <xsl:otherwise>
                        <xsl:value-of select="$parentDef/@Origin"/>
                      </xsl:otherwise>
                    </xsl:choose> 
                  </td><!-- end of 'Origin' column -->
                  
                </xsl:if>
                
                <td>
                  <xsl:choose>
                    <xsl:when test="$parentDef/@def:ComputationMethodOID!=''">
                      <xsl:variable name="methodOID" select="$parentDef/@def:ComputationMethodOID"/>
                      <xsl:variable name="method"
                        select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod[@OID=$methodOID]"/>
                    	See Method: <a>
                        <xsl:attribute name="href">#<xsl:value-of select="$parentDef/@def:ComputationMethodOID"/>
                        </xsl:attribute>
                        <xsl:value-of select="$parentDef/@def:ComputationMethodOID"/>
                    	</a>: <br />
                    	<xsl:value-of select="$method"/>
                    </xsl:when>
                    <xsl:otherwise><xsl:value-of select="$parentDef/@Comment"/></xsl:otherwise>
                  </xsl:choose>
                </td>

              </xsl:element>
            </xsl:for-each>

          </table>
        </xsl:element>
        <xsl:call-template name="lineBreak"/>


      </xsl:for-each>
      </div>
      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>
  </xsl:template>

  <!-- *************************************************************** -->
  <!-- Template: AppendixComputationMethod                             -->
  <!-- Create the Computational Algorithms section                     -->
  <!-- *************************************************************** -->
  <xsl:template name="AppendixComputationMethod">

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod">

      <xsl:element name="fieldset">
        <!-- page break after -->
        <xsl:attribute name="style">
          <xsl:text>page-break-after: always;</xsl:text>
        </xsl:attribute>

        <xsl:attribute name="id">compmethod</xsl:attribute>
        
        <!-- set the fieldset legend (title) -->
        <xsl:element name="legend">
          <xsl:choose>
            <xsl:when test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:ItemGroupDef[translate(@Purpose,$g_lowercase,$g_uppercase)='ANALYSIS']">
              Analysis Derivations</xsl:when>
            <xsl:otherwise>Computational Algorithms</xsl:otherwise>
          </xsl:choose>
        </xsl:element>

        <table>
          <tr class="header">
            <th scope="col">Method</th>
            <th scope="col">Description</th>
          </tr>
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:ComputationMethod">

            <xsl:element name="tr">

              <!-- Create an anchor -->
              <xsl:attribute name="id">
                <xsl:value-of select="@OID"/>
              </xsl:attribute>
              
              <xsl:call-template name="rowClass">
                <xsl:with-param name="rowNum" select="position()"/>
              </xsl:call-template>


              <td>
                <xsl:value-of select="@OID"/>
              </td>
              <td>
                <xsl:value-of select="."/>
              </td>
            </xsl:element>
          </xsl:for-each>
        </table>
      </xsl:element>
      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>
  </xsl:template>

  <!-- *************************************************************** -->
  <!-- Template: AppendixDecodeList                                    -->
  <!-- *************************************************************** -->
  <xsl:template name="AppendixDecodeList">

    <!-- ***************************************** -->
    <!-- Discrete Value Listings                   -->
    <!-- ***************************************** -->

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:EnumeratedItem]">

      <xsl:element name="fieldset">
        <!-- page break after -->
        <xsl:attribute name="style">
          <xsl:text>page-break-after: always;</xsl:text>
        </xsl:attribute>

        <xsl:element name="legend">Discrete Value Listings</xsl:element>

        <xsl:attribute name="id">valuelist</xsl:attribute>
        
        <xsl:for-each
          select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:EnumeratedItem]">

          <fieldset class="inner">
            <xsl:attribute name="id">CL.<xsl:value-of select="@OID"/></xsl:attribute>
            <legend>
              <xsl:value-of select="@Name"/>, Reference Name (<xsl:value-of select="@OID"/>)
            </legend>

            <table>
              
              <tr>
                <th scope="col">Valid Values</th>
              </tr>

              <xsl:for-each select="./odm:EnumeratedItem">
                <xsl:sort data-type="number" select="@Rank" order="ascending"/>

                <xsl:element name="tr">
                  <xsl:call-template name="rowClass">
                    <xsl:with-param name="rowNum" select="position()"/>
                  </xsl:call-template>
                  <td><xsl:value-of select="@CodedValue"/></td>
                </xsl:element>


              </xsl:for-each>
            </table>
          </fieldset>
        </xsl:for-each>

      </xsl:element>

      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>


    <!-- ***************************************** -->
    <!-- Code List Items                           -->
    <!-- ***************************************** -->

    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:CodeListItem]">

      <div id="decodelist">
      
        <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:CodeListItem]">
  
          <fieldset>
            <xsl:attribute name="id">CL.<xsl:value-of select="@OID"/></xsl:attribute>
            <legend>Code List - <xsl:value-of select="@Name"/>, Reference Name (<xsl:value-of
                select="@OID"/>) </legend>
            <table>
  
             <tr class="header">
                <th scope="col" class="codedvalue">Coded Value</th>
                <th scope="col">Decode</th>
              </tr>
  
              <xsl:for-each select="./odm:CodeListItem">
                <xsl:sort data-type="number" select="@Rank" order="ascending"/>
                <xsl:element name="tr">
  
                  <xsl:call-template name="rowClass">
                    <xsl:with-param name="rowNum" select="position()"/>
                  </xsl:call-template>
                  <td><xsl:value-of select="@CodedValue"/></td>
                  <td><xsl:value-of select="./odm:Decode/odm:TranslatedText"/></td>
                </xsl:element>
              </xsl:for-each>
            </table>
          </fieldset>
          <xsl:call-template name="lineBreak"/>
        </xsl:for-each>

      </div>

      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>

    </xsl:if>

    <!-- ***************************************** -->
    <!-- External Dictionaries                     -->
    <!-- ***************************************** -->
    
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList[odm:ExternalCodeList]">
      
      <xsl:element name="fieldset">
        <!-- page break after -->
        <xsl:attribute name="style">
          <xsl:text>page-break-after: always;</xsl:text>
        </xsl:attribute>
        
        <xsl:attribute name="id">externaldictionary</xsl:attribute>
        
        <!-- set the fieldset legend (title) -->
        <xsl:element name="legend">External Dictionaries</xsl:element>
        
        <table>
          
          <tr class="header">
            <th scope="col">Reference Name</th>
            <th scope="col">External Dictionary</th>
            <th scope="col">Dictionary Version</th>
          </tr>
          
          <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/odm:CodeList/odm:ExternalCodeList">
            
            <xsl:element name="tr">
              
              <!-- Create an anchor -->
              <xsl:attribute name="id">CL.<xsl:value-of select="../@OID"/></xsl:attribute>
              
              <xsl:call-template name="rowClass">
                <xsl:with-param name="rowNum" select="position()"/>
              </xsl:call-template>
              
              <td><xsl:value-of select="../@Name"/> (<xsl:value-of select="../@OID" />)</td>
              <td>
                <xsl:value-of select="@Dictionary"/>
              </td>
              <td>
                <xsl:value-of select="@Version"/>
              </td>
            </xsl:element>
          </xsl:for-each>
        </table>
      </xsl:element>
      
      <xsl:call-template name="linktop"/>
      <xsl:call-template name="lineBreak"/>
      
    </xsl:if>
    


  </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template: SupplementalDataDefinitionDoc                       -->
  <!-- ************************************************************* -->
  <xsl:template name="SupplementalDataDefinitionDoc">
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:SupplementalDoc">
      <xsl:for-each
        select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:SupplementalDoc/def:DocumentRef">
        <xsl:variable name="leafIDs" select="@leafID"/>
        <xsl:variable name="leaf" select="../../def:leaf[@ID=$leafIDs]"/>

        <p class="supplementaldatadefinition">
          <a>
            <xsl:attribute name="href">
              <xsl:value-of select="$leaf/@xlink:href"/>
            </xsl:attribute>
            <xsl:value-of select="$leaf/def:title"/>
          </a>
        </p>

      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <!-- ======================================================== -->
  <!-- Hypertext Link to CRF Pages (if necessary)               -->
  <!-- New mechanism: transform all numbers found in the string -->
  <!-- to hyperlinks                                            -->
  <!-- ======================================================== -->
  <xsl:template name="crfpagenumberstohyperlinks">
    <xsl:param name="ORIGINSTRING"/>
    <xsl:param name="SEPARATOR"/>
    <!--
  <xsl:message>ORIGINSTRING = <xsl:value-of select="$ORIGINSTRING"/></xsl:message>
  <xsl:message>STRING-LENGTH = <xsl:value-of select="string-length($ORIGINSTRING)"/></xsl:message>
  -->
    <!-- split the string in words, this is done recursively -->
    <xsl:variable name="first">
      <xsl:choose>
        <!-- the string contains the separator, select the part coming before the separator -->
        <xsl:when test="contains($ORIGINSTRING,$SEPARATOR)">
          <xsl:value-of select="substring-before($ORIGINSTRING,$SEPARATOR)"/>
        </xsl:when>
        <!-- the string does NOT contain the separator, just take the string -->
        <xsl:otherwise>
          <xsl:value-of select="$ORIGINSTRING"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="rest" select="substring-after($ORIGINSTRING,$SEPARATOR)"/>
    <!-- take the first part and check whether it contains a comma, then separate by comma when necessary -->
    <!--
  <xsl:message>FIRST = <xsl:value-of select="$first"/></xsl:message>
  <xsl:message>REST = <xsl:value-of select="$rest"/></xsl:message>
  -->
    <xsl:variable name="stringlengthfirst" select="string-length($first)"/>
    <xsl:if test="string-length($first) > 0">
      <!-- we need to test whether the word (after splitting of a possible comma or semicolon at the end, is a number -->
      <!-- split of the comma or semicolon -->
      <xsl:variable name="WORDWITHOUTCOMMAORSEMICOLON">
        <xsl:choose>
          <xsl:when test="substring($first,$stringlengthfirst) = ','">
            <!--xsl:message>Word ending with a comma</xsl:message-->
            <xsl:value-of select="substring($first,1,string-length($first)-1)"/>
          </xsl:when>
          <xsl:when test="substring($first,$stringlengthfirst) = ';'">
            <!--xsl:message>Word ending with a semicolon</xsl:message-->
            <xsl:value-of select="substring($first,1,string-length($first)-1)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$first"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- is the value of the variable WORDWITHOUTCOMMA a number? if so create a hyperling -->
      <!-- TODO: restore the blank and the comma -->
      <xsl:choose>
        <xsl:when test="number($WORDWITHOUTCOMMAORSEMICOLON)">
          <!-- it is a number, create the hyperlink -->
          <!--xsl:message>NUMBER = <xsl:value-of select="$WORDWITHOUTCOMMAORSEMICOLON"/></xsl:message-->
          <xsl:call-template name="createsinglepagehyperlink">
            <xsl:with-param name="pagenumber" select="$WORDWITHOUTCOMMAORSEMICOLON"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <!-- it is not a number -->
          <!--xsl:message>TEXT = <xsl:value-of select="$WORDWITHOUTCOMMAORSEMICOLON"/></xsl:message-->
          <xsl:value-of select="$WORDWITHOUTCOMMAORSEMICOLON"/>
          <xsl:value-of select="$SEPARATOR"/>
        </xsl:otherwise>
      </xsl:choose>
      <!-- add the comma or semicolon again if there was one at the end of the word -->
      <xsl:if test="substring($first,$stringlengthfirst) = ','">
        <xsl:value-of select="','"/>
      </xsl:if>
      <xsl:if test="substring($first,$stringlengthfirst) = ';'">
        <xsl:value-of select="';'"/>
      </xsl:if>
      <!-- and of course, the separator -->
      <xsl:value-of select="$SEPARATOR"/>
    </xsl:if>
    <!-- split up the second part in words (recursion) -->
    <xsl:if test="string-length($rest) > 0">
      <xsl:call-template name="crfpagenumberstohyperlinks">
        <xsl:with-param name="ORIGINSTRING" select="$rest"/>
        <xsl:with-param name="SEPARATOR" select="' '"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="createsinglepagehyperlink">
    <xsl:param name="pagenumber"/>
    <!--xsl:message>Creating individual hyperlink for page = <xsl:value-of select="$pagenumber"/></xsl:message-->
    <xsl:if test="/odm:ODM/odm:Study/odm:MetaDataVersion/def:AnnotatedCRF">
      <xsl:for-each select="/odm:ODM/odm:Study/odm:MetaDataVersion/def:AnnotatedCRF/def:DocumentRef">
        <xsl:variable name="leafIDs" select="@leafID"/>
        <xsl:variable name="leaf" select="../../def:leaf[@ID=$leafIDs]"/>
        <!-- create the hyperlink itself -->
        <a>
          <xsl:attribute name="href"><xsl:value-of select="concat($leaf/@xlink:href,'#page=',$pagenumber)"/></xsl:attribute>
          <xsl:value-of select="$pagenumber"/>
        </a>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>
  

  <!-- ************************************************************* -->
  <!-- Template:    rowClass                                         -->
  <!-- Description: This template sets the table row class attribute -->
  <!--              based on the specified table row number          -->
  <!-- ************************************************************* -->
  <xsl:template name="rowClass">
    <!-- rowNum: current table row number (1-based) -->
    <xsl:param name="rowNum"/>

    <!-- set the class attribute to "tableroweven" for even rows, "tablerowodd" for odd rows -->
    <xsl:attribute name="class">
      <xsl:choose>
        <xsl:when test="$rowNum mod 2 = 0">
          <xsl:text>tableroweven</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>tablerowodd</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template:    lineBreak                                        -->
  <!-- Description: This template adds a line break element          -->
  <!-- ************************************************************* -->
  <xsl:template name="lineBreak">
    <xsl:element name="br">
      <xsl:call-template name="noBreakSpace"/>
    </xsl:element>
  </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template:    noBreakSpace                                     -->
  <!-- Description: This template returns a no-break-space character -->
  <!-- ************************************************************* -->
  <xsl:template name="noBreakSpace">
    <!-- equivalent to &nbsp; -->
    <xsl:text></xsl:text>
  </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template: linktop                                             -->
  <!-- ************************************************************* -->
  <xsl:template name="linktop">
    <p class="linktop">Go to the <a href="#main">top</a> of the define.xml</p>
  </xsl:template>
  
  <!-- ************************************************************* -->
  <!-- Template: DocGenerationDate                                   -->
  <!-- ************************************************************* -->
  <xsl:template name="DocGenerationDate">
    <p class="documentinfo">Date of document generation: <xsl:value-of select="/odm:ODM/@CreationDateTime"/></p>
 </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template: StyleSheetDate                                      -->
  <!-- ************************************************************* -->
  <xsl:template name="StylesheetDate">
    <p class="stylesheetinfo">Stylesheet version: <xsl:value-of select="$g_stylesheetVersion"/></p>
    <xsl:call-template name="lineBreak"/>
  </xsl:template>

  <!-- ************************************************************* -->
  <!-- Template: "GenerateJavaScript"                                -->
  <!-- ************************************************************* -->
  <xsl:template name="GenerateJavaScript">

    <script type="text/javascript">
      <xsl:text disable-output-escaping="yes">
      <![CDATA[
      <!--  
      /**
       * With one argument, return the textContent or innerText of the element.
       * With two arguments, set the textContent or innerText of element to value.
       */
      function textContent(element, value) {
        var content = element.textContent;  // Check if textContent is defined
        if (value === undefined) { // No value passed, so return current text
            if (content !== undefined) return content;
            else return element.innerText;
        }
        else {                     // A value was passed, so set text
            if (content !== undefined) element.textContent = value;
            else element.innerText = value;
        }
      }
      
      ITEM  = '\u00A0';
      OPEN  = '\u25BC';
      CLOSE = '\u25BA';
      function toggle_submenu(e) {
        /** e.innerHTML = (textContent(e)==OPEN) ? CLOSE : OPEN; */
        
        if (textContent(e)==OPEN) {
          textContent(e, CLOSE);
        }
        else {
          textContent(e, OPEN);
        }
        
        for (var c, p=e.parentNode, i=0; c=p.childNodes[i]; i++)
          if (c.tagName=='UL') c.style.display=(c.style.display=='none') ? 'block' : 'none';
      }
      function reset_menus() {
        var li_tags = document.getElementsByTagName('LI');
        for (var li, i=0; li=li_tags[i]; i++) { 
          if ( li.className.match('hmenu-item') )
            for (var c, j=0; c=li.childNodes[j]; j++)
              if ( c.tagName == 'SPAN' && c.className.match('hmenu-bullet') ) {textContent(c, ITEM);}
          if ( li.className.match('hmenu-submenu') )
            for (var c, j=0; c=li.childNodes[j]; j++)
              if ( c.tagName == 'SPAN' && c.className.match('hmenu-bullet') ) {textContent(c, CLOSE);}
              else if ( c.tagName == 'UL' ) { c.style.display = 'none'; }
        }
      }
      //-->
      ]]>
      </xsl:text>
    </script>
  </xsl:template>


  <!-- ************************************************************* -->
  <!-- Template: "GenerateCSS"                                       -->
  <!-- ************************************************************* -->
  <xsl:template name="GenerateCSS">

    <style type="text/css">
      a{ color:blue; }
      a:hover{ color:#F90; }
      a.tocItem{
        color:#004A95;
        font-family:Arial, Helvetica, sans-serif;
        font-size:12px;
        font-weight:bold;
        text-decoration:none;
        margin-top:2px;
      }
      a.tocItem.level2{ margin-left:15px; }
      
      table{
        width:98%;
        border-spacing:4px;
        border-width:1px;
        border-style:solid;
        border-color:black;
        background-color:#EEEEEE;
        margin-top:5px;
        margin-bottom:5px;
        margin-left:5px;
        margin-right:0;
        border-collapse:collapse;
        empty-cells:show;
      }
      
      
      tr { border:1px solid black;}
      
      tr.header{
        background-color:#6699CC;
        color:#FFFFFF;
        font-family:Verdana, Arial, Helvetica, sans-serif;
        font-size:12px;
        font-weight:bold;
      }
      
      th{
        font-weight:bold;
        vertical-align:top;
        text-align: left;
        padding: 5px;
        border: 1px solid black;
        }

      th.codedvalue {width: 20%;} 
            
      td{
        font-family:Verdana, Arial, Helvetica, sans-serif;
        font-size:12px;
        vertical-align:top;
        padding: 5px;
        border: 1px solid black;
      }
      
      td.datatype {text-align: center; }
      td.number {text-align: right; }
      td.label{
        font-weight:bold; 
        width: 20%;
      }
      
      .hmenu li      { list-style:none; line-height:18px; padding-left:0; }
      .hmenu ul      { padding-left:14px; margin-left:0; }
      .hmenu-item    { }
      .hmenu-submenu { font-weight:bold; }
      .hmenu-bullet  { float:left; width:16px; color:#AAA; }
      
      ul { margin-left:0px; }
      
      legend{
        font-family:Verdana, Arial, Helvetica, sans-serif;
        font-size:14px;
        font-weight:bolder;
        text-align:left;
        color:maroon;
      }
      
      fieldset{
        width:98%;
      }
      
      fieldset.inner{
        margin-top:20px;
        margin-left:5px;
        margin-right:0px;
        border:none;
      }
      
      .code{
        font-family:monospace;
        white-space:pre;
        display:block;
        vertical-align:top;
      }
      
      .tablerowodd{ background-color:#FFFFFF; }
      .tableroweven{ background-color:#E2E2E2; }
      
      .linktop { font-size:12px; margin-top:5px; }
      .linksummary { font-size:12px; margin-top:5px; }
      .docgenerationdate  { font-size:12px; margin-top:5px; }
      .supplementaldatadefinition { font-size:12px; margin-top:5px; }
      
     
       .documentinfo, .stylesheetinfo{
       }

        span.error{
        width:95%;
        font-weight: bold;	
        padding:5px;
        color:#FF0000;
        border-spacing:4px;
        border:2px solid #FF0000;
        }
        td.error{
        color:#FF0000;
        }
        
        .standard{
        font-weight:bolder;
        text-align:left;
        padding:15px;
        margin-left:20px;
        margin-top:40px;
        margin-right:20px;
        margin-bottom:20px;
        color:#800000;
        border:0px;
        }

       #main .docinfo{
       width:95%;
       text-align:right;
       font-size:10px;
       }

       #menu{
        position:fixed;
        left:0px;
        width:20%;
        height:96%;
        bottom:0px;
        overflow:auto;
        background-color:white;
        color:black;
        border-width:0px;
        border-style:none;
        border-color:black;
        font-family:Verdana, Arial, sans-serif;
        font-size:12px;
        font-weight:bold;
        text-align:left;
        white-space:nowrap;
        margin-top:5px;
        }
      
      #main{
        position:absolute;
        left:20%;
        overflow:auto;
        font-family:Verdana, Arial, sans-serif;
        color:black;
        background-color:white;
        margin-top:5px;
        }

    </style>  

  </xsl:template>


</xsl:stylesheet>
