package com.sas.ptc.transform.xml;

import java.io.File;
import java.io.IOException;

import javax.xml.parsers.ParserConfigurationException;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.sas.ptc.transform.xml.log.Log;
import com.sas.ptc.transform.xml.log.LogEntry;
import com.sas.ptc.util.xml.DOMUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Encapsulates the data needed for processing the conversion of a (SAS cube XML) to/from a standard XML document.
 */
public class StandardXMLTransformerParams {

    private static final String DEFAULT_IMPORT_OR_EXPORT = "EXPORT";
    private static final String DEFAULT_ENCODING = "UTF-8";
    private static final String DEFAULT_CREATION_OVERRIDE = "2008-05-24T16:31:25-04:00";
    private static final String DEFAULT_LOG_OVERRIDE = "2008-05-24T16:31:25-04:00";

    private static final String DEFAULT_HEADER_COMMENT_TEXT = "Produced from SAS data using the SAS Clinical Standards Toolkit";

    public static final String EXPORT = "EXPORT";
    public static final String IMPORT = "IMPORT";

    private String availableTransformsFilePath;

    private String importOrExport;

    private String sasXMLPath;
    private String standardXMLPath;

    private boolean creatingFoldersForOutput;

    private String standardName;
    private String standardVersion;

    private String schemaBasePath;
    private String xslBasePath;

    private int logLevel;
    private String logFilePath;

    private String headerCommentText;

    private String outputEncoding;

    private boolean creatingDisplayStylesheet;
    private String customStylesheetPath;
    private String outputStylesheetName;

    private boolean validatingStandardXML;
    private boolean validatingXMLOnly;
    private boolean failOnValidationError;

    private boolean overridingCreationDate;
    private String creationDateOverrideValue;

    private boolean overridingLogTimestampDate;
    private String logTimestampDateOverrideValue;

    /**
     * Construct an instance containing the appropriate default values where applicable.
     */
    public StandardXMLTransformerParams() {
        this.importOrExport = DEFAULT_IMPORT_OR_EXPORT;
        this.outputEncoding = DEFAULT_ENCODING;
        this.overridingCreationDate = false;
        this.creationDateOverrideValue = DEFAULT_CREATION_OVERRIDE;
        this.logTimestampDateOverrideValue = DEFAULT_LOG_OVERRIDE;
        this.validatingStandardXML = true;
        this.headerCommentText = DEFAULT_HEADER_COMMENT_TEXT;
        this.failOnValidationError = false;
        this.logLevel = Log.LOG_LEVEL_WARNING;
        this.creatingFoldersForOutput = true;
    }

    /**
     * Constructs an instance, initializing values to those supplied in the configuration file at the path (absolute)
     * indicated.
     * 
     * @param pathToConfigFile
     * @throws ParserConfigurationException
     * @throws SAXException
     * @throws IOException
     */
    public StandardXMLTransformerParams(final String pathToConfigFile)
        throws ParserConfigurationException, SAXException, IOException {
        this();
        final File f = new File(pathToConfigFile);
        final Document document = DOMUtils.getDocument(f);
        populateConfig(document);
    }

    /**
     * Constructor for StandardXMLTransformerParams.
     * 
     * @param pathToConfigFile String
     * @param workspaceRootPath String
     * @throws ParserConfigurationException
     * @throws SAXException
     * @throws IOException
     */
    public StandardXMLTransformerParams(final String pathToConfigFile, final String workspaceRootPath)
        throws ParserConfigurationException, SAXException, IOException {
        this(pathToConfigFile);
        if (isAdjustingPathProperties(workspaceRootPath)) {
            final File workspaceRootFolder = new File(workspaceRootPath);
            adjustPathProperties(workspaceRootFolder);
        }
    }

    /**
     * Method isAdjustingPathProperties.
     * 
     * @param workspaceRootPath String
     * @return boolean
     */
    protected boolean isAdjustingPathProperties(final String workspaceRootPath) {
        if (workspaceRootPath != null) {
            final File workspaceRootFolder = new File(workspaceRootPath);
            if (workspaceRootFolder.exists() && workspaceRootFolder.isDirectory()) {
                return true;
            }
        }

        return false;
    }

    /**
     * Method adjustPathProperties.
     * 
     * @param workspaceRootFolder File
     */
    protected void adjustPathProperties(final File workspaceRootFolder) {
        // adjust paths for:
        // sasXMLPath, xslBasePath, standardXMLPath, schemaBasePath,
        // extensionBasePath
        // customStylesheetPath, logFilePath
        this.sasXMLPath = adjustPathProperty(workspaceRootFolder, this.sasXMLPath);
        this.xslBasePath = adjustPathProperty(workspaceRootFolder, this.xslBasePath);
        this.standardXMLPath = adjustPathProperty(workspaceRootFolder, this.standardXMLPath);
        this.schemaBasePath = adjustPathProperty(workspaceRootFolder, this.schemaBasePath);
        this.customStylesheetPath = adjustPathProperty(workspaceRootFolder, this.customStylesheetPath);
        this.logFilePath = adjustPathProperty(workspaceRootFolder, this.logFilePath);
        this.availableTransformsFilePath = adjustPathProperty(workspaceRootFolder, this.availableTransformsFilePath);
    }

    /**
     * Method adjustPathProperty.
     * 
     * @param workspaceRootFolder File
     * @param value String
     * @return String
     */
    protected String adjustPathProperty(final File workspaceRootFolder, final String value) {
        String result = value;
        if (value != null) {
            result = new File(workspaceRootFolder, value).getAbsolutePath();
        }

        return result;
    }

    /**
     * A testing utility that populates the transform params from an XML file representing a transform configuration.
     * 
     * @param doc An XML configuration file
     */
    protected void populateConfig(final Document doc) {
        final NodeList paramElements = doc.getElementsByTagName("Param");
        for (int i = 0; i < paramElements.getLength(); ++i) {
            final Element param = (Element) paramElements.item(i);
            final String paramName = param.getAttribute("name");
            final String paramValue = param.getAttribute("value");

            if ("sasXMLPath".equals(paramName)) {
                this.sasXMLPath = paramValue;
            } else if ("xslBasePath".equals(paramName)) {
                this.xslBasePath = paramValue;
            } else if ("standardXMLPath".equals(paramName)) {
                this.standardXMLPath = paramValue;
            } else if ("standardName".equals(paramName)) {
                this.standardName = paramValue;
            } else if ("standardVersion".equals(paramName)) {
                this.standardVersion = paramValue;
            } else if ("sasXMLPath".equals(paramName)) {
                this.sasXMLPath = paramValue;
            } else if ("creatingDisplayStylesheet".equals(paramName)) {
                this.creatingDisplayStylesheet = Boolean.valueOf(paramValue).booleanValue();
            } else if ("customStylesheetPath".equals(paramName)) {
                this.customStylesheetPath = paramValue;
            } else if ("outputStylesheetName".equals(paramName)) {
                this.outputStylesheetName = paramValue;
            } else if ("validatingStandardXML".equals(paramName)) {
                this.validatingStandardXML = Boolean.valueOf(paramValue).booleanValue();
            } else if ("schemaBasePath".equals(paramName)) {
                this.schemaBasePath = paramValue;
            } else if ("importOrExport".equals(paramName)) {
                this.importOrExport = paramValue;
            } else if ("outputEncoding".equals(paramName)) {
                this.outputEncoding = paramValue;
            } else if ("overridingCreationDate".equals(paramName)) {
                this.overridingCreationDate = Boolean.valueOf(paramValue).booleanValue();
            } else if ("creationDateOverrideValue".equals(paramName)) {
                this.creationDateOverrideValue = paramValue;
            } else if ("logFilePath".equals(paramName)) {
                this.logFilePath = paramValue;
            } else if ("overridingLogTimestampDate".equals(paramName)) {
                this.overridingLogTimestampDate = Boolean.valueOf(paramValue).booleanValue();
            } else if ("logTimestampDateOverrideValue".equals(paramName)) {
                this.logTimestampDateOverrideValue = paramValue;
            } else if ("headerCommentText".equals(paramName)) {
                this.headerCommentText = paramValue;
            } else if ("failOnValidationError".equals(paramName)) {
                this.failOnValidationError = Boolean.valueOf(paramValue).booleanValue();
            } else if ("availableTransformsFilePath".equals(paramName)) {
                this.availableTransformsFilePath = paramValue;
            } else if ("logLevel".equals(paramName)) {
                this.logLevel = LogEntry.getLogLevel(paramValue);
            } else if ("validatingXMLOnly".equals(paramName)) {
                this.validatingXMLOnly = Boolean.valueOf(paramValue).booleanValue();
            }
        }
    }

    /**
     * Determines whether the transformation will be an import of a standards-compliant XML file, or an export of a SAS
     * cube XML file. The parameter will be set to either "IMPORT" or "EXPORT", with "EXPORT" being the default.
     * 
     * @return Whether the transform will be an import or an export
     */
    public String getImportOrExport() {
        return this.importOrExport;
    }

    /**
     * Determines whether the transformation will be an import of a standards-compliant XML file, or an export of a SAS
     * cube XML file. The parameter will be set to either "IMPORT" or "EXPORT", with "EXPORT" being the default.
     * 
     * @param importOrExport Whether the transform will be an import or an export
     */
    public void setImportOrExport(final String importOrExport) {
        this.importOrExport = importOrExport;
    }

    /**
     * The absolute path to the SAS cube XML file. In the case of an export, this will be the source file. In the case
     * of an import, this will be the destination file.
     * 
     * @return The absolute path to the SAS cube XML file
     */
    public String getSasXMLPath() {
        return sasXMLPath;
    }

    /**
     * Sets the absolute path to the SAS cube XML file. In the case of an export, this will be the source file. In the
     * case of an import, this will be the destination file.
     * 
     * @param sasXMLPath The absolute path to the SAS cube XML file
     */
    public void setSasXMLPath(final String sasXMLPath) {
        this.sasXMLPath = sasXMLPath;
    }

    /**
     * The absolute path to the standards-compliant XML file. In the case of an export, this will be the destination
     * file. In the case of an import, this will be the source file.
     * 
     * @return The absolute path to the standards-compliant XML file
     */
    public String getStandardXMLPath() {
        return standardXMLPath;
    }

    /**
     * Sets the absolute path to the standards-compliant XML file. In the case of an export, this will be the
     * destination file. In the case of an import, this will be the source file.
     * 
     * @param standardXMLPath The absolute path to the standards-compliant XML file
     */
    public void setStandardXMLPath(final String standardXMLPath) {
        this.standardXMLPath = standardXMLPath;
    }

    /**
     * Gets the absolute path to the file in which logging information regarding the transform will be placed.
     * 
     * @return The absolute path to the log file.
     */
    public String getLogFilePath() {
        return logFilePath;
    }

    /**
     * Sets the absolute path to the file in which logging information regarding the transform will be placed. Any
     * existing log file at the same location will be overwritten when a transform is initiated.
     * 
     * @param logFilePath The absolute path to the log file.
     */
    public void setLogFilePath(final String logFilePath) {
        this.logFilePath = logFilePath;
    }

    /**
     * Method isCreatingDisplayStylesheet.
     * 
     * @return boolean
     */
    public boolean isCreatingDisplayStylesheet() {
        return creatingDisplayStylesheet;
    }

    /**
     * Method setCreatingDisplayStylesheet.
     * 
     * @param creatingDisplayStylesheet boolean
     */
    public void setCreatingDisplayStylesheet(final boolean creatingDisplayStylesheet) {
        this.creatingDisplayStylesheet = creatingDisplayStylesheet;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param creatingDisplayStylesheet
     */
    public void setCreatingDisplayStylesheetString(final String creatingDisplayStylesheet) {
        if (creatingDisplayStylesheet != null) {
            this.creatingDisplayStylesheet = Boolean.valueOf(creatingDisplayStylesheet).booleanValue();
        }
    }

    /**
     * Needed for SAS9.1 javaobj.
     */
    public void createDisplayStylesheet() {
        this.creatingDisplayStylesheet = true;
    }

    /**
     * Method getCustomStylesheetPath.
     * 
     * @return String
     */
    public String getCustomStylesheetPath() {
        return customStylesheetPath;
    }

    /**
     * Method setCustomStylesheetPath.
     * 
     * @param customStylesheetPath String
     */
    public void setCustomStylesheetPath(final String customStylesheetPath) {
        this.customStylesheetPath = customStylesheetPath;
    }

    /**
     * Method getOutputStylesheetName.
     * 
     * @return String
     */
    public String getOutputStylesheetName() {
        return outputStylesheetName;
    }

    /**
     * Method setOutputStylesheetName.
     * 
     * @param outputStylesheetName String
     */
    public void setOutputStylesheetName(final String outputStylesheetName) {
        this.outputStylesheetName = outputStylesheetName;
    }

    /**
     * Whether or not the standards XML file will be validated against the schema specified in its
     * StandardTransformInfo. true by default. When true, the standards file will be validated after having been
     * produced (in the case of an export) or before being consumed (in the case of an import).
     * 
     * @return Whether standards files will be validated against their schema
     */
    public boolean isValidatingStandardXML() {
        return validatingStandardXML;
    }

    /**
     * Sets whether or not the standards XML file will be validated against the schema specified in its
     * StandardTransformInfo. true by default. When true, the standards file will be validated after having been
     * produced (in the case of an export) or before being consumed (in the case of an import).
     * 
     * @param validatingStandardXML Whether standards files will be validated against their schema
     */
    public void setValidatingStandardXML(final boolean validatingStandardXML) {
        this.validatingStandardXML = validatingStandardXML;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param validatingStandardXML
     */
    public void setValidatingStandardXMLString(final String validatingStandardXML) {
        if (validatingStandardXML != null) {
            this.validatingStandardXML = Boolean.valueOf(validatingStandardXML).booleanValue();
        }
    }

    /**
     * Method setValidatingXMLOnly.
     * 
     * @param validateOnly boolean
     */
    public void setValidatingXMLOnly(final boolean validateOnly) {
        this.validatingXMLOnly = validateOnly;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param validateXMLOnlyString String
     */
    public void setValidatingXMLOnlyString(final String validateXMLOnlyString) {
        if (validateXMLOnlyString != null) {
            this.validatingXMLOnly = Boolean.valueOf(validateXMLOnlyString).booleanValue();
        }
    }

    /**
     * Method isValidatingXMLOnly.
     * 
     * @return boolean
     */
    public boolean isValidatingXMLOnly() {
        return this.validatingXMLOnly;
    }

    /**
     * Needed for SAS9.1 javaobj.
     */
    public void dontValidateStandardXML() {
        this.validatingStandardXML = false;
    }

    /**
     * The absolute path to the root folder of the XSL repository.
     * 
     * @return The absolute path to the root folder of the XSL repository
     */
    public String getXslBasePath() {
        return xslBasePath;
    }

    /**
     * Sets the absolute path to the root folder of the XSL repository.
     * 
     * @param xslBasePath The absolute path to the root folder of the XSL repository
     */
    public void setXslBasePath(final String xslBasePath) {
        this.xslBasePath = xslBasePath;
    }

    /**
     * The desired encoding for the generated file. The default is UTF-8.
     * 
     * @return The desired encoding for the generated file.
     */
    public String getOutputEncoding() {
        return outputEncoding;
    }

    /**
     * Sets the desired encoding for the generated file. The default is UTF-8.
     * 
     * @param outputEncoding The desired encoding for the generated file.
     */
    public void setOutputEncoding(final String outputEncoding) {
        this.outputEncoding = outputEncoding;
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
     * 
     * Sets the name of the standard. For example, "CRT-DDS" or "ODM".
     * 
     * @param standardName The name of the standard
     */
    public void setStandardName(final String standardName) {
        this.standardName = standardName.trim();
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
        this.standardVersion = standardVersion.trim();
    }

    /**
     * By default, this property is set to false, meaning that a creation date will be calculated during transform
     * execution and used in output generation as required. However, it may be useful to override this behavior, instead
     * forcing the creation date value to be set to a known value (especially handy when testing produced XML against a
     * fixed prototype file).
     * 
     * @return Whether or not a fixed creation date will be used
     */
    public boolean isOverridingCreationDate() {
        return overridingCreationDate;
    }

    /**
     * By default, this property is set to false, meaning that a creation date will be calculated during transform
     * execution and used in output generation as required. However, it may be useful to override this behavior, instead
     * forcing the creation date value to be set to a known value (especially handy when testing produced XML against a
     * fixed prototype file).
     * 
     * @param overridingCreationDate Whether or not a fixed creation date will be used
     */
    public void setOverridingCreationDate(final boolean overridingCreationDate) {
        this.overridingCreationDate = overridingCreationDate;
    }

    /**
     * If overridingCreationDate is true, this fixed value will be used instead of the current time.
     * 
     * @return A fixed xsd:dateTime
     */
    public String getCreationDateOverrideValue() {
        return creationDateOverrideValue;
    }

    /**
     * If overridingCreationDate is true, this fixed value will be used instead of the current time.
     * 
     * @param creationDateOverrideValue The xsd:dateTime to be used as the current time
     */
    public void setCreationDateOverrideValue(final String creationDateOverrideValue) {
        this.creationDateOverrideValue = creationDateOverrideValue;
    }

    /**
     * The path to the root folder of the schema repository. Absolute schema paths will be calculated by appending a
     * particular relative value in a StandardTransformInfo object to this path.
     * 
     * @return The path to the root folder of the schema repository
     */
    public String getSchemaBasePath() {
        return schemaBasePath;
    }

    /**
     * Sets the path to the root folder of the schema repository. Absolute schema paths will be calculated by appending
     * a particular relative value in a StandardTransformInfo object to this path.
     * 
     * @param schemaBasePath The path to the root folder of the schema repository
     */
    public void setSchemaBasePath(final String schemaBasePath) {
        this.schemaBasePath = schemaBasePath;
    }

    /**
     * Gets the text to be placed in a top-level comment in any exported standards file.
     * 
     * @return The text to be placed in a top-level comment in any exported standards file
     */
    public String getHeaderCommentText() {
        return DOMUtils.escapeForXML(headerCommentText);
    }

    /**
     * Sets the text to be placed in a top-level comment in any exported standards file.
     * 
     * @param headerCommentText The text to be placed in a top-level comment in any exported standards file
     */
    public void setHeaderCommentText(final String headerCommentText) {
        this.headerCommentText = headerCommentText;
    }

    /**
     * Whether or not the transform should proceed if the document to be processed was schema-validated and found to be
     * not valid.
     * 
     * @return True if the transformation should not continue if the input document was found to be invalid against its
     *         schema, false if the transform should continue regardless
     */
    public boolean getFailOnValidationError() {
        return failOnValidationError;
    }

    /**
     * Sets whether or not the transform should proceed if the document to be processed was schema-validated and found
     * to be not valid.
     * 
     * @param failOnValidationError True if the transformation should not continue if the input document was found to be
     *            invalid against its schema, false if the transform should continue regardless
     */
    public void setFailOnValidationError(final boolean failOnValidationError) {
        this.failOnValidationError = failOnValidationError;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param s true or false
     */
    public void setFailOnValidationErrorString(final String s) {
        if (s != null) {
            this.failOnValidationError = Boolean.valueOf(s).booleanValue();
        }
    }

    /**
     * Gets the minimum level of log messages to produce. All messages at the given severity and higher will be
     * produced.
     * 
     * @return The minimum level of log messages to produce
     */
    public int getLogLevel() {
        return logLevel;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param logLevel A String representing a minimum log level
     * @see LogEntry#SEVERITY_ERROR
     * @see LogEntry#SEVERITY_FATAL_ERROR
     * @see LogEntry#SEVERITY_INFO
     * @see LogEntry#SEVERITY_WARNING
     */
    public void setLogLevelString(final String logLevel) {
        this.logLevel = LogEntry.getLogLevel(logLevel);
    }

    /**
     * Sets the minimum level of log messages to produce. All messages at the given severity and higher will be
     * produced.
     * 
     * @param logLevel The minimum level of log messages to produce
     */
    public void setLogLevel(final int logLevel) {
        this.logLevel = logLevel;
    }

    /**
     * Method isOverridingLogTimestampDate.
     * 
     * @return boolean
     */
    public boolean isOverridingLogTimestampDate() {
        return overridingLogTimestampDate;
    }

    /**
     * Method setOverridingLogTimestampDate.
     * 
     * @param overridingLogTimestampDate boolean
     */
    public void setOverridingLogTimestampDate(final boolean overridingLogTimestampDate) {
        this.overridingLogTimestampDate = overridingLogTimestampDate;
    }

    /**
     * Method getLogTimestampDateOverrideValue.
     * 
     * @return String
     */
    public String getLogTimestampDateOverrideValue() {
        return logTimestampDateOverrideValue;
    }

    /**
     * Method setLogTimestampDateOverrideValue.
     * 
     * @param logTimestampDateOverrideValue String
     */
    public void setLogTimestampDateOverrideValue(final String logTimestampDateOverrideValue) {
        this.logTimestampDateOverrideValue = logTimestampDateOverrideValue;
    }

    /**
     * Method isCreatingFoldersForOutput.
     * 
     * @return boolean
     */
    public boolean isCreatingFoldersForOutput() {
        return creatingFoldersForOutput;
    }

    /**
     * Method setCreatingFoldersForOutput.
     * 
     * @param creatingFoldersForOutput boolean
     */
    public void setCreatingFoldersForOutput(final boolean creatingFoldersForOutput) {
        this.creatingFoldersForOutput = creatingFoldersForOutput;
    }

    /**
     * Needed for SAS9.1 javaobj.
     * 
     * @param creatingFoldersForOutput String
     */
    public void setCreatingFoldersForOutputString(final String creatingFoldersForOutput) {
        if (creatingFoldersForOutput != null) {
            this.creatingFoldersForOutput = Boolean.valueOf(creatingFoldersForOutput).booleanValue();
        }
    }

    /**
     * Method getAvailableTransformsFilePath.
     * 
     * @return String
     */
    public String getAvailableTransformsFilePath() {
        return availableTransformsFilePath;
    }

    /**
     * Method setAvailableTransformsFilePath.
     * 
     * @param availableTransformsFilePath String
     */
    public void setAvailableTransformsFilePath(final String availableTransformsFilePath) {
        this.availableTransformsFilePath = availableTransformsFilePath;
    }

}
