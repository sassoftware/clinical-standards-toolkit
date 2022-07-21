<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="UserLocationRef">	

      <xsl:element name="UserLocationRef">
         <xsl:element name="LocationOID"><xsl:value-of select="@LocationOID"/></xsl:element> 
         <xsl:element name="FK_User"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>