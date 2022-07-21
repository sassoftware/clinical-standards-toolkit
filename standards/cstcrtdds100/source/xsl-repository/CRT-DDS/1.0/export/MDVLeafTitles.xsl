<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2">

	<xsl:template name="MDVLeafTitles">
	
	     <xsl:param name="parentKey" />
       
         <xsl:for-each select="../MDVLeafTitles[FK_MDVLeaf = $parentKey]">
       
          <xsl:element name="def:title">
            <xsl:value-of select="title"/>
          </xsl:element>
        
         </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>