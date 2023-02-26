<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:import href="CLItemDecodeTranslatedText.xsl"/>
  <xsl:import href="CodeListItemAliases.xsl"/>
  <xsl:import href="CodeListItemSynonym.xsl"/>

  <xsl:template name="CodeListItems">

    <xsl:param name="parentKey" />
    <xsl:for-each select="../CodeListItems[FK_CodeLists = $parentKey]">

        <xsl:element name="CodeListItem">

            <xsl:attribute name="CodedValue"><xsl:value-of select="CodedValue" />
            </xsl:attribute>
            <xsl:if test="string-length(normalize-space(Rank)) &gt; 0">
                <xsl:attribute name="Rank"><xsl:value-of select="Rank" />
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(OrderNumber)) &gt; 0">
	    	<xsl:attribute name="OrderNumber"><xsl:value-of select="OrderNumber" />
	        </xsl:attribute>
	    </xsl:if>
            <xsl:if test="string-length(normalize-space(ExtCodeID)) &gt; 0">
                <xsl:attribute name="nciodm:ExtCodeID"><xsl:value-of select="ExtCodeID"/></xsl:attribute>
            </xsl:if>

            <xsl:call-template name="CLItemDecodeTranslatedText">
                <xsl:with-param name="parentKey">
                    <xsl:value-of select="OID" />
                </xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="CodeListItemAliases">
                <xsl:with-param name="parentKey">
                    <xsl:value-of select="OID" />
                </xsl:with-param>
            </xsl:call-template>

               <xsl:call-template name="CodeListItemSynonym">
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

