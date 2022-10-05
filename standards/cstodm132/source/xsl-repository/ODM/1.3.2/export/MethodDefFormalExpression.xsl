<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="MethodDefFormalExpression">

	  <xsl:param name="parentKey" />
    
      <xsl:for-each select="../MethodDefFormalExpression[FK_MethodDefs = $parentKey]">      
         <xsl:element name="FormalExpression">
            <xsl:attribute name="Context"><xsl:value-of select="Context"/></xsl:attribute>
            <xsl:value-of select="Expression"/>
         </xsl:element>        
      </xsl:for-each>

	</xsl:template>
</xsl:stylesheet>