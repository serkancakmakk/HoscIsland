import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var screens: [(id: CGDirectDisplayID, screen: NSScreen)] = Settings.availableScreens()
    @State private var gmailEmailInput = ""
    @State private var gmailPasswordInput = ""

    var body: some View {
        VStack(spacing: 0) {
            header.padding([.horizontal, .top], 18).padding(.bottom, 10)
            TabView {
                tab(appearanceTab)
                    .tabItem { Label(L("Genel", "General"), systemImage: "slider.horizontal.3") }
                tab(interactionTab)
                    .tabItem { Label(L("Etkileşim", "Interaction"), systemImage: "hand.tap") }
                tab(featuresTab)
                    .tabItem { Label(L("Özellikler", "Features"), systemImage: "square.grid.2x2") }
                tab(connectionsTab)
                    .tabItem { Label(L("Bağlantılar", "Connections"), systemImage: "link") }
            }
            .padding([.horizontal, .bottom], 12)
        }
        .frame(width: 420, height: 600)
        .background(softBackground)
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = Settings.availableScreens()
        }
    }

    /// Wrap a tab's content in a scroll view with consistent padding.
    private func tab<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView { VStack(alignment: .leading, spacing: 10) { content() }.padding(14) }
    }

    // MARK: - Tabs

    @ViewBuilder
    private func appearanceTab() -> some View {
        sectionTitle(L("Görünüm", "Appearance"))
        card {
            screenRow
            insetDivider
            row("character.bubble", .blue, L("Dil", "Language")) {
                compactPicker($settings.language, AppLanguage.allCases) { $0.label }
            }
            insetDivider
            row("rectangle.roundedtop", .indigo, L("Köşe yuvarlaklığı", "Corner rounding")) {
                compactPicker($settings.cornerStyle, CornerStyle.allCases) { $0.label }
            }
            insetDivider
            tappableRow("arrow.clockwise", .gray, L("Ekranları yenile", "Refresh screens")) {
                screens = Settings.availableScreens()
            }
        }
    }

    @ViewBuilder
    private func interactionTab() -> some View {
        sectionTitle(L("Etkileşim", "Interaction"))
        card {
            row("hand.tap.fill", .purple, L("Açılma şekli", "Open mode")) {
                compactPicker($settings.interactionMode, InteractionMode.allCases) { $0.label }
            }
            insetDivider
            row("timer", .teal, L("Hover hassasiyeti", "Hover sensitivity")) {
                compactPicker($settings.hoverSensitivity, HoverSensitivity.allCases) { $0.label }
            }
            insetDivider
            row("arrow.up.and.down.and.arrow.left.and.right", .orange, L("Taşınabilir ada", "Movable island"),
                subtitle: L("Üst notch şeridinden tutup sürükle", "Grab the top notch strip to drag")) {
                Toggle("", isOn: $settings.movableNotch)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            insetDivider
            tappableRow("arrow.counterclockwise", .gray, L("Konumu sıfırla", "Reset position"),
                        enabled: settings.notchOffset != .zero) {
                settings.notchOffset = .zero
                settings.movableNotch = settings.movableNotch  // republish → re-center
            }
        }
    }

    @ViewBuilder
    private func featuresTab() -> some View {
        sectionTitle(L("Özellikler", "Features"))
        card {
            toggleRow("power", .green, L("Açılışta başlat", "Launch at login"), $settings.launchAtLogin)
            insetDivider
            toggleRow("music.note", .pink, L("Müzik göstergesi", "Music indicator"), $settings.showMusic)
            insetDivider
            toggleRow("message.fill", .green, L("Bildirim banner'ı", "Notification banner"), $settings.showNotifications)
            insetDivider
            toggleRow("bell.badge.fill", .red, L("Okunmamış rozeti", "Unread badge"), $settings.showUnreadCount)
            insetDivider
            row("battery.100", .green, L("Pil göstergesi", "Battery indicator")) {
                compactPicker($settings.batteryMode, BatteryMode.allCases) { $0.label }
            }
        }
    }

    @ViewBuilder
    private func connectionsTab() -> some View {
        sectionTitle(L("Takvim", "Calendar"))
        card { calendarContent }

        sectionTitle("Gmail")
        card { gmailContent }
    }

    // MARK: - Gmail

    @ViewBuilder
    private var gmailContent: some View {
        if settings.gmailConnected {
            row("envelope.fill", .red, settings.gmailEmail ?? "", subtitle: L("Bağlı · gelen okunmamışlar adada", "Connected · unread inbox on the island")) {
                Button(L("Kaldır", "Remove")) { settings.disconnectGmail() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    badge("envelope.fill", .red)
                    Text(L("Gmail bağla", "Connect Gmail")).font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                TextField("ornek@gmail.com", text: $gmailEmailInput)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                SecureField(L("Uygulama şifresi (16 hane)", "App password (16 chars)"), text: $gmailPasswordInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Link(L("Uygulama şifresi al ↗", "Get app password ↗"), destination: URL(string: "https://myaccount.google.com/apppasswords")!)
                        .font(.system(size: 10))
                    Spacer()
                    Button(L("Bağla", "Connect")) {
                        settings.connectGmail(email: gmailEmailInput, appPassword: gmailPasswordInput)
                        gmailPasswordInput = ""
                    }
                    .disabled(gmailEmailInput.isEmpty || gmailPasswordInput.isEmpty)
                }
                Text(L("Google hesabında 2 adımlı doğrulama açıkken Uygulama Şifresi oluştur; normal şifre çalışmaz.",
                       "With 2-step verification on, create an App Password in your Google account; your normal password won't work."))
                    .font(.system(size: 9.5)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                badge("calendar", .orange)
                Text(L("Takvim (iCal URL)", "Calendar (iCal URL)")).font(.system(size: 13, weight: .medium))
                Spacer()
            }
            TextField("https://…/basic.ics", text: Binding(
                get: { settings.calendarURL ?? "" },
                set: { settings.calendarURL = $0.trimmingCharacters(in: .whitespaces) }
            ))
            .textFieldStyle(.roundedBorder)
            Text(L("Google/iCloud/Outlook'ta takvimin **gizli iCal adresini** yapıştır; boştaki kartta sıradaki etkinlik gösterilir.",
                   "Paste your calendar's **private iCal address** from Google/iCloud/Outlook; the next event shows on the idle card."))
                .font(.system(size: 9.5)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
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
                Text(L("Dynamic Island ayarları", "Dynamic Island settings"))
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
        row("macbook", .blue, L("Ekran", "Display")) {
            Picker("", selection: $settings.selectedDisplayID) {
                Text(L("Otomatik", "Automatic")).tag(CGDirectDisplayID?.none)
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
