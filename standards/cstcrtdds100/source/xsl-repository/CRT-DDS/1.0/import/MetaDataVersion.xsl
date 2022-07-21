<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0">

    <xsl:import href="AnnotatedCRFs.xsl" />
    <xsl:import href="SupplementalDocs.xsl" />
    <xsl:import href="MDVLeaf.xsl" />
    <xsl:import href="ComputationMethods.xsl" />
    <xsl:import href="ValueLists.xsl" />
    <xsl:import href="ProtocolEventRefs.xsl" />
    <xsl:import href="StudyEventDefs.xsl" />
    <xsl:import href="FormDefs.xsl" />
    <xsl:import href="ItemGroupDefs.xsl" />
    <xsl:import href="ItemDefs.xsl" />
    <xsl:import href="CodeLists.xsl" />
    <xsl:import href="ExternalCodeLists.xsl" />
    <xsl:import href="CodeListItems.xsl" />
    <xsl:import href="CLItemDecodeTranslatedText.xsl" />
    <xsl:import href="ImputationMethods.xsl" />
    <xsl:import href="Presentation.xsl" />
 
	<xsl:template name="MetaDataVersion">	
    
    <xsl:for-each select="odm:MetaDataVersion">

      <xsl:element name="MetaDataVersion">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element> 
         <xsl:element name="Description"><xsl:value-of select="@Description"/></xsl:element> 
         <xsl:element name="IncludedOID"><xsl:value-of select="Include/@MetaDataVersionOID"/></xsl:element>
         <xsl:element name="IncludedStudyOID"><xsl:value-of select="Include/@StudyOID"/></xsl:element>
         <xsl:element name="DefineVersion"><xsl:value-of select="@def:DefineVersion"/></xsl:element>
         <xsl:element name="StandardName"><xsl:value-of select="@def:StandardName"/></xsl:element>
         <xsl:element name="StandardVersion"><xsl:value-of select="@def:StandardVersion"/></xsl:element>
         <xsl:element name="FK_Study"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      
      <xsl:call-template name="AnnotatedCRFs"/>
      <xsl:call-template name="SupplementalDocs"/>
      <xsl:call-template name="MDVLeaf"/>
      <xsl:call-template name="ComputationMethods"/>
      <xsl:call-template name="ValueLists"/>
      <xsl:call-template name="ProtocolEventRefs"/>
      <xsl:call-template name="StudyEventDefs"/>
      <xsl:call-template name="FormDefs"/>
      <xsl:call-template name="ItemGroupDefs"/>
      <xsl:call-template name="ItemDefs"/>
      <xsl:call-template name="CodeLists"/>
      
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:ExternalCodeList">
      <xsl:call-template name="ExternalCodeLists"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem">
      <xsl:call-template name="CodeListItems"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem/odm:Decode/odm:TranslatedText">
      <xsl:call-template name="CLItemDecodeTranslatedText"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:ImputationMethod">
      <xsl:call-template name="ImputationMethods"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:Presentation">
      <xsl:call-template name="Presentation"/>
    </xsl:for-each>
           	
  </xsl:template>
</xsl:stylesheet>