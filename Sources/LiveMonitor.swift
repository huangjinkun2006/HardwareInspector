//  LiveMonitor.swift
//  轻量实时采样层：不调用 system_profiler，全部走 Darwin / Mach / IOKit 的低开销接口。
//  一次采样通常 < 2 ms，可以每秒执行；完整检测报告仍由 HardwareCollector.collect() 负责。
//
//  数据来源：
//    · host_statistics(HOST_CPU_LOAD_INFO)   —— CPU tick 增量（用户/系统/空闲）
//    · host_statistics64(HOST_VM_INFO64)     —— 内存分页、压缩、页面错误
//    · getifaddrs + if_data.ifi_i/obytes     —— 网络累计字节，差分得速率
//    · statfs("/")                           —— 启动盘剩余容量
//    · IOKit AppleSmartBattery               —— 电量、充放电、电压、温度
//    · getloadavg / proc_listpids / sysctl   —— 负载、进程数、Swap
//    · ProcessInfo.thermalState              —— 系统热压力

import Foundation
import Darwin
import IOKit

// MARK: - 单次采样快照

func jsonRound(_ x: Double, _ digits: Int = 3) -> Double {
    Double(String(format: "%.\(digits)f", x)) ?? x
}

struct LiveSample: Encodable {
    let time: Date

    // 处理器
    var cpuUsage: Double = 0          // 0...1
    var cpuUser: Double = 0
    var cpuSystem: Double = 0
    var cpuIdle: Double = 0
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0
    var logicalCores: Int = 0
    var physicalCores: Int = 0

    // 内存（字节）
    var memTotal: UInt64 = 0
    var memUsed: UInt64 = 0
    var memFree: UInt64 = 0
    var memWired: UInt64 = 0
    var memCompressed: UInt64 = 0
    var memCached: UInt64 = 0
    var swapUsed: UInt64 = 0
    var faultsPerSec: Double = 0
    var memRatio: Double = 0

    // 磁盘（字节）
    var diskTotal: UInt64 = 0
    var diskFree: UInt64 = 0
    var diskRatio: Double = 0

    // 网络（字节 / 秒 + 累计字节）
    var netRxPerSec: Double = 0
    var netTxPerSec: Double = 0
    var netRxTotal: UInt64 = 0
    var netTxTotal: UInt64 = 0

    // 电池
    var hasBattery: Bool = false
    var batteryLevel: Double = 0
    var isCharging: Bool = false
    var externalPower: Bool = false
    var fullyCharged: Bool = false
    var cycleCount: Int = 0
    var designCapacity: Int = 0
    var maxCapacity: Int = 0
    var currentCapacity: Int = 0
    var batteryTempC: Double?
    var voltageV: Double?
    var amperageA: Double?
    var powerW: Double?
    var minutesRemaining: Int?

    // 系统
    var uptime: TimeInterval = 0
    var processCount: Int = 0
    var thermalText: String = "正常"
    var thermalLevel: Int = 0

    /// 命令行 --live --json 使用。JSONEncoder 用最短浮点表示，
    /// 不会像 JSONSerialization 那样把 0.761 打印成 0.76100000000000001。
    enum CodingKeys: String, CodingKey {
        case time, cpuUsage, cpuUser, cpuSystem, cpuIdle
        case load1, load5, load15, logicalCores, physicalCores
        case memTotal, memUsed, memFree, memWired, memCompressed, memCached
        case swapUsed, faultsPerSec, memRatio
        case diskTotal, diskFree, diskRatio
        case netRxPerSec, netTxPerSec, netRxTotal, netTxTotal
        case hasBattery, batteryLevel, isCharging, externalPower, fullyCharged
        case cycleCount, designCapacity, maxCapacity, currentCapacity
        case batteryTempC, voltageV, amperageA, powerW, minutesRemaining
        case uptime, processCount, thermalLevel
        case thermalText = "thermal"
    }

    func jsonData() -> Data? {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return try? e.encode(self)
    }

    /// 输出前把浮点收敛到合理精度（对界面显示无影响）
    mutating func normalize() {
        cpuUsage = jsonRound(cpuUsage); cpuUser = jsonRound(cpuUser)
        cpuSystem = jsonRound(cpuSystem); cpuIdle = jsonRound(cpuIdle)
        load1 = jsonRound(load1, 2); load5 = jsonRound(load5, 2); load15 = jsonRound(load15, 2)
        memRatio = jsonRound(memRatio); diskRatio = jsonRound(diskRatio)
        batteryLevel = jsonRound(batteryLevel)
        faultsPerSec = Double(Int(max(0, faultsPerSec)))
        netRxPerSec = Double(Int(max(0, netRxPerSec)))
        netTxPerSec = Double(Int(max(0, netTxPerSec)))
        uptime = Double(Int(uptime))
        if let v = batteryTempC { batteryTempC = jsonRound(v, 1) }
        if let v = voltageV { voltageV = jsonRound(v, 2) }
        if let v = amperageA { amperageA = jsonRound(v, 2) }
        if let v = powerW { powerW = jsonRound(v, 1) }
    }

    /// 终端单行摘要
    var oneLine: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        let net = "↓\(humanBytes(UInt64(netRxPerSec)))/s ↑\(humanBytes(UInt64(netTxPerSec)))/s"
        let bat = hasBattery
            ? "电池 \(String(format: "%.0f%%", batteryLevel * 100))\(isCharging ? " 充电中" : (fullyCharged ? " 已充满" : ""))"
            : "无电池"
        return String(format: "%@  CPU %5.1f%%  内存 %5.1f%%  磁盘 %5.1f%%  %@  %@  热压力 %@",
                      f.string(from: time), cpuUsage * 100, memRatio * 100,
                      diskRatio * 100, net, bat, thermalText)
    }
}

// MARK: - 底层读取

enum LiveProbe {

    /// 所有非回环链路的累计收发字节（32 位计数器会回绕，差分时单独处理）
    static func networkTotals() -> (rx: UInt64, tx: UInt64) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }
        var rx: UInt64 = 0, tx: UInt64 = 0
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cur {
            let e = p.pointee
            let name = String(cString: e.ifa_name)
            if e.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               !name.hasPrefix("lo"), let d = e.ifa_data {
                let stat = d.assumingMemoryBound(to: if_data.self).pointee
                rx += UInt64(stat.ifi_ibytes)
                tx += UInt64(stat.ifi_obytes)
            }
            cur = e.ifa_next
        }
        return (rx, tx)
    }

    static func loadAverage() -> (Double, Double, Double) {
        var l = [Double](repeating: 0, count: 3)
        _ = getloadavg(&l, 3)
        return (l[0], l[1], l[2])
    }

    /// proc_listpids 返回所需缓冲区字节数，除以 pid_t 大小即进程数
    static func processCount() -> Int {
        let n = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard n > 0 else { return 0 }
        return Int(n) / MemoryLayout<pid_t>.size
    }

    static func thermal() -> (String, Int) {
        let s = ProcessInfo.processInfo.thermalState
        let text: String
        switch s {
        case .nominal: text = "正常"
        case .fair: text = "偏高 (Fair)"
        case .serious: text = "较高 (Serious)"
        case .critical: text = "过高 (Critical)"
        @unknown default: text = "未知"
        }
        return (text, s.rawValue)
    }

    static func battery(into s: inout LiveSample) {
        guard let b = IO.battery(), (b["BatteryInstalled"] as? NSNumber)?.intValue != 0 else { return }
        func num(_ key: String) -> Double? { (b[key] as? NSNumber)?.doubleValue }

        let cur = num("CurrentCapacity") ?? 0
        let rawMax = num("AppleRawMaxCapacity") ?? num("MaxCapacity") ?? 0
        let design = num("DesignCapacity") ?? 0
        s.hasBattery = rawMax > 0
        s.currentCapacity = Int(cur)
        s.maxCapacity = Int(rawMax)
        s.designCapacity = Int(design)
        s.batteryLevel = rawMax > 0 ? max(0, min(1, cur / rawMax)) : 0
        s.isCharging = (num("IsCharging") ?? 0) != 0
        s.externalPower = (num("ExternalConnected") ?? 0) != 0
        s.fullyCharged = (num("FullyCharged") ?? 0) != 0
        s.cycleCount = Int(num("CycleCount") ?? 0)

        if let t = num("Temperature"), t > 100, t < 9000 { s.batteryTempC = t / 100.0 }
        if let v = num("Voltage"), v > 1000 { s.voltageV = v / 1000.0 }
        if let a = num("InstantAmperage") ?? num("Amperage") {
            // AppleSmartBattery 的电流字段是带符号的 64 位补码，超大值视为无效
            if abs(a) < 100_000 { s.amperageA = a / 1000.0 }
        }
        if let v = s.voltageV, let a = s.amperageA {
            s.powerW = abs(v * a)
        }
        if !s.externalPower {
            let m = num("AvgTimeToEmpty") ?? 0
            if m > 0 && m < 24 * 60 { s.minutesRemaining = Int(m) }
        }
    }
}

// MARK: - 采样器（后台串行队列 + 主线程回调）

final class LiveMonitor {

    /// 历史窗口：1 秒采样时保留约 3 分钟
    private let historyLimit = 180
    private let queue = DispatchQueue(label: "cn.hardwareinspector.live", qos: .utility)
    private var timer: DispatchSourceTimer?

    private var previousTicks: CPUTicks?
    private var previousNet: (rx: UInt64, tx: UInt64, at: Date)?
    private var previousFaults: (count: UInt64, at: Date)?
    private var paused = false

    private(set) var history: [LiveSample] = []
    private(set) var sampleCount = 0

    var interval: TimeInterval = 1.0
    var onUpdate: ((LiveSample, [LiveSample]) -> Void)?

    var isPaused: Bool { paused }

    deinit { timer?.cancel() }

    /// 建立基线：CPU 使用率与网络速率都靠相邻两次采样的差值计算
    func primeBaseline() {
        previousTicks = readCPUTicks()
        let (rx, tx) = LiveProbe.networkTotals()
        previousNet = (rx, tx, Date())
        if let vm = readVMInfo() { previousFaults = (vm.faults, Date()) }
    }

    func start(interval: TimeInterval = 1.0) {
        stop()
        self.interval = max(0.5, interval)
        queue.async { [weak self] in
            guard let self = self else { return }
            self.paused = false
            self.primeBaseline()
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + self.interval, repeating: self.interval,
                       leeway: .milliseconds(120))
            t.setEventHandler { [weak self] in
                guard let self = self, !self.paused else { return }
                let s = self.takeSample()
                self.history.append(s)
                if self.history.count > self.historyLimit {
                    self.history.removeFirst(self.history.count - self.historyLimit)
                }
                self.sampleCount += 1
                let snapshot = self.history
                DispatchQueue.main.async { [weak self] in
                    self?.onUpdate?(s, snapshot)
                }
            }
            self.timer = t
            t.resume()
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func setPaused(_ value: Bool) {
        queue.async { [weak self] in self?.paused = value }
    }

    func setInterval(_ value: TimeInterval) {
        let v = max(0.5, value)
        queue.async { [weak self] in
            guard let self = self, abs(self.interval - v) > 0.01 else { return }
            self.interval = v
            self.timer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + v, repeating: v, leeway: .milliseconds(120))
            t.setEventHandler { [weak self] in
                guard let self = self, !self.paused else { return }
                let s = self.takeSample()
                self.history.append(s)
                if self.history.count > self.historyLimit {
                    self.history.removeFirst(self.history.count - self.historyLimit)
                }
                self.sampleCount += 1
                let snapshot = self.history
                DispatchQueue.main.async { [weak self] in self?.onUpdate?(s, snapshot) }
            }
            self.timer = t
            t.resume()
        }
    }

    /// 供命令行与自检使用；调用方需串行执行（GUI 内部走同一条串行队列）
    func sample() -> LiveSample { takeSample() }

    private func takeSample() -> LiveSample {
        let now = Date()
        var s = LiveSample(time: now)

        // ---- CPU 增量 ----
        if let cur = readCPUTicks() {
            if let prev = previousTicks, cur.total > prev.total {
                let du = cur.user >= prev.user ? cur.user - prev.user : 0
                let ds = cur.system >= prev.system ? cur.system - prev.system : 0
                let dn = cur.nice >= prev.nice ? cur.nice - prev.nice : 0
                let di = cur.idle >= prev.idle ? cur.idle - prev.idle : 0
                let dt = du + ds + dn + di
                if dt > 0 {
                    s.cpuUser = Double(du) / Double(dt)
                    s.cpuSystem = Double(ds + dn) / Double(dt)
                    s.cpuIdle = Double(di) / Double(dt)
                    s.cpuUsage = 1 - s.cpuIdle
                }
            }
            previousTicks = cur
        }
        (s.load1, s.load5, s.load15) = LiveProbe.loadAverage()
        s.logicalCores = Int(Sysctl.uint("hw.logicalcpu") ?? 0)
        s.physicalCores = Int(Sysctl.uint("hw.physicalcpu") ?? 0)

        // ---- 内存 ----
        let totalMem = Sysctl.uint("hw.memsize") ?? UInt64(ProcessInfo.processInfo.physicalMemory)
        s.memTotal = totalMem
        if let vm = readVMInfo() {
            let ps = vm.pageSize
            let free = (vm.free - min(vm.free, vm.speculative)) * ps
            let cached = (vm.inactive + vm.speculative) * ps
            s.memFree = free
            s.memCached = cached
            s.memWired = vm.wired * ps
            s.memCompressed = vm.compressed * ps
            s.memUsed = totalMem > free + cached ? totalMem - free - cached : 0
            if let prev = previousFaults {
                let dt = now.timeIntervalSince(prev.at)
                if dt > 0 && vm.faults >= prev.count {
                    s.faultsPerSec = Double(vm.faults - prev.count) / dt
                }
            }
            previousFaults = (vm.faults, now)
        }
        s.memRatio = totalMem > 0 ? Double(s.memUsed) / Double(totalMem) : 0
        s.swapUsed = Sysctl.swapUsage()?.used ?? 0

        // ---- 磁盘 ----
        if let root = rootVolume() {
            s.diskTotal = root.total
            s.diskFree = root.available
            s.diskRatio = root.total > 0 ? Double(root.total - root.available) / Double(root.total) : 0
        }

        // ---- 网络速率 ----
        let (rx, tx) = LiveProbe.networkTotals()
        s.netRxTotal = rx
        s.netTxTotal = tx
        if let prev = previousNet {
            let dt = now.timeIntervalSince(prev.at)
            if dt > 0 {
                // 计数器回绕 / 接口重置时本次速率记 0，避免出现天文数字
                if rx >= prev.rx { s.netRxPerSec = Double(rx - prev.rx) / dt }
                if tx >= prev.tx { s.netTxPerSec = Double(tx - prev.tx) / dt }
            }
        }
        previousNet = (rx, tx, now)

        // ---- 电池 ----
        LiveProbe.battery(into: &s)

        // ---- 系统 ----
        s.uptime = ProcessInfo.processInfo.systemUptime
        s.processCount = LiveProbe.processCount()
        (s.thermalText, s.thermalLevel) = LiveProbe.thermal()
        s.normalize()
        return s
    }
}

// MARK: - 格式化辅助（实时页与命令行共用）

func liveRate(_ bytesPerSec: Double) -> String {
    humanBytes(UInt64(max(0, bytesPerSec))) + "/s"
}

func liveCount(_ perSec: Double) -> String {
    let v = max(0, perSec)
    return v >= 10_000 ? String(format: "%.1f 万次/秒", v / 10_000) : "\(Int(v)) 次/秒"
}

func liveMinutes(_ minutes: Int?) -> String {
    guard let m = minutes, m > 0 else { return "—" }
    return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟"
}
