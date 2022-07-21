<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="UserAddress">	

      <xsl:element name="UserAddress">
         <xsl:element name="GeneratedID"><xsl:value-of select="generate-id(.)"/></xsl:element>
         <xsl:element name="City"><xsl:value-of select="odm:City"/></xsl:element> 
         <xsl:element name="StateProv"><xsl:value-of select="odm:StateProv"/></xsl:element> 
         <xsl:element name="Country"><xsl:value-of select="odm:Country"/></xsl:element> 
         <xsl:element name="PostalCode"><xsl:value-of select="odm:PostalCode"/></xsl:element> 
         <xsl:element name="OtherText"><xsl:value-of select="odm:OtherText"/></xsl:element> 
         <xsl:element name="FK_User"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>