//
//  VPNExtensionXPCProtocol.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 24/11/2026.
//

import Foundation

@objc protocol VPNExtensionXPCProtocol {
    func updateSession(token: String, region: String, reply: @escaping (_ regionSwitched: Bool) -> Void)
}

@objc protocol VPNAppXPCProtocol {
    func didFail(reason: String)
}

enum VPNStartOption {
    static let proxyHost = "proxyHost"
    static let proxyPort = "proxyPort"
    static let region = "region"
    static let token = "token"
}

enum VPNTunnelFailure: String {
    case sessionExpired
    case zoneNotAllowed
    case proxyUnreachable
}

enum VPNExtensionXPC {
    static let appCodeSigningRequirement = "identifier \"internxt.InternxtDesktop\" and anchor apple generic and certificate leaf[subject.OU] = \"JR4S3SY396\""

    static func machServiceName(in bundle: Bundle) -> String? {
        let networkExtension = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any]
        return networkExtension?["NEMachServiceName"] as? String
    }
}
