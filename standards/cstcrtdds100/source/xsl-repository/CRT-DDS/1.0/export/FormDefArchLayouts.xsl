<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:xlink="http://www.w3.org/1999/xlink">

	<xsl:template name="FormDefArchLayouts">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../FormDefArchLayouts[FK_FormDefs = $parentKey]">      
       
         <xsl:element name="ArchiveLayout">
               <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
               <xsl:attribute name="PdfFileName"><xsl:value-of select="PdfFileName"/></xsl:attribute>
               <xsl:if test="string-length(normalize-space(PresentationOID)) &gt; 0">
                  <xsl:attribute name="PresentationOID"><xsl:value-of select="PresentationOID"/></xsl:attribute>
               </xsl:if>
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>