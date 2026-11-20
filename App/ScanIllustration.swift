import SwiftUI
import AppKit

struct ScanIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let appIcon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) * 60
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.07))
                    .frame(width: 134, height: 134)
                Circle()
                    .stroke(Color.accentColor.opacity(0.13), lineWidth: 2)
                    .frame(width: 132, height: 132)
                Circle()
                    .trim(from: 0.02, to: 0.29)
                    .stroke(
                        AngularGradient(colors: [.clear, .accentColor.opacity(0.8)], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 132, height: 132)
                    .rotationEffect(.degrees(angle))
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.accentColor.opacity(0.18), radius: 9, y: 5)
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 140, height: 140)
        }
        .accessibilityHidden(true)
    }
}
