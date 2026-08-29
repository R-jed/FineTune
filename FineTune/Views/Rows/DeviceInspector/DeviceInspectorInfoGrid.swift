// FineTune/Views/Rows/DeviceInspector/DeviceInspectorInfoGrid.swift
import AppKit
import SwiftUI

/// Column-aligned info grid for the Device Inspector pane.
@MainActor
struct DeviceInspectorInfoGrid: View {
    let info: DeviceInspectorInfo
    let onSampleRateSelected: (Double) -> Void

    var body: some View {
        let layout = InfoGridLayout(info: info)
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: DesignTokens.Spacing.md, verticalSpacing: 4) {
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                rowView(for: row)
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: InfoGridLayout.Row) -> some View {
        switch row {
        case .transport(let transportType):
            GridRow {
                labelCell("Transport")
                Text(transportType.displayName)
                    .font(DesignTokens.Typography.pickerText)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .gridColumnAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        case .sampleRate(let display, let isPicker, let options):
            GridRow {
                labelCell("Sample rate")
                if isPicker {
                    SampleRatePickerValue(currentDisplay: display, options: options, onSelect: onSampleRateSelected)
                        .gridColumnAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    valueCell(display)
                }
            }
        case .format(let value):
            GridRow {
                labelCell("Format")
                valueCell(value)
            }
        case .deviceID(let uid):
            GridRow {
                labelCell("Device ID")
                DeviceIDValueCell(uid: uid)
                    .gridColumnAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func labelCell(_ resource: LocalizedStringResource) -> some View {
        Text(resource)
            .font(DesignTokens.Typography.pickerText)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .gridColumnAlignment(.leading)
    }

    private func valueCell(_ text: String) -> some View {
        Text(verbatim: text)
            .font(DesignTokens.Typography.pickerText)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineLimit(1)
            .gridColumnAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .combine)
    }
}

private struct SampleRatePickerValue: View {
    let currentDisplay: String
    let options: [Double]
    let onSelect: (Double) -> Void
    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { rate in
                Button {
                    onSelect(rate)
                } label: {
                    Text(verbatim: DeviceInspectorInfo.formatSampleRate(rate))
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(verbatim: currentDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius).fill(DesignTokens.Surface.raised))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .strokeBorder(isHovered ? DesignTokens.Stroke.hover : DesignTokens.Stroke.resting, lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovered)
        .accessibilityLabel(Text("Sample rate") + Text(verbatim: ": \(currentDisplay). ") + Text("Activate to change"))
    }
}

private struct DeviceIDValueCell: View {
    let uid: String
    @State private var copied = false

    private var helpText: LocalizedStringResource { copied ? "Copied" : "Copy device ID" }
    private var accessibilityText: LocalizedStringResource { copied ? "Device ID copied" : "Copy device ID" }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(verbatim: uid)
                .font(DesignTokens.Typography.pickerText)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(Text(verbatim: uid))

            Button(action: copyToClipboard) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(copied ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(
                        minWidth: DesignTokens.Dimensions.minTouchTarget,
                        minHeight: DesignTokens.Dimensions.minTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(helpText)
            .accessibilityLabel(Text(accessibilityText))
        }
        .accessibilityElement(children: .contain)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uid, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
