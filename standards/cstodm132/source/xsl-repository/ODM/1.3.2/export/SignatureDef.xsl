<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

        
	<xsl:template name="SignatureDef">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../SignatureDef[FK_AdminData = $parentKey]">      
       
         <xsl:element name="SignatureDef">
  
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
 
            <xsl:if test="string-length(normalize-space(Methodology)) &gt; 0">
               <xsl:attribute name="Methodology"><xsl:value-of select="Methodology"/></xsl:attribute>
            </xsl:if>
  
            <xsl:element name="Meaning"><xsl:value-of select="Meaning"/></xsl:element>
            <xsl:element name="LegalReason"><xsl:value-of select="LegalReason"/></xsl:element>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>