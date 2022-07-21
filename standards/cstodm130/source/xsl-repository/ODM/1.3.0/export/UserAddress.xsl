<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">
     
    <xsl:import href="UserAddressStreetName.xsl" />
    
	<xsl:template name="UserAddress">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../UserAddress[FK_User = $parentKey]">      
         
           <xsl:element name="Address">

           <xsl:call-template name="UserAddressStreetName">
               <xsl:with-param name="parentKey"><xsl:value-of select="GeneratedID"/></xsl:with-param>
           </xsl:call-template>
         
           <xsl:if test="string-length(normalize-space(City)) &gt; 0">
               <xsl:element name="City"><xsl:value-of select="City"/></xsl:element>
           </xsl:if>
                    
           <xsl:if test="string-length(normalize-space(StateProv)) &gt; 0">
               <xsl:element name="StateProv"><xsl:value-of select="StateProv"/></xsl:element>
           </xsl:if>
                    
           <xsl:if test="string-length(normalize-space(Country)) &gt; 0">
               <xsl:element name="Country"><xsl:value-of select="Country"/></xsl:element>
           </xsl:if>

           <xsl:if test="string-length(normalize-space(PostalCode)) &gt; 0">
               <xsl:element name="PostalCode"><xsl:value-of select="PostalCode"/></xsl:element>
           </xsl:if>

           <xsl:if test="string-length(normalize-space(OtherText)) &gt; 0">
               <xsl:element name="OtherText"><xsl:value-of select="OtherText"/></xsl:element>
           </xsl:if>
          
           </xsl:element>

       </xsl:for-each>
       
   </xsl:template> 
</xsl:stylesheet>