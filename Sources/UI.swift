//  UI.swift
//  AppKit 纯代码界面（不依赖 Xcode 工程 / xib）：
//  顶部设备信息 + 实时指标条 + 左侧分类导航 + 右侧卡片式明细 + 底部状态栏

import AppKit

// MARK: - 配色（自动适配浅色 / 深色外观）

enum Theme {
    static let card = NSColor(name: "HICard") { a in
        a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.165, alpha: 1) : NSColor.white
    }
    static let sidebar = NSColor(name: "HISidebar") { a in
        a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.13, alpha: 1) : NSColor(calibratedRed: 0.965, green: 0.969, blue: 0.980, alpha: 1)
    }
    static let border = NSColor(name: "HIBorder") { a in
        a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.28, alpha: 1) : NSColor(calibratedRed: 0.89, green: 0.90, blue: 0.92, alpha: 1)
    }
    static let track = NSColor(name: "HITrack") { a in
        a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.30, alpha: 1) : NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.93, alpha: 1)
    }
    static let accentSoft = NSColor(name: "HIAccentSoft") { a in
        a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor.controlAccentColor.withAlphaComponent(0.26)
            : NSColor.controlAccentColor.withAlphaComponent(0.13)
    }
    static let palette: [NSColor] = [
        NSColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1),   // CPU 蓝
        NSColor(srgbRed: 0.42, green: 0.35, blue: 0.90, alpha: 1),   // 内存 紫
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1),   // 磁盘 橙
        NSColor(srgbRed: 0.10, green: 0.74, blue: 0.42, alpha: 1),   // 电池 绿
    ]
}

func hiSymbol(_ name: String) -> NSImage? {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)
}

/// 固定点阵尺寸的 SF Symbol 图标：避免 NSButton / NSImageView 按固有尺寸把它放大到数十像素
func hiIcon(_ name: String, side: CGFloat = 22) -> NSImage? {
    guard let img = hiSymbol(name) else { return nil }
    img.size = NSSize(width: side, height: side)
    img.isTemplate = true
    return img
}

extension NSView {
    var allSubviews: [NSView] {
        var out: [NSView] = []
        for s in subviews {
            out.append(s)
            out.append(contentsOf: s.allSubviews)
        }
        return out
    }
}

class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

// MARK: - 进度条

final class BarView: NSView {
    var ratio: Double = 0 { didSet { needsDisplay = true } }
    var tint: NSColor = .controlAccentColor { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let h = bounds.height
        let bg = NSBezierPath(roundedRect: bounds, xRadius: h / 2, yRadius: h / 2)
        Theme.track.setFill()
        bg.fill()
        let w = bounds.width * CGFloat(max(0, min(1, ratio)))
        guard w > 0.5 else { return }
        let fg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h), xRadius: h / 2, yRadius: h / 2)
        tint.setFill()
        fg.fill()
    }
}

// MARK: - 单个实时指标卡

final class VitalCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let bar = BarView()
    private let spark = SparklineView()

    init(vital: HWVital, index: Int) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = Theme.card.cgColor
        layer?.borderColor = Theme.border.cgColor
        layer?.borderWidth = 1

        // 趋势线是最底层背景，不参与文字布局，因此不会挤占或裁切任何文本
        spark.tint = Theme.palette[index % Theme.palette.count]
        spark.translatesAutoresizingMaskIntoConstraints = false
        spark.alphaValue = 0.30
        addSubview(spark)
        NSLayoutConstraint.activate([
            spark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            spark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            spark.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            spark.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])

        titleLabel.stringValue = vital.title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        valueLabel.stringValue = vital.value
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 21, weight: .semibold)
        valueLabel.textColor = .labelColor

        detailLabel.stringValue = vital.detail
        detailLabel.font = .systemFont(ofSize: 10.5)
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail

        bar.ratio = vital.ratio ?? 0
        bar.tint = Theme.palette[index % Theme.palette.count]

        // 显式定位 + 固定高度：不用 NSStackView 的自动填充分布，
        // 否则卡片高度不足时它会压缩子视图，把文字裁成半截。
        for v in [titleLabel, valueLabel, detailLabel, bar] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.heightAnchor.constraint(equalToConstant: 16),

            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.heightAnchor.constraint(equalToConstant: 27),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            detailLabel.heightAnchor.constraint(equalToConstant: 15),

            bar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bar.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 4),
            bar.heightAnchor.constraint(equalToConstant: 4),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 实时刷新：只改文本与数值，不重建视图树（避免闪烁）
    func update(_ vital: HWVital, history: [Double] = []) {
        if titleLabel.stringValue != vital.title { titleLabel.stringValue = vital.title }
        if valueLabel.stringValue != vital.value { valueLabel.stringValue = vital.value }
        if detailLabel.stringValue != vital.detail { detailLabel.stringValue = vital.detail }
        bar.ratio = vital.ratio ?? 0
        spark.values = history
    }
}

// MARK: - 侧栏分类按钮

final class SidebarButton: NSButton {
    let groupID: String
    var isActive = false {
        didSet { refreshAppearance() }
    }

    init(group: HWGroup, target: AnyObject, action: Selector) {
        self.groupID = group.id
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = group.title
        font = .systemFont(ofSize: 14, weight: .medium)
        // 22pt 固定尺寸：比原来的 ~14pt 系统默认图标明显更大，又不会撑破行高
        image = hiIcon(group.symbol, side: 28) ?? hiIcon("chart.bar", side: 28)
            ?? hiIcon("square", side: 28) ?? NSImage(size: NSSize(width: 28, height: 28))
        imageScaling = .scaleNone
        imagePosition = .imageLeading
        imageHugsTitle = true
        alignment = .left
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = 8
        contentTintColor = .labelColor
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        heightAnchor.constraint(equalToConstant: 40).isActive = true
        refreshAppearance()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refreshAppearance() {
        layer?.backgroundColor = isActive ? Theme.accentSoft.cgColor : NSColor.clear.cgColor
        contentTintColor = isActive ? .controlAccentColor : .secondaryLabelColor
        let pointSize = font?.pointSize ?? 13
        font = .systemFont(ofSize: pointSize, weight: isActive ? .semibold : .medium)
    }
}

// MARK: - 分隔线

func hairline() -> NSView {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.backgroundColor = Theme.border.cgColor
    v.translatesAutoresizingMaskIntoConstraints = false
    return v
}

// MARK: - 窗口控制器

final class MainWindowController: NSWindowController {

    private var report: HWReport?
    private var selectedIndex = 0
    private var sidebarButtons: [SidebarButton] = []
    private var displayGroups: [HWGroup] = []
    private var vitalCards: [VitalCardView] = []
    private var livePage: LivePageView?
    private var lastLiveSample: LiveSample?
    private var itemCount = 0

    // 实时监控
    private var monitor: LiveMonitor?
    private var livePaused = false
    private var liveInterval: TimeInterval = 1.0
    private let liveIndicator = NSTextField(labelWithString: "● 实时")
    private let livePauseButton = NSButton(title: "暂停", target: nil, action: nil)
    private let intervalPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private let deviceIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "硬件检测")
    private let identityLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "正在读取本机硬件信息…")
    private let vitalsStrip = NSStackView()
    private let sidebarStack = FlippedStackView()
    private let contentStack = FlippedStackView()
    private let scrollView = NSScrollView()
    private let statusLeft = NSTextField(labelWithString: "本机离线采集 · IOKit / sysctl / Mach / system_profiler")
    private let statusRight = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let refreshButton = NSButton(title: "刷新检测", target: nil, action: nil)

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 700),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "硬件检测 · Hardware Inspector"
        w.minSize = NSSize(width: 820, height: 560)
        w.center()
        w.isReleasedWhenClosed = false
        self.init(window: w)
        buildUI()
    }

    // MARK: 构建界面

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // ---- Header ----
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        deviceIcon.image = hiSymbol("desktopcomputer")
        deviceIcon.contentTintColor = .controlAccentColor
        deviceIcon.imageScaling = .scaleProportionallyUpOrDown
        deviceIcon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 23, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        identityLabel.font = .systemFont(ofSize: 10.5, weight: .semibold)
        identityLabel.textColor = .systemOrange
        identityLabel.lineBreakMode = .byTruncatingTail
        identityLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 11.5)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.bezelStyle = .rounded
        refreshButton.font = .systemFont(ofSize: 12, weight: .medium)
        refreshButton.target = self
        refreshButton.action = #selector(reload)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let exportButton = NSButton(title: "导出报告", target: self, action: #selector(showExportMenu(_:)))
        exportButton.bezelStyle = .rounded
        exportButton.font = .systemFont(ofSize: 12, weight: .medium)
        exportButton.translatesAutoresizingMaskIntoConstraints = false

        for v in [titleLabel, identityLabel, subtitleLabel] {
            v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        header.addSubview(deviceIcon)
        header.addSubview(titleLabel)
        header.addSubview(identityLabel)
        header.addSubview(subtitleLabel)
        header.addSubview(refreshButton)
        header.addSubview(exportButton)
        NSLayoutConstraint.activate([
            deviceIcon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            deviceIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            deviceIcon.widthAnchor.constraint(equalToConstant: 66),
            deviceIcon.heightAnchor.constraint(equalToConstant: 66),

            titleLabel.leadingAnchor.constraint(equalTo: deviceIcon.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 17),
            identityLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            identityLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            identityLabel.trailingAnchor.constraint(lessThanOrEqualTo: refreshButton.leadingAnchor, constant: -16),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: refreshButton.leadingAnchor, constant: -16),

            exportButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            exportButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 96),
            refreshButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -10),
            refreshButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 96),
        ])

        // ---- Vitals ----
        vitalsStrip.orientation = .horizontal
        vitalsStrip.distribution = .fillEqually
        vitalsStrip.spacing = 12
        vitalsStrip.edgeInsets = NSEdgeInsets(top: 8, left: 20, bottom: 12, right: 20)
        vitalsStrip.translatesAutoresizingMaskIntoConstraints = false

        let vitalsContainer = NSView()
        vitalsContainer.translatesAutoresizingMaskIntoConstraints = false
        vitalsContainer.addSubview(vitalsStrip)
        NSLayoutConstraint.activate([
            vitalsStrip.leadingAnchor.constraint(equalTo: vitalsContainer.leadingAnchor),
            vitalsStrip.trailingAnchor.constraint(equalTo: vitalsContainer.trailingAnchor),
            vitalsStrip.topAnchor.constraint(equalTo: vitalsContainer.topAnchor),
            vitalsStrip.bottomAnchor.constraint(equalTo: vitalsContainer.bottomAnchor),
        ])

        // ---- Sidebar ----
        let sidebarContainer = NSView()
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.backgroundColor = Theme.sidebar.cgColor
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false

        let sidebarTitle = NSTextField(labelWithString: "检测分类")
        sidebarTitle.font = .systemFont(ofSize: 11.5, weight: .semibold)
        sidebarTitle.textColor = .tertiaryLabelColor
        sidebarTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 3
        sidebarStack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarStack.addArrangedSubview(sidebarTitle)
        sidebarStack.setCustomSpacing(10, after: sidebarTitle)
        sidebarTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebarTitle.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor, constant: -28).isActive = true

        // 窗口较矮时侧栏也要能滚动，否则下面的分类会被裁掉
        let sidebarScroll = NSScrollView()
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.hasHorizontalScroller = false
        sidebarScroll.autohidesScrollers = true
        sidebarScroll.drawsBackground = false
        sidebarScroll.contentView.drawsBackground = false
        sidebarScroll.documentView = sidebarStack
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebarScroll)
        let sideClip = sidebarScroll.contentView
        NSLayoutConstraint.activate([
            sidebarScroll.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebarScroll.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebarScroll.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebarScroll.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
            sidebarStack.leadingAnchor.constraint(equalTo: sideClip.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sideClip.trailingAnchor),
            sidebarStack.topAnchor.constraint(equalTo: sideClip.topAnchor),
        ])

        // ---- Content ----
        contentStack.orientation = .vertical
        // 注意：NSStackView 的 .width 在嵌套 StackView 上不会撑满，实测会把
        // 所有卡片靠右对齐、左侧留出大片空白。改为 .leading + 显式宽度约束。
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.edgeInsets = NSEdgeInsets(top: 18, left: 22, bottom: 26, right: 22)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentStack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let clip = scrollView.contentView
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: clip.topAnchor),
        ])

        let body = NSView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(sidebarContainer)
        body.addSubview(scrollView)
        let sideSep = hairline()
        body.addSubview(sideSep)
        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            sidebarContainer.topAnchor.constraint(equalTo: body.topAnchor),
            sidebarContainer.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            sidebarContainer.widthAnchor.constraint(equalToConstant: 214),
            sideSep.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sideSep.topAnchor.constraint(equalTo: body.topAnchor),
            sideSep.bottomAnchor.constraint(equalTo: body.bottomAnchor),
            sideSep.widthAnchor.constraint(equalToConstant: 1),
            scrollView.leadingAnchor.constraint(equalTo: sideSep.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: body.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: body.bottomAnchor),
        ])

        // ---- Status bar ----
        let status = NSView()
        status.translatesAutoresizingMaskIntoConstraints = false
        statusLeft.font = .systemFont(ofSize: 10.5)
        statusLeft.textColor = .tertiaryLabelColor
        statusRight.font = .systemFont(ofSize: 10.5)
        statusRight.textColor = .tertiaryLabelColor
        statusRight.alignment = .right
        statusLeft.translatesAutoresizingMaskIntoConstraints = false
        statusRight.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        liveIndicator.font = .systemFont(ofSize: 10.5, weight: .semibold)
        liveIndicator.textColor = .systemGreen
        liveIndicator.translatesAutoresizingMaskIntoConstraints = false

        livePauseButton.isBordered = false
        livePauseButton.font = .systemFont(ofSize: 10.5, weight: .medium)
        livePauseButton.contentTintColor = .controlAccentColor
        livePauseButton.target = self
        livePauseButton.action = #selector(toggleLive)
        livePauseButton.toolTip = "暂停 / 继续实时采样"
        livePauseButton.translatesAutoresizingMaskIntoConstraints = false

        intervalPopup.addItems(withTitles: ["1 秒", "2 秒", "5 秒"])
        intervalPopup.selectItem(at: 0)
        intervalPopup.isBordered = false
        intervalPopup.font = .systemFont(ofSize: 10.5)
        intervalPopup.target = self
        intervalPopup.action = #selector(changeInterval(_:))
        intervalPopup.toolTip = "实时采样间隔"
        intervalPopup.translatesAutoresizingMaskIntoConstraints = false

        for v in [statusLeft, statusRight, spinner, liveIndicator, livePauseButton, intervalPopup] {
            status.addSubview(v)
        }
        NSLayoutConstraint.activate([
            statusLeft.leadingAnchor.constraint(equalTo: status.leadingAnchor, constant: 18),
            statusLeft.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: statusLeft.trailingAnchor, constant: 8),
            spinner.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 14),
            spinner.heightAnchor.constraint(equalToConstant: 14),

            liveIndicator.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 12),
            liveIndicator.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            liveIndicator.heightAnchor.constraint(equalToConstant: 15),

            intervalPopup.trailingAnchor.constraint(equalTo: status.trailingAnchor, constant: -12),
            intervalPopup.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            intervalPopup.widthAnchor.constraint(equalToConstant: 62),
            intervalPopup.heightAnchor.constraint(equalToConstant: 18),

            livePauseButton.trailingAnchor.constraint(equalTo: intervalPopup.leadingAnchor, constant: -6),
            livePauseButton.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            livePauseButton.widthAnchor.constraint(equalToConstant: 40),
            livePauseButton.heightAnchor.constraint(equalToConstant: 18),

            statusRight.leadingAnchor.constraint(greaterThanOrEqualTo: liveIndicator.trailingAnchor, constant: 12),
            statusRight.trailingAnchor.constraint(equalTo: livePauseButton.leadingAnchor, constant: -12),
            statusRight.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            statusRight.heightAnchor.constraint(equalToConstant: 15),
        ])

        let topSep = hairline()
        let statusSep = hairline()

        for v in [header, vitalsContainer, topSep, body, statusSep, status] {
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 88),

            vitalsContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            vitalsContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            vitalsContainer.topAnchor.constraint(equalTo: header.bottomAnchor),
            vitalsContainer.heightAnchor.constraint(equalToConstant: 120),

            topSep.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            topSep.topAnchor.constraint(equalTo: vitalsContainer.bottomAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 1),

            body.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            body.topAnchor.constraint(equalTo: topSep.bottomAnchor),
            body.bottomAnchor.constraint(equalTo: statusSep.topAnchor),

            statusSep.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusSep.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusSep.bottomAnchor.constraint(equalTo: status.topAnchor),
            statusSep.heightAnchor.constraint(equalToConstant: 1),

            status.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            status.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            status.heightAnchor.constraint(equalToConstant: 26),
        ])

        // 窗口拉宽 / 收窄时在单双列之间切换，始终保持内容区被填满
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize(_:)),
                                               name: NSWindow.didResizeNotification, object: window)
    }

    // MARK: 数据采集

    @objc func reload() {
        refreshButton.isEnabled = false
        spinner.startAnimation(nil)
        statusRight.stringValue = "正在采集…"
        DispatchQueue.global(qos: .userInitiated).async {
            let r = HardwareCollector.collect()
            DispatchQueue.main.async {
                self.apply(r)
                self.startLive()
            }
        }
    }

    func apply(_ r: HWReport) {
        report = r
        deviceIcon.contentTintColor = nil       // 真实 Logo 保持原始配色
        deviceIcon.image = BrandLogo.image(for: r.identity.primaryBrandKey, size: 66)
        titleLabel.stringValue = "\(r.identity.primaryBrandName) · \(r.deviceName)"
        identityLabel.stringValue = r.identity.isGenuineApple
            ? "Apple 原厂机型"
            : "OpenCore 模拟机型 · 物理线索：\(r.identity.physicalBrandName)"
        identityLabel.textColor = r.identity.isGenuineApple ? .systemGreen : .systemOrange
        subtitleLabel.stringValue = "\(r.identity.modelIdentifier) · \(r.identity.releaseHint)  |  \(r.subtitle)"
        window?.title = "硬件检测 · \(r.identity.primaryBrandName) \(r.deviceName)"

        for v in vitalsStrip.arrangedSubviews { vitalsStrip.removeArrangedSubview(v); v.removeFromSuperview() }
        vitalCards.removeAll()
        for (i, v) in r.vitals.enumerated() {
            let card = VitalCardView(vital: v, index: i)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.heightAnchor.constraint(equalToConstant: 82).isActive = true
            vitalsStrip.addArrangedSubview(card)
            vitalCards.append(card)
        }

        // 「实时状态」是运行时页面，由 LiveMonitor 驱动，不属于静态检测报告
        let liveGroup = HWGroup(id: "live", title: "实时状态", symbol: "waveform.path.ecg", sections: [])
        displayGroups = [liveGroup] + r.groups

        for b in sidebarButtons { sidebarStack.removeArrangedSubview(b); b.removeFromSuperview() }
        sidebarButtons = displayGroups.map {
            SidebarButton(group: $0, target: self, action: #selector(selectGroup(_:)))
        }
        for b in sidebarButtons {
            sidebarStack.addArrangedSubview(b)
            b.widthAnchor.constraint(equalTo: sidebarStack.widthAnchor, constant: -28).isActive = true
        }

        itemCount = r.groups.reduce(0) { $0 + $1.sections.reduce(0) { $0 + $1.items.count } }
        statusRight.stringValue = "共 \(itemCount) 项指标  ·  更新于 \(shortTime())"
        refreshButton.isEnabled = true
        spinner.stopAnimation(nil)

        selectedIndex = 0
        renderSelection()
    }

    // MARK: 实时监控

    private func startLive() {
        guard monitor == nil else { return }
        let m = LiveMonitor()
        m.onUpdate = { [weak self] sample, history in
            self?.onLive(sample, history)
        }
        monitor = m
        m.start(interval: liveInterval)
        if livePaused { m.setPaused(true) }
        liveIndicator.stringValue = livePaused ? "● 已暂停" : "● 实时"
        liveIndicator.textColor = livePaused ? .systemOrange : .systemGreen
    }

    @objc private func toggleLive() {
        livePaused.toggle()
        monitor?.setPaused(livePaused)
        livePauseButton.title = livePaused ? "继续" : "暂停"
        liveIndicator.stringValue = livePaused ? "● 已暂停" : "● 实时"
        liveIndicator.textColor = livePaused ? .systemOrange : .systemGreen
        if let s = lastLiveSample {
            livePage?.update(s, monitor?.history ?? [], sampleCount: monitor?.sampleCount ?? 0,
                             interval: liveInterval, paused: livePaused)
        }
    }

    @objc private func changeInterval(_ sender: NSPopUpButton) {
        let values: [TimeInterval] = [1, 2, 5]
        let idx = max(0, min(values.count - 1, sender.indexOfSelectedItem))
        liveInterval = values[idx]
        monitor?.setInterval(liveInterval)
    }

    private func liveVitals(_ s: LiveSample) -> [HWVital] {
        let batteryDetail: String
        if !s.hasBattery { batteryDetail = "未检测到电池" }
        else if s.isCharging { batteryDetail = "充电中 · 循环 \(s.cycleCount) 次" }
        else if s.fullyCharged { batteryDetail = "已充满 · 循环 \(s.cycleCount) 次" }
        else { batteryDetail = "循环 \(s.cycleCount) 次" }
        return [
            HWVital(title: "CPU 使用率", value: percent(s.cpuUsage),
                    detail: "\(s.logicalCores) 逻辑核心 · 负载 \(String(format: "%.2f", s.load1))",
                    ratio: s.cpuUsage),
            HWVital(title: "内存占用", value: percent(s.memRatio),
                    detail: "\(humanBytes(s.memUsed)) / \(humanBytes(s.memTotal))", ratio: s.memRatio),
            HWVital(title: "启动盘占用", value: percent(s.diskRatio),
                    detail: "剩余 \(humanBytes(s.diskFree))", ratio: s.diskRatio),
            HWVital(title: "电池电量", value: s.hasBattery ? percent(s.batteryLevel) : "不适用",
                    detail: batteryDetail, ratio: s.hasBattery ? s.batteryLevel : nil),
        ]
    }

    func onLive(_ s: LiveSample, _ history: [LiveSample]) {
        lastLiveSample = s
        let vitals = liveVitals(s)
        let series: [[Double]] = [
            history.map { $0.cpuUsage },
            history.map { $0.memRatio },
            history.map { $0.diskRatio },
            history.map { $0.batteryLevel },
        ]
        for (i, card) in vitalCards.enumerated() where i < vitals.count {
            card.update(vitals[i], history: i < series.count ? series[i] : [])
        }
        statusRight.stringValue = "更新于 \(shortTime())  ·  共 \(itemCount) 项指标"
        if let page = livePage, displayGroups.indices.contains(selectedIndex),
           displayGroups[selectedIndex].id == "live" {
            page.update(s, history, sampleCount: monitor?.sampleCount ?? 0,
                        interval: liveInterval, paused: livePaused)
        }
    }

    /// 隐藏自检：不显示窗口，逐页计算布局并汇报视图树结果
    func selfTest(_ r: HWReport) -> String {
        apply(r)
        window?.contentView?.layoutSubtreeIfNeeded()
        var lines = [
            "整机品牌          \(r.identity.primaryBrandName) / \(r.identity.productName)",
            "原厂判定          \(r.identity.isGenuineApple ? "Apple 原厂" : "非原厂（\(r.identity.firmwareName)）")",
            "物理整机线索      \(r.identity.physicalBrandName)",
            "品牌清单          \(r.brands.count) 项：\(r.brands.map { $0.name }.joined(separator: "、"))",
            "分类 / 侧栏 / 指标卡  \(displayGroups.count) / \(sidebarButtons.count) / \(vitalsStrip.arrangedSubviews.count)",
            "逐页渲染检查：",
        ]
        for (i, g) in displayGroups.enumerated() {
            selectedIndex = i
            renderSelection()
            window?.contentView?.layoutSubtreeIfNeeded()
            let blocks = contentStack.arrangedSubviews.count
            let fields = contentStack.allSubviews.compactMap { $0 as? NSTextField }
            let nonEmpty = fields.filter { !$0.stringValue.isEmpty }.count
            let logos = contentStack.allSubviews.compactMap { $0 as? NSImageView }.count
            lines.append("  \(g.title)：内容块 \(blocks) / 文本 \(nonEmpty) / Logo \(logos) / 高 \(Int(contentStack.frame.height)) px")
        }

        // 真实采样 3 次，验证实时页字段与指标卡趋势线都被填充
        let probe = LiveMonitor()
        probe.primeBaseline()
        var samples: [LiveSample] = []
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 0.35)
            samples.append(probe.sample())
        }
        selectedIndex = 0
        renderSelection()
        onLive(samples.last!, samples)
        window?.contentView?.layoutSubtreeIfNeeded()
        let last = samples.last!
        lines.append("实时采样        3 次 / CPU \(percent(last.cpuUsage)) / 内存 \(percent(last.memRatio)) / 下行 \(liveRate(last.netRxPerSec))")
        let liveFields = contentStack.allSubviews.compactMap { $0 as? NSTextField }
        let filled = liveFields.filter { !$0.stringValue.isEmpty && $0.stringValue != "—" }.count
        lines.append("实时页字段      \(liveFields.count) 个 / 已填充 \(filled) 个 / 趋势样本 \(samples.count)")
        let sparks = vitalsStrip.allSubviews.compactMap { $0 as? SparklineView }
        lines.append("指标卡趋势线    \(sparks.count) 条 / 有数据 \(sparks.filter { !$0.values.isEmpty }.count) 条")

        let vitalFields = vitalsStrip.allSubviews.compactMap { $0 as? NSTextField }
        let squeezed = vitalFields.filter {
            $0.frame.height < ($0.font?.pointSize ?? 11) * 1.05
        }
        let detail = squeezed.isEmpty ? "" : " → " + squeezed.map {
            "\($0.stringValue)=\(Int($0.frame.height))pt/字号\(Int($0.font?.pointSize ?? 0))"
        }.joined(separator: ", ")
        lines.append("指标卡文字      \(vitalFields.count) 个 / 高度不足 \(squeezed.count) 个\(detail)")
        let realCount = BrandCatalog.names.keys.filter { BrandLogo.hasRealLogo($0) }.count
        lines.append("真实 Logo 素材   \(realCount) / \(BrandCatalog.names.count) 个品牌（其余为纯文字降级）")
        lines.append("自定义 Logo 目录  \(BrandLogo.customDirectoryPath)")
        lines.append("Header Logo      \(deviceIcon.image != nil ? "已设置" : "缺失") / \(Int(deviceIcon.frame.width))×\(Int(deviceIcon.frame.height)) pt")
        let icon = sidebarButtons.first?.image?.size ?? .zero
        lines.append("侧栏图标        \(sidebarButtons.count) 个 / \(Int(icon.width))×\(Int(icon.height)) pt")
        let blocks = contentStack.arrangedSubviews
        let narrow = blocks.filter { $0.frame.width < contentStack.frame.width - 70 }
        let minW = blocks.map { $0.frame.width }.min() ?? 0
        lines.append("内容区 frame     \(NSStringFromRect(contentStack.frame))")
        lines.append("内容块宽度      \(blocks.count) 块 / 最窄 \(Int(minW)) px / 未撑满 \(narrow.count) 块")
        return lines.joined(separator: "\n")
    }

    @objc private func selectGroup(_ sender: SidebarButton) {
        guard let idx = displayGroups.firstIndex(where: { $0.id == sender.groupID }) else { return }
        selectedIndex = idx
        renderSelection()
    }

    /// 内容区统一入口：显式把每个内容块钉到内容区宽度（左右各 22pt 内边距），
    /// 彻底避免 NSStackView 按固有宽度把卡片挤到右侧、留下大片空白。
    private func addBlock(_ v: NSView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -44).isActive = true
    }

    private func renderSelection() {
        guard let r = report, displayGroups.indices.contains(selectedIndex) else { return }
        for (i, b) in sidebarButtons.enumerated() { b.isActive = i == selectedIndex }
        let group = displayGroups[selectedIndex]

        for v in contentStack.arrangedSubviews { contentStack.removeArrangedSubview(v); v.removeFromSuperview() }

        if group.id == "brands" {
            livePage = nil
            renderBrandsPage(r, group: group)
            scrollToTop()
            return
        }

        if group.id == "live" {
            let page = LivePageView()
            addBlock(page)
            livePage = page
            if let s = lastLiveSample {
                page.update(s, monitor?.history ?? [], sampleCount: monitor?.sampleCount ?? 0,
                            interval: liveInterval, paused: livePaused)
            }
            scrollToTop()
            return
        }

        livePage = nil
        addBlock(pageHeader(group.title,
            "\(group.sections.count) 个分组  ·  \(group.sections.reduce(0) { $0 + $1.items.count }) 项指标"))
        renderSections(group)
        scrollToTop()
    }

    /// 宽窗口时把分组卡片排成两列，避免一整列把内容区拉成大片空白
    private var renderedColumns = 1

    private func sectionColumns() -> Int {
        scrollView.contentView.bounds.width - 44 >= 860 ? 2 : 1
    }

    private func renderSections(_ group: HWGroup) {
        let columns = sectionColumns()
        renderedColumns = columns
        if columns == 1 {
            for s in group.sections { addBlock(makeCard(s, symbol: group.symbol)) }
            return
        }
        var row: [NSView] = []
        for s in group.sections {
            row.append(makeCard(s, symbol: group.symbol))
            if row.count == columns { addBlock(makeGridRow(row)); row = [] }
        }
        if !row.isEmpty {
            while row.count < columns {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                row.append(spacer)
            }
            addBlock(makeGridRow(row))
        }
    }

    @objc private func windowDidResize(_ note: Notification) {
        guard report != nil, displayGroups.indices.contains(selectedIndex) else { return }
        let g = displayGroups[selectedIndex]
        guard g.id != "live" && g.id != "brands" else { return }
        if sectionColumns() != renderedColumns { renderSelection() }
    }

    private func scrollToTop() {
        contentStack.layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: NSPoint.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func pageHeader(_ title: String, _ subtitle: String) -> NSView {
        let h = uiLabel(title, 17, .semibold, .labelColor)
        let s = uiLabel(subtitle, 11, .regular, .tertiaryLabelColor)
        let stack = NSStackView(views: [h, s])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private func uiLabel(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.lineBreakMode = .byTruncatingTail
        t.translatesAutoresizingMaskIntoConstraints = false
        t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return t
    }

    private func roundedCard() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 10
        v.layer?.backgroundColor = Theme.card.cgColor
        v.layer?.borderColor = Theme.border.cgColor
        v.layer?.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: 品牌识别专页

    private func renderBrandsPage(_ r: HWReport, group: HWGroup) {
        addBlock(pageHeader(group.title,
            "整机身份 · 证据链 · \(r.brands.count) 个硬件品牌"))
        addBlock(makeIdentityCard(r.identity))
        if let s = group.sections.first(where: { $0.title == "识别依据" }) {
            addBlock(makeCard(s, symbol: group.symbol))
        }
        let gridTitle = uiLabel("硬件品牌", 14, .semibold, .labelColor)
        addBlock(gridTitle)

        let columns = 3
        var row: [NSView] = []
        for b in r.brands {
            row.append(makeBrandTile(b))
            if row.count == columns {
                addBlock(makeGridRow(row))
                row = []
            }
        }
        if !row.isEmpty {
            while row.count < columns {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                row.append(spacer)
            }
            addBlock(makeGridRow(row))
        }
        let footnote = uiLabel(
            "Logo 为真实品牌图形：取自 Simple Icons (CC0)、gilbarbara/logos 与 Acidanthera OpenCore 官方仓库，"
            + "非 AI 生成或手绘；无官方素材的品牌仅显示品牌文字。商标归各自权利人所有，整机判定依据见上方证据链。",
            10.5, .regular, .tertiaryLabelColor)
        footnote.lineBreakMode = .byWordWrapping
        addBlock(footnote)
        contentStack.setCustomSpacing(3, after: footnote)

        let custom = uiLabel(
            "如需替换为官方彩色 Logo，把 PNG 放到 " + BrandLogo.customDirectoryPath
            + " ，命名为 <品牌标识>.png（如 amd.png），重启应用即生效。",
            10.5, .regular, .tertiaryLabelColor)
        custom.lineBreakMode = .byWordWrapping
        custom.toolTip = BrandLogo.customDirectoryPath
        addBlock(custom)
    }

    private func makeGridRow(_ views: [NSView]) -> NSView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.distribution = .fillEqually
        s.alignment = .top
        s.spacing = 12
        return s
    }

    private func makeIdentityCard(_ id: DeviceIdentity) -> NSView {
        let card = roundedCard()
        card.heightAnchor.constraint(equalToConstant: 210).isActive = true

        let logo = NSImageView(image: BrandLogo.image(for: id.primaryBrandKey, size: 96))
        logo.translatesAutoresizingMaskIntoConstraints = false
        let name = uiLabel(id.primaryBrandName, 22, .bold, .labelColor)
        let product = uiLabel(id.productName, 12.5, .medium, .secondaryLabelColor)
        let meta = uiLabel("\(id.modelIdentifier)  ·  \(id.formFactor)  ·  \(id.releaseHint)", 11, .regular, .tertiaryLabelColor)
        let status = uiLabel(id.isGenuineApple ? "Apple 原厂机型" : "非原厂机型 · 模拟机型",
                             11, .semibold, id.isGenuineApple ? .systemGreen : .systemOrange)
        let note = uiLabel(id.note, 10.5, .regular, .tertiaryLabelColor)
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 3

        let fw = makeMiniBadge(id.firmwareBrandKey, "引导固件", id.firmwareName)
        let phys = makeMiniBadge(id.physicalBrandKey, "物理整机线索", id.physicalBrandName + " · " + id.confidence)
        let badges = NSStackView(views: [fw, phys])
        badges.orientation = .horizontal
        badges.distribution = .fillEqually
        badges.spacing = 10
        badges.translatesAutoresizingMaskIntoConstraints = false

        for v in [logo, name, product, meta, status, note, badges] { card.addSubview(v) }
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            logo.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            logo.widthAnchor.constraint(equalToConstant: 96),
            logo.heightAnchor.constraint(equalToConstant: 96),

            name.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 18),
            name.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            product.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            product.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3),
            meta.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            meta.topAnchor.constraint(equalTo: product.bottomAnchor, constant: 3),
            status.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            status.topAnchor.constraint(equalTo: meta.bottomAnchor, constant: 6),

            badges.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            badges.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            badges.widthAnchor.constraint(equalToConstant: 380),
            badges.heightAnchor.constraint(equalToConstant: 76),

            note.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            note.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            note.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 14),
        ])
        return card
    }

    private func makeMiniBadge(_ key: String, _ caption: String, _ value: String) -> NSView {
        let v = roundedCard()
        v.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.07).cgColor
        v.heightAnchor.constraint(equalToConstant: 76).isActive = true
        let logo = NSImageView(image: BrandLogo.image(for: key, size: 46))
        logo.translatesAutoresizingMaskIntoConstraints = false
        let c = uiLabel(caption, 10, .medium, .tertiaryLabelColor)
        let val = uiLabel(value, 11, .semibold, .labelColor)
        for x in [logo, c, val] { v.addSubview(x) }
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            logo.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 46),
            logo.heightAnchor.constraint(equalToConstant: 46),
            c.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 10),
            c.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
            c.topAnchor.constraint(equalTo: v.topAnchor, constant: 17),
            val.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            val.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            val.topAnchor.constraint(equalTo: c.bottomAnchor, constant: 4),
        ])
        return v
    }

    private func makeBrandTile(_ b: BrandInfo) -> NSView {
        let tile = roundedCard()
        tile.heightAnchor.constraint(equalToConstant: 122).isActive = true
        let logo = NSImageView(image: BrandLogo.image(for: b.key, size: 64))
        logo.translatesAutoresizingMaskIntoConstraints = false
        let name = uiLabel(b.name, 13, .semibold, .labelColor)
        let cat = uiLabel(b.category, 11, .medium, .controlAccentColor)
        let model = uiLabel(b.model, 11, .regular, .secondaryLabelColor)
        model.toolTip = b.model + "（来源：\(b.source)）"
        for x in [logo, name, cat, model] { tile.addSubview(x) }
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 14),
            logo.topAnchor.constraint(equalTo: tile.topAnchor, constant: 14),
            logo.widthAnchor.constraint(equalToConstant: 64),
            logo.heightAnchor.constraint(equalToConstant: 64),
            name.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 12),
            name.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -10),
            name.topAnchor.constraint(equalTo: tile.topAnchor, constant: 18),
            cat.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            cat.trailingAnchor.constraint(equalTo: name.trailingAnchor),
            cat.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 5),
            model.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 14),
            model.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -12),
            model.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 12),
        ])
        return tile
    }

    // MARK: 卡片与行

    private func makeCard(_ section: HWSection, symbol: String? = nil) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 0
        card.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = Theme.card.cgColor
        card.layer?.borderColor = Theme.border.cgColor
        card.layer?.borderWidth = 1

        let title = NSTextField(labelWithString: section.title)
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .controlAccentColor
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // 每张卡片配一个大图标：有真实品牌素材用品牌 Logo，否则用该分类的 SF Symbol
        let iconSize: CGFloat = 30
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        if let key = section.brandKey, !key.isEmpty {
            icon.image = BrandLogo.image(for: key, size: iconSize)
        } else {
            icon.image = (symbol.flatMap { hiIcon($0, side: 28) }
                          ?? hiIcon("square.grid.2x2", side: 28))
            icon.contentTintColor = .controlAccentColor
        }

        let titleRow = NSStackView(views: [icon, title])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 9
        card.addArrangedSubview(titleRow)
        pinCardWidth(titleRow, card)
        card.setCustomSpacing(11, after: titleRow)

        for (i, item) in section.items.enumerated() {
            let row = makeRow(item)
            card.addArrangedSubview(row)
            pinCardWidth(row, card)
            if i < section.items.count - 1 {
                let line = hairline()
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                card.addArrangedSubview(line)
                pinCardWidth(line, card)
            }
        }
        return card
    }

    /// 卡片内每一行都钉到卡片宽度（左右各 16pt 内边距），避免文字挤在右侧
    private func pinCardWidth(_ v: NSView, _ card: NSStackView) {
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -32).isActive = true
    }

    private func makeRow(_ item: HWItem) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let key = NSTextField(labelWithString: item.label)
        key.font = .systemFont(ofSize: 12.5)
        key.textColor = .secondaryLabelColor
        key.lineBreakMode = .byTruncatingTail
        key.translatesAutoresizingMaskIntoConstraints = false

        let value = NSTextField(labelWithString: item.value)
        value.font = .systemFont(ofSize: 12.5, weight: .medium)
        value.textColor = .labelColor
        value.alignment = .right
        value.lineBreakMode = .byTruncatingMiddle
        value.isSelectable = true
        value.allowsExpansionToolTips = true
        value.toolTip = item.value
        value.translatesAutoresizingMaskIntoConstraints = false
        // 超长值（如 CPU 特性位串）必须允许压缩截断，否则会把窗口自动撑宽
        value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        key.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addSubview(key)
        row.addSubview(value)
        NSLayoutConstraint.activate([
            key.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            key.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            key.widthAnchor.constraint(equalToConstant: 160),
            value.leadingAnchor.constraint(equalTo: key.trailingAnchor, constant: 12),
            value.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            value.centerYAnchor.constraint(equalTo: key.centerYAnchor),
        ])

        var bottom: NSLayoutYAxisAnchor = key.bottomAnchor
        if let hint = item.hint, !hint.isEmpty {
            let note = NSTextField(labelWithString: "↳ " + hint)
            note.font = .systemFont(ofSize: 10.5)
            note.textColor = .tertiaryLabelColor
            note.alignment = .right
            note.lineBreakMode = .byTruncatingTail
            note.translatesAutoresizingMaskIntoConstraints = false
            note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addSubview(note)
            NSLayoutConstraint.activate([
                note.leadingAnchor.constraint(equalTo: key.trailingAnchor, constant: 12),
                note.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                note.topAnchor.constraint(equalTo: key.bottomAnchor, constant: 2),
            ])
            bottom = note.bottomAnchor
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 26),
            row.bottomAnchor.constraint(greaterThanOrEqualTo: bottom, constant: 4),
        ])
        return row
    }

    // MARK: 导出

    @objc private func showExportMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let md = NSMenuItem(title: "导出 Markdown 报告…", action: #selector(exportMarkdown), keyEquivalent: "")
        md.target = self
        let js = NSMenuItem(title: "导出 JSON 数据…", action: #selector(exportJSON), keyEquivalent: "")
        js.target = self
        menu.addItem(md)
        menu.addItem(js)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 6), in: sender)
    }

    @objc func exportMarkdown() { export(kind: "md") }
    @objc func exportJSON() { export(kind: "json") }

    private func export(kind: String) {
        guard let r = report else { return }
        let panel = NSSavePanel()
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        panel.nameFieldStringValue = "硬件检测报告-\(f.string(from: Date())).\(kind)"
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        panel.message = "选择报告保存位置（仅写入本机，不会上传任何数据）"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if kind == "md" {
                    try ReportRenderer.markdown(r).write(to: url, atomically: true, encoding: .utf8)
                } else {
                    try ReportRenderer.jsonData(r).write(to: url)
                }
                self?.statusRight.stringValue = "已导出  \(url.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let alert = NSAlert()
                alert.messageText = "导出失败"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func shortTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        let c = MainWindowController()
        c.showWindow(nil)
        controller = c
        NSApp.activate(ignoringOtherApps: true)
        c.reload()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        let about = NSMenuItem(title: "关于硬件检测", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出硬件检测", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        main.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        let refresh = NSMenuItem(title: "刷新检测", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        fileMenu.addItem(refresh)
        fileMenu.addItem(.separator())
        let md = NSMenuItem(title: "导出 Markdown 报告…", action: #selector(exportMDAction), keyEquivalent: "")
        md.target = self
        fileMenu.addItem(md)
        let js = NSMenuItem(title: "导出 JSON 数据…", action: #selector(exportJSONAction), keyEquivalent: "")
        js.target = self
        fileMenu.addItem(js)
        fileItem.submenu = fileMenu

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        let close = NSMenuItem(title: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(close)
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "硬件检测 · Hardware Inspector",
            .credits: NSAttributedString(string: "基于 IOKit、sysctl、Mach 与 system_profiler 的 macOS 原生硬件检测工具。\n所有数据仅在本机采集，不会联网上传。"),
        ])
    }
    @objc private func refreshAction() { controller?.reload() }
    @objc private func exportMDAction() { controller?.exportMarkdown() }
    @objc private func exportJSONAction() { controller?.exportJSON() }
}
