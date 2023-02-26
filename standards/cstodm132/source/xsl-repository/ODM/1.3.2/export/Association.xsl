<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="KeySet.xsl" />
    <xsl:import href="Annotation.xsl" />

	<xsl:template name="Association">
	
      <xsl:for-each select="Association">
           
          <xsl:element name="Association">
              <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/></xsl:attribute>
              <xsl:attribute name="MetaDataVersionOID"><xsl:value-of select="MetaDataVersionOID"/></xsl:attribute>
                       
              <xsl:call-template name="KeySet">
                  <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
              </xsl:call-template>

              <xsl:call-template name="Annotation">
                  <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
                  <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
              </xsl:call-template>
          </xsl:element>
          
      </xsl:for-each>    
        	
    </xsl:template>
</xsl:stylesheet>