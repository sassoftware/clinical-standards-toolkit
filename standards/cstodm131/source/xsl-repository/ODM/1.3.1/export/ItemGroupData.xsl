<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
   
    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Signature.xsl" />
    <xsl:import href="Annotation.xsl" />
    <xsl:import href="ItemData.xsl" />
            
	<xsl:template name="ItemGroupData">
	
	   <xsl:param name="parentKey" />
	   <xsl:param name="parentType" />

	   <xsl:for-each select="../ItemGroupData[FK_FormData = $parentKey]">

	       <xsl:element name="ItemGroupData">

	           <xsl:attribute name="ItemGroupOID"><xsl:value-of select="ItemGroupOID" />
	           </xsl:attribute>

	           <xsl:if test="string-length(normalize-space(ItemGroupRepeatKey)) &gt; 0">
	               <xsl:attribute name="ItemGroupRepeatKey"><xsl:value-of select="ItemGroupRepeatKey" />
	               </xsl:attribute>
	           </xsl:if>

	           <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	               <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	               </xsl:attribute>
	           </xsl:if>

	           <xsl:call-template name="AuditRecord">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="Signature">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="Annotation">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="ItemData">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	           </xsl:call-template>

	       </xsl:element>

	   </xsl:for-each>

	   <xsl:for-each select="../ItemGroupData[FK_ReferenceData = $parentKey]">

	       <xsl:element name="ItemGroupData">

	           <xsl:attribute name="ItemGroupOID"><xsl:value-of select="ItemGroupOID" />
	           </xsl:attribute>

	           <xsl:if test="string-length(normalize-space(ItemGroupRepeatKey)) &gt; 0">
	               <xsl:attribute name="ItemGroupRepeatKey"><xsl:value-of select="ItemGroupRepeatKey" />
	               </xsl:attribute>
	           </xsl:if>

	           <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	               <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	               </xsl:attribute>
	           </xsl:if>

	           <xsl:call-template name="AuditRecord">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="Signature">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="Annotation">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	               <xsl:with-param name="parentType">
	                   <xsl:value-of select="local-name(.)" />
	               </xsl:with-param>
	           </xsl:call-template>

	           <xsl:call-template name="ItemData">
	               <xsl:with-param name="parentKey">
	                   <xsl:value-of select="OID" />
	               </xsl:with-param>
	           </xsl:call-template>

	       </xsl:element>

	   </xsl:for-each>

	</xsl:template>
</xsl:stylesheet>