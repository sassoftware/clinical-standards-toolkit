package com.sas.ptc.transform.xml;

import java.io.IOException;

import javax.xml.parsers.ParserConfigurationException;

import org.xml.sax.SAXException;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Produces a CDI Toolkit-consumable cube XML file from a standards-compliant XML file.
 */
public class StandardXMLImporter extends StandardXMLTransformer {

    /**
     * Constructs an importer configured to the provided parameters.
     * 
     * @param params Parameters for the execution of this import
     */
    public StandardXMLImporter(final StandardXMLTransformerParams params) {
        super(params);
    }

    /**
     * Executes the transformation, subject to the instance's current set of parameters.
     * 
     * @throws TransformNotFoundException
     * @throws IOException
     */
    @Override
    public void exec() throws TransformNotFoundException {
        initLog();

        if (getParams().isCreatingFoldersForOutput()) {
            createOutputFolders();
        }

        getLog().logInfo("Transform starting.");
        getLog().logInfo("Using JRE: " + System.getProperty("java.home"));
        getLog().logParameters(getParams());
        boolean isValid = true;

        if (getParams().isValidatingStandardXML()) {
            final String schemaPath = getFullValidatingSchemaPath();
            if (schemaPath != null) {
                try {
                    validateStandardXML(getTransformInputPath(), schemaPath);
                } catch (final SAXException e) {
                    isValid = false;
                    getLog().logError(e);
                } catch (final IOException e) {
                    isValid = false;
                    getLog().logError(e);
                }
            }
        }

        if (isValid || (!isValid && !getParams().getFailOnValidationError())) {
            if (!getParams().isValidatingXMLOnly()) {
                runTransform(getTransformInputPath(), getAvailableTransforms().getXSLFileToInvoke(getParams()),
                    getTransformOutputPath());
            }
        }

        try {
            writeLog();
        } catch (final ParserConfigurationException e) {
            e.printStackTrace();
        }
    }

    /**
     * Method getTransformInputPath.
     * 
     * @return String
     */
    @Override
    protected String getTransformInputPath() {
        return getParams().getStandardXMLPath();
    }

    /**
     * Method getTransformOutputPath.
     * 
     * @return String
     */
    @Override
    protected String getTransformOutputPath() {
        return getParams().getSasXMLPath();
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