<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2">

	<xsl:template name="Presentation">
	
	     <xsl:param name="parentKey" />
       
         <xsl:for-each select="../Presentation[FK_MetaDataVersion = $parentKey]">
       
          <xsl:element name="Presentation">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>  
            <xsl:if test="string-length(normalize-space(lang)) &gt; 0">
                <xsl:attribute name="xml:lang"><xsl:value-of select="lang"/></xsl:attribute>
            </xsl:if>         
            <xsl:value-of select="presentation"/>               
          </xsl:element>
        
         </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>