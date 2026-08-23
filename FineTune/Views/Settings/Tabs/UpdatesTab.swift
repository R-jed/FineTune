// FineTune/Views/Settings/Tabs/UpdatesTab.swift
import SwiftUI

@MainActor
struct UpdatesTab: View {
    @ObservedObject var updateManager: UpdateManager
    let language: AppLanguage

    private var localization: LocalizationContext {
        LocalizationContext(language: language)
    }

    private var lastCheckDescription: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = localization.localized("Version")

        if let date = updateManager.lastUpdateCheckDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.locale = localization.presentationLocale
            let relativeDate = formatter.localizedString(for: date, relativeTo: .now)
            return "\(versionLabel) \(version) · \(relativeDate)"
        }

        let neverChecked = localization.localized("Never checked")
        return "\(versionLabel) \(version) · \(neverChecked)"
    }

    private var automaticallyChecksBinding: Binding<Bool> {
        Binding(
            get: { updateManager.automaticallyChecksForUpdates },
            set: { updateManager.automaticallyChecksForUpdates = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection("Software Updates") {
                    SettingsRow(
                        "Automatic updates",
                        description: "Check for new versions automatically"
                    ) {
                        Toggle("", isOn: automaticallyChecksBinding)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                    SettingsRowDivider()
                    SettingsRow(
                        "Last checked",
                        verbatimDescription: lastCheckDescription
                    ) {
                        Button("Check Now") {
                            updateManager.checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}
