<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="LocationVersion.xsl" />
        
	<xsl:template name="Location">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../Location[FK_AdminData = $parentKey]">      
       
         <xsl:element name="Location">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(LocationType)) &gt; 0">
               <xsl:attribute name="LocationType"><xsl:value-of select="LocationType"/></xsl:attribute>
            </xsl:if>

            <xsl:call-template name="LocationVersion">
                <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
         
         </xsl:element>       
         
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>