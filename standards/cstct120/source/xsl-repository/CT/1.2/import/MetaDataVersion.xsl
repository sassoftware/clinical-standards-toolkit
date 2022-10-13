<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:odm="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:import href="CodeLists.xsl" />
  <xsl:import href="CodeListTranslatedText.xsl" />
  <xsl:import href="ExternalCodeLists.xsl" />
  <xsl:import href="EnumeratedItems.xsl" />
  <xsl:import href="EnumeratedItemAliases.xsl" />
  <xsl:import href="EnumeratedItemSynonym.xsl" />
  <xsl:import href="CodeListItems.xsl" />
  <xsl:import href="CLItemDecodeTranslatedText.xsl" />
  <xsl:import href="CodeListItemAliases.xsl" />
  <xsl:import href="CodeListItemSynonym.xsl" />
  <xsl:import href="CodeListAliases.xsl" />
  <xsl:import href="CodeListSynonym.xsl" />

  <xsl:template name="MetaDataVersion">

    <xsl:for-each select="odm:MetaDataVersion">

      <xsl:element name="MetaDataVersion">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element>
         <xsl:element name="Description"><xsl:value-of select="@Description"/></xsl:element>
         <xsl:element name="IncludedOID"><xsl:value-of select="odm:Include/@MetaDataVersionOID"/></xsl:element>
         <xsl:element name="IncludedStudyOID"><xsl:value-of select="odm:Include/@StudyOID"/></xsl:element>
         <xsl:element name="FK_Study"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      <xsl:call-template name="CodeLists"/>

    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:Description">
      <xsl:call-template name="CodeListTranslatedText"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:ExternalCodeList">
      <xsl:call-template name="ExternalCodeLists"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:EnumeratedItem">
      <xsl:call-template name="EnumeratedItems"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:EnumeratedItem/odm:Alias">
      <xsl:call-template name="EnumeratedItemAliases"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem">
      <xsl:call-template name="CodeListItems"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem/odm:Decode/odm:TranslatedText">
      <xsl:call-template name="CLItemDecodeTranslatedText"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem/odm:Alias">
      <xsl:call-template name="CodeListItemAliases"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:Alias">
      <xsl:call-template name="CodeListAliases"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/nciodm:CDISCSynonym">
      <xsl:call-template name="CodeListSynonym"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem/nciodm:CDISCSynonym">
      <xsl:call-template name="CodeListItemSynonym"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:EnumeratedItem/nciodm:CDISCSynonym">
      <xsl:call-template name="EnumeratedItemSynonym"/>
    </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>