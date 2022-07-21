package com.sas.ptc.util.xml;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.TransformerException;

import org.w3c.dom.Comment;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.w3c.dom.ProcessingInstruction;
import org.w3c.dom.Text;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * A set of utilities for manipulating XML DOMs.
 */
public class DOMUtils {

    /**
     * This class will be accessible only via static methods.
     */
    private DOMUtils() {
    }

    /**
     * Parses the file into a DOM.
     * 
     * @param f The XML file to be parsed.
     * @return The DOM.
     * 
     * @throws ParserConfigurationException If the JRE is misconfigured for XML parsing.
     * @throws SAXException If the XML is not valid.
     * @throws IOException If the file could not be read.
     */
    public static Document getDocument(final File f) throws ParserConfigurationException, SAXException, IOException {
        final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();

        final DocumentBuilder builder = factory.newDocumentBuilder();
        final Document document = builder.parse(f);

        return document;
    }

    /**
     * Parses the InputStream into a DOM.
     * 
     * @param is The stream.
     * @return A DOM representing the XML document retrieved via the stream.
     * 
     * @throws ParserConfigurationException If the JRE is misconfigured for XML parsing.
     * @throws SAXException If the XML is not valid.
     * @throws IOException If the file could not be read.
     */
    public static Document getDocument(final InputStream is)
        throws ParserConfigurationException, SAXException, IOException {
        final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();

        final DocumentBuilder builder = factory.newDocumentBuilder();
        final Document document = builder.parse(is);

        return document;
    }

    /**
     * Returns a DOM object, given an InputStream.
     * 
     * @param is An input stream
     * @return The DOM result of parsing the input stream
     * @throws ParserConfigurationException If the JRE is misconfigured for XML parsing
     * @throws SAXException If the input stream could not be parsed into XML
     * @throws IOException If an error occurred during the read I/O operation
     */
    public static Document getDocument(final InputSource is)
        throws ParserConfigurationException, SAXException, IOException {
        final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();

        final DocumentBuilder builder = factory.newDocumentBuilder();
        final Document document = builder.parse(is);

        return document;
    }

    /**
     * Retrieves a string representing the text content of the first subelement having the given name.
     * 
     * @param elem The parent element
     * @param subelementName The name of the child element
     * @return The text content of the child element
     */
    public static String getFirstSubelementValue(final Element elem, final String subelementName) {
        String returnValue = null;
        final NodeList subList = elem.getElementsByTagName(subelementName);
        if (subList.getLength() != 0) {
            final Element subelement = (Element) subList.item(0);
            returnValue = getTextContent(subelement);
        }
        if (returnValue != null) {
            returnValue = returnValue.trim();
        }

        return returnValue;
    }

    /**
     * Gets the text content of the given Element node.
     * 
     * @param theNode An element node
     * @return Its text content. This value will never be null, but may be empty.
     */
    public static String getTextContent(final Node theNode) {
        final StringBuffer sb = new StringBuffer();

        final NodeList nl = theNode.getChildNodes();
        for (int i = 0; i < nl.getLength(); ++i) {
            final Node n = nl.item(i);
            if (n.getNodeType() == Node.TEXT_NODE) {
                final Text textNode = (Text) n;
                sb.append(textNode.getData());
            }
        }

        return sb.toString();
    }

    /**
     * Gets the first processing instruction, after any XML-declaration processing instruction.
     * 
     * @param doc The DOM to be examined.
     * @return This first processing instruction immediately following the XML declaration, or null if no such
     *         processing instruction was found
     */
    public static ProcessingInstruction getFirstProcessingInstruction(final Document doc) {
        final Node n = doc.getFirstChild();
        ProcessingInstruction pi = null;
        if (n.getNodeType() == Node.PROCESSING_INSTRUCTION_NODE) {
            pi = (ProcessingInstruction) n;
        }

        return pi;
    }

    /**
     * Gets the first top-level (child of the document node itself) comment node in the given document.
     * 
     * @param doc The DOM to be examined.
     * @return The encountered comment node, or null if no top-level comment nodes were discovered.
     */
    public static Comment getFirstComment(final Document doc) {
        final NodeList nlist = doc.getChildNodes();
        Comment comment = null;
        for (int i = 0; i < nlist.getLength(); ++i) {
            final Node n = nlist.item(i);
            if (n.getNodeType() == Node.COMMENT_NODE) {
                comment = (Comment) n;
                break;
            }
        }

        return comment;
    }

    /**
     * Creates a new XML DOM Document.
     * 
     * @return The new document
     * @throws ParserConfigurationException If a document could not be created due to a parser misconfiguration
     */
    public static Document createNewDocument() throws ParserConfigurationException {
        final DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();

        final DocumentBuilder builder = factory.newDocumentBuilder();
        return builder.newDocument();
    }

    /**
     * Gets the root element of the given document.
     * 
     * @param indoc An XML document
     * @return That XML document's root element
     */
    public static Element getDocumentRootElement(final Document indoc) {
        final NodeList nlist = indoc.getChildNodes();
        for (int i = 0; i < nlist.getLength(); ++i) {
            final Node n = nlist.item(i);
            if (n.getNodeType() == Node.ELEMENT_NODE) {
                return (Element) n;
            }
        }

        return null;
    }

    /**
     * Gets all the direct child elements of the given element. Only elements are included in the returned list; text
     * and attribute nodes are filtered out.
     * 
     * @param elem An XML element
     * @return All of the elements that are direct children of the given element
     */
    public static List<Node> getAllChildElements(final Element elem) {
        final List<Node> children = new ArrayList<>();

        final NodeList nlist = elem.getChildNodes();
        for (int i = 0; i < nlist.getLength(); ++i) {
            final Node n = nlist.item(i);
            if (n.getNodeType() == Node.ELEMENT_NODE) {
                children.add(n);
            }
        }

        return children;
    }

    /**
     * Method writeDOM.
     * 
     * @param doc Document
     * @param filepath String
     * @throws TransformerException
     * @throws IOException
     */
    public static void writeDOM(final Document doc, final String filepath) throws IOException {
        final OutputStream fos = new FileOutputStream(new File(filepath));
        try {
            writeDOM(doc, fos);
        } finally {
            if (fos != null) {
                fos.flush();
                fos.close();
            }
        }
    }

    /**
     * Method writeDOM.
     * 
     * @param doc Document
     * @param os OutputStream
     */
    public static void writeDOM(final Document doc, final OutputStream os) {
        // use specific Xerces class to write DOM-data to a file:
        Class<?> xmlSerializerClass = null;
        Class<?> outputFormatClass = null;
        final String serClass14 = "org.apache.xml.serialize.XMLSerializer";
        final String ofClass14 = "org.apache.xml.serialize.OutputFormat";
        final String serClass15 = "com.sun.org.apache.xml.internal.serialize.XMLSerializer";
        final String ofClass15 = "com.sun.org.apache.xml.internal.serialize.OutputFormat";

        try {
            xmlSerializerClass = Class.forName(serClass15);
            outputFormatClass = Class.forName(ofClass15);
        } catch (final ClassNotFoundException e) {
            try {
                xmlSerializerClass = Class.forName(serClass14);
                outputFormatClass = Class.forName(ofClass14);
            } catch (final ClassNotFoundException e1) {
                // this is all we can do, can't output log now
                e1.printStackTrace();
            }
        }

        if ((xmlSerializerClass != null) && (outputFormatClass != null)) {
            try {
                final String defaultCharset = java.nio.charset.Charset.defaultCharset().name();

                // set up output format
                final Constructor<?> ofConstructor = outputFormatClass
                    .getConstructor(new Class[] { String.class, String.class, Boolean.TYPE });
                final Object ofInstance = ofConstructor.newInstance(new Object[] { 
                    "XML", defaultCharset, Boolean.TRUE });

                // set up the serializer
                final Constructor<?> serConstructor = xmlSerializerClass.getConstructor(new Class[] { outputFormatClass });
                final Object serInstance = serConstructor.newInstance(new Object[] { ofInstance });

                final Method setOutStreamMethod = xmlSerializerClass.getMethod("setOutputCharStream",
                    new Class[] { Writer.class });
                final Method serializeMethod = xmlSerializerClass.getMethod("serialize",
                    new Class[] { Document.class });

                setOutStreamMethod.invoke(serInstance, new Object[] { new OutputStreamWriter(os) });
                serializeMethod.invoke(serInstance, new Object[] { doc });
            } catch (final InstantiationException e) {
                e.printStackTrace();
            } catch (final IllegalAccessException e) {
                e.printStackTrace();
            } catch (final SecurityException e) {
                e.printStackTrace();
            } catch (final NoSuchMethodException e) {
                e.printStackTrace();
            } catch (final IllegalArgumentException e) {
                e.printStackTrace();
            } catch (final InvocationTargetException e) {
                e.printStackTrace();
            }
        }

    }

    /**
     * Method setText.
     * 
     * @param elem Element
     * @param s String
     */
    public static void setText(final Element elem, final String s) {
        final Text textNode = elem.getOwnerDocument().createTextNode(s);
        elem.appendChild(textNode);
    }

    /**
     * Handles < > & and "/'
     * 
     * @param str the string to escape
     * @return escaped string
     */
    public static String escapeForXML(String str) {
        if (str == null) {
            return null;
        }
        // not the most-efficient approach, but it works
        str = str.replaceAll("&", "&amp;");
        str = str.replaceAll("\"", "&quot;");
        str = str.replaceAll("'", "&quot;");
        str = str.replaceAll(">", "&gt;");
        str = str.replaceAll("<", "&lt;");
        // doesn't handle unicode escapes, but that generally will be OK, since
        // the source is a Java entry field

        return str;
    }

}
