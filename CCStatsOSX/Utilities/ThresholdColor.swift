import SwiftUI

extension Color {
    static func forUtilization(_ percentage: Double, settings: AppSettings = .shared) -> Color {
        if percentage >= Double(settings.criticalThreshold) {
            return .red
        } else if percentage >= Double(settings.warningThreshold) {
            return .orange
        } else {
            return .blue
        }
    }
}
