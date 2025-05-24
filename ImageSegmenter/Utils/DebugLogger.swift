import Foundation

/// Debug logging utility for consistent logging throughout the app
class DebugLogger {

    /// Log levels
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    /// Log a message to the console
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The file where the log was called
    ///   - function: The function where the log was called
    ///   - line: The line where the log was called
    static func log(
        _ message: String,
        level: Level = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Always use NSLog for reliable console output
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date().description
        let output = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"

        // Try multiple logging methods to ensure visibility

        // 1. Use NSLog for reliable console output
        NSLog("%@", output)

        // 2. Use print to standard output
        print(output)

        // 3. Write directly to stderr
        fputs("\(output)\n", stderr)

        // Flush output streams
        fflush(stdout)
        fflush(stderr)
    }

    /// Log debug level message
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log info level message
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    /// Log warning level message
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    /// Log error level message
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}

// Global convenience function
func debugLog(_ message: String, level: DebugLogger.Level = .debug, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.log(message, level: level, file: file, function: function, line: line)
}
