<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0"
	xmlns="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:xlink="http://www.w3.org/1999/xlink">

    <xsl:import href="ItemQuestionTranslatedText.xsl"/>
    <xsl:import href="ItemQuestionExternal.xsl"/>
    <xsl:import href="ItemMURefs.xsl"/>
    <xsl:import href="ItemRangeChecks.xsl"/>
    <xsl:import href="ItemRole.xsl"/>
    <xsl:import href="ItemAliases.xsl"/>
    <xsl:import href="ItemValueListRefs.xsl"/>
        
	<xsl:template name="ItemDefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../ItemDefs[FK_MetaDataVersion = $parentKey]">      
       
         <xsl:element name="ItemDef">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:attribute name="Name"><xsl:value-of select="Name"/></xsl:attribute>
            <xsl:attribute name="DataType"><xsl:value-of select="DataType"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(Length)) &gt; 0">
               <xsl:attribute name="Length"><xsl:value-of select="Length"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(SignificantDigits)) &gt; 0">
               <xsl:attribute name="SignificantDigits"><xsl:value-of select="SignificantDigits"/></xsl:attribute>
            </xsl:if>            
            <xsl:if test="string-length(normalize-space(SASFieldName)) &gt; 0">
              <xsl:attribute name="SASFieldName"><xsl:value-of select="SASFieldName"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="string-length(normalize-space(SDSVarName)) &gt; 0">
              <xsl:attribute name="SDSVarName"><xsl:value-of select="SDSVarName"/></xsl:attribute>
            </xsl:if>            
            <xsl:if test="string-length(normalize-space(Origin)) &gt; 0">
              <xsl:attribute name="Origin"><xsl:value-of select="Origin"/></xsl:attribute>
            </xsl:if>        
            <xsl:if test="string-length(normalize-space(Comment)) &gt; 0">
              <xsl:attribute name="Comment"><xsl:value-of select="Comment"/></xsl:attribute>
            </xsl:if> 
            <xsl:if test="string-length(normalize-space(Label)) &gt; 0">
              <xsl:attribute name="def:Label"><xsl:value-of select="Label"/></xsl:attribute>
            </xsl:if> 
            <xsl:if test="string-length(normalize-space(DisplayFormat)) &gt; 0">
              <xsl:attribute name="def:DisplayFormat"><xsl:value-of select="DisplayFormat"/></xsl:attribute>
            </xsl:if> 
            <xsl:if test="string-length(normalize-space(ComputationMethodOID)) &gt; 0">
              <xsl:attribute name="def:ComputationMethodOID"><xsl:value-of select="ComputationMethodOID"/></xsl:attribute>
            </xsl:if>               
            <xsl:call-template name="ItemQuestionTranslatedText">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemQuestionExternal">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemMURefs">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemRangeChecks">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:if test="string-length(normalize-space(CodeListRef)) &gt; 0">
              <xsl:element name="CodeListRef">
                 <xsl:attribute name="CodeListOID"><xsl:value-of select="CodeListRef"/></xsl:attribute>
              </xsl:element>
            </xsl:if>
            <xsl:call-template name="ItemRole">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemAliases">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="ItemValueListRefs">
              <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
            </xsl:call-template>
                                                                                   
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>