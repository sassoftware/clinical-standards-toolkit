package com.sas.ptc.transform.xml.log;

import java.io.IOException;
import java.text.ParseException;
import java.util.Collection;
import java.util.Date;
import java.util.Iterator;
import java.util.List;
import java.util.Properties;
import java.util.Vector;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.validation.SchemaFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.xml.sax.SAXParseException;

import com.sas.ptc.transform.xml.StandardXMLTransformerParams;
import com.sas.ptc.util.xml.DOMUtils;
import com.sas.ptc.util.xml.DateTimeUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Carries any log entries produced during transformation execution, and is responsible for writing out the log entries.
 */
public class Log {
    public static final int LOG_LEVEL_INFO = 0;
    public static final int LOG_LEVEL_WARNING = 1;
    public static final int LOG_LEVEL_ERROR = 2;
    public static final int LOG_LEVEL_FATAL_ERROR = 3;
    public static final int LOG_LEVEL_NONE = 4;

    private static final String ROOT_ELEMENT_NAME = "TABLE";

    private final List<LogEntry> logEntryList;
    private final String logPath;
    private int logLevel;

    private final boolean overridingTimestamps;
    private Date timestampOverrideValue;

    /**
     * Constructs an empty log.
     * 
     * @param logPath The absolute path to the log file.
     * @param logLevel The minimum log level for which output will be produced.
     */
    public Log(final String logPath, final int logLevel) {
        this(logPath, logLevel, false, null);
    }

    /**
     * Constructor for Log.
     * 
     * @param logPath String
     * @param logLevel int
     * @param overridingTimestamps boolean
     * @param timestampOverrideValue String
     */
    public Log(final String logPath, final int logLevel, final boolean overridingTimestamps,
        final String timestampOverrideValue) {
        this.logEntryList = new Vector<>();
        this.logPath = logPath;
        this.logLevel = logLevel;
        this.overridingTimestamps = overridingTimestamps;
        if (overridingTimestamps) {
            // do read of format
            try {
                this.timestampOverrideValue = DateTimeUtils.schemaDateTimeToJavaDate(timestampOverrideValue);
            } catch (final ParseException e) {
                logError(e);
            }
        }
    }

    /**
     * Method buildDOM.
     * 
     * @return Document
     * @throws ParserConfigurationException
     */
    public Document buildDOM() throws ParserConfigurationException {
        // build up a DOM
        final Document doc = DOMUtils.createNewDocument();
        final Element rootElement = doc.createElement(ROOT_ELEMENT_NAME);
        doc.appendChild(rootElement);

        final Iterator<LogEntry> i = getLogEntryList().iterator();
        while (i.hasNext()) {
            final LogEntry msg = i.next();
            if (msg.isValidForLogLevel(getLogLevel())) {
                msg.writeInDOM(rootElement);
            }
        }

        return doc;
    }

    /**
     * Method logValidationMessage.
     * 
     * @param severity String
     * @param ex SAXParseException
     */
    public void logValidationMessage(final String severity, final SAXParseException ex) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new XMLValidationLogEntry(severity, LogEntry.ORIGIN_XML_VALIDATION, ex.getMessage(),
                ex.getLineNumber(), ex.getColumnNumber(), getTimestampOverrideValue());
        } else {
            entry = new XMLValidationLogEntry(severity, LogEntry.ORIGIN_XML_VALIDATION, ex.getMessage(),
                ex.getLineNumber(), ex.getColumnNumber());
        }
        addEntry(entry);
    }

    /**
     * Method logError.
     * 
     * @param t Throwable
     */
    public void logError(final Throwable t) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_ERROR, LogEntry.ORIGIN_TRANSFORMER, t.getMessage(),
                getTimestampOverrideValue());
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_ERROR, LogEntry.ORIGIN_TRANSFORMER, t.getMessage());
        }
        addEntry(entry);
    }

    /**
     * Method logError.
     * 
     * @param msg String
     */
    public void logError(final String msg) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_ERROR, LogEntry.ORIGIN_TRANSFORMER, msg,
                getTimestampOverrideValue());
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_ERROR, LogEntry.ORIGIN_TRANSFORMER, msg);
        }
        addEntry(entry);
    }

    /**
     * Method logFatalError.
     * 
     * @param msg String
     */
    public void logFatalError(final String msg) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_FATAL_ERROR, LogEntry.ORIGIN_TRANSFORMER, msg,
                getTimestampOverrideValue());
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_FATAL_ERROR, LogEntry.ORIGIN_TRANSFORMER, msg);
        }
        addEntry(entry);
    }

    /**
     * Method logInfo.
     * 
     * @param msg String
     */
    public void logInfo(final String msg) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_INFO, LogEntry.ORIGIN_TRANSFORMER, msg, getTimestampOverrideValue());
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_INFO, LogEntry.ORIGIN_TRANSFORMER, msg);
        }
        addEntry(entry);
    }

    /**
     * Method logWarning.
     * 
     * @param msg String
     */
    public void logWarning(final String msg) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_WARNING, LogEntry.ORIGIN_TRANSFORMER, msg,
                getTimestampOverrideValue());
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_WARNING, LogEntry.ORIGIN_TRANSFORMER, msg);
        }
        addEntry(entry);
    }

    /**
     * Method logParameter.
     * 
     * @param paramName String
     * @param paramValue String
     */
    public void logParameter(final String paramName, final String paramValue) {
        logParameter(paramName, paramValue, LogEntry.SCOPE_USER);
    }

    /**
     * 
     * @param paramName
     * @param paramValue
     * @param scope USER or SYSTEM
     */
    public void logParameter(final String paramName, final String paramValue, final String scope) {
        LogEntry entry = null;
        if (isOverridingTimestamps()) {
            entry = new LogEntry(LogEntry.SEVERITY_INFO, LogEntry.ORIGIN_TRANSFORM_PARAM, paramName + ": " + paramValue,
                getTimestampOverrideValue(), scope);
        } else {
            entry = new LogEntry(LogEntry.SEVERITY_INFO, LogEntry.ORIGIN_TRANSFORM_PARAM, paramName + ": " + paramValue,
                scope);
        }
        addEntry(entry);
    }

    /**
     * Method logParameters.
     * 
     * @param params StandardXMLTransformerParams
     */
    public void logParameters(final StandardXMLTransformerParams params) {
        logParameter("Import Or Export", params.getImportOrExport());
        logParameter("Standards XML Path", params.getStandardXMLPath());
        logParameter("Fail on Validation Error", "" + params.getFailOnValidationError());
        logParameter("Standard Name", params.getStandardName());
        logParameter("Standard Version", params.getStandardVersion());
        logParameter("Schema Repository Location", params.getSchemaBasePath());
        logParameter("XSL Repository Location", params.getXslBasePath());
        logParameter("Output Encoding", params.getOutputEncoding());
        logParameter("Log File Location", params.getLogFilePath());
        logParameter("Header Comment Text", params.getHeaderCommentText());
        logParameter("Is Validating XML", "" + params.isValidatingStandardXML());
        logParameter("Creating Display Stylesheet", "" + params.isCreatingDisplayStylesheet());
        logParameter("Custom Stylesheet", params.getCustomStylesheetPath());
        logParameter("Custom Stylesheet Output Shortname", params.getOutputStylesheetName());
        logParameter("Creating Output Folders", "" + params.isCreatingFoldersForOutput());
        logParameter("XML Factory Actual Type", DocumentBuilderFactory.newInstance().getClass().toString(),
            LogEntry.SCOPE_SYSTEM);
        try {
            logParameter("XML Builder Actual Type",
                DocumentBuilderFactory.newInstance().newDocumentBuilder().getClass().toString(), LogEntry.SCOPE_SYSTEM);
        } catch (final ParserConfigurationException e) {
            logError(e);
        }
        logParameter("XML Schema Factory Actual Type",
            SchemaFactory.newInstance("http://www.w3.org/2001/XMLSchema").getClass().toString(), LogEntry.SCOPE_SYSTEM);

        final Properties props = System.getProperties();
        final Collection<Object> keys = props.keySet();
        final Iterator<Object> keysIterator = keys.iterator();
        while (keysIterator.hasNext()) {
            final Object keyObj = keysIterator.next();
            final String val = props.getProperty((String) keyObj);
            logParameter((String) keyObj, val, LogEntry.SCOPE_SYSTEM);
        }
    }

    /**
     * Method addEntry.
     * 
     * @param entry LogEntry
     */
    public void addEntry(final LogEntry entry) {
        getLogEntryList().add(entry);
    }

    /**
     * Method getLogEntryList.
     * 
     * @return List
     */
    protected List<LogEntry> getLogEntryList() {
        return logEntryList;
    }

    /**
     * Method getLogPath.
     * 
     * @return String
     */
    protected String getLogPath() {
        return logPath;
    }

    /**
     * Method write.
     * 
     * @throws ParserConfigurationException
     * @throws TransformerException
     */
    public void write() throws ParserConfigurationException {
        final String filepath = getLogPath();
        final Document logDoc = buildDOM();

        try {
            if (filepath != null) {
                DOMUtils.writeDOM(logDoc, filepath);
            } else {
                DOMUtils.writeDOM(logDoc, System.out);
                System.out.flush();
            }
        } catch (final IOException e) {
            e.printStackTrace();
        }
    }

    /**
     * Method getLogLevel.
     * 
     * @return int
     */
    protected int getLogLevel() {
        return logLevel;
    }

    /**
     * Method setLogLevel.
     * 
     * @param logLevel int
     */
    protected void setLogLevel(final int logLevel) {
        this.logLevel = logLevel;
    }

    /**
     * Method isOverridingTimestamps.
     * 
     * @return boolean
     */
    protected boolean isOverridingTimestamps() {
        return overridingTimestamps;
    }

    /**
     * Method getTimestampOverrideValue.
     * 
     * @return Date
     */
    protected Date getTimestampOverrideValue() {
        return timestampOverrideValue;
    }

    /**
     * Method isValidLogLevel.
     * 
     * @param levelToCheck int
     * @return boolean
     */
    public static boolean isValidLogLevel(final int levelToCheck) {
        return (levelToCheck >= LOG_LEVEL_INFO) && (levelToCheck <= LOG_LEVEL_NONE);
    }

}
