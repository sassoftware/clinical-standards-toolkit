package com.sas.ptc.transform.xml;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Calendar;
import java.util.Date;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.TransformerException;

import org.xml.sax.SAXException;

import com.sas.ptc.transform.xml.log.Log;
import com.sas.ptc.transform.xml.log.ValidationErrorHandler;
import com.sas.ptc.util.xml.DateTimeUtils;
import com.sas.ptc.util.xml.XMLValidator;
import com.sas.ptc.util.xml.XSLTransform;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * The controller class for executing a transform between a standards-compliant XML file and a CDI toolkit-consumable
 * cube XML file.
 */
public abstract class StandardXMLTransformer {

    private Log log;

    /**
     * The parameters to transform execution.
     */
    private StandardXMLTransformerParams params;

    /**
     * The set of transforms and standards known to the system.
     */
    private AvailableTransforms availableTransforms;

    protected static final int FILENAME_RANDOM_RANGE = 100000;

    /**
     * Purely for unit-testing purposes.
     * 
     * @param args The lone arg is the absolute path to a params file
     */
    public static void main(final String[] args) {
        StandardXMLTransformer generator = null;
        try {
            final StandardXMLTransformerParams params = new StandardXMLTransformerParams(args[0]);

            if (StandardXMLTransformerParams.IMPORT.equals(params.getImportOrExport())) {
                generator = new StandardXMLImporter(params);
            } else {
                generator = new StandardXMLExporter(params);
            }
        } catch (final ParserConfigurationException e) {
            e.printStackTrace();
        } catch (final SAXException e) {
            e.printStackTrace();
        } catch (final IOException e) {
            e.printStackTrace();
        }

        try {
            generator.exec();
        } catch (final TransformNotFoundException e) {
            e.printStackTrace();
        } catch (final IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * Constructs an instance, configured to the supplied parameters.
     * 
     * @param params the parameters to transform execution.
     */
    protected StandardXMLTransformer(final StandardXMLTransformerParams params) {
        this.params = params;

        this.availableTransforms = new AvailableTransforms(params);
        try {
            this.availableTransforms.init();
        } catch (final ParserConfigurationException e) {
            getLog().logError(e);
        } catch (final SAXException e) {
            getLog().logError(e);
        } catch (final IOException e) {
            getLog().logError(e);
        }
    }

    /**
     * Creates folders for the log file and the output file. If the output folder does not exist and could not be
     * created, this is a fatal error, and false is returned.
     * 
     * @return false if the output folder could not be created, true otherwise
     */
    protected boolean createOutputFolders() {
        // create log folder
        if (getParams().getLogFilePath() != null) {
            final File logFolder = new File(getParams().getLogFilePath()).getParentFile();
            if (!logFolder.exists()) {
                final boolean success = logFolder.mkdirs();
                if (!success) {
                    getLog().logWarning("Folder '" + logFolder.getAbsolutePath()
                        + "' does not exist and could not be created. The log will be redirected to standard output.");
                    getParams().setLogFilePath(null);
                }
            }
        }

        // create output folder
        final File outputFolder = new File(getTransformOutputPath()).getParentFile();
        if (!outputFolder.exists()) {
            final boolean success = outputFolder.mkdirs();
            if (!success) {
                getLog().logFatalError(
                    "Folder '" + outputFolder.getAbsolutePath() + "' does not exist and could not be created.");
                return false;
            }
        }

        return true;
    }

    /**
     * Initializes the log to be used by the transformer.
     */
    protected void initLog() {
        setLog(new Log(getParams().getLogFilePath(), getParams().getLogLevel(),
            getParams().isOverridingLogTimestampDate(), getParams().getLogTimestampDateOverrideValue()));
    }

    /**
     * Method getTransformOutputPath.
     * 
     * @return String
     */
    protected abstract String getTransformOutputPath();

    /**
     * Method getTransformInputPath.
     * 
     * @return String
     */
    protected abstract String getTransformInputPath();

    /**
     * Factory method for creating a transformer. Removes the need for client code to consider whether to instantiate an
     * importer or exporter subclass based on parameter values.
     * 
     * @param params The parameters to the transform.
     * @return The appropriate transformer object, with the passed-in parameters applied
     */
    public static StandardXMLTransformer createTransformer(final StandardXMLTransformerParams params) {
        StandardXMLTransformer tformer = null;
        if (StandardXMLTransformerParams.IMPORT.equals(params.getImportOrExport())) {
            tformer = new StandardXMLImporter(params);
        } else {
            tformer = new StandardXMLExporter(params);
        }

        return tformer;
    }

    /**
     * Execute the transformation, subject to the instance's current parameters.
     * 
     * @throws TransformNotFoundException If the transform specified by the execution parameters was not found among the
     *             set of transforms currently available to this system.
     * @throws IOException If an error occurred while accessing files
     */
    public abstract void exec() throws TransformNotFoundException, IOException;

    /**
     * Gets the current set of parameters being used for transform execution.
     * 
     * @return The transformation parameters
     */
    public StandardXMLTransformerParams getParams() {
        return params;
    }

    /**
     * Sets the parameters to be used for transform execution.
     * 
     * @param params The transformation parameters
     */
    public void setParams(final StandardXMLTransformerParams params) {
        this.params = params;
    }

    /**
     * Run the XML transformation.
     * 
     * @param sourcePath The absolute path to the source XML file.
     * @param xslPath The absolute path to the XSL file describing the transform.
     * @param resultPath The absolute path to the desired results file.
     */
    public void runTransform(final String sourcePath, final String xslPath, final String resultPath) {
        final XSLTransform tformer = new XSLTransform();
        tformer.setSourceXmlPath(sourcePath);
        tformer.setXsltPath(xslPath);
        tformer.setOutputXmlPath(resultPath);

        configureTransformer(tformer);

        try {
            final long startTime = System.currentTimeMillis();
            tformer.doTransform();
            final long finishTime = System.currentTimeMillis();

            getLog().logInfo("Transform complete.");
            getLog().logInfo("Transform time: " + (finishTime - startTime) + " ms.");
        } catch (final FileNotFoundException e) {
            getLog().logError(e);
        } catch (final TransformerException e) {
            getLog().logError(e);
        } catch (final IOException e) {
            getLog().logError(e);
        }
    }

    /**
     * Method configureTransformer.
     * 
     * @param tformer XSLTransform
     */
    protected void configureTransformer(final XSLTransform tformer) {
        // Handle the timestamp
        final String creationDateTimeParamName = "timestamp.creation";
        String creationDateTimeValue = null;
        if (getParams().isOverridingCreationDate()) {
            creationDateTimeValue = getParams().getCreationDateOverrideValue();
        } else {
            // provide actual timestamp
            Date nowDate = Calendar.getInstance().getTime();
            if (nowDate == null) {
                final long systime = System.currentTimeMillis();
                nowDate = new Date(systime);
            }
            if (nowDate != null) {
                creationDateTimeValue = DateTimeUtils.javaDateToSchemaDateTime(nowDate);
            }
        }
        tformer.addParameter(creationDateTimeParamName, creationDateTimeValue);

        // Handle the output encoding
        final String outputEncoding = getParams().getOutputEncoding();
        if (null != outputEncoding) {
            tformer.setOutputEncoding(outputEncoding);
        } else {
            tformer.setOutputEncoding("UTF-8");
        }

        // handle the header comment text
        final String headerCommentText = getParams().getHeaderCommentText();
        tformer.addParameter("header.comment.text", headerCommentText);
    }

    /**
     * Validates the XML file produced.
     * 
     * @param xmlFilePath The XML file to be validated.
     * @param schemaPath The W3C XML Schema file against which the XML will be validated.
     * @throws SAXException
     * @throws IOException
     * @throws TransformerException
     */
    public void validateStandardXML(final String xmlFilePath, final String schemaPath)
        throws SAXException, IOException {
        // set up and perform validation on the output
        final XMLValidator validator = new XMLValidator();
        validator.setXmlPath(xmlFilePath);
        validator.setSchemaPath(schemaPath);

        getLog().logParameter("XML File to Validate", xmlFilePath);
        getLog().logParameter("Schema being validated against", schemaPath);

        ValidationErrorHandler errorHandler = null;
        errorHandler = new ValidationErrorHandler(getLog());
        validator.setErrorHandler(errorHandler);
        validator.doValidate();
        final boolean success = errorHandler.isValid();
        if (success) {
            getLog().logInfo("The document validated successfully");
        } else {
            getLog().logWarning("Document validation failed");
        }
    }

    /**
     * Gets the registry of available transformations.
     * 
     * @return The registry of available transformations
     */
    public AvailableTransforms getAvailableTransforms() {
        return availableTransforms;
    }

    /**
     * Sets the registry of available transformations.
     * 
     * @param availableTransforms The registry of available transformations
     */
    public void setAvailableTransforms(final AvailableTransforms availableTransforms) {
        this.availableTransforms = availableTransforms;
    }

    /**
     * Gets the object representing the configuration of the transform to be executed. This value is arrived at by
     * retrieving the matching object from the AvailableTransforms registry, using the name and version of the standard
     * given in the current parameters.
     * 
     * @return The transform configuration information corresponding to the standard name and version given in the
     *         parameters
     * @throws TransformNotFoundException
     */
    public StandardTransformInfo getCurrentTransformInfo() throws TransformNotFoundException {
        return getAvailableTransforms().getTransformInfo(getParams().getStandardName(),
            getParams().getStandardVersion());
    }

    /**
     * Gets the absolute path to the XML Schema file to be used during any validation of a standards file during
     * execution of this transform. This value is arrived at by retrieving the Schema path from the AvailableTransforms
     * registry, using the name and version of the standard given in the current parameters. The parameters'
     * schemaBasePath value is also used, allowing for calculation of the required absolute path.
     * 
     * @return The absolute path to the Schema file to be used for any validation of standards files
     * @throws TransformNotFoundException
     */
    protected String getFullValidatingSchemaPath() throws TransformNotFoundException {
        final StandardTransformInfo currentTransform = getCurrentTransformInfo();

        return currentTransform.getFullSchemaPath(getParams().getSchemaBasePath());
    }

    /**
     * Method getLog.
     * 
     * @return Log
     */
    protected Log getLog() {
        return log;
    }

    /**
     * Method setLog.
     * 
     * @param log Log
     */
    protected void setLog(final Log log) {
        this.log = log;
    }

    /**
     * Method writeLog.
     * 
     * @throws TransformerException
     * @throws ParserConfigurationException
     */
    protected void writeLog() throws ParserConfigurationException {
        getLog().write();
    }

    /**
     * Method validateParameters.
     * 
     * @return boolean
     */
    protected boolean validateParameters() {
        boolean isValid = true;

        // validate input file existence
        if (!getParams().isValidatingXMLOnly()) {
            final String inputPath = getTransformInputPath();
            if ((inputPath == null) || (inputPath.trim().length() == 0)) {
                getLog().logFatalError("The input file path was not specified.");
                isValid = false;
            } else {
                final File f = new File(inputPath);
                if (!f.exists()) {
                    getLog().logFatalError("Specified input file '" + f.getAbsolutePath() + "' does not exist.");
                    isValid = false;
                }
            }
        }

        // check output path
        if (!getParams().isValidatingXMLOnly()) {
            final String outputPath = getTransformOutputPath();
            if ((outputPath == null) || (outputPath.trim().length() == 0)) {
                getLog().logFatalError("The output path was not specified.");
                isValid = false;
            } else {
                final File f = new File(outputPath);
                final File dir = f.getParentFile();
                if (!dir.exists()) {
                    getLog().logFatalError("Specified output folder '" + dir.getAbsolutePath() + "' does not exist.");
                    isValid = false;
                }
            }
        }

        // valid log level (in range)
        final boolean logLevelValid = Log.isValidLogLevel(getParams().getLogLevel());
        if (!logLevelValid) {
            getLog().logWarning("Invalid log level requested: '" + getParams().getLogLevel() + "'. Resetting to '"
                + Log.LOG_LEVEL_WARNING + "' (Warning and higher).");
            getParams().setLogLevel(Log.LOG_LEVEL_WARNING);
        }

        // validate schema repository dir existence
        final String xsdRepoPath = getParams().getSchemaBasePath();
        if ((xsdRepoPath == null) || (xsdRepoPath.trim().length() == 0)) {
            getLog().logFatalError("The xml schema repository path was not specified.");
            isValid = false;
        } else {
            final File f = new File(xsdRepoPath);
            if (!f.exists()) {
                getLog().logFatalError(
                    "Supplied xml schema repository folder '" + f.getAbsolutePath() + "' does not exist.");
                isValid = false;
            }
        }

        // validate xsl repository dir existence
        if (!getParams().isValidatingXMLOnly()) {
            final String xslRepoPath = getParams().getXslBasePath();
            if ((xslRepoPath == null) || (xslRepoPath.trim().length() == 0)) {
                getLog().logFatalError("The xsl-repository path was not specified.");
                isValid = false;
            } else {
                final File f = new File(xslRepoPath);
                if (!f.exists()) {
                    getLog()
                        .logFatalError("Supplied xsl-repository folder '" + f.getAbsolutePath() + "' does not exist.");
                    isValid = false;
                }
            }
        }

        // if creating, validate custom path existence
        if (!getParams().isValidatingXMLOnly()) {
            if (getParams().isCreatingDisplayStylesheet()) {
                final String customPath = getParams().getCustomStylesheetPath();
                if ((null == customPath) || (customPath.trim().length() == 0)) {
                    try {
                        getLog()
                            .logInfo("Custom display stylesheet path not specified. Using built-in default stylesheet "
                                + getCurrentTransformInfo().getDefaultStylesheet() + ".");
                    } catch (final TransformNotFoundException e1) {
                        getLog().logError(e1);
                    }
                } else {
                    final File f = new File(customPath);
                    if (!f.exists()) {
                        getLog().logWarning("No file exists at supplied custom display stylesheet path '"
                            + f.getAbsolutePath() + "'. Using default display stylesheet instead.");
                        getParams().setCustomStylesheetPath(null);
                    }
                }
            }
        }

        return isValid;
    }
}