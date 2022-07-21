<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="AnnotationFlag">
          
          <xsl:for-each select="//odm:Annotation/odm:Flag">
            <xsl:element name="AnnotationFlag">
                <xsl:element name="FlagValue"><xsl:value-of select="odm:FlagValue"/></xsl:element>
                <xsl:element name="FlagValueCodeListOID"><xsl:value-of select="odm:FlagValue/@CodeListOID"/></xsl:element>
                <xsl:element name="FlagType"><xsl:value-of select="odm:FlagType"/></xsl:element>
                <xsl:element name="FlagTypeCodeListOID"><xsl:value-of select="odm:FlagType/@CodeListOID"/></xsl:element>
                <xsl:element name="FK_Annotation"><xsl:value-of select="generate-id(..)"/></xsl:element>           
            </xsl:element>
          </xsl:for-each>    

    </xsl:template>
  
</xsl:stylesheet>