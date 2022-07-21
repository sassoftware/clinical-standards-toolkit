<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="KeySet">	
     <xsl:for-each select="odm:KeySet">
      <xsl:element name="KeySet">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="StudyOID"><xsl:value-of select="@StudyOID"/></xsl:element>         
         <xsl:element name="SubjectKey"><xsl:value-of select="@SubjectKey"/></xsl:element> 
         <xsl:element name="StudyEventOID"><xsl:value-of select="@StudyEventOID"/></xsl:element> 
         <xsl:element name="StudyEventRepeatKey"><xsl:value-of select="@StudyEventRepeatKey"/></xsl:element> 
         <xsl:element name="FormOID"><xsl:value-of select="@FormOID"/></xsl:element> 
         <xsl:element name="FormRepeatKey"><xsl:value-of select="@FormRepeatKey"/></xsl:element> 
         <xsl:element name="ItemGroupOID"><xsl:value-of select="@ItemGroupOID"/></xsl:element> 
         <xsl:element name="ItemGroupRepeatKey"><xsl:value-of select="@ItemGroupRepeatKey"/></xsl:element> 
         <xsl:element name="ItemOID"><xsl:value-of select="@ItemOID"/></xsl:element>        
         <xsl:element name="FK_Association"><xsl:value-of select="generate-id(..)"/></xsl:element>
      </xsl:element>   
     </xsl:for-each>      	
  </xsl:template>
  
</xsl:stylesheet>