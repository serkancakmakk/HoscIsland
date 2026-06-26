import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var screens: [(id: CGDirectDisplayID, screen: NSScreen)] = Settings.availableScreens()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 0) {
                    Text("HoscIsland")
                        .font(.system(size: 16, weight: .bold))
                    Text("Dynamic Island ayarları")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Hangi ekranda görünsün?")
                    .font(.system(size: 13, weight: .semibold))

                screenRow(
                    title: "Otomatik",
                    subtitle: "Notch'lu ekranı tercih eder",
                    systemImage: "wand.and.stars",
                    isSelected: settings.selectedDisplayID == nil
                ) {
                    settings.selectedDisplayID = nil
                }

                ForEach(screens, id: \.id) { entry in
                    screenRow(
                        title: entry.screen.localizedName,
                        subtitle: subtitle(for: entry),
                        systemImage: Settings.isNotched(entry.screen) ? "macbook" : "display",
                        isSelected: settings.selectedDisplayID == entry.id
                    ) {
                        settings.selectedDisplayID = entry.id
                    }
                }
            }

            Button {
                screens = Settings.availableScreens()
            } label: {
                Label("Ekranları yenile", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Özellikler")
                    .font(.system(size: 13, weight: .semibold))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Açılma şekli")
                            .font(.system(size: 12, weight: .medium))
                        Text("Üzerine gelince mi tıklayınca mı açılsın")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.interactionMode) {
                        ForEach(InteractionMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 130)
                    .controlSize(.small)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Taşınabilir ada")
                            .font(.system(size: 12, weight: .medium))
                        Text("Açıkken adayı sürükleyerek taşı")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if settings.movableNotch {
                        Button("Sıfırla") {
                            settings.notchOffset = .zero
                            settings.movableNotch = true   // republish → controller re-centers
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                    Toggle("", isOn: $settings.movableNotch)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                }

                featureToggle("Açılışta başlat", "Oturum açınca otomatik başlasın", isOn: $settings.launchAtLogin)

                featureToggle("Müzik göstergesi", "Çalan parça + kontroller", isOn: $settings.showMusic)
                featureToggle("WhatsApp banner", "Gelen mesajı gönderen + metniyle göster", isOn: $settings.showNotifications)
                featureToggle("Okunmamış rozeti", "WhatsApp okunmamış sayısı", isOn: $settings.showUnreadCount)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pil göstergesi")
                            .font(.system(size: 12, weight: .medium))
                        Text("Kapalı · sadece kablo değişince · her zaman")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.batteryMode) {
                        ForEach(BatteryMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                    .controlSize(.small)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 400, height: 610)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = Settings.availableScreens()
        }
    }

    private func subtitle(for entry: (id: CGDirectDisplayID, screen: NSScreen)) -> String {
        let f = entry.screen.frame
        let res = "\(Int(f.width))×\(Int(f.height))"
        let notch = Settings.isNotched(entry.screen) ? " • Notch ✓" : ""
        return res + notch
    }

    private func featureToggle(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func screenRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .frame(width: 26)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
