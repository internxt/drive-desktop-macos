//
//  CleanerHelperXPCProtocol.swift
//  Helper
//
//  Created by Patricio Tovar on 28/8/25.
//

import Foundation

@objc protocol CleanerHelperXPCProtocol {
    func scanCategories(categoriesData: Data,
                       optionsData: Data?,
                       reply: @escaping (Data?, NSError?) -> Void)
    
    
    func startCleanupWithProgress(categoriesData: Data,
                                optionsData: Data?,
                                reply: @escaping (String, NSError?) -> Void)
    
    func getCleanupProgress(operationId: String,
                          reply: @escaping (Data?, NSError?) -> Void)
    
    func getCleanupResult(operationId: String,
                        reply: @escaping (Data?, NSError?) -> Void)
    

    
    func startCleanupWithSpecificFilesProgress(cleanupData: Data,
                                             optionsData: Data?,
                                             reply: @escaping (String, NSError?) -> Void)
    
    func getFilesForCategory(categoryData: Data,
                            optionsData: Data?,
                            reply: @escaping (Data?, NSError?) -> Void)
    
    func cancelOperation(reply: @escaping () -> Void)
}
