<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:template name="EnumeratedItemSynonym">

  <xsl:param name="parentKey" />

    <xsl:if test="count(../EnumeratedItemSynonym[FK_EnumeratedItems = $parentKey]) != 0">
           <xsl:for-each select="../EnumeratedItemSynonym[FK_EnumeratedItems = $parentKey]">

              <xsl:element name="nciodm:CDISCSynonym"><xsl:value-of select="CDISCSynonym"/></xsl:element>

           </xsl:for-each>
    </xsl:if>

  </xsl:template>
</xsl:stylesheet>