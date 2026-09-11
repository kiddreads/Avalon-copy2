// Avalon — logging.
//
// Categories are subsystem-shaped, not console-shaped. PPSSPP's are the counter-example: its
// `enum class Log` hardcodes `sceAudio`, `sceCtrl`, `sceDisplay`, `Mpeg`, `Atrac`, `SasMix`
// (`PPSSPP/Common/Log.h:33-80`), so every file that logs depends on PSP vocabulary. In a platform
// hosting a dozen systems that is unusable — a Dolphin core would be logging under `sceDisplay`.
//
// Hot-path cost is the other requirement. Cores log per frame and sometimes per block, so a
// disabled category must cost a relaxed atomic load and nothing else: no string formatting, no
// allocation, no autoclosure capture of anything expensive. Hence `@autoclosure @escaping` on the
// message and the `isEnabled` check before it is ever evaluated.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

public enum LogLevel: Int, Comparable, Sendable, CaseIterable {
    case trace = 0, debug, info, warning, error, critical
    public static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }

    public var label: String {
        switch self {
        case .trace: return "TRACE"; case .debug: return "DEBUG"; case .info: return "INFO"
        case .warning: return "WARN"; case .error: return "ERROR"; case .critical: return "CRIT"
        }
    }
}

/// What part of Avalon is speaking. Open string so a core can add its own without touching this.
public struct LogCategory: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let core: Self = "core"
    public static let cpu: Self = "cpu"
    public static let jit: Self = "jit"
    public static let memory: Self = "memory"
    public static let graphics: Self = "graphics"
    public static let audio: Self = "audio"
    public static let input: Self = "input"
    public static let storage: Self = "storage"
    public static let config: Self = "config"
    public static let library: Self = "library"
    public static let platform: Self = "platform"
}

public struct LogRecord: Sendable {
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String
    public let line: Int
    public let timestamp: Date
}

public protocol LogSink: AnyObject, Sendable {
    func write(_ record: LogRecord)
}

/// Writes to stderr. Deliberately the only sink here: an OSLog or file sink is platform code.
public final class ConsoleLogSink: LogSink {
    public init() {}
    public func write(_ r: LogRecord) {
        let name = (r.file as NSString).lastPathComponent
        FileHandle.standardError.write(
            "[\(r.level.label)][\(r.category.rawValue)] \(r.message)  (\(name):\(r.line))\n"
                .data(using: .utf8)!)
    }
}

/// Collects records in memory. Used by tests and by the in-app diagnostics view.
public final class MemoryLogSink: LogSink, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [LogRecord] = []
    private let limit: Int

    public init(limit: Int = 4096) { self.limit = limit }

    public func write(_ r: LogRecord) {
        lock.lock(); defer { lock.unlock() }
        records.append(r)
        if records.count > limit { records.removeFirst(records.count - limit) }
    }

    public var all: [LogRecord] { lock.lock(); defer { lock.unlock() }; return records }
    public func records(in category: LogCategory) -> [LogRecord] { all.filter { $0.category == category } }
    public func clear() { lock.lock(); defer { lock.unlock() }; records.removeAll() }
}

public final class Logger: @unchecked Sendable {
    public static let shared = Logger()

    private let lock = NSLock()
    private var sinks: [LogSink] = []
    private var categoryLevels: [LogCategory: LogLevel] = [:]
    private var globalLevel: LogLevel = .info

    public init() {}

    public func add(sink: LogSink) { lock.lock(); defer { lock.unlock() }; sinks.append(sink) }
    public func removeAllSinks() { lock.lock(); defer { lock.unlock() }; sinks.removeAll() }

    public func setLevel(_ level: LogLevel, for category: LogCategory? = nil) {
        lock.lock(); defer { lock.unlock() }
        if let category { categoryLevels[category] = level } else { globalLevel = level }
    }

    public func isEnabled(_ level: LogLevel, _ category: LogCategory) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return level >= (categoryLevels[category] ?? globalLevel)
    }

    /// The message closure is only evaluated when the category is enabled, so an expensive
    /// interpolation on a disabled hot path costs nothing.
    public func log(_ level: LogLevel, _ category: LogCategory,
                    _ message: @autoclosure () -> String,
                    file: String = #fileID, line: Int = #line) {
        guard isEnabled(level, category) else { return }
        let record = LogRecord(level: level, category: category, message: message(),
                               file: file, line: line, timestamp: Date())
        lock.lock(); let targets = sinks; lock.unlock()
        for s in targets { s.write(record) }
    }

    public func trace(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.trace, c, m(), file: file, line: line) }
    public func debug(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.debug, c, m(), file: file, line: line) }
    public func info(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.info, c, m(), file: file, line: line) }
    public func warning(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.warning, c, m(), file: file, line: line) }
    public func error(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.error, c, m(), file: file, line: line) }
    public func critical(_ c: LogCategory, _ m: @autoclosure () -> String, file: String = #fileID, line: Int = #line) { log(.critical, c, m(), file: file, line: line) }
}
