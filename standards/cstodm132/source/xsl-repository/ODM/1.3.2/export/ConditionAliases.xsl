<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

        <xsl:template name="ConditionAliases">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../ConditionAliases[FK_ConditionDefs = $parentKey]">      
       
         <xsl:element name="Alias">
               <xsl:attribute name="Context"><xsl:value-of select="Context"/></xsl:attribute>
               <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>