<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:odm="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:template name="CLItemDecodeTranslatedText">

    <xsl:for-each select=".">
      <xsl:element name="CLItemDecodeTranslatedText">
        <xsl:element name="TranslatedText">
          <xsl:value-of select="." />
        </xsl:element>
        <xsl:element name="lang">
          <xsl:value-of select="@xml:lang" />
        </xsl:element>
        <xsl:element name="FK_CodeListItems">
          <xsl:value-of select="generate-id(../..)"/>
        </xsl:element>
      </xsl:element>
    </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>