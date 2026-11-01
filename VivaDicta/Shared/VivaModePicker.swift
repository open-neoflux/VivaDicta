//
//  VivaModePicker.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.13
//

import SwiftUI

struct VivaModePicker: View {
    let modes: [VivaMode]
    @Binding var selectedModeName: String
    var onSelectionChanged: (() -> Void)?

    /// The selected mode's localized name; falls back to the raw value when
    /// the mode isn't in the list yet (e.g. during a cross-device sync).
    private var selectedDisplayName: String {
        modes.first { $0.name == selectedModeName }?.displayName ?? selectedModeName
    }

    var body: some View {
        Menu {
            ForEach(modes) { mode in
                Button {
                    selectedModeName = mode.name
                    onSelectionChanged?()
                } label: {
                    if mode.name == selectedModeName {
                        Label(mode.displayName, systemImage: "checkmark")
                    } else {
                        Text(mode.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedDisplayName)
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .modePickerBackground()
        }
        .tint(.primary)
        .accessibilityLabel("Mode selector")
        .accessibilityValue(selectedModeName)
        .accessibilityHint("Double tap to choose a different mode")
    }
}

// MARK: - Mode Picker Background

private struct ModePickerBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.tertiary, in: .capsule)
        }
    }
}

extension View {
    fileprivate func modePickerBackground() -> some View {
        modifier(ModePickerBackgroundModifier())
    }
}

#Preview {
    VivaModePicker(
        modes: [VivaMode.defaultMode],
        selectedModeName: .constant("Default")
    )
}
