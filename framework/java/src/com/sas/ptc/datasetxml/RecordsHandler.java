package com.sas.ptc.datasetxml;

import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

import org.xml.sax.Attributes;
import org.xml.sax.helpers.DefaultHandler;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Implementation of SAX callback handler
 *
 */
class RecordsHandler extends DefaultHandler {

    // dataset-xml node names
    private static final String ELEM_NAME_ODM = "ODM";
    private static final String ELEM_NAME_CLINICALDATA = "ClinicalData";
    private static final String ELEM_NAME_REFERENCEDATA = "ReferenceData";
    private static final String ELEM_NAME_ITEMGROUPDATA = "ItemGroupData";
    private static final String ELEM_NAME_ITEMDATA = "ItemData";
    private static final String ATTR_NAME_FILEOID = "FileOID";
    private static final String ATTR_NAME_STUDYOID = "StudyOID";
    private static final String ATTR_NAME_MDVOID = "MetaDataVersionOID";
    private static final String ATTR_NAME_ITEMGROUPOID = "ItemGroupOID";
    private static final String ATTR_NAME_ITEMOID = "ItemOID";
    private static final String ATTR_NAME_VALUE = "Value";
    private static final String ATTR_NAME_IGDATASEQ = "data:ItemGroupDataSeq";

    // CSTK record format
    private static final String RECORD_SEPARATOR = "|";
    private static final String RECORD_ABBREV_ITEMDATA = "[]";
    private static final String RECORD_ABBREV_ITEMGROUPDATA = "[IG]";
    private static final String RECORD_ABBREV_CLINICALDATA = "[CD]";
    private static final String RECORD_ABBREV_REFDATA = "[RD]";
    private static final String RECORD_ABBREV_ODM = "[ODM]";

    private final List<String> records = new ArrayList<>();
    private String filePath;
    private PrintWriter printWriter;

    /**
     * Gets printWriter
     *
     * @return printWriter
     */
    public PrintWriter getPrintWriter() {
        return printWriter;
    }

    /**
     * Sets printWriter
     *
     * @param printWriter PrintWriter
     */
    public void setPrintWriter(final PrintWriter printWriter) {
        this.printWriter = printWriter;
    }

    /**
     * Gets the path to the output file.
     *
     * @return filePath
     */
    public String getFilePath() {
        return filePath;
    }

    /**
     * Sets the path to the output file.
     *
     * @param filePath path to the output file.
     */
    public void setFilePath(final String filePath) {
        this.filePath = filePath;
    }

    /**
     * Assumes filePath has been set!
     *
     * @throws FileNotFoundException
     */
    public void openPrintWriter() throws FileNotFoundException {
        setPrintWriter(new PrintWriter(getFilePath()));
    }

    /**
     * Closes printWriter
     *
     */
    public void closePrintWriter() {
        if (this.printWriter != null) {
            this.printWriter.close();
        }
    }

    /**
     * Receive notification of the start of an element.
     *
     * @param uri The Namespace URI, or the empty string if the element has no Namespace URI or if Namespace processing
     *            is not being performed.
     * @param localName The local name (without prefix), or the empty string if Namespace processing is not being
     *            performed.
     * @param qName The qualified name (with prefix), or the empty string if qualified names are not available.
     * @param attributes The attributes attached to the element. If there are no attributes, it shall be an empty
     *            Attributes object.
     */
    @Override
    public void startElement(final String uri, final String localName, final String qName,
        final Attributes attributes) {
        if (ELEM_NAME_ITEMDATA.equals(qName)) {
            addRecord(RECORD_ABBREV_ITEMDATA, new String[] { ATTR_NAME_ITEMOID, ATTR_NAME_VALUE }, attributes);
        } else if (ELEM_NAME_ITEMGROUPDATA.equals(qName)) {
            addRecord(RECORD_ABBREV_ITEMGROUPDATA, new String[] { ATTR_NAME_ITEMGROUPOID, ATTR_NAME_IGDATASEQ },
                attributes);
        } else if (ELEM_NAME_CLINICALDATA.equals(qName)) {
            records.clear();
            addRecord(RECORD_ABBREV_CLINICALDATA, new String[] { ATTR_NAME_STUDYOID, ATTR_NAME_MDVOID }, attributes);
        } else if (ELEM_NAME_REFERENCEDATA.equals(qName)) {
            records.clear();
            addRecord(RECORD_ABBREV_REFDATA, new String[] { ATTR_NAME_STUDYOID, ATTR_NAME_MDVOID }, attributes);
        } else if (ELEM_NAME_ODM.equals(qName)) {
            printWriter.println(createRecord(RECORD_ABBREV_ODM, new String[] { ATTR_NAME_FILEOID }, attributes));
        }
    }

    /**
     * Creates a record, and adds it to the list.
     *
     * @param recordAbbrev The CSTK element abbreviation.
     * @param attrNames The names of the attributes to be extracted into the record.
     * @param attrs The XML attributes.
     */
    protected void addRecord(final String recordAbbrev, final String[] attrNames, final Attributes attrs) {
        records.add(createRecord(recordAbbrev, attrNames, attrs));
    }

    /**
     * Creates a record.
     *
     * @param recordAbbrev The CSTK element abbreviation.
     * @param attrNames The names of the attributes to be extracted into the record.
     * @param attrs The XML attributes
     * @return A String containing the record.
     */
    protected String createRecord(final String recordAbbrev, final String[] attrNames, final Attributes attrs) {
        final StringBuilder record = new StringBuilder();
        record.append(recordAbbrev);
        for (int i = 0; i < attrNames.length; ++i) {
            if (attrs.getValue(attrNames[i]) != null) {
                record.append(attrs.getValue(attrNames[i]).trim());
            }
            if (i < (attrNames.length - 1)) { // don't want one at the end
                record.append(RECORD_SEPARATOR);
            }
        }
        return record.toString();
    }

    /**
     * Receive notification of the end of an element.
     *
     * @param uri The Namespace URI, or the empty string if the element has no Namespace URI or if Namespace processing
     *            is not being performed.
     * @param localName The local name (without prefix), or the empty string if Namespace processing is not being
     *            performed.
     * @param qName The qualified name (with prefix), or the empty string if qualified names are not available.
     */
    @Override
    public void endElement(final String uri, final String localName, final String qName) {
        if (ELEM_NAME_ITEMGROUPDATA.equals(qName)) {
            for (final String s : records) {
                printWriter.println(s);
            }
            records.clear();
        }
    }
}