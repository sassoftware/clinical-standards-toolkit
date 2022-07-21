<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
        
	<xsl:template name="AnnotationFlag">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../AnnotationFlag[FK_Annotation = $parentKey]">      
       
         <xsl:element name="Flag">
  
            <xsl:element name="FlagValue">
                <xsl:attribute name="CodeListOID"><xsl:value-of select="FlagValueCodeListOID"/></xsl:attribute>
                <xsl:value-of select="FlagValue"/>
            </xsl:element>
 
            <xsl:element name="FlagType">
                <xsl:if test="string-length(normalize-space(FlagTypeCodeListOID)) &gt; 0">
                    <xsl:attribute name="CodeListOID"><xsl:value-of select="FlagTypeCodeListOID"/></xsl:attribute>
                </xsl:if>
                <xsl:value-of select="FlagType"/>
            </xsl:element>
         
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>