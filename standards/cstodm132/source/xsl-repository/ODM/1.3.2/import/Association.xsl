<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
  
	<xsl:template name="Association"> 
        <xsl:for-each select="odm:Association">               
          <xsl:element name="Association">
            <xsl:element name="GeneratedID"><xsl:value-of select="generate-id(.)"/></xsl:element>
            <xsl:element name="StudyOID"><xsl:value-of select="@StudyOID"/></xsl:element>
            <xsl:element name="MetaDataVersionOID"><xsl:value-of select="@MetaDataVersionOID"/></xsl:element> 
            <xsl:element name="FK_ODM"><xsl:value-of select="../@FileOID"/></xsl:element>
          </xsl:element>
       </xsl:for-each>  
  </xsl:template>
</xsl:stylesheet>