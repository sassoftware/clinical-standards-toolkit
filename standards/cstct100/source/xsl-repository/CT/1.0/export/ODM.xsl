<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.cdisc.org/ns/odm/v1.3"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

  <xsl:import href="Study.xsl" />


  <xsl:template match="/LIBRARY">

    <!--  import stylesheet if desired -->
    <xsl:if test="$stylesheetref.creation = 'true'">
      <!-- Xalan has a bug that causes the quoting to be messed up in a PI if you use xsl:text.
           Therefore, this must stay all on one line, like so: -->
      <xsl:text><xsl:processing-instruction name="xml-stylesheet">type="text/xsl" href="<xsl:value-of select='$stylesheetref.name'/>"</xsl:processing-instruction>
</xsl:text>        
    </xsl:if>

		<xsl:if test="string-length(normalize-space($header.comment.text)) &gt; 0">
    <xsl:text>
</xsl:text>
    <xsl:comment>
        <xsl:value-of select="$header.comment.text"/>
    </xsl:comment><xsl:text>
</xsl:text>
		</xsl:if>

    <ODM xmlns="http://www.cdisc.org/ns/odm/v1.3">

      <xsl:attribute name="FileOID"><xsl:value-of select="ODM/FileOID"/></xsl:attribute>
      <xsl:attribute name="CreationDateTime"><xsl:value-of select="$timestamp.creation"/></xsl:attribute>
      <xsl:if test="string-length(normalize-space(ODM/Archival)) &gt; 0">
         <xsl:attribute name="Archival"><xsl:value-of select="ODM/Archival"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/AsOfDateTime)) &gt; 0">
         <xsl:attribute name="AsOfDateTime"><xsl:value-of select="ODM/AsOfDateTime"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/Description)) &gt; 0">
         <xsl:attribute name="Description"><xsl:value-of select="ODM/Description"/></xsl:attribute>
      </xsl:if>
      <xsl:attribute name="FileType"><xsl:value-of select="ODM/FileType"/></xsl:attribute>
      <xsl:if test="string-length(normalize-space(ODM/Granularity)) &gt; 0">
         <xsl:attribute name="Granularity"><xsl:value-of select="ODM/Granularity"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/Id)) &gt; 0">
         <xsl:attribute name="Id"><xsl:value-of select="ODM/Id"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/ODMVersion)) &gt; 0">
         <xsl:attribute name="ODMVersion"><xsl:value-of select="ODM/ODMVersion"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/Originator)) &gt; 0">
         <xsl:attribute name="Originator"><xsl:value-of select="ODM/Originator"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/PriorFileOID)) &gt; 0">
         <xsl:attribute name="PriorFileOID"><xsl:value-of select="ODM/PriorFileOID"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/SourceSystem)) &gt; 0">
         <xsl:attribute name="SourceSystem"><xsl:value-of select="ODM/SourceSystem"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="string-length(normalize-space(ODM/SourceSystemVersion)) &gt; 0">
         <xsl:attribute name="SourceSystemVersion"><xsl:value-of select="ODM/SourceSystemVersion"/></xsl:attribute>
      </xsl:if>

     <xsl:call-template name="Study"/>

  </ODM>

  </xsl:template>

</xsl:stylesheet>