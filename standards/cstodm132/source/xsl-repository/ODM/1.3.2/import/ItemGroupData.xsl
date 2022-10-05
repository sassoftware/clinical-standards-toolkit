<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="ItemGroupData">
      
      <xsl:for-each select="odm:ItemGroupData">
        <xsl:element name="ItemGroupData">
          <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element> 
          <xsl:element name="ItemGroupOID"><xsl:value-of select="@ItemGroupOID"/></xsl:element>
          <xsl:element name="ItemGroupRepeatKey"><xsl:value-of select="@ItemGroupRepeatKey"/></xsl:element>
          <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
          <xsl:element name="FK_FormData">
            <xsl:if test="local-name(..) = 'FormData'">
              <xsl:value-of select="generate-id(..)"/> 
            </xsl:if>
          </xsl:element>
          <xsl:element name="FK_ReferenceData">
            <xsl:if test="local-name(..) = 'ReferenceData'">
              <xsl:value-of select="generate-id(..)"/>
            </xsl:if>
          </xsl:element> 
        </xsl:element>                  
      </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>