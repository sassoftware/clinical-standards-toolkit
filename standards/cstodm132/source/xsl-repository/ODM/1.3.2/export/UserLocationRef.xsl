<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
        
	<xsl:template name="UserLocationRef">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../UserLocationRef[FK_User = $parentKey]">      
            <xsl:element name="LocationRef">
            <xsl:attribute name="LocationOID"><xsl:value-of select="LocationOID"/></xsl:attribute>
            </xsl:element>
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>