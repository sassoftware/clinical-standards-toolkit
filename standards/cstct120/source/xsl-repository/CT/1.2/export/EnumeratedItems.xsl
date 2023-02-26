<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:import href="EnumeratedItemAliases.xsl"/>
  <xsl:import href="EnumeratedItemSynonym.xsl"/>

  <xsl:template name="EnumeratedItems">

    <xsl:param name="parentKey" />
          <xsl:for-each select="../EnumeratedItems[FK_CodeLists = $parentKey]">

             <xsl:element name="EnumeratedItem">
               <xsl:attribute name="CodedValue"><xsl:value-of select="CodedValue"/></xsl:attribute>
               <xsl:if test="string-length(normalize-space(Rank)) &gt; 0">
                    <xsl:attribute name="Rank"><xsl:value-of select="Rank" /></xsl:attribute>
               </xsl:if>
               <xsl:if test="string-length(normalize-space(OrderNumber)) &gt; 0">
	            <xsl:attribute name="OrderNumber"><xsl:value-of select="OrderNumber" />
	            </xsl:attribute>
	       </xsl:if>
               <xsl:if test="string-length(normalize-space(ExtCodeID)) &gt; 0">
                    <xsl:attribute name="nciodm:ExtCodeID"><xsl:value-of select="ExtCodeID"/></xsl:attribute>
               </xsl:if>

               <xsl:call-template name="EnumeratedItemAliases">
                   <xsl:with-param name="parentKey">
                       <xsl:value-of select="OID" />
                   </xsl:with-param>
               </xsl:call-template>

               <xsl:call-template name="EnumeratedItemSynonym">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
               </xsl:call-template>

               <xsl:for-each select="CDISCDefinition">
                   <xsl:element name="nciodm:CDISCDefinition"><xsl:value-of select="."/></xsl:element>
               </xsl:for-each>
               <xsl:for-each select="PreferredTerm">
                   <xsl:element name="nciodm:PreferredTerm"><xsl:value-of select="."/></xsl:element>
               </xsl:for-each>


             </xsl:element>

         </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>