// Avalon — configuration.
//
// Three scopes, resolved narrowest-first: per-game beats per-system beats global. That shape comes
// from Manic EMU, which is the only project here that gets it right
// (`Manic EMU/.../Common/Models/Prefference.swift:17-149`). Delta by contrast stores per-game
// settings as an opaque `NSDictionary` with four keys (`Delta/.../Misc/GameSetting.h:11-15`), which
// is why nothing in Delta can be overridden per game without a schema change.
//
// Values are typed. Folium's settings are the cautionary tale: it defines ~40 3DS settings, maps 14
// of them to the core, and silently discards every non-Bool (`Folium/.../Cytrus.swift:145-152`), so
// upscale factor, texture filter and volume are shown in the UI and never applied.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A typed setting value. Closed on purpose — an open `Any` is how Folium's silently-dropped
/// settings happened.
public enum SettingValue: Hashable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var intValue: Int? {
        switch self { case .int(let v): return v; case .double(let v): return Int(v); default: return nil }
    }
    public var doubleValue: Double? {
        switch self { case .double(let v): return v; case .int(let v): return Double(v); default: return nil }
    }
    public var stringValue: String? { if case .string(let v) = self { return v }; return nil }
}

/// Where a setting was defined. Narrower scopes win.
public enum SettingScope: Int, Comparable, Sendable, CaseIterable {
    case global = 0, system = 1, game = 2
    public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

/// A declared setting: identity, type and default, in one place.
///
/// Declaring settings rather than free-form keys is what lets `unknownKeys` exist, which is the
/// check that would have caught Folium's 26 unmapped settings.
public struct SettingKey: Hashable, Sendable {
    public let name: String
    public let defaultValue: SettingValue
    /// Cores that understand this setting. Empty means "any".
    public let appliesTo: Set<String>

    public init(_ name: String, default defaultValue: SettingValue, appliesTo: Set<String> = []) {
        self.name = name; self.defaultValue = defaultValue; self.appliesTo = appliesTo
    }
}

/// Resolved settings for one game on one core.
public struct ResolvedSettings: Sendable {
    public let values: [String: SettingValue]
    /// Which scope each value came from, so a UI can show "overridden for this game".
    public let origins: [String: SettingScope]

    public subscript(_ name: String) -> SettingValue? { values[name] }
    public func origin(of name: String) -> SettingScope? { origins[name] }
    public func bool(_ n: String) -> Bool? { values[n]?.boolValue }
    public func int(_ n: String) -> Int? { values[n]?.intValue }
    public func double(_ n: String) -> Double? { values[n]?.doubleValue }
    public func string(_ n: String) -> String? { values[n]?.stringValue }
}

/// The three-scope settings store.
public final class ConfigurationStore {
    private var declared: [String: SettingKey] = [:]
    private var global: [String: SettingValue] = [:]
    private var system: [SystemIdentifier: [String: SettingValue]] = [:]
    private var game: [String: [String: SettingValue]] = [:]
    private let lock = NSLock()

    public init(declaring keys: [SettingKey] = []) {
        for k in keys { declared[k.name] = k }
    }

    public func declare(_ key: SettingKey) {
        lock.lock(); defer { lock.unlock() }
        declared[key.name] = key
    }

    public var declaredKeys: [SettingKey] {
        lock.lock(); defer { lock.unlock() }
        return Array(declared.values)
    }

    /// Set a value. Rejects an undeclared key or a type mismatch rather than storing something the
    /// core will later ignore.
    @discardableResult
    public func set(_ name: String, _ value: SettingValue,
                    scope: SettingScope,
                    system sys: SystemIdentifier? = nil,
                    gameID: String? = nil) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let key = declared[name] else { return false }
        guard sameCase(key.defaultValue, value) else { return false }
        switch scope {
        case .global: global[name] = value
        case .system:
            guard let sys else { return false }
            system[sys, default: [:]][name] = value
        case .game:
            guard let gameID else { return false }
            game[gameID, default: [:]][name] = value
        }
        return true
    }

    public func clear(_ name: String, scope: SettingScope,
                      system sys: SystemIdentifier? = nil, gameID: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        switch scope {
        case .global: global[name] = nil
        case .system: if let sys { system[sys]?[name] = nil }
        case .game: if let gameID { game[gameID]?[name] = nil }
        }
    }

    /// Resolve every declared setting for a given core, system and game.
    public func resolve(coreID: String? = nil,
                        system sys: SystemIdentifier? = nil,
                        gameID: String? = nil) -> ResolvedSettings {
        lock.lock(); defer { lock.unlock() }
        var values: [String: SettingValue] = [:]
        var origins: [String: SettingScope] = [:]

        for (name, key) in declared {
            if let coreID, !key.appliesTo.isEmpty, !key.appliesTo.contains(coreID) { continue }
            var v = key.defaultValue
            var origin: SettingScope? = nil
            if let g = global[name] { v = g; origin = .global }
            if let sys, let s = system[sys]?[name] { v = s; origin = .system }
            if let gameID, let gv = game[gameID]?[name] { v = gv; origin = .game }
            values[name] = v
            if let origin { origins[name] = origin }
        }
        return ResolvedSettings(values: values, origins: origins)
    }

    /// Stored keys a core will never read — settings shown to the user and silently dropped.
    ///
    /// This is the Folium failure made detectable.
    public func unknownKeys(for coreID: String) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        var stored = Set(global.keys)
        for (_, m) in system { stored.formUnion(m.keys) }
        for (_, m) in game { stored.formUnion(m.keys) }
        return stored.filter { name in
            guard let k = declared[name] else { return true }
            return !k.appliesTo.isEmpty && !k.appliesTo.contains(coreID)
        }
    }

    private func sameCase(_ a: SettingValue, _ b: SettingValue) -> Bool {
        switch (a, b) {
        case (.bool, .bool), (.int, .int), (.double, .double), (.string, .string): return true
        default: return false
        }
    }
}
