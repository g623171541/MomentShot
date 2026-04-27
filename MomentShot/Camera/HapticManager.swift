//
//  HapticManager.swift
//  MomentShot
//

import UIKit

@MainActor
enum HapticManager {

    static func light() {
        guard AppSettings.shared.hapticEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard AppSettings.shared.hapticEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func rigid() {
        guard AppSettings.shared.hapticEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func success() {
        guard AppSettings.shared.hapticEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard AppSettings.shared.hapticEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
