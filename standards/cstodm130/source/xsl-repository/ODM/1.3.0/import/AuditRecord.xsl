<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
  
	<xsl:template name="AuditRecord">         
          <xsl:for-each select="//odm:AuditRecord">
            <xsl:element name="AuditRecord">
                <xsl:element name="ID"><xsl:value-of select="@ID"/></xsl:element>
                <xsl:element name="EditPoint"><xsl:value-of select="@EditPoint"/></xsl:element>
                <xsl:element name="UsedImputationMethod"><xsl:value-of select="@UsedImputationMethod"/></xsl:element>
                <xsl:element name="UserOID"><xsl:value-of select="odm:UserRef/@UserOID"/></xsl:element>    
                <xsl:element name="LocationOID"><xsl:value-of select="odm:LocationRef/@LocationOID"/></xsl:element>
                <xsl:element name="DateTimeStamp"><xsl:value-of select="odm:DateTimeStamp"/></xsl:element>
                <xsl:element name="ReasonForChange"><xsl:value-of select="odm:ReasonForChange"/></xsl:element>
                <xsl:element name="SourceID"><xsl:value-of select="odm:SourceID"/></xsl:element>  
                <xsl:element name="ParentType"><xsl:value-of select="local-name(..)"/></xsl:element>
                <xsl:element name="ParentKey"><xsl:value-of select="generate-id(..)"/></xsl:element>           
            </xsl:element>
          </xsl:for-each>    
    </xsl:template>
  
</xsl:stylesheet>