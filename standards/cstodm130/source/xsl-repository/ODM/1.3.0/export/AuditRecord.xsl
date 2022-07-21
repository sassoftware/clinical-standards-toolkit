<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

        
	<xsl:template name="AuditRecord">
	
	   <xsl:param name="parentKey" />
       <xsl:param name="parentType" />

       <xsl:if test="count(../AuditRecord[ParentType = 'AuditRecords'][$parentType='ClinicalData']) != 0">
           <xsl:element name="AuditRecords">
               <xsl:for-each select="../AuditRecord[ParentType = 'AuditRecords'][$parentType='ClinicalData']">

                   <xsl:element name="AuditRecord">

                       <xsl:attribute name="ID"><xsl:value-of select="ID" />
                       </xsl:attribute>

                       <xsl:if test="string-length(normalize-space(EditPoint)) &gt; 0">
                           <xsl:attribute name="EditPoint"><xsl:value-of select="EditPoint" />
                           </xsl:attribute>
                       </xsl:if>

                       <xsl:if test="string-length(normalize-space(UsedImputationMethod)) &gt; 0">
                           <xsl:attribute name="UsedImputationMethod"><xsl:value-of select="UsedImputationMethod" />
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

                       <xsl:if test="string-length(normalize-space(DateTimeStamp)) &gt; 0">
                           <xsl:element name="DateTimeStamp">
                               <xsl:value-of select="DateTimeStamp" />
                           </xsl:element>
                       </xsl:if>

                       <xsl:if test="string-length(normalize-space(ReasonForChange)) &gt; 0">
                           <xsl:element name="ReasonForChange">
                               <xsl:value-of select="ReasonForChange" />
                           </xsl:element>
                       </xsl:if>

                       <xsl:if test="string-length(normalize-space(SourceID)) &gt; 0">
                           <xsl:element name="SourceID">
                               <xsl:value-of select="SourceID" />
                           </xsl:element>
                       </xsl:if>

                   </xsl:element>

               </xsl:for-each>
           </xsl:element>
       </xsl:if>

       <xsl:for-each select="../AuditRecord[ParentKey = $parentKey][ParentType = $parentType]">

           <xsl:element name="AuditRecord">

               <xsl:if test="string-length(normalize-space(ID)) &gt; 0">
                   <xsl:attribute name="ID"><xsl:value-of select="ID" />
               </xsl:attribute>
               </xsl:if>

               <xsl:if test="string-length(normalize-space(EditPoint)) &gt; 0">
                   <xsl:attribute name="EditPoint"><xsl:value-of select="EditPoint" />
                   </xsl:attribute>
               </xsl:if>

               <xsl:if test="string-length(normalize-space(UsedImputationMethod)) &gt; 0">
                   <xsl:attribute name="UsedImputationMethod"><xsl:value-of select="UsedImputationMethod" />
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

               <xsl:if test="string-length(normalize-space(DateTimeStamp)) &gt; 0">
                   <xsl:element name="DateTimeStamp">
                       <xsl:value-of select="DateTimeStamp" />
                   </xsl:element>
               </xsl:if>

               <xsl:if test="string-length(normalize-space(ReasonForChange)) &gt; 0">
                   <xsl:element name="ReasonForChange">
                       <xsl:value-of select="ReasonForChange" />
                   </xsl:element>
               </xsl:if>

               <xsl:if test="string-length(normalize-space(SourceID)) &gt; 0">
                   <xsl:element name="SourceID">
                       <xsl:value-of select="SourceID" />
                   </xsl:element>
               </xsl:if>

           </xsl:element>

       </xsl:for-each>

	</xsl:template>
</xsl:stylesheet>