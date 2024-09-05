//
//  AppSettings.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/11/23.
//

import Foundation
import Combine

public enum Languages: String {
    case en
    case es
    case fr
    case deviceLanguage
}

enum BackupFrequencyEnum: String {
    case six = "6", hour = "1", daily = "24", manually = "0"
    
    var timeInterval: TimeInterval {
        switch self {
        case .six:
            return 21600
        case .hour:
            return 3600
        case .daily:
            return 86400
        case .manually:
            return 0
        }
    }

}


class AppSettings: ObservableObject {
    static var shared = AppSettings()
    
    public var local: Locale {
        Locale(identifier: selectedLanguage.rawValue)
    }

    public var deviceLanguage: Languages? {
        guard let deviceLanguage = Bundle.main.preferredLocalizations.first else {
            return nil
        }
        return Languages(rawValue: deviceLanguage)
    }

    var uuid: String {
        UUID().uuidString
    }

    @Published public var selectedLanguage: Languages = .en
    @Published public var selectedBackupFrequency: BackupFrequencyEnum = .manually

    private var bag = Set<AnyCancellable>()

    @AppUserDefault(.selectedLanguage, defaultValue: nil)
    private var _language: String?

    @AppUserDefault(.selectedBackupFrequency, defaultValue: nil)
    private var _backupFrequency: String?

    public init(defaultLanguage: Languages = .deviceLanguage, defaultBackupFrequency: BackupFrequencyEnum = .manually) {
        if _language == nil {
            _language = (defaultLanguage == .deviceLanguage ? deviceLanguage : defaultLanguage).map { $0.rawValue }
        }
        
        selectedLanguage = Languages(rawValue: _language!)!
        
        if _backupFrequency == nil {
            _backupFrequency = defaultBackupFrequency.rawValue
        }
        
        selectedBackupFrequency = BackupFrequencyEnum(rawValue: _backupFrequency!)!
        
        observeForSelectedLanguage()
        observeForSelectedBackupFrequency()
    }

    private func observeForSelectedLanguage() {
        $selectedLanguage
            .map({ $0.rawValue })
            .sink { [weak self] value in
                self?._language = value
            }
            .store(in: &bag)
    }

    private func observeForSelectedBackupFrequency() {
        $selectedBackupFrequency
            .map({ $0.rawValue })
            .sink { [weak self] value in
                self?._backupFrequency = value
            }
            .store(in: &bag)
    }
}
