<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xsi="http://www.w3c.org/2001/XMLSchema-instance"
	xmlns:xlink="http://www.w3.org/1999/xlink"
	xmlns:odm="http://www.cdisc.org/ns/odm/v1.2"
	xmlns:xalan="http://xml.apache.org/xalan">

    <!--  Set up Global Parameters -->    
    <xsl:import href="config/Parameters.xsl" />
    
    <!-- Start building -->
    <xsl:import href="DefineDocument.xsl" />
    
    <xsl:output method="xml" encoding="UTF-8" indent="yes" xalan:indent-amount="4"/>
        
</xsl:stylesheet>