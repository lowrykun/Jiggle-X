import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Jiggle-X")
                .font(.title)
                .bold()
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("During your working hours, Jiggle-X tells macOS you're active whenever you step away, so Microsoft Teams keeps showing you as Available. Outside your hours, or while paused, it does nothing.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("While active, the screensaver and auto-lock won't start.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 380)
    }
}
