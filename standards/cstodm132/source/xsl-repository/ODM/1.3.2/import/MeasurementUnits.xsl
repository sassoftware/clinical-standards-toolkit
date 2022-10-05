<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="MUTranslatedText.xsl" />
    <xsl:import href="MUAliases.xsl" />

	<xsl:template name="MeasurementUnits">
      
      <xsl:for-each select="odm:BasicDefinitions/odm:MeasurementUnit">
        <xsl:element name="MeasurementUnits">
          <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element> 
          <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element>
          <xsl:element name="FK_Study"><xsl:value-of select="../../@OID"/></xsl:element> 
        </xsl:element>                  
      </xsl:for-each>
      
      <!-- Can't nest this, since all observations for a given data set must appear contiguously -->
      <xsl:for-each select="odm:BasicDefinitions/odm:MeasurementUnit/odm:Symbol/odm:TranslatedText">
        <xsl:call-template name="MUTranslatedText"/>
      </xsl:for-each>	
        	
    <xsl:for-each select="odm:BasicDefinitions/odm:MeasurementUnit/odm:Alias">
      <xsl:call-template name="MUAliases"/>
    </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>