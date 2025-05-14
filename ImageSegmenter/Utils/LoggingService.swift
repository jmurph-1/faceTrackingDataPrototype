import Foundation

class LoggingService {
    
    enum LogLevel: Int {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        case verbose = 5
        
        var prefix: String {
            switch self {
            case .none: return ""
            case .error: return "❌ ERROR"
            case .warning: return "⚠️ WARNING"
            case .info: return "ℹ️ INFO"
            case .debug: return "🔍 DEBUG"
            case .verbose: return "📝 VERBOSE"
            }
        }
    }
    
    static var currentLogLevel: LogLevel = .debug
    
    static var showTimestamps: Bool = true
    
    static func log(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.rawValue <= currentLogLevel.rawValue else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = showTimestamps ? "[\(dateFormatter.string(from: Date()))] " : ""
        let logMessage = "\(timestamp)\(level.prefix) [\(fileName):\(line)] \(function): \(message)"
        
        print(logMessage)
    }
    
    static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func verbose(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .verbose, file: file, function: function, line: line)
    }
    
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
