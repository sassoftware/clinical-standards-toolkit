<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">
  
    <xsl:import href="User.xsl" />
    <xsl:import href="UserAddress.xsl" />
    <xsl:import href="UserAddressStreetName.xsl" />
    <xsl:import href="UserEmail.xsl" />
    <xsl:import href="UserFax.xsl" />
    <xsl:import href="UserPhone.xsl" />
    <xsl:import href="UserLocationRef.xsl" />
    <xsl:import href="Location.xsl" />
    <xsl:import href="LocationVersion.xsl" />
    <xsl:import href="SignatureDef.xsl" />  
             
	<xsl:template match="odm:AdminData">
  
       <xsl:element name="AdminData">
         <xsl:element name="GeneratedID"><xsl:value-of select="generate-id(.)"/></xsl:element>
         <xsl:element name="StudyOID"><xsl:value-of select="@StudyOID"/></xsl:element> 
         <xsl:element name="FK_ODM"><xsl:value-of select="../@FileOID"/></xsl:element>
       </xsl:element>   
       
      <xsl:for-each select="odm:User">
        <xsl:call-template name="User"/>
      </xsl:for-each>
      
      <xsl:for-each select="odm:User/odm:Address">
        <xsl:call-template name="UserAddress"/>
      </xsl:for-each>

      <xsl:for-each select="odm:User/odm:Address/odm:StreetName">
        <xsl:call-template name="UserAddressStreetName"/>
      </xsl:for-each>
      
      <xsl:for-each select="odm:User/odm:Email">
        <xsl:call-template name="UserEmail"/>
      </xsl:for-each>

      <xsl:for-each select="odm:User/odm:Fax">
        <xsl:call-template name="UserFax"/>
      </xsl:for-each>
      
      <xsl:for-each select="odm:User/odm:Phone">
        <xsl:call-template name="UserPhone"/>
      </xsl:for-each>
      
      <xsl:for-each select="odm:User/odm:LocationRef">
        <xsl:call-template name="UserLocationRef"/>
      </xsl:for-each>

      <xsl:for-each select="odm:Location">
        <xsl:call-template name="Location"/>
      </xsl:for-each>

      <xsl:for-each select="odm:Location/odm:MetaDataVersionRef">
        <xsl:call-template name="LocationVersion"/>
      </xsl:for-each>

      <xsl:for-each select="odm:SignatureDef">
        <xsl:call-template name="SignatureDef"/>
      </xsl:for-each>
            	
    </xsl:template>
  
</xsl:stylesheet>