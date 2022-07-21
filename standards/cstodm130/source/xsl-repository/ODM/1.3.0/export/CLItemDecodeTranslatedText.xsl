<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:template name="CLItemDecodeTranslatedText">

        <xsl:param name="parentKey" />

        <xsl:element name="Decode">

            <xsl:choose>
                <xsl:when test="count(../CLItemDecodeTranslatedText[FK_CodeListItems = $parentKey]) &gt; 0">

                    <xsl:for-each select="../CLItemDecodeTranslatedText[FK_CodeListItems = $parentKey]">

                        <xsl:element name="TranslatedText">
                            <xsl:if test="string-length(normalize-space(lang)) &gt; 0">
                                <xsl:attribute name="xml:lang"><xsl:value-of select="lang" />
                                </xsl:attribute>
                            </xsl:if>
                            <xsl:value-of select="TranslatedText" />
                        </xsl:element>

                    </xsl:for-each>

                </xsl:when>
                <xsl:otherwise>
                    <xsl:element name="TranslatedText" />
                </xsl:otherwise>
            </xsl:choose>

        </xsl:element>

    </xsl:template>
</xsl:stylesheet>