//  LiveViews.swift
//  实时状态可视化：迷你趋势线（指标卡背景）、大趋势图、以及可局部刷新的「实时状态」页。
//  设计要点：数值更新只改 NSTextField.stringValue 与图表 needsDisplay，
//  不重建视图树，避免每秒刷新时的闪烁与滚动位置丢失。

import AppKit

// MARK: - 迷你趋势线（作为指标卡的低对比度背景）

final class SparklineView: NSView {
    var values: [Double] = [] { didSet { needsDisplay = true } }
    var tint: NSColor = .controlAccentColor { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        guard values.count >= 2 else { return }
        let w = bounds.width, h = bounds.height
        guard w > 2, h > 2 else { return }

        let pts = values.map { max(0, min(1, $0)) }
        let step = w / CGFloat(max(1, pts.count - 1))
        func point(_ i: Int) -> NSPoint {
            NSPoint(x: CGFloat(i) * step, y: 2 + (h - 4) * CGFloat(pts[i]))
        }

        let area = NSBezierPath()
        area.move(to: NSPoint(x: 0, y: 0))
        for i in pts.indices { area.line(to: point(i)) }
        area.line(to: NSPoint(x: w, y: 0))
        area.close()
        tint.withAlphaComponent(0.16).setFill()
        area.fill()

        let line = NSBezierPath()
        line.move(to: point(0))
        for i in 1..<pts.count { line.line(to: point(i)) }
        line.lineWidth = 1.6
        line.lineJoinStyle = .round
        tint.withAlphaComponent(0.85).setStroke()
        line.stroke()
    }
}

// MARK: - 大趋势图（CPU / 内存 / 网络）

final class TrendChartView: NSView {
    var history: [LiveSample] = [] { didSet { needsDisplay = true } }
    private var latest: LiveSample? { history.last }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        guard rect.width > 80, rect.height > 60 else { return }

        let padL: CGFloat = 38, padR: CGFloat = 12, padT: CGFloat = 30, padB: CGFloat = 22
        let plot = NSRect(x: padL, y: padB, width: rect.width - padL - padR,
                          height: rect.height - padT - padB)
        guard plot.width > 10, plot.height > 10 else { return }

        let grid = NSColor.secondaryLabelColor.withAlphaComponent(0.20)
        let caption = NSColor.tertiaryLabelColor

        // 网格 + 左侧百分比刻度
        for i in 0...4 {
            let y = plot.minY + plot.height * CGFloat(i) / 4
            let path = NSBezierPath()
            path.move(to: NSPoint(x: plot.minX, y: y))
            path.line(to: NSPoint(x: plot.maxX, y: y))
            grid.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            let label = "\(i * 25)%"
            label.draw(at: NSPoint(x: 4, y: y - 6),
                       withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                                        .foregroundColor: caption])
        }
        guard history.count >= 2 else {
            "正在收集样本…".draw(at: NSPoint(x: plot.midX - 40, y: plot.midY),
                                withAttributes: [.font: NSFont.systemFont(ofSize: 11),
                                                 .foregroundColor: caption])
            return
        }

        let step = plot.width / CGFloat(max(1, history.count - 1))
        func series(_ pick: (LiveSample) -> Double, maxScale: Double? = nil) -> (NSBezierPath, NSBezierPath) {
            let scale = maxScale ?? 1.0
            let line = NSBezierPath(), area = NSBezierPath()
            var first = true
            for (i, s) in history.enumerated() {
                let v = max(0, min(1, pick(s) / scale))
                let p = NSPoint(x: plot.minX + CGFloat(i) * step,
                                y: plot.minY + plot.height * CGFloat(v))
                if first { line.move(to: p); area.move(to: NSPoint(x: p.x, y: plot.minY)); first = false }
                else { line.line(to: p) }
                area.line(to: p)
            }
            area.line(to: NSPoint(x: plot.minX + CGFloat(history.count - 1) * step, y: plot.minY))
            area.close()
            return (line, area)
        }

        let colors: [NSColor] = [
            NSColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1),
            NSColor(srgbRed: 0.42, green: 0.35, blue: 0.90, alpha: 1),
            NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1),
        ]
        let netPeak = max(history.map { max($0.netRxPerSec, $0.netTxPerSec) }.max() ?? 1, 64 * 1024)
        let picks: [(LiveSample) -> Double] = [
            { $0.cpuUsage }, { $0.memRatio }, { $0.netRxPerSec / netPeak },
        ]

        for (i, pick) in picks.enumerated() {
            let (line, area) = series(pick)
            colors[i].withAlphaComponent(0.10).setFill()
            area.fill()
            line.lineWidth = i == 2 ? 1.4 : 1.9
            line.lineJoinStyle = .round
            colors[i].withAlphaComponent(0.95).setStroke()
            line.stroke()
        }

        // 图例与当前值
        let legends: [(String, NSColor)] = [
            ("CPU", colors[0]), ("内存", colors[1]), ("网络下行（相对峰值）", colors[2]),
        ]
        var x = plot.minX
        for (text, color) in legends {
            let dot = NSBezierPath(ovalIn: NSRect(x: x, y: rect.height - 18, width: 7, height: 7))
            color.setFill(); dot.fill()
            text.draw(at: NSPoint(x: x + 11, y: rect.height - 20),
                      withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                                       .foregroundColor: NSColor.secondaryLabelColor])
            x += 11 + (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 10)]).width + 20
        }
        if let s = latest {
            let right = "↓ \(liveRate(s.netRxPerSec))   ↑ \(liveRate(s.netTxPerSec))"
            let w = (right as NSString).size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)]).width
            right.draw(at: NSPoint(x: plot.maxX - w, y: rect.height - 20),
                       withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
                                        .foregroundColor: NSColor.secondaryLabelColor])
        }
        let span = "最近 \(history.count) 次采样"
        span.draw(at: NSPoint(x: plot.minX, y: 4),
                  withAttributes: [.font: NSFont.systemFont(ofSize: 9),
                                   .foregroundColor: caption])
    }
}

// MARK: - 实时状态页

final class LivePageView: FlippedStackView {
    private var bindings: [String: NSTextField] = [:]
    private let chart = TrendChartView()
    private var latestSample: LiveSample?

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .width
        spacing = 14
        edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: 构建

    /// 每个顶层块都显式钉到页面宽度：NSStackView 的 alignment=.width
    /// 在有 autoresizing mask 的子视图上不生效，会造成整页按文字固有宽度居中。
    private func addBlock(_ v: NSView, after spacing: CGFloat? = nil) {
        v.translatesAutoresizingMaskIntoConstraints = false
        addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        if let s = spacing { setCustomSpacing(s, after: v) }
    }

    private func build() {
        addBlock(header("实时状态", "自动采样（间隔可调） · 数值来自本机 Darwin / Mach / IOKit，不联网"))

        let chartCard = rounded()
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 186).isActive = true
        chartCard.addArrangedSubview(chart)
        chart.widthAnchor.constraint(equalTo: chartCard.widthAnchor, constant: -28).isActive = true
        addBlock(chartCard, after: 14)

        let cpu = card("处理器", [
            row("总使用率", "cpu"), row("用户态 / 系统态", "cpuSplit"), row("空闲", "cpuIdle"),
            row("负载均值（1 / 5 / 15 分）", "load"), row("逻辑 / 物理核心", "cores"),
        ])
        let mem = card("内存", [
            row("已用 / 总量", "memUsed"), row("占用率", "memRatio"),
            row("有线内存", "memWired"), row("已压缩", "memCompressed"),
            row("可回收缓存", "memCached"), row("空闲", "memFree"),
            row("Swap 已用", "swap"), row("每秒页面错误", "faults"),
        ])
        addBlock(twoColumns(cpu, mem))

        let net = card("网络", [
            row("下行速率", "rx"), row("上行速率", "tx"),
            row("累计接收", "rxTotal"), row("累计发送", "txTotal"),
        ])
        let disk = card("启动盘", [
            row("占用率", "diskRatio"), row("已用", "diskUsed"),
            row("剩余", "diskFree"), row("总容量", "diskTotal"),
        ])
        addBlock(twoColumns(net, disk))

        let battery = card("电池 / 电源", [
            row("电量", "battery"), row("供电状态", "powerState"),
            row("充电功率", "watts"), row("电压 / 电流", "voltAmp"),
            row("电池温度", "battTemp"), row("剩余使用时间", "timeLeft"),
            row("循环次数", "cycles"), row("健康度", "health"),
        ])
        let system = card("系统", [
            row("已运行", "uptime"), row("进程数", "processes"),
            row("热压力", "thermal"), row("采样次数", "samples"),
            row("最后更新", "updated"),
        ])
        addBlock(twoColumns(battery, system))

        let note = label("提示：CPU 使用率与网络速率由相邻两次采样的计数差值计算，启动后第一个采样点为零属正常。"
                         + " 底部状态栏可暂停监控或切换 1 / 2 / 5 秒采样间隔。",
                         10.5, .regular, .tertiaryLabelColor)
        note.lineBreakMode = .byWordWrapping
        note.usesSingleLineMode = false
        note.maximumNumberOfLines = 3
        note.heightAnchor.constraint(equalToConstant: 32).isActive = true
        addBlock(note)
    }

    private func header(_ title: String, _ subtitle: String) -> NSView {
        let t = label(title, 17, .semibold, .labelColor)
        let sub = label(subtitle, 11, .regular, .tertiaryLabelColor)
        let s = FlippedStackView(views: [t, sub])
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 2
        s.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            t.widthAnchor.constraint(equalTo: s.widthAnchor),
            sub.widthAnchor.constraint(equalTo: s.widthAnchor),
        ])
        return s
    }

    private func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = .systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.lineBreakMode = .byTruncatingTail
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }

    private func rounded() -> FlippedStackView {
        let v = FlippedStackView()
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 0
        v.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        v.wantsLayer = true
        v.layer?.cornerRadius = 10
        v.layer?.backgroundColor = Theme.card.cgColor
        v.layer?.borderColor = Theme.border.cgColor
        v.layer?.borderWidth = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func card(_ title: String, _ rows: [NSView]) -> NSView {
        let v = rounded()
        let t = label(title, 12.5, .semibold, .controlAccentColor)
        t.heightAnchor.constraint(equalToConstant: 18).isActive = true
        v.addArrangedSubview(t)
        v.setCustomSpacing(8, after: t)
        // card 左右内边距各 14pt
        t.widthAnchor.constraint(equalTo: v.widthAnchor, constant: -28).isActive = true
        for r in rows {
            v.addArrangedSubview(r)
            r.widthAnchor.constraint(equalTo: v.widthAnchor, constant: -28).isActive = true
        }
        return v
    }

    /// 固定 22px 行高 + 18px 文字高度，杜绝 NSStackView 压缩导致文字被裁
    private func row(_ title: String, _ key: String) -> NSView {
        let r = NSView()
        r.translatesAutoresizingMaskIntoConstraints = false
        r.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let k = label(title, 11.5, .regular, .secondaryLabelColor)
        let v = label("—", 11.5, .medium, .labelColor)
        v.alignment = .right
        v.lineBreakMode = .byTruncatingTail
        v.toolTip = title
        v.isSelectable = true
        bindings[key] = v

        r.addSubview(k); r.addSubview(v)
        NSLayoutConstraint.activate([
            k.leadingAnchor.constraint(equalTo: r.leadingAnchor),
            k.centerYAnchor.constraint(equalTo: r.centerYAnchor),
            k.heightAnchor.constraint(equalToConstant: 18),
            k.widthAnchor.constraint(equalTo: r.widthAnchor, multiplier: 0.52),
            v.leadingAnchor.constraint(equalTo: k.trailingAnchor, constant: 8),
            v.trailingAnchor.constraint(equalTo: r.trailingAnchor),
            v.centerYAnchor.constraint(equalTo: r.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 18),
        ])
        return r
    }

    private func twoColumns(_ a: NSView, _ b: NSView) -> NSView {
        let s = FlippedStackView(views: [a, b])
        s.orientation = .horizontal
        s.distribution = .fillEqually
        s.alignment = .top
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        a.translatesAutoresizingMaskIntoConstraints = false
        b.translatesAutoresizingMaskIntoConstraints = false
        // 两列等高，避免行数不同时高度参差
        a.heightAnchor.constraint(equalTo: b.heightAnchor).isActive = true
        return s
    }

    // MARK: 局部刷新

    func set(_ key: String, _ value: String) {
        if let f = bindings[key], f.stringValue != value { f.stringValue = value }
    }

    func update(_ s: LiveSample, _ history: [LiveSample], sampleCount: Int, interval: TimeInterval, paused: Bool) {
        latestSample = s
        chart.history = history

        set("cpu", percent(s.cpuUsage))
        set("cpuSplit", String(format: "%.1f %% / %.1f %%", s.cpuUser * 100, s.cpuSystem * 100))
        set("cpuIdle", percent(s.cpuIdle))
        set("load", String(format: "%.2f  /  %.2f  /  %.2f", s.load1, s.load5, s.load15))
        set("cores", s.logicalCores > 0 ? "\(s.logicalCores) / \(s.physicalCores)" : "—")

        set("memUsed", "\(humanBytes(s.memUsed)) / \(humanBytes(s.memTotal))")
        set("memRatio", percent(s.memRatio))
        set("memWired", humanBytes(s.memWired))
        set("memCompressed", humanBytes(s.memCompressed))
        set("memCached", humanBytes(s.memCached))
        set("memFree", humanBytes(s.memFree))
        set("swap", s.swapUsed > 0 ? humanBytes(s.swapUsed) : "未使用")
        set("faults", liveCount(s.faultsPerSec))

        set("rx", liveRate(s.netRxPerSec))
        set("tx", liveRate(s.netTxPerSec))
        set("rxTotal", humanBytes(s.netRxTotal))
        set("txTotal", humanBytes(s.netTxTotal))

        set("diskRatio", percent(s.diskRatio))
        set("diskUsed", humanBytes(s.diskTotal > s.diskFree ? s.diskTotal - s.diskFree : 0))
        set("diskFree", humanBytes(s.diskFree))
        set("diskTotal", humanBytes(s.diskTotal))

        if s.hasBattery {
            set("battery", percent(s.batteryLevel))
            let state = s.isCharging ? "充电中"
                : s.fullyCharged ? "已充满 · 外接电源" : s.externalPower ? "外接电源" : "使用电池"
            set("powerState", state)
            set("watts", s.isCharging ? (s.powerW.map { String(format: "%.1f W", $0) } ?? "—") : "未充电")
            set("voltAmp", String(format: "%.2f V / %+.2f A", s.voltageV ?? 0, s.amperageA ?? 0))
            set("battTemp", s.batteryTempC.map { String(format: "%.1f °C", $0) } ?? "—")
            set("timeLeft", s.externalPower ? "接电源中" : liveMinutes(s.minutesRemaining))
            set("cycles", "\(s.cycleCount) 次")
            let health = s.designCapacity > 0 ? Double(s.maxCapacity) / Double(s.designCapacity) : 0
            set("health", health > 0 ? "\(percent(health))  (\(s.maxCapacity) / \(s.designCapacity) mAh)" : "—")
        } else {
            for k in ["battery", "powerState", "watts", "voltAmp", "battTemp", "timeLeft", "cycles", "health"] {
                set(k, "未检测到电池")
            }
        }

        set("uptime", durationString(s.uptime))
        set("processes", s.processCount > 0 ? "\(s.processCount)" : "—")
        set("thermal", s.thermalText)
        set("samples", "\(sampleCount) 次  ·  \(String(format: "%.0f", interval)) 秒间隔\(paused ? "  ·  已暂停" : "")")
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        set("updated", f.string(from: s.time))
    }
}
