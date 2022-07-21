<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="FormData">
      
      <xsl:for-each select="odm:FormData">
        <xsl:element name="FormData">
          <!-- need to generate an OID -->
          <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element> 
          <xsl:element name="FormOID"><xsl:value-of select="@FormOID"/></xsl:element>
          <xsl:element name="FormRepeatKey"><xsl:value-of select="@FormRepeatKey"/></xsl:element>
          <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
          <xsl:element name="ArchiveLayoutRefOID"><xsl:value-of select="odm:ArchiveLayoutRef/@ArchiveLayoutOID"/></xsl:element>
          <xsl:element name="FK_StudyEventData"><xsl:value-of select="generate-id(..)"/></xsl:element> 
        </xsl:element>                  
      </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>