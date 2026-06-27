import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var screens: [(id: CGDirectDisplayID, screen: NSScreen)] = Settings.availableScreens()
    @State private var gmailEmailInput = ""
    @State private var gmailPasswordInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                    .padding(.bottom, 4)

                sectionTitle("Görünüm")
                card {
                    screenRow
                    insetDivider
                    tappableRow("arrow.clockwise", .gray, "Ekranları yenile") {
                        screens = Settings.availableScreens()
                    }
                }

                sectionTitle("Etkileşim")
                card {
                    row("hand.tap.fill", .purple, "Açılma şekli") {
                        compactPicker($settings.interactionMode, InteractionMode.allCases) { $0.label }
                    }
                    insetDivider
                    row("timer", .teal, "Hover hassasiyeti") {
                        compactPicker($settings.hoverSensitivity, HoverSensitivity.allCases) { $0.label }
                    }
                    insetDivider
                    row("arrow.up.and.down.and.arrow.left.and.right", .orange, "Taşınabilir ada",
                        subtitle: "Üst notch şeridinden tutup sürükle") {
                        Toggle("", isOn: $settings.movableNotch)
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    insetDivider
                    tappableRow("arrow.counterclockwise", .gray, "Konumu sıfırla",
                                enabled: settings.notchOffset != .zero) {
                        settings.notchOffset = .zero
                        settings.movableNotch = settings.movableNotch  // republish → re-center
                    }
                }

                sectionTitle("Özellikler")
                card {
                    toggleRow("power", .green, "Açılışta başlat", $settings.launchAtLogin)
                    insetDivider
                    toggleRow("music.note", .pink, "Müzik göstergesi", $settings.showMusic)
                    insetDivider
                    toggleRow("message.fill", .green, "WhatsApp banner", $settings.showNotifications)
                    insetDivider
                    toggleRow("bell.badge.fill", .red, "Okunmamış rozeti", $settings.showUnreadCount)
                    insetDivider
                    row("battery.100", .green, "Pil göstergesi") {
                        compactPicker($settings.batteryMode, BatteryMode.allCases) { $0.label }
                    }
                }

                sectionTitle("Gmail")
                card { gmailContent }
            }
            .padding(18)
        }
        .frame(width: 420, height: 600)
        .background(softBackground)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = Settings.availableScreens()
        }
    }

    // MARK: - Gmail

    @ViewBuilder
    private var gmailContent: some View {
        if settings.gmailConnected {
            row("envelope.fill", .red, settings.gmailEmail ?? "", subtitle: "Bağlı · gelen okunmamışlar adada") {
                Button("Kaldır") { settings.disconnectGmail() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    badge("envelope.fill", .red)
                    Text("Gmail bağla").font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                TextField("ornek@gmail.com", text: $gmailEmailInput)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                SecureField("Uygulama şifresi (16 hane)", text: $gmailPasswordInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Link("Uygulama şifresi al ↗", destination: URL(string: "https://myaccount.google.com/apppasswords")!)
                        .font(.system(size: 10))
                    Spacer()
                    Button("Bağla") {
                        settings.connectGmail(email: gmailEmailInput, appPassword: gmailPasswordInput)
                        gmailPasswordInput = ""
                    }
                    .disabled(gmailEmailInput.isEmpty || gmailPasswordInput.isEmpty)
                }
                Text("Google hesabında 2 adımlı doğrulama açıkken Uygulama Şifresi oluştur; normal şifre çalışmaz.")
                    .font(.system(size: 9.5)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    // MARK: - Header / background

    private var header: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(.white))
                .shadow(color: .purple.opacity(0.35), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("HoscIsland").font(.system(size: 19, weight: .bold))
                Text("Dynamic Island ayarları")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var softBackground: some View {
        LinearGradient(
            colors: [Color(nsColor: .underPageBackgroundColor), Color(nsColor: .windowBackgroundColor)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 8)
            .padding(.top, 6)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 9, y: 3)
    }

    private var insetDivider: some View {
        Divider().padding(.leading, 52).opacity(0.5)
    }

    private func badge(_ systemName: String, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color.gradient)
            .frame(width: 28, height: 28)
            .overlay(Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white))
    }

    private func row<T: View>(_ icon: String, _ color: Color, _ title: String,
                              subtitle: String? = nil, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            badge(icon, color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func toggleRow(_ icon: String, _ color: Color, _ title: String, _ isOn: Binding<Bool>) -> some View {
        row(icon, color, title) {
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }

    private func tappableRow(_ icon: String, _ color: Color, _ title: String,
                             enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            row(icon, color, title) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private func compactPicker<V: Hashable>(_ selection: Binding<V>, _ options: [V],
                                            label: @escaping (V) -> String) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { Text(label($0)).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .tint(.secondary)
    }

    @ViewBuilder
    private var screenRow: some View {
        row("macbook", .blue, "Ekran") {
            Picker("", selection: $settings.selectedDisplayID) {
                Text("Otomatik").tag(CGDirectDisplayID?.none)
                ForEach(screens, id: \.id) { entry in
                    Text(screenLabel(entry)).tag(CGDirectDisplayID?.some(entry.id))
                }
            }
            .labelsHidden()
            .fixedSize()
            .tint(.secondary)
        }
    }

    private func screenLabel(_ entry: (id: CGDirectDisplayID, screen: NSScreen)) -> String {
        let notch = Settings.isNotched(entry.screen) ? " • Notch" : ""
        return "\(entry.screen.localizedName)\(notch)"
    }
}
