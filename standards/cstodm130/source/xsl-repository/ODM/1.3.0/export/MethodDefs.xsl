<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="MethodDefTranslatedText.xsl"/>
    <xsl:import href="MethodDefFormalExpression.xsl"/>
        
	<xsl:template name="MethodDefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../MethodDefs[FK_MetaDataVersion = $parentKey]">      
       
         <xsl:element name="MethodDef">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>   
            <xsl:if test="string-length(normalize-space(Type)) &gt; 0">
              <xsl:attribute name="Type"><xsl:value-of select="Type"/></xsl:attribute>
            </xsl:if>
            
            <xsl:call-template name="MethodDefTranslatedText">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>          
            <xsl:call-template name="MethodDefFormalExpression">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>