<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:xlink="http://www.w3.org/1999/xlink">

	<xsl:template name="ValueListItemRefs">
	
	     <xsl:param name="parentKey" />
       
         <xsl:for-each select="../ValueListItemRefs[FK_ValueLists = $parentKey]">      
       
          <xsl:element name="ItemRef">
            <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(OrderNumber)) &gt; 0">
               <xsl:attribute name="OrderNumber"><xsl:value-of select="OrderNumber"/></xsl:attribute>
            </xsl:if>
            <xsl:attribute name="Mandatory"><xsl:value-of select="Mandatory"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(KeySequence)) &gt; 0">
               <xsl:attribute name="KeySequence"><xsl:value-of select="KeySequence"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(ImputationMethodOID)) &gt; 0">
               <xsl:attribute name="ImputationMethodOID"><xsl:value-of select="ImputationMethodOID"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(Role)) &gt; 0">
               <xsl:attribute name="Role"><xsl:value-of select="Role"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(RoleCodeListOID)) &gt; 0">
               <xsl:attribute name="RoleCodeListOID"><xsl:value-of select="RoleCodeListOID"/></xsl:attribute>                         
            </xsl:if>
          </xsl:element>
        
         </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>