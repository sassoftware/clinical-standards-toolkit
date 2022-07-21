<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    
    <xsl:import href="StudyEventData.xsl" />
    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Signature.xsl" />
    <xsl:import href="Annotation.xsl" />
        
	<xsl:template name="SubjectData">
	
	   <xsl:param name="parentKey" />
       <xsl:param name="parentType" />
       
       <xsl:for-each select="../SubjectData[FK_ClinicalData = $parentKey]">      
       
         <xsl:element name="SubjectData">
         
            <xsl:attribute name="SubjectKey"><xsl:value-of select="SubjectKey"/></xsl:attribute>
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
 
            <xsl:if test="string-length(normalize-space(InvestigatorRefOID)) &gt; 0">
              <xsl:element name="InvestigatorRef">
                <xsl:attribute name="UserOID"><xsl:value-of select="InvestigatorRefOID"/></xsl:attribute>
              </xsl:element>
            </xsl:if>

            <xsl:if test="string-length(normalize-space(SiteRefOID)) &gt; 0">
              <xsl:element name="SiteRef">
                <xsl:attribute name="LocationOID"><xsl:value-of select="SiteRefOID"/></xsl:attribute>
              </xsl:element>
            </xsl:if>
 
             <xsl:call-template name="Annotation">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
              <xsl:with-param name="parentType"><xsl:value-of select="local-name(.)"/></xsl:with-param>
            </xsl:call-template>
                                    
            <xsl:call-template name="StudyEventData">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>