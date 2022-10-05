<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
 
	<xsl:template name="User">	

      <xsl:element name="User">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="UserType"><xsl:value-of select="@UserType"/></xsl:element> 
         <xsl:element name="LoginName"><xsl:value-of select="odm:LoginName"/></xsl:element> 
         <xsl:element name="DisplayName"><xsl:value-of select="odm:DisplayName"/></xsl:element> 
         <xsl:element name="FullName"><xsl:value-of select="odm:FullName"/></xsl:element> 
         <xsl:element name="FirstName"><xsl:value-of select="odm:FirstName"/></xsl:element> 
         <xsl:element name="LastName"><xsl:value-of select="odm:LastName"/></xsl:element> 
         <xsl:element name="Organization"><xsl:value-of select="odm:Organization"/></xsl:element> 
         <xsl:element name="PictureImageType"><xsl:value-of select="odm:Picture/@ImageType"/></xsl:element> 
         <xsl:element name="PictureFileName"><xsl:value-of select="odm:Picture/@PictureFileName"/></xsl:element> 
         <xsl:element name="Pager"><xsl:value-of select="odm:Pager"/></xsl:element> 
         <xsl:element name="FK_AdminData"><xsl:value-of select="generate-id(..)"/></xsl:element>
      </xsl:element>

  </xsl:template>
</xsl:stylesheet>