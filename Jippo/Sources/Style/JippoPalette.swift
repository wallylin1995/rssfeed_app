import SwiftUI

enum JippoPalette {
    static let canvas = Color(red: 0.09, green: 0.09, blue: 0.10)
    static let panel = Color(red: 0.18, green: 0.18, blue: 0.19)
    static let panelSoft = Color(red: 0.23, green: 0.23, blue: 0.24)
    static let highlight = Color(red: 0.98, green: 0.34, blue: 0.43)
}

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
