<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="LocationVersion">	

      <xsl:element name="LocationVersion">
         <xsl:element name="StudyOID"><xsl:value-of select="@StudyOID"/></xsl:element> 
         <xsl:element name="MetaDataVersionOID"><xsl:value-of select="@MetaDataVersionOID"/></xsl:element> 
         <xsl:element name="EffectiveDate"><xsl:value-of select="@EffectiveDate"/></xsl:element> 
         <xsl:element name="FK_Location"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>