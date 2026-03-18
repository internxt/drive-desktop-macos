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
  let defaults: UserDefaults

  init(_ key: DefaultsKeys, defaultValue: T, suiteName: String? = nil) {
    self.key = key.rawValue
    self.defaultValue = defaultValue
    self.defaults = suiteName != nil ? UserDefaults(suiteName: suiteName!) ?? .standard : .standard
  }

  var wrappedValue: T {
    get {
      return defaults.object(forKey: key) as? T ?? defaultValue
    }
    set {
      defaults.set(newValue, forKey: key)
    }
  }
}

enum DefaultsKeys: String {
  case selectedLanguage = "INTERNXT_SELECTED_LANGUAGE"
  case selectedBackupFrequency = "INTERNXT_SELECTED_BACKUP_FREQUENCY"
  case reduceBandwidth = "INTERNXT_REDUCE_BANDWIDTH"
}
