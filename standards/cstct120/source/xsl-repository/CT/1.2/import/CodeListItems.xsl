<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:odm="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:template name="CodeListItems">

    <xsl:for-each select=".">

      <xsl:element name="CodeListItems">
         <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element>
         <xsl:element name="CodedValue"><xsl:value-of select="@CodedValue"/></xsl:element>
         <xsl:element name="Rank"><xsl:value-of select="@Rank"/></xsl:element>
         <xsl:element name="OrderNumber"><xsl:value-of select="@OrderNumber"/></xsl:element> 
         <xsl:element name="ExtCodeID"><xsl:value-of select="@nciodm:ExtCodeID"/></xsl:element>
         <xsl:if test="string-length(normalize-space(nciodm:CDISCDefinition)) &gt; 0">
             <xsl:element name="CDISCDefinition"><xsl:value-of select="nciodm:CDISCDefinition/text()"/></xsl:element>
         </xsl:if>
         <xsl:if test="string-length(normalize-space(nciodm:PreferredTerm)) &gt; 0">
             <xsl:element name="PreferredTerm"><xsl:value-of select="nciodm:PreferredTerm/text()"/></xsl:element>
         </xsl:if>
         <xsl:element name="FK_CodeLists"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>

    </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>