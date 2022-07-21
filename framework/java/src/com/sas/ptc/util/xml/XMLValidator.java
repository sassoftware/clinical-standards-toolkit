package com.sas.ptc.util.xml;

import java.io.File;
import java.io.IOException;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Source;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;

import org.xml.sax.ErrorHandler;
import org.xml.sax.SAXException;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Provides for validation of an XML document against a W3C XML Schema.
 */
public class XMLValidator {

    private String xmlPath;
    private String schemaPath;
    private ErrorHandler errorHandler;

    private static final String FILE_PROTOCOL_PREFIX = "file:///";

    private static final int ARGSCOUNT = 2;

    /**
     * The main entry point for the application.
     * 
     * @param args The path to the XML file and the path to the Schema file, in that order.
     */
    public static void main(final String[] args) {
        if (args.length != ARGSCOUNT) {
            System.err.println("Usage: java XMLValidator pathToXML pathToSchema");
        }

        final String xmlFilePath = args[0];
        final String schemaPath = args[1];

        final XMLValidator validator = new XMLValidator();
        validator.setXmlPath(xmlFilePath);
        validator.setSchemaPath(schemaPath);

        try {
            final boolean success = validator.doValidate();
            if (success) {
                System.out.println("Validation was successful.");
            }
        } catch (final SAXException e) {
            e.printStackTrace();
            System.exit(1);
        } catch (final IOException e) {
            e.printStackTrace();
            System.exit(1);
        } finally {
            System.out.println(">> DONE >>");
            System.exit(0);
        }
    }

    /**
     * Validates the XML file known to this instance against the schema file supplied to this class.
     * 
     * @return true if the XML document was found to be valid. If there is a validation error, a SAXException will be
     *         thrown.
     * @throws ParserConfigurationException If JAXP is not configured. Should never happen.
     * @throws SAXException If a validation error occurred.
     * @throws IOException If the XML file or the schema file could not be read.
     */
    public boolean doValidate() throws SAXException, IOException {

        // 1. Lookup a factory for the W3C XML Schema language
        final SchemaFactory factory = SchemaFactory.newInstance("http://www.w3.org/2001/XMLSchema");

        // 2. Compile the schema.
        final File schemaLocation = new File(getSchemaPath());
        final Schema schema = factory.newSchema(schemaLocation);

        // 3. Get a validator from the schema.
        final Validator validator = schema.newValidator();

        // 4. Parse the document
        final Source source = new StreamSource(FILE_PROTOCOL_PREFIX + getXmlPath());

        // 5. Check the document
        try {
            if (getErrorHandler() != null) {
                validator.setErrorHandler(getErrorHandler());
            }
            validator.validate(source);
            return true;
        } catch (final SAXException ex) {
            return false;
        }
    }

    /**
     * Gets the path to the XML file.
     * 
     * @return The absolute path to the XML file.
     */
    public String getXmlPath() {
        return this.xmlPath;
    }

    /**
     * Sets the path to the XML file.
     * 
     * @param xmlPath The absolute path to the XML file.
     */
    public void setXmlPath(final String xmlPath) {
        this.xmlPath = xmlPath;
    }

    /**
     * Gets the path to the Schema file.
     * 
     * @return the absolute path to the Schema file.
     */
    public String getSchemaPath() {
        return this.schemaPath;
    }

    /**
     * Sets the path to the Schema file.
     * 
     * @param schemaPath the absolute path to the Schema file.
     */
    public void setSchemaPath(final String schemaPath) {
        this.schemaPath = schemaPath;
    }

    /**
     * Method getErrorHandler.
     * 
     * @return ErrorHandler
     */
    public ErrorHandler getErrorHandler() {
        return errorHandler;
    }

    /**
     * Method setErrorHandler.
     * 
     * @param errorHandler ErrorHandler
     */
    public void setErrorHandler(final ErrorHandler errorHandler) {
        this.errorHandler = errorHandler;
    }
}
