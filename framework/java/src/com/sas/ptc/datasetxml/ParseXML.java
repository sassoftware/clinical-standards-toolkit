package com.sas.ptc.datasetxml;

import java.io.FileNotFoundException;
import java.io.UnsupportedEncodingException;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;

import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.XMLReader;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Parses a Dataset-XML file to create a flat file.
 */
public class ParseXML {

    // toolkit-specific messages
    private static final String CSTERROR_MSG = "ERROR: [CSTLOG" + "MESSAGE] ";
    private static final String CSTERROR_ENCODING = "Unsupported Encoding: ";

    /**
     * Parses a Dataset-XML file to create a flat file.
     *
     * @param xmlFile Dataset-XML file.
     * @param txtFile Output flat file.
     */
    public void parseDatasetXML(final String xmlFile, final String txtFile) {

        XMLReader reader = null;
        SAXParser parser = null;
        RecordsHandler handler;

        final SAXParserFactory factory = SAXParserFactory.newInstance();
        try {
            parser = factory.newSAXParser();
        } catch (final ParserConfigurationException e) {
            cstError(e);
            e.printStackTrace();
            return;
        } catch (final SAXException e) {
            cstError(e);
            e.printStackTrace();
            return;
        }
        try {
            reader = parser.getXMLReader();
        } catch (final SAXException e) {
            cstError(e);
            e.printStackTrace();
            return;
        }

        handler = new RecordsHandler();
        reader.setContentHandler(handler);

        handler.setFilePath(txtFile);
        try {
            handler.openPrintWriter();
        } catch (final FileNotFoundException e) {
            cstError(e);
            return;
        }

        try {
            reader.parse(xmlFile);
        } catch (final SAXParseException e) {
            cstError(e);
        } catch (final FileNotFoundException e) {
            cstError(e);
        } catch (final UnsupportedEncodingException e) {
            cstError(e, CSTERROR_ENCODING);
        } catch (final Throwable t) {
            cstError(t);
            t.printStackTrace();
        } finally {
            handler.closePrintWriter();
        }
    }

    /**
     * Generic error
     *
     * @param t
     */
    protected void cstError(final Throwable t) {
        cstError(t, null);
    }

    /**
     * Error with a specific sub-message
     *
     * @param t
     * @param subMessage
     */
    protected void cstError(final Throwable t, final String subMessage) {
        String msg = CSTERROR_MSG;
        if (subMessage != null) {
            msg += subMessage;
        }
        msg += t.getMessage();
        System.out.println(msg);
    }
}
