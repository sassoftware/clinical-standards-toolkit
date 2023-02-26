<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:import href="CodeLists.xsl"/>

  <xsl:template name="MetaDataVersion">

       <xsl:param name="parentKey" />

         <xsl:for-each select="../MetaDataVersion[FK_Study = $parentKey]">

          <xsl:element name="MetaDataVersion">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(Description)) &gt; 0">
               <xsl:attribute name="Description"><xsl:value-of select="Description"/></xsl:attribute>
            </xsl:if>

            <!-- Include is a subelement. Both attrs are required -->
            <xsl:if test="string-length(normalize-space(IncludedOID)) &gt; 0 or string-length(normalize-space(IncludedStudyOID)) &gt; 0">
               <xsl:element name="Include">
                  <xsl:attribute name="StudyOID"><xsl:value-of select="IncludedStudyOID"/></xsl:attribute>
                  <xsl:attribute name="MetaDataVersionOID"><xsl:value-of select="IncludedOID"/></xsl:attribute>
               </xsl:element>
            </xsl:if>

            <xsl:call-template name="CodeLists">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>

           </xsl:element>

         </xsl:for-each>

  </xsl:template>

</xsl:stylesheet>