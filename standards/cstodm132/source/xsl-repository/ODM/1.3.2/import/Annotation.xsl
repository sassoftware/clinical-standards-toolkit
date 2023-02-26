<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="Annotation">
          
          <xsl:for-each select="odm:ClinicalData//odm:Annotation | odm:ReferenceData//odm:Annotation | odm:Association/odm:Annotation">
            <xsl:element name="Annotation">
                <!--  the ID attribute is not required, so we must generate one that is guaranteed to exist -->
                <xsl:element name="GeneratedID"><xsl:value-of select="generate-id(.)"/></xsl:element>
                <xsl:element name="ID"><xsl:value-of select="@ID"/></xsl:element>
                <xsl:element name="SeqNum"><xsl:value-of select="@SeqNum"/></xsl:element>
                <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
                <xsl:element name="CommentSponsorOrSite"><xsl:value-of select="odm:Comment/@SponsorOrSite"/></xsl:element>    
                <xsl:element name="Comment"><xsl:value-of select="odm:Comment"/></xsl:element>
                <xsl:element name="ParentType"><xsl:value-of select="local-name(..)"/></xsl:element>
                <xsl:element name="ParentKey"><xsl:value-of select="generate-id(..)"/></xsl:element> 
                <xsl:element name="GrandParentType"><xsl:value-of select="local-name(../..)"/></xsl:element>
                <xsl:element name="GrandParentKey"><xsl:value-of select="generate-id(../..)"/></xsl:element> 
            </xsl:element>
          </xsl:for-each>    

    </xsl:template>
  
</xsl:stylesheet>