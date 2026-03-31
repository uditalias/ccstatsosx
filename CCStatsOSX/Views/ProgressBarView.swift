import SwiftUI

struct ProgressBarView: View {
    let value: Double
    let label: String
    let icon: String
    let resetDate: Date?

    private let claudeColor = Color(red: 0.78, green: 0.38, blue: 0.22)
    private let claudeColorLight = Color(red: 0.78, green: 0.38, blue: 0.22).opacity(0.15)

    @State private var currentDate = Date()
    @State private var animatedValue: Double = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var barColor: Color {
        let settings = AppSettings.shared
        if value >= Double(settings.criticalThreshold) {
            return .red
        } else if value >= Double(settings.warningThreshold) {
            return .orange
        } else {
            return claudeColor
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [barColor.opacity(0.7), barColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: icon + label + large percentage
            HStack(alignment: .center, spacing: 0) {
                // Icon + label
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(barColor.opacity(0.8))
                        .frame(width: 16)
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                }

                Spacer()

                // Large percentage
                Text("\(Int(value))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(barColor)
                    .contentTransition(.numericText())
            }

            // Progress bar with glow
            GeometryReader { geometry in
                let fillWidth = max(geometry.size.width * CGFloat(min(animatedValue, 100) / 100), 4)
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    // Fill with subtle glow
                    Capsule()
                        .fill(barGradient)
                        .frame(width: fillWidth)
                        .shadow(color: barColor.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 5)

            // Reset info row
            if let resetDate {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.35))
                        .padding(.trailing, 4)
                    Text(TimeFormatter.resetDate(resetDate))
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.4))

                    Spacer()

                    Text(TimeFormatter.countdown(to: resetDate, from: currentDate))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.65))
                }
                .onReceive(timer) { self.currentDate = $0 }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedValue = newValue
            }
        }
    }
}
