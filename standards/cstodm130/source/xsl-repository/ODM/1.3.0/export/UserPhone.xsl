<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
        
	<xsl:template name="UserPhone">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../UserPhone[FK_User = $parentKey]">      
       
         <xsl:if test="string-length(normalize-space(Phone)) &gt; 0">
             <xsl:element name="Phone"><xsl:value-of select="Phone"/></xsl:element>
         </xsl:if>
                
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>