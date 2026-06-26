import AppKit

/// Translates the notch's logical sizes into on-screen rectangles.
///
/// All rects are in screen coordinates (bottom-left origin) and anchored to the
/// top-center of `screen`. The struct holds the per-screen measurements
/// (`notchWidth`, `topInset`) so the controller doesn't recompute geometry inline.
struct NotchGeometry {
    var notchWidth: CGFloat
    var topInset: CGFloat
    /// Custom drag offset from the default top-center anchor (+x = right, +y = up).
    /// Applied uniformly to the window frame and the hover zones so they stay in sync.
    var offset: CGSize = .zero

    /// Collapsed pill rect. Widens when there is compact content to show.
    func collapsedRect(on screen: NSScreen, isCompact: Bool) -> NSRect {
        let f = screen.frame
        let w = NotchMetrics.collapsedWidth(notchWidth: notchWidth, hasMusic: isCompact)
        let h = NotchMetrics.collapsedHeight
        return NSRect(x: f.midX - w / 2 + offset.width, y: f.maxY - h + offset.height, width: w, height: h)
    }

    /// Expanded island rect, sized to the *visible* height so the hover zone
    /// doesn't extend into the invisible part of the (taller) window — otherwise
    /// the island stays stuck open while the cursor sits over empty window area.
    func expandedRect(on screen: NSScreen, hasMusic: Bool, hasShelf: Bool) -> NSRect {
        let f = screen.frame
        let w = NotchMetrics.expandedWidth
        let h = NotchMetrics.expandedVisibleHeight(
            topInset: topInset, hasMusic: hasMusic, hasShelf: hasShelf
        )
        return NSRect(x: f.midX - w / 2 + offset.width, y: f.maxY - h + offset.height, width: w, height: h)
    }

    /// The window is always the full (max) size, top-anchored and centered.
    func windowFrame(on screen: NSScreen) -> NSRect {
        let width = NotchMetrics.expandedWidth
        let height = NotchMetrics.windowHeight
        let f = screen.frame
        return NSRect(x: f.midX - width / 2 + offset.width, y: f.maxY - height + offset.height, width: width, height: height)
    }

    // MARK: - Detection

    static func detectNotchWidth(for screen: NSScreen) -> CGFloat {
        // On notched Macs the safe-area top inset is > 0 and the auxiliary
        // top-left/right areas describe the regions either side of the notch.
        if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
            let left = screen.auxiliaryTopLeftArea?.maxX ?? 0
            let right = screen.auxiliaryTopRightArea?.minX ?? screen.frame.width
            let width = right - left
            if width > 60 && width < 400 { return width }
        }
        // Fallback width for Macs without a physical notch.
        return 190
    }

    /// Vertical space taken by the camera/notch (the menu-bar height on notched
    /// Macs). Used to keep the expanded content clear of the camera.
    static func detectTopInset(for screen: NSScreen) -> CGFloat {
        let inset = screen.safeAreaInsets.top
        return inset > 0 ? inset : 12  // non-notched Macs need only a small margin
    }
}
