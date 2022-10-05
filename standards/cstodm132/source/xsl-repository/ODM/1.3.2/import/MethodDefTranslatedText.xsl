<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="MethodDefTranslatedText">

		<xsl:for-each select="odm:TranslatedText">
			<xsl:element name="MethodDefTranslatedText">
				<xsl:element name="TranslatedText">
					<xsl:value-of select="." />
				</xsl:element>
				<xsl:element name="lang">
					<xsl:value-of select="@xml:lang" />
				</xsl:element>
				<xsl:element name="FK_MethodDefs">
					<xsl:value-of select="../../@OID" />
				</xsl:element>
			</xsl:element>
		</xsl:for-each>

	</xsl:template>
</xsl:stylesheet>