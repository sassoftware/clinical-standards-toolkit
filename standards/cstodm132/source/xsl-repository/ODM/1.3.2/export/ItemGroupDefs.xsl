<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ItemGroupDefTranslatedText.xsl"/>
    <xsl:import href="ItemGroupDefItemRefs.xsl"/>
    <xsl:import href="ItemGroupAliases.xsl"/>

	<xsl:template name="ItemGroupDefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../ItemGroupDefs[FK_MetaDataVersion = $parentKey]">      
       
         <xsl:element name="ItemGroupDef">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
            <xsl:attribute name="Repeating"><xsl:value-of select="Repeating"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(IsReferenceData)) &gt; 0">
              <xsl:attribute name="IsReferenceData"><xsl:value-of select="IsReferenceData"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(SASDatasetName)) &gt; 0">
              <xsl:attribute name="SASDatasetName"><xsl:value-of select="SASDatasetName"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Domain)) &gt; 0">
              <xsl:attribute name="Domain"><xsl:value-of select="Domain"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Origin)) &gt; 0">
              <xsl:attribute name="Origin"><xsl:value-of select="Origin"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Role)) &gt; 0">
              <xsl:attribute name="Role"><xsl:value-of select="Role"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Purpose)) &gt; 0">
              <xsl:attribute name="Purpose"><xsl:value-of select="Purpose"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Comment)) &gt; 0">
              <xsl:attribute name="Comment"><xsl:value-of select="Comment"/></xsl:attribute>
            </xsl:if>
            <xsl:call-template name="ItemGroupDefTranslatedText">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemGroupDefItemRefs">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemGroupAliases">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>                       
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>