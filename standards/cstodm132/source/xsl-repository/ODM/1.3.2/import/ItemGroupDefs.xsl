<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ItemGroupDefTranslatedText.xsl" />
    <xsl:import href="ItemGroupDefItemRefs.xsl" />
    <xsl:import href="ItemGroupAliases.xsl" />

	<xsl:template name="ItemGroupDefs">	
    
    <xsl:for-each select="odm:ItemGroupDef">

      <xsl:element name="ItemGroupDefs">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element> 
         <xsl:element name="Repeating"><xsl:value-of select="@Repeating"/></xsl:element> 
         <xsl:element name="IsReferenceData"><xsl:value-of select="@IsReferenceData"/></xsl:element>
         <xsl:element name="SASDatasetName"><xsl:value-of select="@SASDatasetName"/></xsl:element>
         <xsl:element name="Domain"><xsl:value-of select="@Domain"/></xsl:element>
         <xsl:element name="Origin"><xsl:value-of select="@Origin"/></xsl:element>
         <xsl:element name="Role"><xsl:value-of select="@Role"/></xsl:element>
         <xsl:element name="Purpose"><xsl:value-of select="@Purpose"/></xsl:element>
         <xsl:element name="Comment"><xsl:value-of select="@Comment"/></xsl:element>
         <xsl:element name="FK_MetaDataVersion"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      
    </xsl:for-each>
 
    <xsl:for-each select="odm:ItemGroupDef/odm:Description">
      <xsl:call-template name="ItemGroupDefTranslatedText"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemGroupDef/odm:ItemRef">
      <xsl:call-template name="ItemGroupDefItemRefs"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemGroupDef/odm:Alias">
      <xsl:call-template name="ItemGroupAliases"/>
    </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>