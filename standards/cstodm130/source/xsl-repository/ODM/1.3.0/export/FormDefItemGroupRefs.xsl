<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="FormDefItemGroupRefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../FormDefItemGroupRefs[FK_FormDefs = $parentKey]">      
       
         <xsl:element name="ItemGroupRef">
               <xsl:attribute name="ItemGroupOID"><xsl:value-of select="ItemGroupOID"/></xsl:attribute>
               <xsl:attribute name="Mandatory"><xsl:value-of select="Mandatory"/></xsl:attribute>
               <xsl:if test="string-length(normalize-space(OrderNumber)) &gt; 0">
                  <xsl:attribute name="OrderNumber"><xsl:value-of select="OrderNumber"/></xsl:attribute>
               </xsl:if>
               <xsl:if test="string-length(normalize-space(CollectionExceptionConditionOID)) &gt; 0">
                  <xsl:attribute name="CollectionExceptionConditionOID"><xsl:value-of select="CollectionExceptionConditionOID"/></xsl:attribute>
               </xsl:if>
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>