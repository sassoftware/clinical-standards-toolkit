package com.sas.ptc.transform.xml;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import javax.xml.parsers.ParserConfigurationException;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.sas.ptc.util.StringUtils;
import com.sas.ptc.util.xml.DOMUtils;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Maintains the list of transforms available to the system. Information on the set of available transforms is stored as
 * a list of StandardTransformInfo objects. The list of available transforms is populated via a read of the file in this
 * package having the name indicated by the TRANSFORMS_FILE_NAME constant. All transform info is cleared and reloaded
 * from this file when init() is invoked.
 */
public class AvailableTransforms {
    /**
     * Constants denoting the element names within the available transforms file.
     */
    private static final String TRANSFORM_DEFINITION_ELEMENT_NAME = "Transform";

    /**
     * The list maintained by this class.
     */
    private final List<StandardTransformInfo> transformInfoList;

    private StandardXMLTransformerParams params;

    /**
     * Constructs an empty instance.
     *
     * @param params StandardXMLTransformerParams
     */
    public AvailableTransforms(final StandardXMLTransformerParams params) {
        this.transformInfoList = new ArrayList<>();
        this.params = params;
    }

    /**
     * Clears any currently-loaded transform information, and reloads it from the AvailableTransforms file.
     *
     * @throws ParserConfigurationException
     * @throws SAXException
     * @throws IOException
     */
    public void init() throws ParserConfigurationException, SAXException, IOException {
        this.transformInfoList.clear();
        readAvailableTransformsFile();
    }

    /**
     * Adds a transformInfo object to the list of available transforms being maintained.
     * 
     * @param info The transform to be added
     */
    public void addTransformInfo(final StandardTransformInfo info) {
        this.transformInfoList.add(info);
    }

    /**
     * Removes a transformInfo object from the list of available transforms being maintained.
     * 
     * @param info The transform to be removed
     */
    public void removeTransformInfo(final StandardTransformInfo info) {
        this.transformInfoList.remove(info);
    }

    /**
     * Gets the StandardTransformInfo object matching the supplied standard name and version.
     * 
     * @param standardName The name of the standard
     * @param standardVersion The version of the standard
     * @return The corresponding StandardTransformInfo object
     * @throws TransformNotFoundException If no matching transform is known to the system
     */
    public StandardTransformInfo getTransformInfo(final String standardName, final String standardVersion)
        throws TransformNotFoundException {
        StandardTransformInfo returnInfo = null;
        final Iterator<StandardTransformInfo> i = this.transformInfoList.iterator();
        while (i.hasNext()) {
            final StandardTransformInfo info = i.next();
            if (standardName.equals(info.getStandardName()) && standardVersion.equals(info.getStandardVersion())) {
                returnInfo = info;
                break;
            }
        }

        if (returnInfo == null) {
            throw new TransformNotFoundException(standardName, standardVersion, this);
        }

        return returnInfo;
    }

    /**
     * Gets the full list of StandardTransformInfos known to the system.
     * 
     * @return The full list of StandardTransformInfos
     */
    public List<StandardTransformInfo> getTransformInfoList() {
        return this.transformInfoList;
    }

    /**
     * Gets the absolute path to the XSL file to be used for this transform. This value is arrived at by retrieving the
     * XSL path from the AvailableTransforms registry, using the name and version of the standard given in the current
     * parameters. The parameters' importOrExport setting determines whether the import XSL or the export XSL is
     * selected. The parameters' xslBasePath value is also used, allowing for calculation of the required absolute path.
     * 
     * @param params The parameters to the current transform execution
     * @return The absolute path to the XSL file to be used for the transform specified by the parameters.
     * @throws TransformNotFoundException
     */
    public String getXSLFileToInvoke(final StandardXMLTransformerParams params) throws TransformNotFoundException {
        final StandardTransformInfo currentTransformInfo = getTransformInfo(params.getStandardName(),
            params.getStandardVersion());

        String mainXSLPath = null;
        final String xslRepositoryPath = params.getXslBasePath();

        // can get xslt path directly

        if (StandardXMLTransformerParams.IMPORT.equals(params.getImportOrExport())) {
            mainXSLPath = currentTransformInfo.getFullImportXSLPath(xslRepositoryPath);
        } else {
            mainXSLPath = currentTransformInfo.getFullExportXSLPath(xslRepositoryPath);
        }

        return mainXSLPath;
    }

    /**
     * Initiates the read and parse of the AvailableTransforms file.
     * 
     * @throws ParserConfigurationException
     * @throws SAXException
     * @throws IOException
     */
    protected void readAvailableTransformsFile() throws ParserConfigurationException, SAXException, IOException {
        final Document doc = getAvailableTransformsDocument();
        populateAvailableTransforms(doc);
    }

    /**
     * Gets the XML document that specifies the transforms available to the system.
     * 
     * @return The XML document that specifies the transforms available to the system
     * @throws ParserConfigurationException If the XML parser is misconfigured
     * @throws SAXException If the available transforms XML document is not well-formed XML
     * @throws IOException If an error occurred while reading the XML file
     */
    protected Document getAvailableTransformsDocument() throws ParserConfigurationException, SAXException, IOException {
        final String availableTransformsFilePath = getParams().getAvailableTransformsFilePath();

        Document doc = null;
        InputStream in = null;
        try {
            final File f = new File(availableTransformsFilePath);
            in = new FileInputStream(f);
            doc = DOMUtils.getDocument(in);
        } finally {
            if (in != null) {
                in.close();
            }
        }

        return doc;
    }

    /**
     * Iterates through the transform declarations found in the AvailableTransforms file. For each, a
     * StandardTransformInfo object is constructed, populated, and added to the list of available transforms maintained
     * by this class.
     * 
     * @param doc The XML document representation of the information found in the AvailableTransforms file.
     */
    protected void populateAvailableTransforms(final Document doc) {
        final NodeList paramElements = doc.getElementsByTagName(TRANSFORM_DEFINITION_ELEMENT_NAME);
        for (int i = 0; i < paramElements.getLength(); ++i) {
            final Element transformElement = (Element) paramElements.item(i);

            final StandardTransformInfo transformInfo = new StandardTransformInfo(transformElement);

            addTransformInfo(transformInfo);
        }
    }

    /**
     * Returns a listing of the names and versions of the standards currently known to this instance.
     * 
     * @return A string containing details of this instance
     */
    @Override
    public String toString() {
        final StringBuffer sb = new StringBuffer();
        sb.append("Currently-available transforms: ");
        sb.append(StringUtils.NEWLINE);
        final Iterator<StandardTransformInfo> i = getTransformInfoList().iterator();
        while (i.hasNext()) {
            final StandardTransformInfo info = i.next();
            sb.append(info.toString());
            sb.append(StringUtils.NEWLINE);
        }

        return sb.toString();
    }

    /**
     * Method getParams.
     * 
     * @return StandardXMLTransformerParams
     */
    protected StandardXMLTransformerParams getParams() {
        return params;
    }

    /**
     * Method setParams.
     * 
     * @param params StandardXMLTransformerParams
     */
    protected void setParams(final StandardXMLTransformerParams params) {
        this.params = params;
    }
}
