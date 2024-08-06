//
//  FileExtension.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import Foundation
let fileExtensionsDict: [String:String] = [
    "txt": "txt",
    "zip": "zip",
    "xls": "xls",
    "xlsx": "xls",
    "avi": "video",
    "mov": "video",
    "mp4": "video",
    "ppt": "ppt",
    "pptx": "ppt",
    "pdf": "pdf",
    "bmp": "image",
    "jpg": "image",
    "jpeg": "image",
    "gif": "image",
    "png": "image",
    "heic": "image",
    "svg": "image",
    "doc": "word",
    "docx": "word",
    "docm": "word",
    "js": "code",
    "ts": "code",
    "tsx": "code",
    "c": "code",
    "cpp": "code",
    "wav": "audio",
    "mp3": "audio",
    "fig": "figma",
    "folder": "folder"
]

func getFileExtensionIconName(filenameWithExtension: String) -> String {
    let filename = filenameWithExtension as NSString
    
    
    let pathExtension = filename.pathExtension
    return getIconNameForFileExtension(fileExtension: pathExtension)
}


func getIconNameForFileExtension(fileExtension: String) -> String {
    if let match = fileExtensionsDict[fileExtension] {
        return match
    }
    
    return "default"
}

