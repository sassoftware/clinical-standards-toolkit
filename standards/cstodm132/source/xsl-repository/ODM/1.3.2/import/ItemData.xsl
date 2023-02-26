<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:odm="http://www.cdisc.org/ns/odm/v1.3">

  <xsl:template name="ItemData">
      <xsl:for-each select="./*[starts-with(local-name(.), 'ItemData')]">
        <xsl:element name="ItemData">
          <!-- need to generate an OID -->
          <xsl:element name="OID"><xsl:value-of select="generate-id(.)"/></xsl:element> 
          <xsl:element name="ItemOID"><xsl:value-of select="@ItemOID"/></xsl:element>
          <xsl:element name="IsNull"><xsl:value-of select="@IsNull"/></xsl:element>
          <xsl:element name="Value">
             <xsl:choose>
               <xsl:when test="local-name(.) = 'ItemData'">
                 <xsl:value-of select="@Value"/>
               </xsl:when>
               <xsl:otherwise>
                 <xsl:value-of select="."/>
               </xsl:otherwise>
             </xsl:choose>
          </xsl:element>
          <xsl:element name="TransactionType"><xsl:value-of select="@TransactionType"/></xsl:element>
          <xsl:element name="AuditRecordID"><xsl:value-of select="@AuditRecordID"/></xsl:element>
          <xsl:element name="SignatureID"><xsl:value-of select="@SignatureID"/></xsl:element>
          <xsl:element name="AnnotationID"><xsl:value-of select="@AnnotationID"/></xsl:element>
          <xsl:element name="MeasurementUnitOID">
             <xsl:choose>
               <xsl:when test="local-name(.) = 'ItemData'">
                 <xsl:value-of select="odm:MeasurementUnitRef/@MeasurementUnitOID"/>
               </xsl:when>
               <xsl:otherwise>
                 <xsl:value-of select="@MeasurementUnitOID"/>
               </xsl:otherwise>
             </xsl:choose>
          </xsl:element>
          <xsl:element name="FK_ItemGroupData"><xsl:value-of select="generate-id(..)"/></xsl:element>
          <xsl:element name="ItemDataType">
               <!-- the node name minus the leading 'ItemData' is the data type -->
               <xsl:value-of select="substring(local-name(.),9)"/>
          </xsl:element>
        </xsl:element>                  
      </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
