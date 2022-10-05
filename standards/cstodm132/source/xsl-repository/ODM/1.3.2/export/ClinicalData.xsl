<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="SubjectData.xsl" />
    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Annotation.xsl" />   
    <xsl:import href="Signature.xsl" />

	<xsl:template name="ClinicalData">
      
      <xsl:for-each select="ClinicalData">
           
          <xsl:element name="ClinicalData">
            <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/></xsl:attribute>
            <xsl:attribute name="MetaDataVersionOID"><xsl:value-of select="MetaDataVersionOID"/></xsl:attribute>
                       
            <xsl:call-template name="SubjectData">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>

            <xsl:call-template name="AuditRecord">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>

            <xsl:call-template name="Signature">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>

            <xsl:call-template name="Annotation">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>

            
          </xsl:element>
          
      </xsl:for-each>    
        	
  </xsl:template>
</xsl:stylesheet>