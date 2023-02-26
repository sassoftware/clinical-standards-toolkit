<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="UserAddress.xsl" />
    <xsl:import href="UserEmail.xsl" />
    <xsl:import href="UserFax.xsl" />
    <xsl:import href="UserPhone.xsl" />
    <xsl:import href="UserLocationRef.xsl" />
        
	<xsl:template name="User">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../User[FK_AdminData = $parentKey]">      
       
         <xsl:element name="User">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            <xsl:if test="string-length(normalize-space(UserType)) &gt; 0">
               <xsl:attribute name="UserType"><xsl:value-of select="UserType"/></xsl:attribute>
            </xsl:if>


             <xsl:if test="string-length(normalize-space(LoginName)) &gt; 0">
                 <xsl:element name="LoginName"><xsl:value-of select="LoginName"/></xsl:element>
             </xsl:if>
                    
             <xsl:if test="string-length(normalize-space(DisplayName)) &gt; 0">
                 <xsl:element name="DisplayName"><xsl:value-of select="DisplayName"/></xsl:element>
             </xsl:if>
                    
             <xsl:if test="string-length(normalize-space(FullName)) &gt; 0">
                 <xsl:element name="FullName"><xsl:value-of select="FullName"/></xsl:element>
             </xsl:if>

             <xsl:if test="string-length(normalize-space(FirstName)) &gt; 0">
                 <xsl:element name="FirstName"><xsl:value-of select="FirstName"/></xsl:element>
             </xsl:if>

             <xsl:if test="string-length(normalize-space(LastName)) &gt; 0">
                 <xsl:element name="LastName"><xsl:value-of select="LastName"/></xsl:element>
             </xsl:if>
         
             <xsl:if test="string-length(normalize-space(Organization)) &gt; 0">
                 <xsl:element name="Organization"><xsl:value-of select="Organization"/></xsl:element>
             </xsl:if>
         
             <xsl:call-template name="UserAddress">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
             <xsl:call-template name="UserEmail">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>

             <xsl:if test="string-length(normalize-space(PictureFileName)) &gt; 0">
                 <xsl:element name="Picture">
                     <xsl:attribute name="PictureFileName"><xsl:value-of select="PictureFileName"/></xsl:attribute>
                     <xsl:attribute name="ImageType"><xsl:value-of select="PictureImageType"/></xsl:attribute>
                 </xsl:element>
             </xsl:if>

             <xsl:if test="string-length(normalize-space(Pager)) &gt; 0">
                 <xsl:element name="Pager"><xsl:value-of select="Pager"/></xsl:element>
             </xsl:if>

             <xsl:call-template name="UserFax">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
             <xsl:call-template name="UserPhone">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
             <xsl:call-template name="UserLocationRef">
                 <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
             
         
         </xsl:element>       
         
       </xsl:for-each>
        	
  </xsl:template>
</xsl:stylesheet>