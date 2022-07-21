package com.sas.ptc.util.xml;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Iterator;
import java.util.Properties;

import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Provides for the XSL transformation of an XML file given an XSL stylesheet.
 *
 * @version 0.0.1
 */
public class XSLTransform {

    private String xsltPath;
    private String sourceXmlPath;
    private String outputXmlPath;
    private final Properties parameters;
    private String outputEncoding;

    /**
     * Creates a new, empty object.
     */
    public XSLTransform() {
        this.parameters = new Properties();
        this.outputEncoding = "UTF-8";
    }

    /**
     * Initiates the transformation using the data supplied to the instance.
     * 
     * @throws TransformerException If an error occurred while processing the actual transformation.
     * @throws IOException
     */
    public void doTransform() throws TransformerException, IOException {

        // 1. Instantiate a TransformerFactory.
        final TransformerFactory tFactory = TransformerFactory.newInstance();

        // 2. Use the TransformerFactory to process the stylesheet Source and
        // generate a Transformer.
        final Transformer transformer = tFactory.newTransformer(new StreamSource(getXsltPath()));

        applyParameters(transformer);
        if (null != getOutputEncoding()) {
            transformer.setOutputProperty(OutputKeys.ENCODING, getOutputEncoding());
        }

        // 3. Use the Transformer to transform an XML Source and send the
        // output to a Result object.
        final StreamSource streamSource = new StreamSource(getSourceXmlPath());
        OutputStream resultStream = null;
        try {
            resultStream = new FileOutputStream(getOutputXmlPath());
            final StreamResult streamResult = new StreamResult(resultStream);
            transformer.transform(streamSource, streamResult);
        } finally {
            if (resultStream != null) {
                resultStream.close();
            }
        }
    }

    /**
     * Applies the name-value pairs supplied as parameters to this instance, to the XSLT transformer object as
     * parameters that can then be read within the XSL files themselves.
     * 
     * @param t The transformer object that will handle the xsl transform.
     */
    protected void applyParameters(final Transformer t) {
        final Properties props = getParameters();
        final Iterator<Object> keyIterator = props.keySet().iterator();
        t.clearParameters();
        while (keyIterator.hasNext()) {
            final String key = (String) keyIterator.next();
            final String value = (String) getParameters().get(key);

            t.setParameter(key, value);
        }
    }

    /**
     * Gets the map of parameters to be applied to the XSL transformer's execution. The current map of parameters will
     * be applied to the underlying transform object via the applyParameters() method.
     * 
     * @return The map of parameters to be applied to the XSL transformer's execution.
     */
    public Properties getParameters() {
        return this.parameters;
    }

    /**
     * Adds a parameter to be applied to the XSL transformer's execution.
     * 
     * @param name The name of the parameter to be applied
     * @param value The desired value for the parameter with the given name
     */
    public void addParameter(final String name, final String value) {
        if (value != null) {
            getParameters().setProperty(name, value);
        }
    }

    /**
     * Removes a parameter from the map of those to be applied to the XSL transformer's execution.
     * 
     * @param name The name of the parameter to be removed
     */
    public void removeParameter(final String name) {
        getParameters().remove(name);
    }

    /**
     * Resets the current parameters map to be empty.
     */
    public void clearParameters() {
        getParameters().clear();
    }

    /**
     * The path to the XSL file to be used for the transform.
     * 
     * @return The path to the XSL file to be used for the transform
     */
    public String getXsltPath() {
        return this.xsltPath;
    }

    /**
     * Sets the absolute path to the XSL file to be used for the transform.
     * 
     * @param xsltPath The absolute path to the XSL file to be used for the transform
     */
    public void setXsltPath(final String xsltPath) {
        this.xsltPath = xsltPath;
    }

    /**
     * The absolute path to the XML file to which the XSL will be applied.
     * 
     * @return The absolute path to the XML file to which the XSL will be applied
     */
    public String getSourceXmlPath() {
        return this.sourceXmlPath;
    }

    /**
     * Sets the absolute path to the XML file to which the XSL will be applied.
     * 
     * @param sourceXmlPath The absolute path to the XML file to which the XSL will be applied
     */
    public void setSourceXmlPath(final String sourceXmlPath) {
        this.sourceXmlPath = sourceXmlPath;
    }

    /**
     * The absolute path to a file to which the transform results will be sent.
     * 
     * @return The absolute path to a file to which the transform results will be sent.
     */
    public String getOutputXmlPath() {
        return this.outputXmlPath;
    }

    /**
     * Sets the absolute path to a file to which the transform results will be sent.
     * 
     * @param outputXmlPath The absolute path to a file to which the transform results will be sent.
     */
    public void setOutputXmlPath(final String outputXmlPath) {
        this.outputXmlPath = outputXmlPath;
    }

    /**
     * The desired encoding for the generated file. The default is UTF-8.
     * 
     * @return The desired encoding for the generated file.
     */
    public String getOutputEncoding() {
        return outputEncoding;
    }

    /**
     * Sets the desired encoding for the generated file. The default is UTF-8.
     * 
     * @param outputEncoding The desired encoding for the generated file.
     */
    public void setOutputEncoding(final String outputEncoding) {
        this.outputEncoding = outputEncoding;
    }

}
