//
//  GenericRepository.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 23/7/24.
//

import Foundation

protocol GenericRepositoryProtocol {
    associatedtype T
    
    func addSyncedNode(_ entity: T) throws
    func find(url: URL, deviceId: Int) -> T?
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws
}
