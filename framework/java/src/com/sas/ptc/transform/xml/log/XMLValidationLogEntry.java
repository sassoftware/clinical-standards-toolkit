package com.sas.ptc.transform.xml.log;

import java.util.Date;

import org.w3c.dom.Element;

import com.sas.ptc.util.xml.DOMUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * A log entry produced during validation of the XML document against its XML schema.
 */
public class XMLValidationLogEntry extends LogEntry {

    private final int lineNumber;
    private final int columnNumber;

    /**
     * Constructor for XMLValidationLogEntry.
     *
     * @param severity String
     * @param origin String
     * @param message String
     * @param lineNumber int
     * @param columnNumber int
     */
    public XMLValidationLogEntry(final String severity, final String origin, final String message, final int lineNumber,
        final int columnNumber) {
        this(severity, origin, message, lineNumber, columnNumber, null);
    }

    /**
     * Constructor for XMLValidationLogEntry.
     *
     * @param severity String
     * @param origin String
     * @param message String
     * @param lineNumber int
     * @param columnNumber int
     * @param dateOverride Date
     */
    public XMLValidationLogEntry(final String severity, final String origin, final String message, final int lineNumber,
        final int columnNumber, final Date dateOverride) {
        super(severity, origin, message, dateOverride);
        this.lineNumber = lineNumber;
        this.columnNumber = columnNumber;
    }

    /**
     * Gets the line number relevant to this log entry of the XML document validated.
     * 
     * @return The line number relevant to this log entry of the XML document validated
     */
    public int getLineNumber() {
        return lineNumber;
    }

    /**
     * Gets the column number relevant to this log entry of the XML document validated.
     * 
     * @return The column number relevant to this log entry of the XML document validated
     */
    public int getColumnNumber() {
        return columnNumber;
    }

    /**
     * Method writeInDOM.
     *
     * @param parentElement Element
     * @return Element
     */
    @Override
    public Element writeInDOM(final Element parentElement) {
        final Element tableElement = super.writeInDOM(parentElement);

        final Element lineElement = parentElement.getOwnerDocument().createElement("LineNumber");
        tableElement.appendChild(lineElement);
        DOMUtils.setText(lineElement, getLineNumber() + "");

        final Element columnElement = parentElement.getOwnerDocument().createElement("ColumnNumber");
        tableElement.appendChild(columnElement);
        DOMUtils.setText(columnElement, getColumnNumber() + "");

        return tableElement;
    }

}
