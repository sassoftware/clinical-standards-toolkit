<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:xlink="http://www.w3.org/1999/xlink">

	<xsl:template name="ItemAliases">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../ItemAliases[FK_ItemDefs = $parentKey]">      
       
         <xsl:element name="Alias">
               <xsl:attribute name="Context"><xsl:value-of select="Context"/></xsl:attribute>
               <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>