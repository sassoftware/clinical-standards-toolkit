package com.sas.ptc.transform.xml;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;

import javax.xml.parsers.ParserConfigurationException;

import org.xml.sax.SAXException;

import com.sas.ptc.util.FileUtils;
import com.sas.ptc.util.xml.XSLTransform;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Produces a standards-compliant XML file, given a set of SAS cube XML files produced by the core CST Toolkit.
 */
public class StandardXMLExporter extends StandardXMLTransformer {

    /**
     * Constructs an exporter configured to the provided parameters.
     * 
     * @param params Parameters for the execution of this export
     */
    public StandardXMLExporter(final StandardXMLTransformerParams params) {
        super(params);
    }

    /**
     * Execute the transformation, subject to the instance's current set of parameters.
     * 
     * @throws IOException If an error occurred while accessing files
     * @throws TransformNotFoundException If the transform specified by the execution parameters was not found among the
     *             set of transforms currently available to this system.
     */
    @Override
    public void exec() {
        initLog();

        if (getParams().isCreatingFoldersForOutput()) {
            createOutputFolders();
        }

        try {
            getLog().logInfo("Transform starting.");
            getLog().logInfo("Using JRE: " + System.getProperty("java.home"));
            getLog().logParameters(getParams());

            final boolean paramsValid = validateParameters();
            if (paramsValid) {
                if (!getParams().isValidatingXMLOnly()) {
                    runTransform(getTransformInputPath(), getAvailableTransforms().getXSLFileToInvoke(getParams()),
                        getTransformOutputPath());
                }

                if (getParams().isValidatingStandardXML()) {
                    final String schemaPath = getFullValidatingSchemaPath();
                    if (schemaPath != null) {
                        try {
                            validateStandardXML(getTransformOutputPath(), schemaPath);
                        } catch (final SAXException e) {
                            getLog().logError(e);
                        } catch (final IOException e) {
                            getLog().logError(e);
                        }
                    }
                }
            }
        } catch (final Throwable t) {
            getLog().logError(t);
        }

        try {
            writeLog();
        } catch (final ParserConfigurationException e) {
            e.printStackTrace(); 
        }
    }

    /**
     * Gets the path to the output file for the transform, regardless of whether the transform is a standards import or
     * export.
     * 
     * @return The path to the output file for the transform
     */
    @Override
    protected String getTransformOutputPath() {
        return getParams().getStandardXMLPath();
    }

    /**
     * Gets the path to the input file for the transform, regardless of whether the transform is a standards import or
     * export.
     * 
     * @return The path to the input file for the transform
     */
    @Override
    protected String getTransformInputPath() {
        return getParams().getSasXMLPath();
    }

    /**
     * This override performs configuration specific to writing to a standards-conformant format. The primary example is
     * the setting of parameters associated with the creation of an XML processing instruction to reference a default
     * stylesheet to be used in display of the generated file.
     * 
     * @param tformer The XSLTransform object to be configured.
     */
    @Override
    protected void configureTransformer(final XSLTransform tformer) {
        // General configuration
        super.configureTransformer(tformer);

        // Display stylesheet work is specific to writing to a standards file
        if (getParams().isCreatingDisplayStylesheet()) {
            createDisplayStylesheet();

            final String stylesheetRefParamName = "stylesheetref.creation";
            tformer.addParameter(stylesheetRefParamName, "true");

            final String styleSheetNameParamName = "stylesheetref.name";
            final String destName = getParams().getOutputStylesheetName();
            tformer.addParameter(styleSheetNameParamName, destName);
        }
    }

    /**
     * Method createDisplayStylesheet.
     */
    protected void createDisplayStylesheet() {

        final String customSourcePath = getParams().getCustomStylesheetPath();
        if ((customSourcePath == null) || (customSourcePath.length() == 0)) {
            // here, we use the default stylesheet
            createDefaultStylesheet();
        } else {
            final File sourceFile = new File(customSourcePath);
            if (sourceFile.exists()) {
                createCustomStylesheet(sourceFile);
            }
        }
    }

    /**
     * Method createDefaultStylesheet.
     */
    protected void createDefaultStylesheet() {
        try {
            String defaultFileName = getCurrentTransformInfo().getDefaultStylesheet();
            if (defaultFileName != null) {
                defaultFileName = defaultFileName.toLowerCase();
                String destName = getParams().getOutputStylesheetName();

                // if a specific destination name was not specified, use the
                // same name as the source file
                if ((null == destName) || (destName.trim().length() == 0)) {
                    destName = defaultFileName;
                    getParams().setOutputStylesheetName(destName);
                }

                final String outputFilePath = getParams().getStandardXMLPath();
                final File outputFile = new File(outputFilePath);
                final String outputFolder = outputFile.getParent();

                final File destFile = new File(outputFolder, destName);
                final InputStream is = this.getClass().getResourceAsStream(defaultFileName);

                try {
                    FileUtils.copyFile(is, destFile);
                } catch (final IOException e) {
                    getLog().logError(e);
                }
            }
        } catch (final TransformNotFoundException e1) {
            getLog().logError(e1);
        }
    }

    /**
     * Method createCustomStylesheet.
     * 
     * @param sourceFile File
     */
    protected void createCustomStylesheet(final File sourceFile) {
        String destName = getParams().getOutputStylesheetName();

        // if a specific destination name was not specified, use the
        // same name as the source file
        if ((null == destName) || (destName.trim().length() == 0)) {
            destName = sourceFile.getName();
            getParams().setOutputStylesheetName(destName);
        }

        final String outputFilePath = getParams().getStandardXMLPath();
        final File outputFile = new File(outputFilePath);
        final String outputFolder = outputFile.getParent();

        final File destFile = new File(outputFolder, destName);

        try {
            if (!FileUtils.pathsAreEquivalent(sourceFile, destFile)) {
                try {
                    FileUtils.copyFile(sourceFile, destFile);
                } catch (final IOException e) {
                    getLog().logError(e);
                }
            } else {
                getLog().logWarning("The stylesheet source and destination are the same.");
            }
        } catch (final IOException e) {
            getLog().logError(e);
        }
    }

    /**
     * Sets the parameters to be used for transform execution.
     * 
     * @param params The transformation parameters
     */
    @Override
    public void setParams(final StandardXMLTransformerParams params) {
        super.setParams(params);
    }
}