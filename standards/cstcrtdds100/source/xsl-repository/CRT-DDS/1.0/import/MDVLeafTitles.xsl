<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0">

	<xsl:template name="MDVLeafTitles">	
    
    <xsl:for-each select=".">

      <xsl:element name="MDVLeafTitles">
         <xsl:element name="title"><xsl:value-of select="."/></xsl:element> 
         <xsl:element name="FK_MDVLeaf"><xsl:value-of select="../@ID"/></xsl:element>
      </xsl:element>
      
    </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>