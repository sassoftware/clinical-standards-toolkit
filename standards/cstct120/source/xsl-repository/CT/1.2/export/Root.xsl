<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xalan="http://xml.apache.org/xalan"
  xmlns:nciodm="http://ncicb.nci.nih.gov/xml/odm/EVS/CDISC">

    <!--  Set up Global Parameters -->
    <xsl:import href="config/Parameters.xsl" />

    <!-- Start building -->
    <xsl:import href="ODM.xsl" />

    <xsl:output method="xml" encoding="UTF-8" indent="yes" xalan:indent-amount="4"/>

</xsl:stylesheet>