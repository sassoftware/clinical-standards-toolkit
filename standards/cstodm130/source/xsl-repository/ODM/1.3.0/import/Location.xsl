<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="Location">	

      <xsl:element name="Location">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element> 
         <xsl:element name="LocationType"><xsl:value-of select="@LocationType"/></xsl:element> 
         <xsl:element name="FK_AdminData"><xsl:value-of select="generate-id(..)"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>