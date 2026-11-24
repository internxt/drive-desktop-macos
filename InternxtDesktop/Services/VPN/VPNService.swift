//
//  VPNService.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import AppKit
import SwiftUI

enum VPNLocation: String, CaseIterable {
    case france = "FR"
    case germany = "DE"
    case poland = "PL"
    case canada = "CA"
    case unitedKingdom = "UK"

    var nameKey: String { "VPN_REGION_\(rawValue)" }

    var flag: String {
        switch self {
        case .france: return "🇫🇷"
        case .germany: return "🇩🇪"
        case .poland: return "🇵🇱"
        case .canada: return "🇨🇦"
        case .unitedKingdom: return "🇬🇧"
        }
    }
}

struct VPNRegion: Identifiable, Equatable {
    let location: VPNLocation
    let isAvailable: Bool

    var id: String { location.rawValue }
}

struct ExitInfo: Equatable {
    let ip: String
    let location: String
    let connectedAt: Date
}

enum VPNError: Equatable {
    case extensionNotApproved
    case sessionExpired
    case zoneNotPermitted
    case proxyUnreachable
    case unknown
}

enum VPNViewState: Equatable {
    case checkingAvailability
    case disconnected
    case needsApproval
    case connecting(VPNLocation)
    case connected(VPNLocation, exit: ExitInfo?)
    case reconnecting(VPNLocation)
    case disconnecting
    case failed(VPNError)
}

@MainActor
final class VPNService: ObservableObject {
    private static var approvalSettingsURL: URL {
        if #available(macOS 15, *) {
            return URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security")!
    }

    @Published var viewState: VPNViewState
    @Published var regions: [VPNRegion]
    @Published var selectedRegion: VPNLocation
    @Published var isFreePlan: Bool

    init(
        viewState: VPNViewState = .disconnected,
        regions: [VPNRegion] = VPNLocation.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) },
        selectedRegion: VPNLocation = .france,
        isFreePlan: Bool = true
    ) {
        self.viewState = viewState
        self.regions = regions
        self.selectedRegion = selectedRegion
        self.isFreePlan = isFreePlan
    }

    func select(_ region: VPNRegion) {
        guard region.isAvailable else {
            URLDictionary.UPGRADE_PLAN.open()
            return
        }
        selectedRegion = region.location
    }

    func openApprovalSettings() {
        NSWorkspace.shared.open(Self.approvalSettingsURL)
    }

    func connect() {}

    func disconnect() {}

    func retry() {}
}
