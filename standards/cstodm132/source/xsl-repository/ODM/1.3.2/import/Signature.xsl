<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="Signature">
          
          <xsl:for-each select="//odm:Signature">
            <xsl:element name="Signature">
                <xsl:element name="ID"><xsl:value-of select="@ID"/></xsl:element>                
                <xsl:element name="UserOID"><xsl:value-of select="odm:UserRef/@UserOID"/></xsl:element>    
                <xsl:element name="LocationOID"><xsl:value-of select="odm:LocationRef/@LocationOID"/></xsl:element>
                <xsl:element name="SignatureDefOID"><xsl:value-of select="odm:SignatureRef/@SignatureOID"/></xsl:element>
                <xsl:element name="DateTimeStamp"><xsl:value-of select="odm:DateTimeStamp"/></xsl:element>
                <xsl:element name="ParentType"><xsl:value-of select="local-name(..)"/></xsl:element>
                <xsl:element name="ParentKey"><xsl:value-of select="generate-id(..)"/></xsl:element>           
                <xsl:element name="GrandParentType"><xsl:value-of select="local-name(../..)"/></xsl:element>
                <xsl:element name="GrandParentKey"><xsl:value-of select="generate-id(../..)"/></xsl:element> 
            </xsl:element>
          </xsl:for-each>    

    </xsl:template>
  
</xsl:stylesheet>