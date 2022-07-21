<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xsi="http://www.w3c.org/2001/XMLSchema-instance"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2">

	<xsl:template name="RCErrorTranslatedText">

		<xsl:for-each select=".">
			<xsl:element name="RCErrorTranslatedText">
				<xsl:element name="TranslatedText">
					<xsl:value-of select="." />
				</xsl:element>
				<xsl:element name="lang">
					<xsl:value-of select="@xml:lang" />
				</xsl:element>
				<xsl:element name="FK_ItemRangeChecks">
					<!--  The grandparent OID was generated so we have something to reference as a parent -->
                    <xsl:value-of select="generate-id(../..)" />
				</xsl:element>
			</xsl:element>
		</xsl:for-each>

	</xsl:template>
</xsl:stylesheet>