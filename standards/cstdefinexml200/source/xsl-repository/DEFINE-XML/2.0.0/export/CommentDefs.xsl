<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3"
	xmlns:def="http://www.cdisc.org/ns/def/v2.0">

  <xsl:include href="DocumentRefs.xsl"/>
  
  <xsl:template name="CommentDefs">
	
	   <xsl:param name="parentKey" />
       
       <xsl:for-each select="../CommentDefs[FK_MetaDataVersion = $parentKey]">      
       
         <xsl:element name="def:CommentDef">
            <xsl:attribute name="OID"><xsl:value-of select="OID"/></xsl:attribute>
            
           <xsl:element name="Description">
             <xsl:call-template name="TranslatedText">
               <xsl:with-param name="parent">CommentDefs</xsl:with-param>
               <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
           </xsl:element> 
         
           <xsl:variable name="CommentOID"><xsl:value-of select="OID"/></xsl:variable>
           <xsl:if test="count(../DocumentRefs[parent = 'CommentDefs' and parentKey = $CommentOID]) &gt; 0">
             <xsl:call-template name="DocumentRefs">
               <xsl:with-param name="parent">CommentDefs</xsl:with-param>
               <xsl:with-param name="parentKey"><xsl:value-of select="OID"/></xsl:with-param>
             </xsl:call-template>
           </xsl:if>
         </xsl:element>
        
       </xsl:for-each>
       	
  </xsl:template>
</xsl:stylesheet>