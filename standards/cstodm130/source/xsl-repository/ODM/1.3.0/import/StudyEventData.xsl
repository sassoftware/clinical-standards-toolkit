<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="StudyEventData">
      
      <xsl:for-each select="odm:StudyEventData">
        <xsl:element name="StudyEventData">
          <!-- need to generate an OID -->
          <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element> 
          <xsl:element name="StudyEventOID"><xsl:value-of select="@StudyEventOID"/></xsl:element>
          <xsl:element name="StudyEventRepeatKey"><xsl:value-of select="@StudyEventRepeatKey"/></xsl:element>
          <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
          <xsl:element name="FK_SubjectData"><xsl:value-of select="generate-id(..)"/></xsl:element> 
        </xsl:element>                  
      </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>