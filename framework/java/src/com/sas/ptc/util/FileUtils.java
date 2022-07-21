package com.sas.ptc.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;

/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0 
 *
 * Utilities for manipulating java.io.File.
 */
public class FileUtils {
    private static final int COPYBUFFER_SHIFT = 4;

    /**
     * Copies one file to another.
     *
     * @param source The source file
     * @param target The copy destination
     * @throws IOException If the source file could not be read or the target file could not be written
     */
    public static void copyFile(final File source, final File target) throws IOException {

        try (FileInputStream srcFileStream = new FileInputStream(source);
            FileOutputStream dstFileStream = new FileOutputStream(target)) {

            // Create channel on the source
            final FileChannel srcChannel = srcFileStream.getChannel();

            // Create channel on the destination
            final FileChannel dstChannel = dstFileStream.getChannel();

            try {
                // Copy file contents from source to destination
                long totalWritten = 0;
                long currentWritten = 0;
                final long size = srcChannel.size();
                while (totalWritten < size) {
                    srcChannel.position(totalWritten);
                    long bytesToWrite = Integer.MAX_VALUE >> COPYBUFFER_SHIFT;
                    if (bytesToWrite > (size - totalWritten)) {
                        bytesToWrite = size - totalWritten;
                    }
                    currentWritten = dstChannel.transferFrom(srcChannel, totalWritten, bytesToWrite);
                    if (currentWritten <= 0) {
                        break;
                    }
                    totalWritten += currentWritten;
                }
            } finally {
                // Close the channels
                if (srcChannel != null) {
                    srcChannel.close();
                }
                if (dstChannel != null) {
                    dstChannel.close();
                }
            }
        }
    }

    /**
     * Method copyFile.
     *
     * @param is InputStream
     * @param target File
     * @throws IOException
     */
    public static void copyFile(final InputStream is, final File target) throws IOException {

        // Create channel on the source
        final ReadableByteChannel srcChannel = Channels.newChannel(is);

        // Create channel on the destination

        try (FileOutputStream dstFile = new FileOutputStream(target)) {

            final FileChannel dstChannel = dstFile.getChannel();

            // Copy file contents from source to destination
            long totalWritten = 0;
            long currentWritten = 0;
            boolean done = false;
            while (!done) {
                final long bytesToWrite = Integer.MAX_VALUE >> COPYBUFFER_SHIFT;
                currentWritten = dstChannel.transferFrom(srcChannel, totalWritten, bytesToWrite);
                if (currentWritten <= 0) {
                    done = true;
                }
                totalWritten += currentWritten;
            }
        } finally {
            // Close the channel
            if (srcChannel != null) {
                srcChannel.close();
            }
        }
    }

    /**
     * Attempts to delete all files contained in the given directory. The directory itself will remain.
     *
     * @param dir The directory whose contents are to be removed.
     * @throws IOException If any file could not be deleted. The deletion process stops upon encountering the first file
     *             that could not be deleted.
     */
    public static void deleteContainedFiles(final File dir) throws IOException {
        final File[] files = dir.listFiles();
        // if the dir is empty, listFiles returns null
        if (files != null) { 
            for (final File cur : files) {
                final boolean success = cur.delete();
                if (!success) {
                    throw new IOException("WARNING: File " + cur.getAbsolutePath() + " could not be deleted.");
                }
            }
        }
    }

    /**
     * Copies all files contained in the source directory into the destination directory, preserving all file names.
     * This operation is not recursive; only those files immediately contained in the source directory will be copied.
     *
     * @param srcDir The folder whose member files are to be copied.
     * @param destDir The folder to which the files will be copied.
     * @throws IOException If any attempt to read or write a file fails.
     */
    public static void copyMemberFiles(final File srcDir, final File destDir) throws IOException {
        final File[] srcFiles = srcDir.listFiles(); // yes, if the dir is empty
        // listFiles() returns null
        if (srcFiles != null) {
            for (final File curBlankFile : srcFiles) {
                final String fileName = curBlankFile.getName();

                // get the corresponding destination path
                final File destFile = new File(destDir, fileName);

                // perform the actual copy
                FileUtils.copyFile(curBlankFile, destFile);

            }
        }
    }

    /**
     * Checks whether the two supplied java.io.File objects represent the same physical file on the filesystem. Takes
     * into account the case-sensitivity of non-windows operating systems vs. the case-sensitivity of UNIX/Linx systems.
     *
     * @param f1 The first file to compare
     * @param f2 The second file to compare
     * @return boolean true if the File objects reference the same physical file
     *
     * @throws IOException If the canonical paths could not be calculated
     */
    public static boolean pathsAreEquivalent(final File f1, final File f2) throws IOException {
        // yes, the below is more reliable than System.getProperty("os.name")
        final boolean isWindows = "\\".equals(File.separator);
        boolean pathsAreEquivalent = false;
        final String p1 = f1.getCanonicalPath();
        final String p2 = f2.getCanonicalPath();
        if (isWindows) {
            pathsAreEquivalent = p1.equalsIgnoreCase(p2);
        } else {
            pathsAreEquivalent = p1.equals(p2);
        }

        return pathsAreEquivalent;
    }
}
