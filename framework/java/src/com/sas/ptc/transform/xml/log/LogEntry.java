package com.sas.ptc.transform.xml.log;

import java.util.Calendar;
import java.util.Date;

import org.w3c.dom.Element;

import com.sas.ptc.util.xml.DOMUtils;
import com.sas.ptc.util.xml.DateTimeUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Represents a single entry in the log produced during the execution of a transformation.
 */
public class LogEntry {
    public static final String SEVERITY_INFO = "INFO";
    public static final String SEVERITY_WARNING = "WARNING";
    public static final String SEVERITY_ERROR = "ERROR";
    public static final String SEVERITY_FATAL_ERROR = "FATAL ERROR";

    public static final String ORIGIN_XML_VALIDATION = "XML VALIDATION";
    public static final String ORIGIN_TRANSFORMER = "XML TRANSFORMER";
    public static final String ORIGIN_TRANSFORM_PARAM = "XML TRANSFORMER PARAMETER";

    public static final String SCOPE_USER = "USER";
    public static final String SCOPE_SYSTEM = "SYSTEM";

    private final String severity;
    private final String origin;
    private final Date timestamp;
    private final String message;
    private final int logLevel;
    private final String scope;

    /**
     * Constructor for LogEntry.
     * 
     * @param severity String
     * @param origin String
     * @param message String
     */
    public LogEntry(final String severity, final String origin, final String message) {
        this(severity, origin, message, Calendar.getInstance().getTime());
    }

    /**
     * 
     * @param severity
     * @param origin
     * @param message
     * @param scope
     */
    public LogEntry(final String severity, final String origin, final String message, final String scope) {
        this(severity, origin, message, Calendar.getInstance().getTime(), scope);
    }

    /**
     * Constructor for LogEntry. Scope is USER by default.
     * 
     * @param severity String
     * @param origin String
     * @param message String
     * @param timestampOverride Date
     */
    public LogEntry(final String severity, final String origin, final String message, final Date timestampOverride) {
        this(severity, origin, message, timestampOverride, SCOPE_USER);
    }

    /**
     * Constructor for LogEntry.
     * 
     * @param severity String
     * @param origin String
     * @param message String
     * @param timestampOverride Date
     * @param scope SYSTEM or USER
     */
    public LogEntry(final String severity, final String origin, final String message, final Date timestampOverride,
        final String scope) {
        this.severity = severity;
        this.logLevel = getLogLevel(severity);
        this.origin = origin;
        this.message = message;
        this.timestamp = timestampOverride;
        this.scope = scope;
    }

    /**
     * 
     * @return user or system
     */
    protected String getScope() {
        return scope;
    }

    /**
     * Method getLogLevel.
     * 
     * @param severity String
     * @return int
     */
    public static int getLogLevel(final String severity) {
        int returnValue = Log.LOG_LEVEL_WARNING;
        if (severity != null) {
            if (SEVERITY_INFO.equalsIgnoreCase(severity)) {
                returnValue = Log.LOG_LEVEL_INFO;
            } else if (SEVERITY_WARNING.equalsIgnoreCase(severity)) {
                returnValue = Log.LOG_LEVEL_WARNING;
            } else if (SEVERITY_ERROR.equalsIgnoreCase(severity)) {
                returnValue = Log.LOG_LEVEL_ERROR;
            } else if (SEVERITY_FATAL_ERROR.equalsIgnoreCase(severity)) {
                returnValue = Log.LOG_LEVEL_FATAL_ERROR;
            }
        }
        return returnValue;
    }

    /**
     * Gets the Date at which the event triggering this entry was encountered.
     * 
     * @return The Date at which the event triggering this entry was encountered
     */
    public Date getTimestamp() {
        return this.timestamp;
    }

    /**
     * Method getSeverity.
     * 
     * @return String
     */
    public String getSeverity() {
        return severity;
    }

    /**
     * Method getMessage.
     * 
     * @return String
     */
    public String getMessage() {
        return message;
    }

    /**
     * Method getOrigin.
     * 
     * @return String
     */
    public String getOrigin() {
        return origin;
    }

    /**
     * Method writeInDOM.
     * 
     * @param parentElement Element
     * @return Element
     */
    public Element writeInDOM(final Element parentElement) {
        final Element tableElement = parentElement.getOwnerDocument().createElement("XMLTransformLog");
        parentElement.appendChild(tableElement);

        final Element tsElement = parentElement.getOwnerDocument().createElement("Timestamp");
        tableElement.appendChild(tsElement);
        if (getTimestamp() != null) {
            DOMUtils.setText(tsElement, DateTimeUtils.javaDateToSchemaDateTime(getTimestamp()));
        }

        final Element scopeElement = parentElement.getOwnerDocument().createElement("Scope");
        tableElement.appendChild(scopeElement);
        DOMUtils.setText(scopeElement, getScope());

        final Element originElement = parentElement.getOwnerDocument().createElement("Origin");
        tableElement.appendChild(originElement);
        DOMUtils.setText(originElement, getOrigin());

        final Element sevElement = parentElement.getOwnerDocument().createElement("Severity");
        tableElement.appendChild(sevElement);
        DOMUtils.setText(sevElement, getSeverity());

        final Element messageElement = parentElement.getOwnerDocument().createElement("Message");
        tableElement.appendChild(messageElement);
        DOMUtils.setText(messageElement, getMessage());

        return tableElement;
    }

    /**
     * Method isValidForLogLevel.
     * 
     * @param logLevel int
     * @return boolean
     */
    public boolean isValidForLogLevel(final int logLevel) {
        return this.logLevel >= logLevel;
    }
}
