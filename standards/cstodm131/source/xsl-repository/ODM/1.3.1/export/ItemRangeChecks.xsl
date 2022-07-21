<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ItemRangeCheckValues.xsl"/>
    <xsl:import href="ItemRCFormalExpression.xsl"/>
    <xsl:import href="RCErrorTranslatedText.xsl"/>

	<xsl:template name="ItemRangeChecks">

	  <xsl:param name="parentKey" />
    
          <xsl:for-each select="../ItemRangeChecks[FK_ItemDefs = $parentKey]">      
              <xsl:element name="RangeCheck">
                <xsl:attribute name="Comparator"><xsl:value-of select="Comparator"/></xsl:attribute>
                <xsl:attribute name="SoftHard"><xsl:value-of select="SoftHard"/></xsl:attribute>
                
                <xsl:call-template name="ItemRangeCheckValues">
                  <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
                </xsl:call-template> 
                
                <xsl:call-template name="ItemRCFormalExpression">
                  <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
                </xsl:call-template> 

                <xsl:if test="string-length(normalize-space(MURefOID)) &gt; 0">
                   <xsl:element name="MeasurementUnitRef">
                      <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MURefOID"/></xsl:attribute>
                   </xsl:element>
                </xsl:if>

                <xsl:call-template name="RCErrorTranslatedText">
                  <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
                </xsl:call-template> 
                                                
              </xsl:element>        
         </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>