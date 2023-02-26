<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

        
	<xsl:template name="Signature">
	
	   <xsl:param name="parentKey" />
	   <xsl:param name="parentType" />

           <xsl:if test="count(../Signature[ParentType = 'Signatures'][$parentType='ReferenceData']) != 0">
               <xsl:element name="Signatures">
                   <xsl:for-each select="../Signature[ParentType = 'Signatures'][GrandParentType = 'ReferenceData'][$parentType='ReferenceData']">
                       <xsl:element name="Signature">

                           <xsl:attribute name="ID"><xsl:value-of select="ID" />
                           </xsl:attribute>

                           <xsl:if test="string-length(normalize-space(UserOID)) &gt; 0">
                               <xsl:element name="UserRef">
                                   <xsl:attribute name="UserOID"><xsl:value-of select="UserOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(LocationOID)) &gt; 0">
                               <xsl:element name="LocationRef">
                                   <xsl:attribute name="LocationOID"><xsl:value-of select="LocationOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(SignatureDefOID)) &gt; 0">
                               <xsl:element name="SignatureRef">
                                   <xsl:attribute name="SignatureOID"><xsl:value-of select="SignatureDefOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(DateTimeStamp)) &gt; 0">
                               <xsl:element name="DateTimeStamp">
                                   <xsl:value-of select="DateTimeStamp" />
                               </xsl:element>
                           </xsl:if>

                       </xsl:element>

                   </xsl:for-each>
               </xsl:element>
           </xsl:if>

           <xsl:if test="count(../Signature[ParentType = 'Signatures'][$parentType='ClinicalData']) != 0">
               <xsl:element name="Signatures">
                   <xsl:for-each select="../Signature[ParentType = 'Signatures'][GrandParentType = 'ClinicalData'][$parentType='ClinicalData']">
                       <xsl:element name="Signature">

                           <xsl:attribute name="ID"><xsl:value-of select="ID" />
                           </xsl:attribute>

                           <xsl:if test="string-length(normalize-space(UserOID)) &gt; 0">
                               <xsl:element name="UserRef">
                                   <xsl:attribute name="UserOID"><xsl:value-of select="UserOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(LocationOID)) &gt; 0">
                               <xsl:element name="LocationRef">
                                   <xsl:attribute name="LocationOID"><xsl:value-of select="LocationOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(SignatureDefOID)) &gt; 0">
                               <xsl:element name="SignatureRef">
                                   <xsl:attribute name="SignatureOID"><xsl:value-of select="SignatureDefOID" />
                                   </xsl:attribute>
                               </xsl:element>
                           </xsl:if>

                           <xsl:if test="string-length(normalize-space(DateTimeStamp)) &gt; 0">
                               <xsl:element name="DateTimeStamp">
                                   <xsl:value-of select="DateTimeStamp" />
                               </xsl:element>
                           </xsl:if>

                       </xsl:element>

                   </xsl:for-each>
               </xsl:element>
           </xsl:if>

	   <xsl:for-each select="../Signature[ParentKey = $parentKey][ParentType = $parentType]">

	       <xsl:element name="Signature">

               <xsl:if test="string-length(normalize-space(ID)) &gt; 0">
                   <xsl:attribute name="ID"><xsl:value-of select="ID" />
               </xsl:attribute>
               </xsl:if>

	           <xsl:if test="string-length(normalize-space(UserOID)) &gt; 0">
	               <xsl:element name="UserRef">
	                   <xsl:attribute name="UserOID"><xsl:value-of select="UserOID" />
	                   </xsl:attribute>
	               </xsl:element>
	           </xsl:if>

	           <xsl:if test="string-length(normalize-space(LocationOID)) &gt; 0">
	               <xsl:element name="LocationRef">
	                   <xsl:attribute name="LocationOID"><xsl:value-of select="LocationOID" />
	                   </xsl:attribute>
	               </xsl:element>
	           </xsl:if>

	           <xsl:if test="string-length(normalize-space(SignatureDefOID)) &gt; 0">
	               <xsl:element name="SignatureRef">
	                   <xsl:attribute name="SignatureOID"><xsl:value-of select="SignatureDefOID" />
	                   </xsl:attribute>
	               </xsl:element>
	           </xsl:if>

	           <xsl:if test="string-length(normalize-space(DateTimeStamp)) &gt; 0">
	               <xsl:element name="DateTimeStamp">
	                   <xsl:value-of select="DateTimeStamp" />
	               </xsl:element>
	           </xsl:if>

	       </xsl:element>

	   </xsl:for-each>

	</xsl:template>
</xsl:stylesheet>