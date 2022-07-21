<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="ProtocolTranslatedText.xsl" />
    <xsl:import href="ProtocolEventRefs.xsl" />
    <xsl:import href="StudyEventDefs.xsl" />
    <xsl:import href="FormDefs.xsl" />
    <xsl:import href="ItemGroupDefs.xsl" />
    <xsl:import href="ItemDefs.xsl" />
    <xsl:import href="CodeLists.xsl" />
    <xsl:import href="ExternalCodeLists.xsl" />
    <xsl:import href="EnumeratedItems.xsl" />
    <xsl:import href="CodeListItems.xsl" />
    <xsl:import href="CLItemDecodeTranslatedText.xsl" />
    <xsl:import href="ImputationMethods.xsl" />
    <xsl:import href="Presentation.xsl" />
    <xsl:import href="MethodDefs.xsl" />
    <xsl:import href="MethodDefTranslatedText.xsl" />
    <xsl:import href="MethodDefFormalExpression.xsl" />
    <xsl:import href="ConditionDefs.xsl" />
    <xsl:import href="ConditionDefTranslatedText.xsl" />
    <xsl:import href="ConditionDefFormalExpression.xsl" />
 
	<xsl:template name="MetaDataVersion">	
    
    <xsl:for-each select="odm:MetaDataVersion">

      <xsl:element name="MetaDataVersion">
         <xsl:element name="OID"><xsl:value-of select="@OID"/></xsl:element>
         <xsl:element name="Name"><xsl:value-of select="@Name"/></xsl:element> 
         <xsl:element name="Description"><xsl:value-of select="@Description"/></xsl:element> 
         <xsl:element name="IncludedOID"><xsl:value-of select="odm:Include/@MetaDataVersionOID"/></xsl:element>
         <xsl:element name="IncludedStudyOID"><xsl:value-of select="odm:Include/@StudyOID"/></xsl:element>
         <xsl:element name="FK_Study"><xsl:value-of select="../@OID"/></xsl:element>
      </xsl:element>
      <xsl:call-template name="ProtocolTranslatedText"/>     
      <xsl:call-template name="ProtocolEventRefs"/>
      <xsl:call-template name="StudyEventDefs"/>
      <xsl:call-template name="FormDefs"/>
      <xsl:call-template name="ItemGroupDefs"/>
      <xsl:call-template name="ItemDefs"/>
      <xsl:call-template name="CodeLists"/>
      
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:ExternalCodeList">
      <xsl:call-template name="ExternalCodeLists"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:EnumeratedItem">
      <xsl:call-template name="EnumeratedItems"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem">
      <xsl:call-template name="CodeListItems"/>
    </xsl:for-each>

    <xsl:for-each select="odm:MetaDataVersion/odm:CodeList/odm:CodeListItem/odm:Decode/odm:TranslatedText">
      <xsl:call-template name="CLItemDecodeTranslatedText"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:ImputationMethod">
      <xsl:call-template name="ImputationMethods"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:Presentation">
      <xsl:call-template name="Presentation"/>
    </xsl:for-each>
    
    <xsl:for-each select="odm:MetaDataVersion/odm:MethodDef">
      <xsl:call-template name="MethodDefs"/>
    </xsl:for-each>
 
     <xsl:for-each select="odm:MetaDataVersion/odm:MethodDef/odm:Description">
      <xsl:call-template name="MethodDefTranslatedText"/>
    </xsl:for-each>
 
    <xsl:for-each select="odm:MetaDataVersion/odm:MethodDef/odm:FormalExpression">
      <xsl:call-template name="MethodDefFormalExpression"/>
    </xsl:for-each>
           	
    <xsl:for-each select="odm:MetaDataVersion/odm:ConditionDef">
      <xsl:call-template name="ConditionDefs"/>
    </xsl:for-each>
 
     <xsl:for-each select="odm:MetaDataVersion/odm:ConditionDef/odm:Description">
      <xsl:call-template name="ConditionDefTranslatedText"/>
    </xsl:for-each>
 
    <xsl:for-each select="odm:MetaDataVersion/odm:ConditionDef/odm:FormalExpression">
      <xsl:call-template name="ConditionDefFormalExpression"/>
    </xsl:for-each>

  </xsl:template>
</xsl:stylesheet>