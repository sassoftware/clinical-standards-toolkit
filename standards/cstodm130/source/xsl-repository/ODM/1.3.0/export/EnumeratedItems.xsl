<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="EnumeratedItems">

	  <xsl:param name="parentKey" />
          <xsl:for-each select="../EnumeratedItems[FK_CodeLists = $parentKey]">  
              
              <xsl:element name="EnumeratedItem">
                 <xsl:attribute name="CodedValue"><xsl:value-of select="CodedValue"/></xsl:attribute>
	             <xsl:if test="string-length(normalize-space(Rank)) &gt; 0">
	                  <xsl:attribute name="Rank"><xsl:value-of select="Rank" /></xsl:attribute>
	              </xsl:if>

              </xsl:element>        
              
         </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>