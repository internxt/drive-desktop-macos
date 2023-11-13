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

    
    @Published public var selectedLanguage: Languages = .deviceLanguage


    private var bag = Set<AnyCancellable>()

    @AppUserDefault(.selectedLanguage, defaultValue: nil)
    private var _language: String?


    public init(defaultLanguage: Languages = .deviceLanguage) {
        if _language == nil {
          _language = (defaultLanguage == .deviceLanguage ? deviceLanguage : defaultLanguage).map { $0.rawValue }
        }
        

        selectedLanguage = Languages(rawValue: _language!)!

        observeForSelectedLanguage()
    }


    private func observeForSelectedLanguage() {
        $selectedLanguage
            .map({ $0.rawValue })
            .sink { [weak self] value in
                self?._language = value
            }
        .store(in: &bag)
    }

}
