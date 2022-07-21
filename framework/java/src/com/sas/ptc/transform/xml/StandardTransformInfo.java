package com.sas.ptc.transform.xml;

import org.w3c.dom.Element;

import com.sas.ptc.util.xml.DOMUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * <p>
 * Encapsulates information on a particular transform type, between SAS cube XML files and an external XML standard.
 * Each transform will be uniquely identified by its name, combined with its version.
 * </p>
 * <p>
 * The data comprising each standard will be read from the AvailableTransforms.xml file. External code should therefore
 * have no need to modify any of the properties of an instance of this class. In general, users of this class will only
 * be interested in the getFullXXXPath() methods.
 * </p>
 */
public class StandardTransformInfo {
    /*
     * Constants denoting the element names within the available transforms file.
     */
    private static final String STANDARD_NAME_ELEMENT_NAME = "StandardName";
    private static final String STANDARD_VERSION_ELEMENT_NAME = "StandardVersion";
    private static final String IMPORT_XSL_LOCATION_ELEMENT_NAME = "ImportXSL";
    private static final String EXPORT_XSL_LOCATION_ELEMENT_NAME = "ExportXSL";
    private static final String SCHEMA_LOCATION_ELEMENT_NAME = "Schema";
    private static final String DEFAULT_STYLESHEET_ELEMENT_NAME = "DefaultStylesheet";

    private String standardName;
    private String standardVersion;
    private String importXSLSubPath;
    private String exportXSLSubPath;
    private String schemaSubPath;
    private String defaultStylesheet;

    /**
     * Constructs an instance based on an element in the XML format for specifying the set of transforms available to
     * the system.
     * 
     * @param transformElement The root element for one transform info in the set
     */
    public StandardTransformInfo(final Element transformElement) {
        setStandardName(DOMUtils.getFirstSubelementValue(transformElement, STANDARD_NAME_ELEMENT_NAME));
        setStandardVersion(DOMUtils.getFirstSubelementValue(transformElement, STANDARD_VERSION_ELEMENT_NAME));
        setImportXSLSubPath(DOMUtils.getFirstSubelementValue(transformElement, IMPORT_XSL_LOCATION_ELEMENT_NAME));
        setExportXSLSubPath(DOMUtils.getFirstSubelementValue(transformElement, EXPORT_XSL_LOCATION_ELEMENT_NAME));
        setSchemaSubPath(DOMUtils.getFirstSubelementValue(transformElement, SCHEMA_LOCATION_ELEMENT_NAME));
        setDefaultStylesheet(DOMUtils.getFirstSubelementValue(transformElement, DEFAULT_STYLESHEET_ELEMENT_NAME));
    }

    /**
     * Gets the absolute path to the XSL file to be invoked for importing a standard XML file.
     * 
     * @param xslRootPath The absolute path to the XSL repository root folder
     * @return The absolute path to the import XSL file
     */
    public String getFullImportXSLPath(final String xslRootPath) {
        final String thePath = xslRootPath + "/" + getImportXSLSubPath();

        return thePath;
    }

    /**
     * Gets the absolute path to the XSL file to be invoked for exporting to a standard XML file.
     * 
     * @param xslRootPath The absolute path to the XSL repository root folder
     * @return The absolute path to the export XSL file
     */
    public String getFullExportXSLPath(final String xslRootPath) {
        final String thePath = xslRootPath + "/" + getExportXSLSubPath();

        return thePath;
    }

    /**
     * Gets the absolute path to the XML Schema file to be invoked for validating an XML file conforming to this
     * standard.
     * 
     * @param schemaRootPath The absolute path to the Schema repository root folder
     * @return The absolute path to the Schema
     */
    public String getFullSchemaPath(final String schemaRootPath) {
        final String thePath = schemaRootPath + "/" + getSchemaSubPath();

        return thePath;
    }

    /**
     * The name of the standard. For example, "CRT-DDS" or "ODM".
     * 
     * @return The name of the standard
     */
    public String getStandardName() {
        return standardName;
    }

    /**
     * Sets the name of the standard. For example, "CRT-DDS" or "ODM".
     * 
     * @param standardName The name of the standard
     */
    public void setStandardName(final String standardName) {
        this.standardName = standardName;
    }

    /**
     * The version of the standard. For example, "1.0" or "1.3.0".
     * 
     * @return The version of the standard
     */
    public String getStandardVersion() {
        return standardVersion;
    }

    /**
     * Sets the version of the standard. For example, "1.0" or "1.3.0".
     * 
     * @param standardVersion The version of the standard
     */
    public void setStandardVersion(final String standardVersion) {
        this.standardVersion = standardVersion;
    }

    /**
     * The path, relative to the XSL repository root, to the XSL file to be invoked for importing a standard XML file.
     * 
     * @return The relative path to the import XSL
     */
    public String getImportXSLSubPath() {
        return importXSLSubPath;
    }

    /**
     * Sets the path, relative to the XSL repository root, to the XSL file to be invoked for importing from a standard
     * XML file.
     * 
     * @param importXSLSubPath The relative path to the import XSL
     */
    public void setImportXSLSubPath(final String importXSLSubPath) {
        this.importXSLSubPath = importXSLSubPath;
    }

    /**
     * The path, relative to the XSL repository root, to the XSL file to be invoked for exporting to a standard XML
     * file.
     * 
     * @return The relative path to the export XSL
     */
    public String getExportXSLSubPath() {
        return exportXSLSubPath;
    }

    /**
     * Sets the path, relative to the XSL repository root, to the XSL file to be invoked for exporting to a standard XML
     * file.
     * 
     * @param exportXSLSubPath The relative path to the export XSL
     */
    public void setExportXSLSubPath(final String exportXSLSubPath) {
        this.exportXSLSubPath = exportXSLSubPath;
    }

    /**
     * The path, relative to the Schema repository root, to the XML Schema file to be invoked for validating an XML file
     * conforming to this standard.
     * 
     * @return The relative path to the Schema
     */
    public String getSchemaSubPath() {
        return schemaSubPath;
    }

    /**
     * Sets the path, relative to the Schema repository root, to the XML Schema file to be invoked for validating an XML
     * file conforming to this standard.
     * 
     * @param schemaSubPath The relative path to the Schema
     */
    public void setSchemaSubPath(final String schemaSubPath) {
        this.schemaSubPath = schemaSubPath;
    }

    /**
     * 
     * @return the default stylesheet short name
     */
    protected String getDefaultStylesheet() {
        return defaultStylesheet;
    }

    /**
     * 
     * @param defaultStylesheet the default stylesheet short name
     */
    protected void setDefaultStylesheet(final String defaultStylesheet) {
        this.defaultStylesheet = defaultStylesheet;
    }

    /**
     * Returns a string containing the identifying standard name and version.
     * 
     * @return A string containing details of this instance
     */
    @Override
    public String toString() {
        final StringBuffer sb = new StringBuffer();
        sb.append("Standard '").append(getStandardName()).append("', version '").append(getStandardVersion());

        return sb.toString();
    }
}
