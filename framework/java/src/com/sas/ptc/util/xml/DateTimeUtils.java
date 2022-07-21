package com.sas.ptc.util.xml;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Utilities for managing date, time and dateTime data during XML processing.
 */
public class DateTimeUtils {

    private static final int TIME_ZONE_STRING_OFFSET = 2;

    /**
     * This class will be accessible only via static methods.
     */
    private DateTimeUtils() {
    }

    /**
     * Converts a java.util.Date object to a string that is conformant to the XML Schema dateTime data type.
     * 
     * @param d The Java Date object.
     * @return A schema-conformant dateTime string.
     */
    public static String javaDateToSchemaDateTime(final Date d) {
        final DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
        final DateFormat timeFormat = new SimpleDateFormat("HH:mm:ss");
        final DateFormat timeZoneFormat = new SimpleDateFormat("Z");

        final String creationDate = dateFormat.format(d);
        final String creationTime = timeFormat.format(d);
        final String timeZone = timeZoneFormat.format(d);

        final int timeZoneColonInsertIndex = timeZone.length() - TIME_ZONE_STRING_OFFSET;
        final String schemaTimeZone = timeZone.substring(0, timeZoneColonInsertIndex) + ":"
            + timeZone.substring(timeZoneColonInsertIndex);

        return creationDate + "T" + creationTime + schemaTimeZone;
    }

    /**
     * Converts an XML Schema-compliant dateTime string to a Java Date. The schema date is formatted as in:
     * 2008-05-24T16:31:25-04:00, and must include the time zone component.
     * 
     * @param schemaDateTime String
     * @return The corresponding Java Date
     * @throws ParseException
     */
    public static Date schemaDateTimeToJavaDate(final String schemaDateTime) throws ParseException {
        final int tzColonIndex = schemaDateTime.lastIndexOf(':');
        final StringBuffer sb = new StringBuffer(schemaDateTime);
        sb.deleteCharAt(tzColonIndex);
        final DateFormat fullFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ");
        return fullFormat.parse(sb.toString());
    }

}
