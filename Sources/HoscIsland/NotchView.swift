import SwiftUI
import UniformTypeIdentifiers

/// Sizes for the notch overlay in its two states.
enum NotchMetrics {
    static let collapsedHeight: CGFloat = 32
    static let expandedHeight: CGFloat = 250        // music-only expanded
    static let shelfRowHeight: CGFloat = 70
    static let clipRowHeight: CGFloat = 40
    static let gmailRowHeight: CGFloat = 78
    static let windowsRowHeight: CGFloat = 64
    static let notifRowHeight: CGFloat = 88
    static let devicesRowHeight: CGFloat = 56
    static let downloadsRowHeight: CGFloat = 70
    /// Fixed-height scrollable drawer holding the secondary sections.
    static let drawerHeight: CGFloat = 172
    static let expandedWidth: CGFloat = 420
    /// Fixed panel height — large enough for the tallest layout (music + drawer).
    static var windowHeight: CGFloat { expandedHeight + drawerHeight }
    static let cornerRadius: CGFloat = 14

    /// Actual visible height of the expanded island for the given content — used
    /// for both the view frame and the hover zone so they always match (otherwise
    /// the island stays "stuck" open over invisible window area).
    /// Body (music or idle) + the fixed scrollable drawer below it.
    static func bodyHeight(topInset: CGFloat, hasMusic: Bool) -> CGFloat {
        hasMusic ? expandedHeight : topInset + 172  // idle = calendar + weather + Pomodoro
    }

    static func expandedVisibleHeight(topInset: CGFloat, hasMusic: Bool) -> CGFloat {
        bodyHeight(topInset: topInset, hasMusic: hasMusic) + drawerHeight
    }

    /// Extra width added to each side of the notch when music is playing, so the
    /// collapsed pill can show album art (left) and an equalizer (right). Wide
    /// enough that the content sits clear of the physical camera housing.
    static let compactWing: CGFloat = 54

    /// Size of the incoming-message banner.
    static let bannerWidth: CGFloat = 390
    /// Size of the screenshot preview.
    static let screenshotWidth: CGFloat = 400
    /// Width of the brightness/volume HUD pill.
    static let hudWidth: CGFloat = 220

    static func collapsedWidth(notchWidth: CGFloat, hasMusic: Bool) -> CGFloat {
        hasMusic ? notchWidth + compactWing * 2 : notchWidth
    }
}

/// Animated equalizer bars (the moving "music rhythm" icon). Bars bounce while
/// playing and rest flat when paused.
struct EqualizerView: View {
    var isPlaying: Bool
    var color: Color = .white
    private let barCount = 4
    private let phases: [Double] = [0.0, 1.1, 2.2, 0.6]

    var body: some View {
        if isPlaying {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                bars((0..<barCount).map { barHeight(sin(t * 6 + phases[$0])) })
            }
        } else {
            bars(Array(repeating: 3, count: barCount))
        }
    }

    private func bars(_ heights: [CGFloat]) -> some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule().fill(color).frame(width: 2.6, height: heights[i])
            }
        }
        .frame(height: 16)
    }

    private func barHeight(_ s: Double) -> CGFloat {
        3 + CGFloat((s + 1) / 2) * 11  // 3...14
    }
}

/// Notch-shaped rectangle: top edge flush with the screen bezel (square top
/// corners) and rounded bottom corners — matching the camera housing area.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Draggable playback progress bar with elapsed / total time labels.
struct SeekBar: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragFraction: Double?

    var body: some View {
        let frac = dragFraction ?? (duration > 0 ? min(max(position / duration, 0), 1) : 0)
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(Color.white).frame(width: max(0, w * frac))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in dragFraction = min(max(v.location.x / w, 0), 1) }
                        .onEnded { v in
                            let f = min(max(v.location.x / w, 0), 1)
                            onSeek(f * duration)
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 12)
            HStack {
                Text(Self.time(frac * duration))
                Spacer()
                Text(Self.time(duration))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Draggable system-volume slider with speaker icons.
struct VolumeBar: View {
    let volume: Double
    let onChange: (Double) -> Void
    @State private var dragValue: Double?

    var body: some View {
        let v = dragValue ?? volume
        HStack(spacing: 8) {
            Image(systemName: v < 0.01 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).frame(width: 14)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: max(0, w * v))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in dragValue = min(max(g.location.x / w, 0), 1) }
                        .onEnded { g in
                            let f = min(max(g.location.x / w, 0), 1)
                            onChange(f); dragValue = nil
                        }
                )
            }
            .frame(height: 12)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).frame(width: 14)
        }
    }
}

/// A small drawn battery that fills to `percentage`, with a charging bolt.
struct BatteryView: View {
    let percentage: Int
    let isCharging: Bool

    var body: some View {
        let frac = max(0.06, min(Double(percentage) / 100.0, 1))
        let fill: Color = isCharging ? .green : (percentage <= 20 ? .red : .white)
        HStack(spacing: 1.5) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1.2)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill)
                        .frame(width: max(2, (geo.size.width - 3) * frac))
                        .padding(1.8)
                }
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.black.opacity(0.75))
                }
            }
            .frame(width: 26, height: 13)
            .animation(.easeOut(duration: 0.5), value: percentage)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.5)).frame(width: 1.8, height: 5)
        }
    }
}

struct NotchView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var pomodoro: PomodoroTimer
    @ObservedObject var clipboard: ClipboardManager
    @ObservedObject var gmail: GmailManager
    @ObservedObject var weather: WeatherManager
    @ObservedObject var windows: WindowsManager
    @ObservedObject var lyrics: LyricsManager
    @ObservedObject var deviceBattery: DeviceBatteryManager
    @ObservedObject var downloads: DownloadsManager
    @ObservedObject var calendar: CalendarManager
    @ObservedObject private var settings = Settings.shared
    @EnvironmentObject var state: NotchState
    let notchWidth: CGFloat
    /// Height of the physical camera/notch area to keep clear at the top.
    let topInset: CGFloat
    @Binding var isExpanded: Bool

    @State private var dropTargeted = false
    @State private var editingPomodoro = false
    @State private var pomodoroInput = ""
    @FocusState private var pomodoroFieldFocused: Bool
    @State private var hostWindow: NSWindow?

    var body: some View {
        ZStack {
            // The black "island" body. Flat top (on the bezel), rounded bottom —
            // exactly like the camera/notch housing.
            NotchShape(bottomRadius: (isExpanded || showBanner || dropTargeted) ? settings.cornerStyle.expandedRadius : 10)
                .fill(Color.black)
                .overlay(
                    NotchShape(bottomRadius: settings.cornerStyle.expandedRadius)
                        .stroke(Color.accentColor, lineWidth: dropTargeted ? 2 : 0)
                )

            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.1)),
                        removal: .opacity.animation(.easeIn(duration: 0.12))
                    ))
            } else if let hud = state.hud {
                hudContent(hud)
                    .transition(.opacity.animation(.easeOut(duration: 0.16)))
            } else if let shot = state.screenshot {
                screenshotContent(shot)
                    .transition(.opacity.animation(.easeOut(duration: 0.22).delay(0.08)))
            } else if let notif = state.notification {
                bannerContent(notif)
                    .transition(.opacity.animation(.easeOut(duration: 0.22).delay(0.08)))
            } else {
                collapsedContent
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .animation(.spring(response: 0.5, dampingFraction: 0.86, blendDuration: 0.25), value: isExpanded)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCompact)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: state.notification)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.batteryFlash)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: state.screenshot)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: state.hud)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dropTargeted)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.hovering)
        .background(WindowAccessor { hostWindow = $0 })
        .onChange(of: isExpanded) { expanded in if !expanded { endPomodoroEdit() } }
        .onChange(of: editingPomodoro) { editing in
            (hostWindow as? KeyablePanel)?.keyEligible = editing
            if editing { hostWindow?.makeKey() }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        .onChange(of: dropTargeted) { _, targeted in
            // Expand into a drop zone while a drag hovers the notch.
            if targeted { isExpanded = true }
        }
        .onChange(of: nowPlaying.track?.title) { _, _ in refreshLyrics() }
        .onAppear { refreshLyrics() }
        // Click-to-open is handled at the AppKit layer (mouseDown) for reliability
        // in the non-activating panel.
    }

    /// In click mode, the collapsed pill grows a touch on hover as an affordance.
    private var nudge: Bool {
        settings.interactionMode == .click && state.hovering && !isExpanded && !showScreenshot && !showBanner
    }

    private func refreshLyrics() {
        guard let t = nowPlaying.track else { return }
        lyrics.update(title: t.title, artist: t.artist, album: t.album, duration: t.duration)
    }

    private var hasMusic: Bool { settings.showMusic && nowPlaying.track != nil }
    private var hasShelf: Bool { !shelf.items.isEmpty }
    private var showScreenshot: Bool { state.screenshot != nil && !isExpanded }
    private var showBanner: Bool { settings.showNotifications && state.notification != nil && !isExpanded && !showScreenshot }
    private var showUnread: Bool { settings.showUnreadCount && unreadCount > 0 }
    /// Live unread = notifications currently in Notification Center (drops as the
    /// user reads them). The watcher reads the DB fresh so this no longer stalls.
    private var unreadCount: Int { state.unreadCount }
    private var alwaysBattery: Bool { settings.batteryMode == .always }
    /// Pill widens for music, a notification, an unread badge, a battery indicator, or a shelf.
    private var isCompact: Bool {
        hasMusic || state.notification != nil || showUnread || state.batteryFlash != nil || alwaysBattery || hasShelf
    }

    /// Pick one or more apps from /Applications and add them to the shelf.
    /// (Files are added by dragging; this button makes adding apps easy since
    /// they live in /Applications rather than somewhere you'd drag from.)
    private func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Ekle"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            shelf.add(panel.urls)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            found = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { shelf.add([url]) }
            }
        }
        return found
    }

    private var bannerHeight: CGFloat { topInset + 60 }
    private var screenshotHeight: CGFloat { topInset + 78 }

    private var showHUD: Bool { state.hud != nil && !isExpanded }

    private var currentWidth: CGFloat {
        if isExpanded { return NotchMetrics.expandedWidth }
        if showHUD { return NotchMetrics.hudWidth }
        if showScreenshot { return NotchMetrics.screenshotWidth }
        if showBanner { return NotchMetrics.bannerWidth }
        return NotchMetrics.collapsedWidth(notchWidth: notchWidth, hasMusic: isCompact) + (nudge ? 10 : 0)
    }

    private var currentHeight: CGFloat {
        if isExpanded {
            return NotchMetrics.expandedVisibleHeight(topInset: topInset, hasMusic: hasMusic)
        }
        if showHUD { return topInset + 26 }
        if showScreenshot { return screenshotHeight }
        if showBanner { return bannerHeight }
        return NotchMetrics.collapsedHeight + (nudge ? 4 : 0)
    }

    // MARK: - Brightness / volume HUD

    private func hudContent(_ hud: HUDInfo) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(spacing: 10) {
                Image(systemName: hudIcon(hud))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 16)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white)
                            .frame(width: max(3, geo.size.width * CGFloat(hud.level)))
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 5)
        }
    }

    private func hudIcon(_ hud: HUDInfo) -> String {
        switch hud.kind {
        case .brightness: return "sun.max.fill"
        case .volume: return hud.level <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        }
    }

    // MARK: - Screenshot preview

    private func screenshotContent(_ shot: ScreenshotPreview) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(spacing: 12) {
                // Thumbnail — click to open.
                Button { ScreenshotActions.open(shot.url) } label: {
                    Group {
                        if let img = shot.image {
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        } else {
                            ZStack { Color.white.opacity(0.08); Image(systemName: "photo") }
                        }
                    }
                    .frame(width: 96, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Ekran görüntüsü", "Screenshot"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 14) {
                        shotAction("doc.on.doc", L("Kopyala", "Copy")) { ScreenshotActions.copy(shot.url); dismissScreenshot() }
                        shotAction("folder", "Finder") { ScreenshotActions.reveal(shot.url); dismissScreenshot() }
                        shotAction("trash", L("Sil", "Delete"), tint: .red) { ScreenshotActions.delete(shot.url); dismissScreenshot() }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 12)
    }

    private func shotAction(_ icon: String, _ label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium))
                Text(label).font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(tint.opacity(0.9))
            .frame(width: 44, height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismissScreenshot() { state.screenshot = nil }

    // MARK: - Incoming-message banner

    private func bannerContent(_ notif: NotchNotification) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)
            HStack(spacing: 11) {
                appIcon(notif.icon, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(notif.sender.isEmpty ? "Bildirim" : notif.sender)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !notif.message.isEmpty {
                        Text(notif.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if showUnread { countBadge(size: 13) }
            }
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 11)
    }

    // MARK: - Collapsed (compact pill)

    @ViewBuilder
    private var collapsedContent: some View {
        if let battery = state.batteryFlash {
            // Transient charge flash (highest priority).
            batteryPill(percentage: battery.percentage, charging: battery.isCharging)
        } else if hasMusic, let track = nowPlaying.track {
            HStack(spacing: 0) {
                compactArtwork
                    .overlay(alignment: .topTrailing) { if showUnread { cornerBadge } }
                Spacer(minLength: notchWidth - 12)
                // When battery is pinned "always", show it on the right instead of
                // the equalizer; otherwise the music equalizer.
                if alwaysBattery {
                    miniBattery
                } else {
                    EqualizerView(isPlaying: track.isPlaying, color: track.isPlaying ? .green : .gray)
                        .frame(width: 24)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(trackSwipe)
        } else if alwaysBattery {
            batteryPill(percentage: state.batteryPercentage, charging: state.batteryPlugged)
        } else if hasShelf {
            HStack(spacing: 0) {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22)
                Spacer(minLength: notchWidth - 12)
                Text("\(shelf.items.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        } else if showUnread {
            HStack(spacing: 0) {
                appIcon(state.notificationHistory.first?.icon ?? state.whatsAppIcon, size: 22)
                    .overlay(alignment: .topTrailing) { cornerBadge }
                Spacer(minLength: notchWidth - 12)
                countBadge(size: 11)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
    }

    /// Full-width compact battery: glyph on the left, percentage on the right.
    private func batteryPill(percentage: Int, charging: Bool) -> some View {
        HStack(spacing: 0) {
            BatteryView(percentage: percentage, isCharging: charging)
            Spacer(minLength: notchWidth - 12)
            Text("%\(percentage)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(charging ? Color.green : .white)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    /// Compact battery glyph for the right wing while music plays (fill conveys
    /// the level; full percentage shows in the music-free / flash states).
    private var miniBattery: some View {
        BatteryView(percentage: state.batteryPercentage, isCharging: state.batteryPlugged)
            .fixedSize()
    }

    private func appIcon(_ image: NSImage?, size: CGFloat) -> some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "bell.fill").foregroundStyle(.green)
            }
        }
        .frame(width: size, height: size)
    }

    /// Rounded count badge (e.g. "3", "9+").
    private func countBadge(size: CGFloat) -> some View {
        Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.55)
            .padding(.vertical, size * 0.2)
            .background(Capsule().fill(Color.green))
    }

    /// Small badge overlaid on an icon's corner.
    private var cornerBadge: some View {
        Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .frame(minWidth: 13, minHeight: 13)
            .background(Capsule().fill(Color.red))
            .offset(x: 5, y: -5)
    }

    private var compactArtwork: some View {
        Group {
            if let art = nowPlaying.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note").font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Reserve the top strip occupied by the physical camera/notch.
            Color.clear.frame(height: topInset)

            Group {
                if settings.showMusic, let track = nowPlaying.track {
                    musicSection(track)
                } else {
                    idleContent
                }
            }
            .frame(height: NotchMetrics.bodyHeight(topInset: topInset, hasMusic: hasMusic) - topInset)

            drawer
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    /// Secondary sections (windows / Gmail / clipboard / shelf) in one fixed-height
    /// scroll area, so the card stays compact no matter how much content there is.
    private var drawer: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                if !windows.windows.isEmpty { windowsStrip }
                if !deviceBattery.devices.isEmpty { devicesStrip }
                if !downloads.items.isEmpty { downloadsStrip }
                if !state.notificationHistory.isEmpty { notificationsStrip }
                if gmail.connected, !gmail.messages.isEmpty { gmailStrip }
                if !clipboard.items.isEmpty { clipboardStrip }
                shelfStrip   // always present (its + button adds apps/files)
            }
            .padding(.top, 6)
        }
        .frame(height: NotchMetrics.drawerHeight - 14)
    }

    private var windowsStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L("Pencereler", "Windows"), systemImage: "macwindow.on.rectangle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(windows.windows) { win in
                        Button { windows.activate(win) } label: {
                            VStack(spacing: 2) {
                                if let icon = windows.icon(win) {
                                    Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: "macwindow").font(.system(size: 22))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Text(win.title.isEmpty ? win.app : win.title)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .frame(width: 56)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(win.title.isEmpty ? win.app : "\(win.app) — \(win.title)")
                        .contextMenu {
                            Button(L("Öne getir", "Bring to front")) { windows.activate(win) }
                            Button(L("Pencereyi kapat", "Close window"), role: .destructive) {
                                windows.close(win)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: NotchMetrics.windowsRowHeight - 6)
    }

    private var clipboardStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(L("Pano", "Clipboard"), systemImage: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { clipboard.clear() } label: {
                    Text(L("Temizle", "Clear")).font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(clipboard.items, id: \.self) { item in
                        Button { clipboard.copy(item) } label: {
                            Text(item.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .frame(maxWidth: 130, alignment: .leading)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: NotchMetrics.clipRowHeight - 6)
    }

    private var gmailStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label("Gmail", systemImage: "envelope.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                if gmail.unread > 0 {
                    Text("\(gmail.unread)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                }
                Spacer()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(gmail.messages.prefix(8)) { msg in
                        Button { openGmail(msg) } label: {
                            HStack(spacing: 7) {
                                Circle().fill(Color.blue).frame(width: 5, height: 5)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(msg.author)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                                    Text(msg.title)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: NotchMetrics.gmailRowHeight - 6)
    }

    private func openGmail(_ message: GmailMessage) {
        let urlString = message.link.isEmpty ? "https://mail.google.com/mail/u/0/#inbox" : message.link
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }

    /// Most recent files from ~/Downloads — click to open, drag out, reveal.
    private var downloadsStrip: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(L("İndirilenler", "Downloads"), systemImage: "arrow.down.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(downloads.items, id: \.self) { url in
                        VStack(spacing: 3) {
                            Image(nsImage: ShelfStore.icon(for: url))
                                .resizable().frame(width: 30, height: 30)
                            Text(url.lastPathComponent)
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .frame(width: 54)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .onTapGesture { NSWorkspace.shared.open(url) }
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        .contextMenu { fileShareMenu(url) }
                        .help(url.lastPathComponent)
                    }
                }
            }
        }
        .frame(height: NotchMetrics.downloadsRowHeight - 14)
    }

    /// Share/quick actions for a file (used by the downloads strip's context menu).
    @ViewBuilder
    private func fileShareMenu(_ url: URL) -> some View {
        Button("AirDrop") { share(url, .sendViaAirDrop) }
        Button("Mail") { share(url, .composeEmail) }
        Button(L("Mesajlar", "Messages")) { share(url, .composeMessage) }
        Divider()
        Button(L("Kopyala", "Copy")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        }
        Button(L("Finder'da Göster", "Reveal in Finder")) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func share(_ url: URL, _ name: NSSharingService.Name) {
        NSSharingService(named: name)?.perform(withItems: [url])
    }

    /// Connected accessory batteries (AirPods / Magic Mouse / keyboard …).
    private var devicesStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L("Cihazlar", "Devices"), systemImage: "battery.100.bolt")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(deviceBattery.devices) { dev in
                        HStack(spacing: 6) {
                            Image(systemName: dev.symbol)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(dev.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                                Text("\(dev.percentage)%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(dev.percentage <= 20 ? .red : .white.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }
                }
            }
        }
        .frame(height: NotchMetrics.devicesRowHeight - 6)
    }

    /// Recent notifications (newest first), with the sending app's icon + a "Temizle".
    private var notificationsStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(L("Bildirimler", "Notifications"), systemImage: "bell.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { state.notificationHistory.removeAll() } label: {
                    Text(L("Temizle", "Clear")).font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(state.notificationHistory) { item in
                        HStack(spacing: 7) {
                            if let icon = item.icon {
                                Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                            } else {
                                Image(systemName: "app.fill").font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.sender)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                                if !item.message.isEmpty {
                                    Text(item.message)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(item.date, style: .relative)
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                    }
                }
            }
        }
        .frame(height: NotchMetrics.notifRowHeight - 6)
    }

    private func musicSection(_ track: NowPlayingManager.Track) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { nowPlaying.activateApp() } label: { artworkView }
                    .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white).lineLimit(1)
                    Text(track.artist).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    Text(track.album).font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if let lyric = lyrics.line(at: track.position) {
                Spacer(minLength: 6)
                Text(lyric)
                    .font(.system(size: 11, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
            Spacer(minLength: 8)
            if track.duration > 0 {
                SeekBar(position: track.position, duration: track.duration) { nowPlaying.seek(to: $0) }
            }
            Spacer(minLength: 8)
            controls(isPlaying: track.isPlaying)
            Spacer(minLength: 10)
            VolumeBar(volume: nowPlaying.volume) { nowPlaying.setVolume($0) }
        }
        .contentShape(Rectangle())
        .gesture(trackSwipe)
    }

    /// Horizontal swipe to change track: left → next, right → previous.
    private var trackSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > 44,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < 0 { nowPlaying.next() }
                else { nowPlaying.previous() }
            }
    }

    // MARK: - Shelf

    private var shelfStrip: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(L("Raf", "Shelf"), systemImage: "tray.full")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { addApp() } label: {
                    Label(L("Uygulama", "App"), systemImage: "plus.app")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.6))
                Button { shelf.clear() } label: {
                    Text(L("Temizle", "Clear")).font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
            }
            if shelf.items.isEmpty {
                Text(L("Dosya sürükle ya da ＋ ile uygulama ekle", "Drop a file or add an app with ＋"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shelf.items, id: \.self) { url in
                            shelfChip(url)
                        }
                    }
                }
            }
        }
        .frame(height: NotchMetrics.shelfRowHeight - 14)
    }

    private func shelfChip(_ url: URL) -> some View {
        VStack(spacing: 3) {
            Image(nsImage: ShelfStore.icon(for: url))
                .resizable().frame(width: 30, height: 30)
            Text(url.lastPathComponent)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(width: 54)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
        .overlay(alignment: .topTrailing) {
            Button { shelf.remove(url) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .onTapGesture { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }

    private var artworkView: some View {
        Group {
            if let art = nowPlaying.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    private func controls(isPlaying: Bool) -> some View {
        let shuffle = nowPlaying.track?.shuffle ?? false
        let repeatOn = nowPlaying.track?.repeatOn ?? false
        return HStack(spacing: 22) {
            toggleButton("shuffle", active: shuffle) { nowPlaying.toggleShuffle() }
            controlButton("backward.fill", size: 16) { nowPlaying.previous() }
            controlButton(isPlaying ? "pause.fill" : "play.fill", size: 22) { nowPlaying.playPause() }
            controlButton("forward.fill", size: 16) { nowPlaying.next() }
            toggleButton("repeat", active: repeatOn) { nowPlaying.toggleRepeat() }
        }
        .frame(maxWidth: .infinity)
    }

    /// A control that lights up green when its mode is active (shuffle / repeat).
    private func toggleButton(_ name: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color.green : Color.white.opacity(0.55))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ name: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Idle (no music) expanded card shows weather + a Pomodoro timer.
    private var idleContent: some View {
        VStack(spacing: 8) {
            if let ev = calendar.nextEvent {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(ev.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Text("· \(calendarWhen(ev))")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            if let w = weather.weather {
                HStack(spacing: 8) {
                    Image(systemName: weatherSymbol(w.code))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(w.city) · \(w.tempC)°")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("\(L("Hissedilen", "Feels")) \(w.feelsLike)° · ↑\(w.hi)° ↓\(w.lo)°")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            Label("Pomodoro", systemImage: "timer")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            if editingPomodoro {
                HStack(spacing: 5) {
                    TextField("", text: $pomodoroInput)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 70)
                        .focused($pomodoroFieldFocused)
                        .onSubmit { applyPomodoroInput() }
                    Text(L("dk", "min"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                Text(pomodoro.label)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .onTapGesture {
                        pomodoroInput = "\(pomodoro.workMinutes)"
                        editingPomodoro = true
                        pomodoroFieldFocused = true
                    }
                    .help(L("Süreyi yaz (tıkla)", "Type a length (click)"))
            }
            HStack(spacing: 18) {
                controlButton(pomodoro.running ? "pause.fill" : "play.fill", size: 20) {
                    pomodoro.toggle()
                }
                controlButton("arrow.counterclockwise", size: 16) { pomodoro.reset() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Apply a typed Pomodoro length (minutes) and leave edit mode.
    private func applyPomodoroInput() {
        if let m = Int(pomodoroInput.trimmingCharacters(in: .whitespaces)) {
            pomodoro.setMinutes(m)
        }
        endPomodoroEdit()
    }

    private func endPomodoroEdit() {
        editingPomodoro = false
        pomodoroFieldFocused = false
    }

    /// "14:30" today, "Yarın 09:00", or a short day+time for the next event.
    private func calendarWhen(_ ev: CalEvent) -> String {
        let cal = Foundation.Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        if ev.allDay {
            if cal.isDateInToday(ev.start) { return "Bugün" }
            if cal.isDateInTomorrow(ev.start) { return "Yarın" }
            f.dateFormat = "d MMM"
            return f.string(from: ev.start)
        }
        f.dateFormat = "HH:mm"
        let time = f.string(from: ev.start)
        if cal.isDateInToday(ev.start) { return time }
        if cal.isDateInTomorrow(ev.start) { return "Yarın \(time)" }
        f.dateFormat = "d MMM HH:mm"
        return f.string(from: ev.start)
    }
}
