<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ConditionDefTranslatedText.xsl"/>
    <xsl:import href="ConditionDefFormalExpression.xsl"/>
        
	<xsl:template name="ConditionDefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../ConditionDefs[FK_MetaDataVersion = $parentKey]">      
       
         <xsl:element name="ConditionDef">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>   
            
            <xsl:call-template name="ConditionDefTranslatedText">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>          
            <xsl:call-template name="ConditionDefFormalExpression">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>