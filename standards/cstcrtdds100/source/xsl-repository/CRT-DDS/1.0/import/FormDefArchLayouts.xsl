<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0">

	<xsl:template name="FormDefArchLayouts">	
    
    <xsl:for-each select=".">

      <xsl:element name="FormDefArchLayouts">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="PdfFileName"><xsl:value-of select="@PdfFileName"/></xsl:element> 
         <xsl:element name="PresentationOID"><xsl:value-of select="@PresentationOID"/></xsl:element>
         <xsl:element name="FK_FormDefs"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      
    </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>