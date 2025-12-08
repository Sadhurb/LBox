import SwiftUI
import Combine
import UserNotifications

struct InAppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    
    enum NotificationType {
        case success
        case info
        case error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .info: return .blue
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentNotification: InAppNotification?
    private var timer: Timer?
    
    // Track app state
    var isAppInForeground: Bool = true
    
    private init() {}
    
    func show(title: String, message: String, type: InAppNotification.NotificationType = .info) {
        if isAppInForeground {
            showInApp(title: title, message: message, type: type)
        } else {
            showSystemNotification(title: title, body: message)
        }
    }
    
    private func showInApp(title: String, message: String, type: InAppNotification.NotificationType) {
        DispatchQueue.main.async {
            // Cancel existing timer if any
            self.timer?.invalidate()
            
            withAnimation(.spring()) {
                self.currentNotification = InAppNotification(title: title, message: message, type: type)
            }
            
            // Auto dismiss after 3 seconds
            self.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                Task { @MainActor in
                    withAnimation(.easeOut) {
                        self.currentNotification = nil
                    }
                }
            }
        }
    }
    
    private func showSystemNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct InAppNotificationView: View {
    @ObservedObject var manager = NotificationManager.shared
    
    var body: some View {
        if let notification = manager.currentNotification {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: notification.type.icon)
                        .font(.title2)
                        .foregroundColor(notification.type.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.horizontal)
                .padding(.top, 8) // Add some top padding
                
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100) // Ensure it stays on top
        }
    }
}
