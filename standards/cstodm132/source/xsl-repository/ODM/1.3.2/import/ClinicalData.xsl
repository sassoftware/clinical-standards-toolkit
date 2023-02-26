<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="SubjectData.xsl" />
    <xsl:import href="StudyEventData.xsl" />
    <xsl:import href="FormData.xsl" />
    <xsl:import href="ItemGroupData.xsl" />
    <xsl:import href="ItemData.xsl" />

	<xsl:template match="odm:ClinicalData">
          
          <xsl:element name="ClinicalData">
            <!-- need a generated OID -->
            <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element>
            <xsl:element name="StudyOID"><xsl:value-of select="@StudyOID"/></xsl:element>
            <xsl:element name="MetaDataVersionOID"><xsl:value-of select="@MetaDataVersionOID"/></xsl:element> 
            <xsl:element name="FK_ODM"><xsl:value-of select="../@FileOID"/></xsl:element>
          </xsl:element>
     
          <xsl:call-template name="SubjectData"/>
          
          <xsl:for-each select="odm:SubjectData">
             <xsl:call-template name="StudyEventData"/>
          </xsl:for-each>

          <xsl:for-each select="odm:SubjectData/odm:StudyEventData">
             <xsl:call-template name="FormData"/>    
          </xsl:for-each>
          
          <xsl:for-each select="odm:SubjectData/odm:StudyEventData/odm:FormData">
             <xsl:call-template name="ItemGroupData"/>
          </xsl:for-each>

          <xsl:for-each select="odm:SubjectData/odm:StudyEventData/odm:FormData/odm:ItemGroupData">
             <xsl:call-template name="ItemData"/>
          </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>