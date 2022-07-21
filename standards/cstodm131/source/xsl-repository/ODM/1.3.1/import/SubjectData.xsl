<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="SubjectData">
      
      <xsl:for-each select="odm:SubjectData">
        <xsl:element name="SubjectData">
          <!-- need to generate an OID -->
          <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element> 
          <xsl:element name="SubjectKey"><xsl:value-of select="@SubjectKey"/></xsl:element>
          <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
          <xsl:element name="InvestigatorRefOID"><xsl:value-of select="odm:InvestigatorRef/@UserOID"/></xsl:element>
          <xsl:element name="SiteRefOID"><xsl:value-of select="odm:SiteRef/@LocationOID"/></xsl:element>
          <xsl:element name="FK_ClinicalData"><xsl:value-of select="generate-id(..)"/></xsl:element> 
        </xsl:element>                  
      </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>