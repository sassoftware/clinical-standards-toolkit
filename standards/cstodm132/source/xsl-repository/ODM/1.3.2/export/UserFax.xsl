<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
        
	<xsl:template name="UserFax">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../UserFax[FK_User = $parentKey]">      
       
         <xsl:if test="string-length(normalize-space(Fax)) &gt; 0">
             <xsl:element name="Fax"><xsl:value-of select="Fax"/></xsl:element>
         </xsl:if>
                
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>