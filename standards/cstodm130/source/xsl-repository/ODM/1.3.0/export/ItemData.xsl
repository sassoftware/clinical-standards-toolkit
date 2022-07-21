<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.cdisc.org/ns/odm/v1.3">

    <xsl:import href="AuditRecord.xsl" />
    <xsl:import href="Signature.xsl" />
    <xsl:import href="Annotation.xsl" />
       
	<xsl:template name="ItemData">
	
	   <xsl:param name="parentKey" />

	   <xsl:for-each select="../ItemData[FK_ItemGroupData = $parentKey]">

	       <xsl:choose>
	           <xsl:when test="ItemDataType = ''">
	               <xsl:element name="ItemData">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:attribute name="Value"><xsl:value-of select="Value" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(IsNull)) &gt; 0">
	                       <xsl:attribute name="IsNull"><xsl:value-of select="IsNull" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(ItemDataType)) &gt; 0">
	                       <xsl:attribute name="ItemDataType"><xsl:value-of select="ItemDataType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>

	                   <xsl:call-template name="AuditRecord">
	                       <xsl:with-param name="parentKey">
	                           <xsl:value-of select="OID" />
	                       </xsl:with-param>
	                       <xsl:with-param name="parentType">
	                           <xsl:value-of select="local-name(.)" />
	                       </xsl:with-param>
	                   </xsl:call-template>

	                   <xsl:call-template name="Signature">
	                       <xsl:with-param name="parentKey">
	                           <xsl:value-of select="OID" />
	                       </xsl:with-param>
	                       <xsl:with-param name="parentType">
	                           <xsl:value-of select="local-name(.)" />
	                       </xsl:with-param>
	                   </xsl:call-template>


	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:element name="MeasurementUnitRef">
	                           <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                           </xsl:attribute>
	                       </xsl:element>
	                   </xsl:if>

	                   <xsl:call-template name="Annotation">
	                       <xsl:with-param name="parentKey">
	                           <xsl:value-of select="OID" />
	                       </xsl:with-param>
	                       <xsl:with-param name="parentType">
	                           <xsl:value-of select="local-name(.)" />
	                       </xsl:with-param>
	                   </xsl:call-template>

	               </xsl:element>

	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Any'">
	               <xsl:element name="ItemDataAny">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'String'">
	               <xsl:element name="ItemDataString">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Integer'">
	               <xsl:element name="ItemDataInteger">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Float'">
	               <xsl:element name="ItemDataFloat">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Date'">
	               <xsl:element name="ItemDataDate">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Time'">
	               <xsl:element name="ItemDataTime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Datetime'">
	               <xsl:element name="ItemDataDatetime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Boolean'">
	               <xsl:element name="ItemDataBoolean">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Double'">
	               <xsl:element name="ItemDataDouble">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'HexBinary'">
	               <xsl:element name="ItemDataHexBinary">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Base64Binary'">
	               <xsl:element name="ItemDataBase64Binary">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'HexFloat'">
	               <xsl:element name="ItemDataHexFloat">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'Base64Float'">
	               <xsl:element name="ItemDataBase64Float">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'PartialDate'">
	               <xsl:element name="ItemDataPartialDate">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'PartialTime'">
	               <xsl:element name="ItemDataPartialTime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'PartialDatetime'">
	               <xsl:element name="ItemDataPartialDatetime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'DurationDatetime'">
	               <xsl:element name="ItemDataDurationDatetime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'IntervalDatetime'">
	               <xsl:element name="ItemDataIntervalDatetime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'IncompleteDatetime'">
	               <xsl:element name="ItemDataIncompleteDatetime">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	           <xsl:when test="ItemDataType = 'URI'">
	               <xsl:element name="ItemDataURI">
	                   <xsl:attribute name="ItemOID"><xsl:value-of select="ItemOID" />
	                   </xsl:attribute>
	                   <xsl:if test="string-length(normalize-space(TransactionType)) &gt; 0">
	                       <xsl:attribute name="TransactionType"><xsl:value-of select="TransactionType" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AuditRecordID)) &gt; 0">
	                       <xsl:attribute name="AuditRecordID"><xsl:value-of select="AuditRecordID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(SignatureID)) &gt; 0">
	                       <xsl:attribute name="SignatureID"><xsl:value-of select="SignatureID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(AnnotationID)) &gt; 0">
	                       <xsl:attribute name="AnnotationID"><xsl:value-of select="AnnotationID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(MeasurementUnitOID)) &gt; 0">
	                       <xsl:attribute name="MeasurementUnitOID"><xsl:value-of select="MeasurementUnitOID" />
	                       </xsl:attribute>
	                   </xsl:if>
	                   <xsl:if test="string-length(normalize-space(Value)) &gt; 0">
	                       <xsl:value-of select="Value" />
	                   </xsl:if>
	               </xsl:element>
	           </xsl:when>
	       </xsl:choose>

	   </xsl:for-each>

	</xsl:template>
</xsl:stylesheet>
