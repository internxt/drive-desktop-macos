//
//  AppUserDefaults.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/11/23.
//

import Foundation


import Foundation

@propertyWrapper
struct AppUserDefault<T> {
  let key: String
  let defaultValue: T

  init(_ key: DefaultsKeys, defaultValue: T) {
    self.key = key.rawValue
    self.defaultValue = defaultValue
  }

  var wrappedValue: T {
    get {
      return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: key)
    }
  }
}

enum DefaultsKeys: String {
  case selectedLanguage = "INTERNXT_SELECTED_LANGUAGE"
  case selectedBackupFrequency = "INTERNXT_SELECTED_BACKUP_FREQUENCY"
}
