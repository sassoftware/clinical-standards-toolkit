<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ItemGroupData.xsl" />
    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Annotation.xsl" />   
    <xsl:import href="Signature.xsl" />

	<xsl:template name="ReferenceData">
      
      <xsl:for-each select="ReferenceData">
           
          <xsl:element name="ReferenceData">
              <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/></xsl:attribute>
              <xsl:attribute name="MetaDataVersionOID"><xsl:value-of select="MetaDataVersionOID"/></xsl:attribute>
                       
              <xsl:call-template name="ItemGroupData">
                  <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
              </xsl:call-template>

              <xsl:call-template name="AuditRecord">
                <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
                <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
              </xsl:call-template>

              <xsl:call-template name="Signature">
                <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
                <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
              </xsl:call-template>

              <xsl:call-template name="Annotation">
                <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
                <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
              </xsl:call-template>

            
          </xsl:element>
          
      </xsl:for-each>    
        	
    </xsl:template>
</xsl:stylesheet>