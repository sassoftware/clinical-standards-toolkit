<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:def="http://www.cdisc.org/ns/def/v1.0">

    <xsl:import href="ItemQuestionTranslatedText.xsl" />
    <xsl:import href="ItemQuestionExternal.xsl" />
    <xsl:import href="ItemMURefs.xsl" />
    <xsl:import href="ItemRangeChecks.xsl" />
    <xsl:import href="ItemRangeCheckValues.xsl" />
    <xsl:import href="RCErrorTranslatedText.xsl" />
    <xsl:import href="ItemRole.xsl" />
    <xsl:import href="ItemAliases.xsl" />
    <xsl:import href="ItemValueListRefs.xsl" />

	<xsl:template name="ItemDefs">	
    
    <xsl:for-each select="odm:ItemDef">

      <xsl:element name="ItemDefs">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element> 
         <xsl:element name="DataType"><xsl:value-of select="@DataType"/></xsl:element> 
         <xsl:element name="Length"><xsl:value-of select="@Length"/></xsl:element> 
         <xsl:element name="SignificantDigits"><xsl:value-of select="@SignificantDigits"/></xsl:element>        
         <xsl:element name="SASFieldName"><xsl:value-of select="@SASFieldName"/></xsl:element>
         <xsl:element name="SDSVarName"><xsl:value-of select="@SDSVarName"/></xsl:element>
         <xsl:element name="Origin"><xsl:value-of select="@Origin"/></xsl:element>
         <xsl:element name="Comment"><xsl:value-of select="@Comment"/></xsl:element>
         <xsl:element name="CodeListRef"><xsl:value-of select="odm:CodeListRef/@CodeListOID"/></xsl:element>
         <xsl:element name="Label"><xsl:value-of select="@def:Label"/></xsl:element>
         <xsl:element name="DisplayFormat"><xsl:value-of select="@def:DisplayFormat"/></xsl:element>
         <xsl:element name="ComputationMethodOID"><xsl:value-of select="@def:ComputationMethodOID"/></xsl:element>
         <xsl:element name="FK_MetaDataVersion"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:Question/odm:TranslatedText">
       <xsl:call-template name="ItemQuestionTranslatedText"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:ExternalQuestion">
       <xsl:call-template name="ItemQuestionExternal"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:MeasurementUnitRef">
       <xsl:call-template name="ItemMURefs"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:RangeCheck">
       <xsl:call-template name="ItemRangeChecks"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:RangeCheck/odm:CheckValue">
       <xsl:call-template name="ItemRangeCheckValues"/>
    </xsl:for-each>

    <xsl:for-each select="odm:ItemDef/odm:RangeCheck/odm:ErrorMessage/odm:TranslatedText">
       <xsl:call-template name="RCErrorTranslatedText"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:Role">
       <xsl:call-template name="ItemRole"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/odm:Alias">
       <xsl:call-template name="ItemAliases"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:ItemDef/def:ValueListRef">
       <xsl:call-template name="ItemValueListRefs"/>
    </xsl:for-each>
           	
  </xsl:template>
</xsl:stylesheet>