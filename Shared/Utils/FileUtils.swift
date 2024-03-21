//
//  FileUtils.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 21/3/24.
//

import Foundation


struct FileUtils {
    
    static func isTmpFile(_ filename: String) -> Bool {
        let isMicrosoftOfficeTmp = isMicrosoftOfficeTemporalFile(filename)
        
        if(isMicrosoftOfficeTmp) {
            return true
        }
            
        return false
    }
    
    
    static func isMicrosoftOfficeTemporalFile(_ filename: String) -> Bool {
        let officeFileExtensions = ["docx", "xlsx", "pptx", "doc", "dot", "xls", "xlsm", "xlsb", "xlt", "xlam", "ppt", "pot", "pptm", "potx"]
        
        let officeTemporalFilePrefixes = ["~$", ".~"]
        
        let lowercasedFilename = filename.lowercased()
        let fileExtension = (filename as NSString).pathExtension.lowercased()
        for prefix in officeTemporalFilePrefixes {
            if lowercasedFilename.hasPrefix(prefix) && officeFileExtensions.contains(fileExtension)  {
                return true
            }
        }
        
        return false
    }
}
