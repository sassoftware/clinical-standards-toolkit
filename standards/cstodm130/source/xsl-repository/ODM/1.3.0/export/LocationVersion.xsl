<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
    
	<xsl:template name="LocationVersion">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../LocationVersion[FK_Location = $parentKey]">      
         
           <xsl:element name="MetaDataVersionRef">
               <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/></xsl:attribute>
               <xsl:attribute name="MetaDataVersionOID"><xsl:value-of select="MetaDataVersionOID"/></xsl:attribute>
               <xsl:attribute name="EffectiveDate"><xsl:value-of select="EffectiveDate"/></xsl:attribute>
           </xsl:element>

       </xsl:for-each>
       
   </xsl:template> 
</xsl:stylesheet>