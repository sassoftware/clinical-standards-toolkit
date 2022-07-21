<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
        
	<xsl:template name="UserAddressStreetName">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../UserAddressStreetName[FK_UserAddress = $parentKey]">      
       
         <xsl:if test="string-length(normalize-space(StreetName)) &gt; 0">
             <xsl:element name="StreetName"><xsl:value-of select="StreetName"/></xsl:element>
         </xsl:if>
                
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>