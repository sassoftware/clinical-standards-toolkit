/**
 * Copyright (c) 2022, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.   
 * SPDX-License-Identifier: Apache-2.0                                            
 */               
                                                                  
import java.text.SimpleDateFormat;
import java.util.Date;
import groovy.io.FileType
import java.security.MessageDigest
import groovy.xml.MarkupBuilder

public class Checksums {

 public void getChecksums(String cstPath, String cstType, String algorithm, String xmlFile, String cstLabel) {

    def FileList = []    
    def dir = new File(cstPath)

      try {
        def MessageDigest digest = MessageDigest.getInstance(algorithm)

      if (!dir.canonicalFile.exists()) {
          println "ERROR: [CSTLOG" + "MESSAGE.Checksums] ER"+ "ROR: Directory $cstPath does not exist."
      } else {
  
          dir.eachFileRecurse (FileType.FILES) { file ->
            FileList << file
          }
          
          def checksumMap = [:]
          
          FileList.each {
            it.withInputStream(){is->
            byte[] buffer = new byte[8192]
            int read = 0
               while( (read = is.read(buffer)) > 0) {
                      digest.update(buffer, 0, read);
                  }
              }
            byte[] checksum = digest.digest()
            BigInteger bigInt = new BigInteger(1, checksum)
            checksumMap.put(it.path, bigInt.toString(16).padLeft(32, '0'))
          }

          SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
          String date=sdf.format (new Date() );
                          
          def xmlObj = new StringWriter()
          def xml = new MarkupBuilder(xmlObj)
          xml.setDoubleQuotes(true)
          xml.mkp.xmlDeclaration(version: "1.0", encoding: "utf-8", standalone: "yes")
          xml.InstalledFiles(folder:dir.canonicalFile, creationdatetime:date, label:cstLabel) {
            checksumMap.each {key, value -> sasfile(prodcode:cstType, checksum:"${value}", name:"${key}") }
          }  
          
        try {
            def f = new File(xmlFile)
            f.write(xmlObj.toString())
            println "[CSTLOG" + "MESSAGE.Checksums] NOTE: $algorithm checksum file $xmlFile created."
        } catch (Exception e) {
              println "[CSTLOG" + "MESSAGE.Checksums] ER"+ "ROR: Could not create file ${e.message}."
          }        
      }
    } catch (Exception e) {
             println "[CSTLOG" + "MESSAGE.Checksums] ER"+ "ROR: Algoritm \"$algorithm\" is not valid."
      }
  }
}
