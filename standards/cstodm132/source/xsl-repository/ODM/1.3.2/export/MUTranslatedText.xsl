<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="MUTranslatedText">

	  <xsl:param name="parentKey" />

<!--  The Symbol element is required to be present as a child of MeasurementUnit.
      We will output it even if it contains no TransltedText elements.
      The output document will not validate in this situation regardless. -->
      
       <xsl:element name="Symbol">
       
         <xsl:for-each select="../MUTranslatedText[FK_MeasurementUnits = $parentKey]">
       
          <xsl:element name="TranslatedText">
            <xsl:if test="string-length(normalize-space(lang)) &gt; 0">
                <xsl:attribute name="xml:lang"><xsl:value-of select="lang"/></xsl:attribute>
            </xsl:if>
            <xsl:value-of select="TranslatedText"/>
          </xsl:element>
        
         </xsl:for-each>
      
       </xsl:element>
        	
  </xsl:template>
</xsl:stylesheet>