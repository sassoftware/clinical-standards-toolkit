<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="User.xsl" />
    <xsl:import href="Location.xsl" />
    <xsl:import href="SignatureDef.xsl" />

      <xsl:template name="AdminData">
      
      <xsl:for-each select="AdminData">
           
          <xsl:element name="AdminData">
            <xsl:if test="string-length(normalize-space(StudyOID)) &gt; 0">
            <xsl:attribute name="StudyOID"><xsl:value-of select="StudyOID"/>
            </xsl:attribute>
            </xsl:if>
                       
            <xsl:call-template name="User">
              <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="Location">
              <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="SignatureDef">
              <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
            </xsl:call-template>

          </xsl:element>
          
      </xsl:for-each>    
        
  </xsl:template>
</xsl:stylesheet>