<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

      
    <xsl:import href="ItemGroupData.xsl" />
    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Signature.xsl" />
    <xsl:import href="Annotation.xsl" />
        
	<xsl:template name="FormData">
	
	   <xsl:param name="parentKey" />
	   <xsl:param name="parentType" />
       
       <xsl:for-each select="../FormData[FK_StudyEventData = $parentKey]">      
       
         <xsl:element name="FormData">
         
            <xsl:attribute name="FormOID"><xsl:value-of select="FormOID"/></xsl:attribute>
 
            <xsl:if test="string-length(normalize-space(FormRepeatKey)) &gt; 0">
               <xsl:attribute name="FormRepeatKey"><xsl:value-of select="FormRepeatKey"/></xsl:attribute>
            </xsl:if>
            
            <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
                <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType"/></xsl:attribute>
            </xsl:if>

            <xsl:call-template name="AuditRecord">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>

            <xsl:call-template name="Signature">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>

            <xsl:if test="string-length(normalize-space(ArchiveLayoutRefOID)) &gt; 0">
                <xsl:element name="ArchiveLayoutRef">
                <xsl:attribute name="ArchiveLayoutOID"><xsl:value-of select="ArchiveLayoutRefOID"/></xsl:attribute>
                </xsl:element>
            </xsl:if>
            
            <xsl:call-template name="Annotation">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>
              
            <xsl:call-template name="ItemGroupData">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>