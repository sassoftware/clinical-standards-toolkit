package com.sas.ptc.transform.xml.log;

import org.xml.sax.ErrorHandler;
import org.xml.sax.SAXParseException;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * The XML error handler object that allows for the capture of error and warning messages during XML Schema validation
 * of the produced XML document.
 */
public class ValidationErrorHandler implements ErrorHandler {

    private boolean valid;
    private final Log log;

    /**
     * Constructor for ValidationErrorHandler.
     *
     * @param log Log
     */
    public ValidationErrorHandler(final Log log) {
        this.log = log;
        this.valid = true;
    }

    /**
     * To be invoked upon encountering a validation error.
     * 
     * @param exception The exception encapsulating the error
     * @see org.xml.sax.ErrorHandler#error(SAXParseException)
     */
    @Override
    public void error(final SAXParseException exception) {
        getLog().logValidationMessage(LogEntry.SEVERITY_ERROR, exception);
        this.valid = false;
    }

    /**
     * To be invoked upon encountering a validation fatal error.
     * 
     * @param exception The exception encapsulating the fatal error
     * @see org.xml.sax.ErrorHandler#fatalError(SAXParseException)
     */
    @Override
    public void fatalError(final SAXParseException exception) {
        getLog().logValidationMessage(LogEntry.SEVERITY_FATAL_ERROR, exception);
        this.valid = false;
    }

    /**
     * To be invoked upon encountering a validation warning.
     * 
     * @param exception The exception encapsulating the warning
     * @see org.xml.sax.ErrorHandler#warning(SAXParseException)
     */
    @Override
    public void warning(final SAXParseException exception) {
        getLog().logValidationMessage(LogEntry.SEVERITY_WARNING, exception);
    }

    /**
     * Method isValid.
     *
     * @return boolean
     */
    public boolean isValid() {
        return valid;
    }

    /**
     * Gets the Log to which entries are being written in response to errors and warnings trapped by this handler.
     * 
     * @return The Log to which entries are being written
     */
    protected Log getLog() {
        return log;
    }

}
