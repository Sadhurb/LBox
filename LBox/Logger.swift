import Foundation
import Combine
import SwiftUI

class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var logs: String = ""
    #if DEBUG
    private let logFileURL: URL
    #endif
    
    private init() {
        #if DEBUG
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        logFileURL = paths[0].appendingPathComponent("debug_log.txt")
        loadLogs()
        #endif
    }
    
    func log(_ message: String) {
        #if DEBUG
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async {
            self.logs.append(logEntry)
        }
        
        // Append to file
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
        #endif
    }
    
    #if DEBUG
    func loadLogs() {
        if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
            self.logs = content
        }
    }
    
    func clearLogs() {
        self.logs = ""
        try? FileManager.default.removeItem(at: logFileURL)
    }
    #endif
}

#if DEBUG
struct DebugLogView: View {
    @ObservedObject var logger = Logger.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logger.logs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Debug Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIPasteboard.general.string = logger.logs
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logger.clearLogs()
                    }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
#endif