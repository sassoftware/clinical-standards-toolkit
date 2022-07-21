<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="AnnotationFlag.xsl" />

    <xsl:template name="Annotation">

        <xsl:param name="parentKey" />
        <xsl:param name="parentType" />


        <xsl:if test="count(../Annotation[ParentType = 'Annotations'][$parentType='ClinicalData']) != 0">
            <xsl:element name="Annotations">
                <xsl:for-each select="../Annotation[ParentType = 'Annotations'][$parentType='ClinicalData']">
                    <xsl:element name="Annotation">

                        <xsl:attribute name="ID"><xsl:value-of select="ID" />
	                    </xsl:attribute>
                        <xsl:attribute name="SeqNum"><xsl:value-of select="SeqNum" />
	                    </xsl:attribute>
                        <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
                            <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                        </xsl:attribute>
                        </xsl:if>

                        <xsl:if test="string-length(normalize-space(CommentSponsorOrSite)) &gt; 0">
                            <xsl:element name="Comment">
                                <xsl:attribute name="SponsorOrSite">
	                            <xsl:value-of select="CommentSponsorOrSite" />
                                </xsl:attribute>
                                <xsl:value-of select="Comment" />
                            </xsl:element>
                        </xsl:if>

                        <xsl:call-template name="AnnotationFlag">
                            <xsl:with-param name="parentKey">
                                <xsl:value-of select="GeneratedID" />
                            </xsl:with-param>
                        </xsl:call-template>


                    </xsl:element>


                </xsl:for-each>
            </xsl:element>
        </xsl:if>

        <xsl:for-each select="../Annotation[ParentKey = $parentKey and ParentType = $parentType]">

            <xsl:element name="Annotation">

                <xsl:if test="string-length(normalize-space(ID)) &gt; 0">
                    <xsl:attribute name="ID"><xsl:value-of select="ID" />
                    </xsl:attribute>
                </xsl:if>

                <xsl:attribute name="SeqNum"><xsl:value-of select="SeqNum" />
	           </xsl:attribute>
                <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
                    <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                </xsl:attribute>
                </xsl:if>

                <xsl:if test="string-length(normalize-space(CommentSponsorOrSite)) &gt; 0">
                    <xsl:element name="Comment">
                        <xsl:attribute name="SponsorOrSite">
	                    <xsl:value-of select="CommentSponsorOrSite" />
                        </xsl:attribute>
                        <xsl:value-of select="Comment" />
                    </xsl:element>
                </xsl:if>

                <xsl:call-template name="AnnotationFlag">
                    <xsl:with-param name="parentKey">
                        <xsl:value-of select="GeneratedID" />
                    </xsl:with-param>
                </xsl:call-template>


            </xsl:element>

        </xsl:for-each>

    </xsl:template>

</xsl:stylesheet>