<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

	<xsl:template name="KeySet">
  
      <xsl:param name="parentKey" />
      
      <xsl:for-each select="../KeySet[FK_Association = $parentKey]">
           
          <xsl:element name="KeySet">
              <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
              <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/></xsl:attribute>

              <xsl:if test="string-length(normalize-space(SubjectKey)) &gt; 0">
                  <xsl:attribute name="SubjectKey"><xsl:value-of select="SubjectKey"/></xsl:attribute>
              </xsl:if>
  
              <xsl:if test="string-length(normalize-space(StudyEventOID)) &gt; 0">
                  <xsl:attribute name="StudyEventOID"><xsl:value-of select="StudyEventOID"/></xsl:attribute>
              </xsl:if>
 
              <xsl:if test="string-length(normalize-space(StudyEventRepeatKey)) &gt; 0">
                  <xsl:attribute name="StudyEventRepeatKey"><xsl:value-of select="StudyEventRepeatKey"/></xsl:attribute>
              </xsl:if>
 
              <xsl:if test="string-length(normalize-space(FormOID)) &gt; 0">
                  <xsl:attribute name="FormOID"><xsl:value-of select="FormOID"/></xsl:attribute>
              </xsl:if>
 
              <xsl:if test="string-length(normalize-space(FormRepeatKey)) &gt; 0">
                  <xsl:attribute name="FormRepeatKey"><xsl:value-of select="FormRepeatKey"/></xsl:attribute>
              </xsl:if>

              <xsl:if test="string-length(normalize-space(ItemGroupOID)) &gt; 0">
                  <xsl:attribute name="ItemGroupOID"><xsl:value-of select="ItemGroupOID"/></xsl:attribute>
              </xsl:if>
 
              <xsl:if test="string-length(normalize-space(ItemGroupRepeatKey)) &gt; 0">
                  <xsl:attribute name="ItemGroupRepeatKey"><xsl:value-of select="ItemGroupRepeatKey"/></xsl:attribute>
              </xsl:if>
 
              <xsl:if test="string-length(normalize-space(ItemOID)) &gt; 0">
                  <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID"/></xsl:attribute>
              </xsl:if>
 
           </xsl:element>
          
      </xsl:for-each>    
        	
    </xsl:template>
</xsl:stylesheet>