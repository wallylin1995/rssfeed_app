import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum JippoPalette {
    static let canvas = platformColor(
        light: PlatformColor(red: 0.945, green: 0.950, blue: 0.962, alpha: 1.0),
        dark: PlatformColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)
    )
    static let panel = platformColor(
        light: PlatformColor(red: 0.972, green: 0.975, blue: 0.982, alpha: 1.0),
        dark: PlatformColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)
    )
    static let panelSoft = platformColor(
        light: PlatformColor(red: 0.905, green: 0.915, blue: 0.935, alpha: 1.0),
        dark: PlatformColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1.0)
    )
    static let highlight = Color(red: 0.98, green: 0.34, blue: 0.43)

    private static func platformColor(light: PlatformColor, dark: PlatformColor) -> Color {
#if os(macOS)
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return match == .darkAqua ? dark : light
            }
        )
#else
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
#endif
    }
}

#if os(macOS)
private typealias PlatformColor = NSColor
#else
private typealias PlatformColor = UIColor
#endif

enum JippoTitleDisplayMode {
    case large
    case inline
}

extension View {
    @ViewBuilder
    func jippoTitleDisplayMode(_ mode: JippoTitleDisplayMode) -> some View {
        #if os(macOS)
        self
        #else
        switch mode {
        case .large:
            navigationBarTitleDisplayMode(.large)
        case .inline:
            navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
}
