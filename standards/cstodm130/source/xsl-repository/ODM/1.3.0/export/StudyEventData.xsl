<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

      
    <xsl:import href="FormData.xsl" />
    <xsl:import href="AuditRecord.xsl" />    
    <xsl:import href="Signature.xsl" />
    <xsl:import href="Annotation.xsl" />

	<xsl:template name="StudyEventData">
	
	   <xsl:param name="parentKey" />
	   <xsl:param name="parentType" />
       
       <xsl:for-each select="../StudyEventData[FK_SubjectData = $parentKey]">      
       
         <xsl:element name="StudyEventData">
         
            <xsl:attribute name="StudyEventOID"><xsl:value-of select="StudyEventOID"/></xsl:attribute>
 
            <xsl:if test="string-length(normalize-space(StudyEventRepeatKey)) &gt; 0">
               <xsl:attribute name="StudyEventRepeatKey"><xsl:value-of select="StudyEventRepeatKey"/></xsl:attribute>
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
            <xsl:call-template name="Annotation">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="FormData">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>