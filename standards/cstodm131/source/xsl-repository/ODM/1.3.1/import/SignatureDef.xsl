<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="SignatureDef">	

      <xsl:element name="SignatureDef">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Methodology"><xsl:value-of select="@Methodology"/></xsl:element> 
         <xsl:element name="Meaning"><xsl:value-of select="odm:Meaning"/></xsl:element> 
         <xsl:element name="LegalReason"><xsl:value-of select="odm:LegalReason"/></xsl:element> 
         <xsl:element name="FK_AdminData"><xsl:value-of select="generate-id(..)"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>