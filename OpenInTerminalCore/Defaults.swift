//
//  Defaults.swift
//  OpenInTerminalCore
//
//  Created by Jianing Wang on 2019/4/21.
//  Copyright © 2019 Jianing Wang. All rights reserved.
//

import Foundation
import Security

private let defaultsMigrationVersionKey = "OIT_DefaultsMigrationVersion"
private let currentDefaultsMigrationVersion = 1
private let legacyPreferenceKeys = [
    "FirstSetup",
    "LaunchAtLogin",
    "QuickToggle",
    "QuickToggleType",
    "HideStatusItem",
    "HideContextMenuItems",
    "ContextMenuUseSubmenu",
    "DefaultTerminal",
    "DefaultEditor",
    "TerminalNewOption",
    "ITermNewOption",
    "CustomMenuOptions",
    "CustomMenuApplyToToolbar",
    "CustomMenuApplyToContext",
    "CustomMenuIconOption",
    "PathEscapeOption",
    "KittyCommand",
    "OnlyActivateShortcutsInFinder",
    "NeovimCommand",
    "GitkrakenCommand",
    "OIT_DefaultTerminalShortcut",
    "OIT_DefaultEditorShortcut",
    "OIT_CopyPathShortcut"
]

private struct DefaultsConfiguration {
    let store: UserDefaults
    let persistentDomainName: String?
}

/// current defaults
///
/// Signed upstream builds use a macOS-style App Group whose prefix matches the
/// signing team. Ad-hoc and differently signed builds cannot access that group,
/// so they use their standard defaults domain rather than silently writing to an
/// invalid suite that cfprefsd will not persist.
private let defaultsConfiguration: DefaultsConfiguration = {
    let bundleIdentifier = Bundle.main.bundleIdentifier
    if bundleIdentifier == Constants.Id.OpenInTerminalLite ||
        bundleIdentifier == Constants.Id.OpenInEditorLite {
        return DefaultsConfiguration(store: .standard,
                                     persistentDomainName: bundleIdentifier)
    }

    if currentSigningTeamIdentifier() == Constants.Id.Group.split(separator: ".").first.map(String.init),
       canAccessAppGroupContainer(Constants.Id.Group),
       let groupDefaults = UserDefaults(suiteName: Constants.Id.Group) {
        migrateLegacyDefaultsIfNeeded(to: groupDefaults)
        return DefaultsConfiguration(store: groupDefaults,
                                     persistentDomainName: Constants.Id.Group)
    }

    let standardDefaults = UserDefaults.standard
    migrateLegacyDefaultsIfNeeded(to: standardDefaults)
    return DefaultsConfiguration(store: standardDefaults,
                                 persistentDomainName: bundleIdentifier)
}()

public var Defaults: UserDefaults = defaultsConfiguration.store

private func currentSigningTeamIdentifier() -> String? {
    var dynamicCode: SecCode?
    guard SecCodeCopySelf([], &dynamicCode) == errSecSuccess,
          let dynamicCode else {
        return nil
    }

    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
          let staticCode else {
        return nil
    }

    var signingInformation: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode,
                                        SecCSFlags(rawValue: kSecCSSigningInformation),
                                        &signingInformation) == errSecSuccess,
          let information = signingInformation as? [CFString: Any] else {
        return nil
    }

    return information[kSecCodeInfoTeamIdentifier] as? String
}

/// On macOS, `containerURL` can return an expected-looking URL even when the
/// process is not authorized for the group. Test the directory itself before
/// selecting the corresponding UserDefaults suite.
private func canAccessAppGroupContainer(_ identifier: String) -> Bool {
    guard let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
        return false
    }

    let probeURL = containerURL
        .appendingPathComponent(".OpenInTerminal-access-\(UUID().uuidString)")
    do {
        try FileManager.default.createDirectory(at: containerURL,
                                                withIntermediateDirectories: true)
        try Data().write(to: probeURL, options: .atomic)
        try FileManager.default.removeItem(at: probeURL)
        return true
    } catch {
        try? FileManager.default.removeItem(at: probeURL)
        return false
    }
}

private func migrateLegacyDefaultsIfNeeded(to destination: UserDefaults) {
    guard destination.integer(forKey: defaultsMigrationVersionKey) <
            currentDefaultsMigrationVersion else {
        return
    }

    if let legacyDefaults = UserDefaults(suiteName: Constants.Id.LegacyGroup) {
        for key in legacyPreferenceKeys where destination.object(forKey: key) == nil {
            if let value = legacyDefaults.object(forKey: key) {
                destination.set(value, forKey: key)
            }
        }
    }

    destination.set(currentDefaultsMigrationVersion,
                    forKey: defaultsMigrationVersionKey)
    destination.synchronize()
}

func removeAllDefaults() {
    if let domainName = defaultsConfiguration.persistentDomainName {
        Defaults.removePersistentDomain(forName: domainName)
    }
    UserDefaults(suiteName: Constants.Id.LegacyGroup)?
        .removePersistentDomain(forName: Constants.Id.LegacyGroup)
    Defaults.set(currentDefaultsMigrationVersion,
                 forKey: defaultsMigrationVersionKey)
    Defaults.synchronize()
}

public class DefaultsKeys {
    fileprivate init() {}
}

public class DefaultsKey<ValueType>: DefaultsKeys {
    let _key: String
    
    init(_ key: String) {
        self._key = key
    }
}

public extension DefaultsKeys {
    // Preferences - General
    static let firstSetup = DefaultsKey<Bool>("FirstSetup")
    static let launchAtLogin = DefaultsKey<Bool>("LaunchAtLogin")
    static let quickToggle = DefaultsKey<Bool>("QuickToggle")
    static let quickToggleType = DefaultsKey<String>("QuickToggleType")
    static let hideStatusItem = DefaultsKey<Bool>("HideStatusItem")
    static let hideContextMenuItems = DefaultsKey<Bool>("HideContextMenuItems")
    static let contextMenuUseSubmenu = DefaultsKey<Bool>("ContextMenuUseSubmenu")
    static let defaultTerminal = DefaultsKey<String>("DefaultTerminal")
    static let defaultEditor = DefaultsKey<String>("DefaultEditor")
    // Preferences - Custom
    static let terminalNewOption = DefaultsKey<String>("TerminalNewOption")
    static let iTermNewOption = DefaultsKey<String>("iTermNewOption")
    static let customMenuOptions = DefaultsKey<Data>("CustomMenuOptions")
    static let customMenuApplyToToolbar = DefaultsKey<Bool>("CustomMenuApplyToToolbar")
    static let customMenuApplyToContext = DefaultsKey<Bool>("CustomMenuApplyToContext")
    static let customMenuIconOption = DefaultsKey<String>("CustomMenuIconOption")
    static let pathEscapeOption = DefaultsKey<Bool>("PathEscapeOption")
    static let kittyCommand = DefaultsKey<String>("KittyCommand")
    static let onlyActivateShortcutsInFinder = DefaultsKey<Bool>("OnlyActivateShortcutsInFinder")
    static let neovimCommand = DefaultsKey<String>("NeovimCommand")
    static let gitkrakenCommand = DefaultsKey<String>("GitkrakenCommand")
    
    // for Lite
    static let liteDefaultTerminal = DefaultsKey<String>("LiteDefaultTerminal")
    static let liteDefaultEditor = DefaultsKey<String>("LiteDefaultEditor")
}

public extension UserDefaults {
    subscript(key: DefaultsKey<String>) -> String? {
        get { return string(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Bool>) -> Bool {
        get { return bool(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Int>) -> Int {
        get { return integer(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Float>) -> Float {
        get { return float(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Double>) -> Double {
        get { return double(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<URL>) -> URL? {
        get { return url(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Any>) -> Any? {
        get { return value(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<[Any]>) -> [Any]? {
        get { return array(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<Data>) -> Data? {
        get { return data(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<[String : Any]>) -> [String : Any]? {
        get { return dictionary(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
    subscript(key: DefaultsKey<[String]>) -> [String]? {
        get { return stringArray(forKey: key._key) }
        set { set(newValue, forKey: key._key) }
    }
}
