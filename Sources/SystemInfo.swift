//  SystemInfo.swift
//  硬件信息采集层：只使用 Apple 原生框架
//    · IOKit           —— 平台序列号 / 主板 / 电池电芯数据
//    · Darwin.sysctl   —— CPU、内存、内核、启动时间、Swap
//    · Mach            —— CPU 负载、虚拟内存统计
//    · getifaddrs      —— 网络接口与 IP
//    · statfs          —— 挂载卷容量
//    · system_profiler —— 显卡、显示器、磁盘、内存条、软件与电源明细

import Foundation
import CoreFoundation
import Darwin
import IOKit

// MARK: - 数据模型

struct HWItem: Codable {
    let label: String
    let value: String
    let hint: String?
}

struct HWSection: Codable {
    let title: String
    let items: [HWItem]
    let brandKey: String?      // 卡片标题旁显示的品牌徽章
}

struct HWGroup: Codable {
    let id: String
    let title: String
    let symbol: String
    let sections: [HWSection]
}

struct HWVital: Codable {
    let title: String
    let value: String
    let detail: String
    let ratio: Double?      // 0...1，用于绘制进度条
}

struct HWReport: Codable {
    let generatedAt: String
    let deviceName: String
    let machineModel: String
    let osVersion: String
    let subtitle: String
    let identity: DeviceIdentity
    let brands: [BrandInfo]
    let vitals: [HWVital]
    let groups: [HWGroup]
}

// MARK: - 通用小工具

typealias JSONDict = [String: Any]

func makeItem(_ label: String, _ value: String?, _ hint: String? = nil) -> HWItem? {
    guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return HWItem(label: label, value: value, hint: hint)
}

func makeSection(_ title: String, _ block: () -> [HWItem?], brand: String? = nil) -> HWSection? {
    let items = block().compactMap { $0 }
    return items.isEmpty ? nil : HWSection(title: title, items: items, brandKey: brand)
}

func appendSections(_ list: inout [HWSection], _ candidates: [HWSection?]) {
    list.append(contentsOf: candidates.compactMap { $0 })
}

func humanBytes(_ b: UInt64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .decimal
    f.allowsNonnumericFormatting = false
    return f.string(fromByteCount: Int64(min(b, UInt64(Int64.max))))
}

func percent(_ ratio: Double) -> String { String(format: "%.1f %%", max(0, min(1, ratio)) * 100) }

func durationString(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    if d > 0 { return "\(d) 天 \(h) 小时 \(m) 分" }
    if h > 0 { return "\(h) 小时 \(m) 分" }
    return "\(m) 分钟"
}

func isoNow() -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: Date())
}

func formattedDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f.string(from: d)
}

func humanNow() -> String { formattedDate(Date()) }

/// 把 system_profiler 里的枚举值翻译成可读中文
func prettify(_ raw: String) -> String {
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return "" }
    // 全部按小写匹配，兼容 system_profiler 不同大小写 / 不同语言环境的取值
    let map: [String: String] = [
        "integrity_enabled": "已启用", "integrity_disabled": "已关闭",
        "normal_boot": "正常模式", "safe_boot": "安全模式",
        "secure_vm_enabled": "已启用", "secure_vm_disabled": "未启用",
        "htt_enabled": "已启用", "htt_disabled": "未启用",
        "ecc_disabled": "未启用", "ecc_enabled": "已启用",
        "ssd": "固态硬盘 (SSD)", "hdd": "机械硬盘 (HDD)", "rotational": "机械硬盘 (HDD)",
        "sppci_vendor_nvidia": "NVIDIA", "sppci_vendor_intel": "Intel",
        "sppci_vendor_ati": "AMD", "sppci_vendor_amd": "AMD", "sppci_vendor_apple": "Apple",
        "spdisplays_pcie_device": "PCI Express", "spdisplays_gpu": "图形处理器",
        "spdisplays_yes": "是", "spdisplays_no": "否",
        "spdisplays_metal4": "Metal 4", "spdisplays_metal3": "Metal 3",
        "spdisplays_metal2": "Metal 2", "spdisplays_metal1": "Metal 1",
        "guid_partition_map_type": "GUID 分区表",
        "master boot record partition map type": "MBR 主引导记录",
        "unknown partition map type": "未知分区表",
        "yes": "是", "no": "否", "true": "是", "false": "否",
        "ok": "正常", "verified": "正常 (Verified)", "failing": "异常 (Failing)",
        "check battery": "建议检修电池", "good": "正常", "normal": "正常",
        "spairport_security_mode_wpa2_personal": "WPA2 个人级",
        "spairport_security_mode_wpa3_personal": "WPA3 个人级",
        "autoselect": "自动选择", "automatic": "自动", "dhcp": "DHCP",
        "internal": "内置显示器", "external": "外接显示器",
        "spdisplays_1080p": "1080p", "spdisplays_retina": "Retina",
        "displayport hdcp capable": "支持 HDCP",
        "spdisplays_displayport_hdcp_capable": "支持 HDCP",
    ]
    let lower = key.lowercased()
    if let v = map[lower] { return v }
    if lower.hasPrefix("sppci_vendor_") { return String(key.dropFirst("sppci_vendor_".count)).uppercased() }
    if lower.hasPrefix("spdisplays_metal") { return "Metal " + String(key.dropFirst("spdisplays_metal".count)) }
    if lower.hasPrefix("spdisplays_") {
        let rest = String(key.dropFirst("spdisplays_".count)).replacingOccurrences(of: "_", with: " ")
        return map[rest.lowercased()] ?? rest
    }
    return key.replacingOccurrences(of: "_", with: " ")
}

func jsonArray(_ value: Any?) -> [JSONDict] {
    (value as? [Any])?.compactMap { $0 as? JSONDict } ?? []
}
func jsonDict(_ value: Any?) -> JSONDict { value as? JSONDict ?? [:] }
func jsonString(_ d: JSONDict, _ keys: [String]) -> String? {
    for k in keys {
        guard let v = d[k] else { continue }
        if let s = v as? String, !s.isEmpty { return s }
        if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.stringValue }
    }
    return nil
}
func jsonUInt(_ v: Any?) -> UInt64? {
    guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
    let d = n.doubleValue
    return d >= 0 && d.isFinite ? UInt64(d) : nil
}
func jsonInt(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
func joined(_ parts: [String?], _ sep: String = " / ") -> String? {
    let v = parts.compactMap { $0 }.filter { !$0.isEmpty }
    return v.isEmpty ? nil : v.joined(separator: sep)
}

// MARK: - sysctl

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size + 1)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }

    static func uint(_ name: String) -> UInt64? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        switch size {
        case 4:
            var v: UInt32 = 0
            return sysctlbyname(name, &v, &size, nil, 0) == 0 ? UInt64(v) : nil
        case 8:
            var v: UInt64 = 0
            return sysctlbyname(name, &v, &size, nil, 0) == 0 ? v : nil
        default:
            var v: Int32 = 0
            return sysctlbyname(name, &v, &size, nil, 0) == 0 && v >= 0 ? UInt64(v) : nil
        }
    }

    static func flag(_ name: String) -> Bool { uint(name) == 1 }

    /// kern.boottime (struct timeval)
    static func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }

    struct SwapUsage { let total, avail, used: UInt64; let encrypted: Bool }

    /// vm.swapusage (struct xsw_usage)
    static func swapUsage() -> SwapUsage? {
        var u = XSwUsage()
        var size = MemoryLayout<XSwUsage>.size
        guard sysctlbyname("vm.swapusage", &u, &size, nil, 0) == 0,
              size == MemoryLayout<XSwUsage>.size else { return nil }
        return SwapUsage(total: u.total, avail: u.avail, used: u.used, encrypted: u.encrypted != 0)
    }
}

private struct XSwUsage {
    var total: UInt64 = 0
    var avail: UInt64 = 0
    var used: UInt64 = 0
    var pageSize: UInt32 = 0
    var encrypted: UInt32 = 0     // C 里的 boolean_t 是 4 字节 unsigned int
}

// MARK: - Mach 统计

struct CPUTicks {
    let user, system, idle, nice: UInt64
    var total: UInt64 { user + system + idle + nice }
}

func readCPUTicks() -> CPUTicks? {
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    var info = host_cpu_load_info_data_t()
    let kr = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    return CPUTicks(user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1),
                    idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
}

/// 采样 250 ms 得到瞬时 CPU 占用率
func sampleCPUUsage() -> Double? {
    guard let a = readCPUTicks() else { return nil }
    usleep(250_000)
    guard let b = readCPUTicks() else { return nil }
    guard b.total > a.total else { return nil }
    let dt = b.total - a.total
    let di = b.idle >= a.idle ? b.idle - a.idle : 0
    return Double(dt - di) / Double(dt)
}

struct VMInfo {
    let pageSize: UInt64
    let free, active, inactive, wired, speculative: UInt64
    let compressed, purgeable, internalPages, externalPages: UInt64
    let pageins, pageouts, swapins, swapouts, faults: UInt64
    func bytes(_ pages: UInt64) -> UInt64 { pages * pageSize }
}

func readVMInfo() -> VMInfo? {
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    var info = vm_statistics64_data_t()
    let kr = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return nil }
    let ps = Sysctl.uint("hw.pagesize") ?? 4096
    return VMInfo(
        pageSize: ps,
        free: UInt64(info.free_count), active: UInt64(info.active_count),
        inactive: UInt64(info.inactive_count), wired: UInt64(info.wire_count),
        speculative: UInt64(info.speculative_count),
        compressed: UInt64(info.compressor_page_count),
        purgeable: UInt64(info.purgeable_count),
        internalPages: UInt64(info.internal_page_count),
        externalPages: UInt64(info.external_page_count),
        pageins: UInt64(info.pageins), pageouts: UInt64(info.pageouts),
        swapins: UInt64(info.swapins), swapouts: UInt64(info.swapouts),
        faults: UInt64(info.faults))
}

// MARK: - IOKit

enum IO {
    static func platformProperties() -> [String: Any] {
        let s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard s != 0 else { return [:] }
        defer { IOObjectRelease(s) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(s, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let cf = props?.takeRetainedValue() else { return [:] }
        return cf as? [String: Any] ?? [:]
    }

    static func dataAsString(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        guard let d = value as? Data else { return nil }
        var bytes = [UInt8](d)
        if bytes.last == 0 { bytes.removeLast() }
        return String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
    }

    static func battery() -> [String: Any]? {
        let s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard s != 0 else { return nil }
        defer { IOObjectRelease(s) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(s, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let cf = props?.takeRetainedValue() else { return nil }
        return cf as? [String: Any]
    }
}

// MARK: - 网络接口 (getifaddrs)

struct NetInterface {
    let name: String
    var mac: String?
    var ipv4: [String] = []
    var ipv6: [String] = []
    var isUp = false
    var isLoopback = false
}

func readInterfaces() -> [NetInterface] {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return [] }
    defer { freeifaddrs(head) }
    var result: [String: NetInterface] = [:]
    var cur: UnsafeMutablePointer<ifaddrs>? = first
    while let p = cur {
        let entry = p.pointee
        let name = String(cString: entry.ifa_name)
        var info = result[name] ?? NetInterface(name: name)
        info.isUp = info.isUp || (entry.ifa_flags & UInt32(IFF_UP)) != 0
        info.isLoopback = name.hasPrefix("lo")
        if let sa = entry.ifa_addr {
            switch Int32(sa.pointee.sa_family) {
            case AF_INET:
                var addr = UnsafeRawPointer(sa).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
                    info.ipv4.append(String(cString: buf))
                }
            case AF_INET6:
                var addr = UnsafeRawPointer(sa).assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr
                var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                if inet_ntop(AF_INET6, &addr, &buf, socklen_t(INET6_ADDRSTRLEN)) != nil {
                    info.ipv6.append(String(cString: buf))
                }
            case AF_LINK:
                let base = UnsafeRawPointer(sa)
                let nlen = Int(base.load(fromByteOffset: 4, as: UInt8.self))
                let alen = Int(base.load(fromByteOffset: 5, as: UInt8.self))
                if alen == 6 {
                    let data = base.advanced(by: 8).assumingMemoryBound(to: UInt8.self)
                    let octets = (0..<alen).map { data[nlen + $0] }
                    info.mac = octets.map { String(format: "%02x", $0) }.joined(separator: ":")
                }
            default: break
            }
        }
        result[name] = info
        cur = entry.ifa_next
    }
    return result.values.sorted {
        let rank: (String) -> Int = { $0 == "en0" ? 0 : ($0 == "en1" ? 1 : ($0.hasPrefix("lo") ? 9 : 2)) }
        return (rank($0.name), $0.name) < (rank($1.name), $1.name)
    }
}

// MARK: - 挂载卷 (statfs)

struct MountedVolume { let total, available: UInt64 }

func rootVolume() -> MountedVolume? {
    var st = statfs()
    guard statfs("/", &st) == 0 else { return nil }
    let block = UInt64(st.f_bsize)
    return MountedVolume(total: UInt64(st.f_blocks) * block, available: UInt64(st.f_bavail) * block)
}

// MARK: - system_profiler

private final class DataBox { var data: Data? }

enum Profiler {
    /// 一次性取回所需数据类型；带 15 秒超时，避免异常机器卡死界面
    static func load() -> JSONDict {
        let types = ["SPHardwareDataType", "SPSoftwareDataType", "SPMemoryDataType",
                     "SPDisplaysDataType", "SPStorageDataType", "SPPowerDataType",
                     "SPNetworkDataType", "SPAirPortDataType"]
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["-json"] + types
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return [:] }
        let box = DataBox()
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.data = out.fileHandleForReading.readDataToEndOfFile()
            sem.signal()
        }
        if sem.wait(timeout: .now() + 15) == .timedOut {
            p.terminate()
            return [:]
        }
        guard let data = box.data,
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? JSONDict else { return [:] }
        return dict
    }
}

// MARK: - 主采集器

enum HardwareCollector {

    static func collect() -> HWReport {
        let prof = Profiler.load()
        let hw = jsonArray(prof["SPHardwareDataType"]).first.map(jsonDict) ?? [:]
        let sw = jsonArray(prof["SPSoftwareDataType"]).first.map(jsonDict) ?? [:]
        let memRoot = jsonArray(prof["SPMemoryDataType"]).first.map(jsonDict) ?? [:]
        let platform = IO.platformProperties()
        let battery = IO.battery()

        let osVersion = jsonString(sw, ["os_version"])
            ?? "macOS " + ProcessInfo.processInfo.operatingSystemVersionString
        let modelID = jsonString(hw, ["machine_model"]) ?? Sysctl.string("hw.model") ?? "未知机型"
        let machineName = jsonString(hw, ["machine_name"]) ?? "Mac"
        let cpuName = jsonString(hw, ["chip_type", "cpu_type"])
            ?? Sysctl.string("machdep.cpu.brand_string")?.trimmingCharacters(in: .whitespaces)
            ?? "未知处理器"

        let totalMem = Sysctl.uint("hw.memsize") ?? UInt64(ProcessInfo.processInfo.physicalMemory)
        let vm = readVMInfo()
        let cpuNow = sampleCPUUsage()
        let cpuTicks = readCPUTicks()
        let swap = Sysctl.swapUsage()
        let bootDate = Sysctl.bootTime()
        let uptime = bootDate.map { Date().timeIntervalSince($0) } ?? ProcessInfo.processInfo.systemUptime
        let root = rootVolume()
        let interfaces = readInterfaces()
        let smbios = SMBIOSReader.read()
        let (identity, detectedBrands) = BrandDetector.detect(
            hw: hw, prof: prof, platform: platform, batteryIOK: battery,
            cpuName: cpuName, modelID: modelID, machineName: machineName, smbios: smbios)

        // 内存占用 = 物理内存 - 空闲 - 可回收缓存
        let freeBytes: UInt64 = vm.map { ($0.free - min($0.free, $0.speculative)) * $0.pageSize } ?? 0
        let reclaimable: UInt64 = vm.map { ($0.inactive + $0.speculative) * $0.pageSize } ?? 0
        let usedMem = totalMem > freeBytes + reclaimable ? totalMem - freeBytes - reclaimable : 0
        let memRatio = totalMem > 0 ? Double(usedMem) / Double(totalMem) : 0
        let diskRatio = root.map { $0.total > 0 ? Double($0.total - $0.available) / Double($0.total) : 0 } ?? 0

        // ---------- 概览 ----------
        var overviewSections: [HWSection] = []
        appendSections(&overviewSections, [
            makeSection("设备标识", {
                [
                    makeItem("设备名称", machineName),
                    makeItem("机型标识", modelID),
                    makeItem("序列号", jsonString(hw, ["serial_number"]) ?? IO.dataAsString(platform["IOPlatformSerialNumber"])),
                    makeItem("硬件 UUID", jsonString(hw, ["platform_UUID"]) ?? IO.dataAsString(platform["IOPlatformUUID"])),
                    makeItem("主板 ID", IO.dataAsString(platform["board-id"])),
                    makeItem("制造商", IO.dataAsString(platform["manufacturer"])),
                    makeItem("Boot ROM", jsonString(hw, ["boot_rom_version"])),
                    makeItem("引导器版本", jsonString(hw, ["os_loader_version"])),
                ]
            }, brand: identity.primaryBrandKey),
            makeSection("运行环境", {
                [
                    makeItem("操作系统", osVersion),
                    makeItem("内核版本", jsonString(sw, ["kernel_version"]) ?? Sysctl.string("kern.version")),
                    makeItem("编译版本", Sysctl.string("kern.osversion")),
                    makeItem("启动磁盘", jsonString(sw, ["boot_volume"])),
                    makeItem("启动模式", prettify(jsonString(sw, ["boot_mode"]) ?? "")),
                    makeItem("电脑名称", jsonString(sw, ["local_host_name"])),
                    makeItem("当前用户", jsonString(sw, ["user_name"])),
                    makeItem("已运行", durationString(uptime)),
                    makeItem("本次开机时间", bootDate.map(formattedDate)),
                ]
            }),
            makeSection("实时状态", {
                [
                    makeItem("CPU 使用率", cpuNow.map { percent($0) }),
                    makeItem("内存占用", "\(humanBytes(usedMem)) / \(humanBytes(totalMem))  ·  \(percent(memRatio))"),
                    makeItem("启动盘占用", root.map { "\(humanBytes($0.total - $0.available)) / \(humanBytes($0.total))  ·  \(percent(diskRatio))" }),
                    makeItem("热压力状态", thermalText()),
                    battery.flatMap { makeItem("电池电量", batteryPercent($0)) },
                    makeItem("处理器温度", "—", "本版本不读取 SMC 底层传感器，避免对非标准机型造成风险"),
                ]
            }),
        ])
        let overview = HWGroup(id: "overview", title: "概览", symbol: "desktopcomputer", sections: overviewSections)

        // ---------- 处理器 ----------
        let physicalCPU = Sysctl.uint("hw.physicalcpu")
        let logicalCPU = Sysctl.uint("hw.logicalcpu") ?? UInt64(ProcessInfo.processInfo.processorCount)
        var cpuSections: [HWSection] = []
        appendSections(&cpuSections, [
            makeSection("规格", {
                [
                    makeItem("处理器型号", cpuName),
                    makeItem("架构", Sysctl.string("hw.machine") ?? (Sysctl.flag("hw.optional.arm64") ? "arm64" : "x86_64")),
                    makeItem("制造商", Sysctl.string("machdep.cpu.vendor")),
                    makeItem("标称主频", jsonString(hw, ["current_processor_speed"])),
                    makeItem("总线频率", Sysctl.uint("hw.cpufrequency").map { String(format: "%.2f GHz", Double($0) / 1_000_000_000) }),
                    makeItem("物理封装", jsonInt(hw["packages"]).map { "\($0)" }),
                    makeItem("物理核心", physicalCPU.map { "\($0) 核" }),
                    makeItem("逻辑核心", "\(logicalCPU) 线程"),
                    makeItem("超线程", prettify(jsonString(hw, ["platform_cpu_htt"]) ?? (logicalCPU > (physicalCPU ?? 0) ? "已启用" : "未启用"))),
                    makeItem("每核二级缓存", jsonString(hw, ["l2_cache_core"])),
                    makeItem("三级缓存", jsonString(hw, ["l3_cache"])),
                    makeItem("二级缓存总量", Sysctl.uint("hw.l2cachesize").map(humanBytes)),
                    makeItem("缓存行大小", Sysctl.uint("hw.cachelinesize").map { "\($0) 字节" }),
                ]
            }, brand: BrandDetector.key(for: cpuName)),
            makeSection("指令集与特性", {
                [
                    makeItem("AES 硬件加速", Sysctl.flag("hw.optional.aes") ? "支持" : "不支持"),
                    makeItem("AVX", Sysctl.flag("hw.optional.avx1_0") ? "支持" : "不支持"),
                    makeItem("AVX2", Sysctl.flag("hw.optional.avx2_0") ? "支持" : "不支持"),
                    makeItem("ARM64", Sysctl.flag("hw.optional.arm64") ? "支持" : "不适用"),
                    makeItem("CPU 特性标志", Sysctl.string("machdep.cpu.features")),
                    makeItem("扩展特性标志", Sysctl.string("machdep.cpu.extfeatures")),
                    makeItem("Family / Model", joined([
                        Sysctl.uint("machdep.cpu.family").map { "\($0)" },
                        Sysctl.uint("machdep.cpu.model").map { "\($0)" },
                    ])),
                ]
            }),
            makeSection("负载统计（自开机累计）", {
                guard let t = cpuTicks, t.total > 0 else { return [] }
                return [
                    makeItem("用户态", percent(Double(t.user) / Double(t.total))),
                    makeItem("系统态", percent(Double(t.system) / Double(t.total))),
                    makeItem("空闲", percent(Double(t.idle) / Double(t.total))),
                    makeItem("Nice", percent(Double(t.nice) / Double(t.total))),
                    makeItem("瞬时采样 (250 ms)", cpuNow.map { percent($0) }),
                    makeItem("活跃处理器数", "\(ProcessInfo.processInfo.activeProcessorCount) / \(ProcessInfo.processInfo.processorCount)"),
                ]
            }),
        ])
        let cpuGroup = HWGroup(id: "cpu", title: "处理器", symbol: "cpu", sections: cpuSections)

        // ---------- 内存 ----------
        var memorySections: [HWSection] = []
        appendSections(&memorySections, [
            makeSection("内存总览", {
                [
                    makeItem("总容量", humanBytes(totalMem)),
                    makeItem("已使用", "\(humanBytes(usedMem))  ·  \(percent(memRatio))"),
                    makeItem("可回收缓存", humanBytes(reclaimable)),
                    makeItem("可用", humanBytes(freeBytes + reclaimable)),
                    makeItem("页面大小", vm.map { humanBytes($0.pageSize) }),
                    makeItem("内存是否可升级", prettify(jsonString(memRoot, ["is_memory_upgradeable"]) ?? "")),
                    makeItem("ECC", prettify(jsonString(memRoot, ["global_ecc_state"]) ?? "")),
                    makeItem("交换分区总量", swap.map { humanBytes($0.total) }),
                    makeItem("交换分区已用", swap.map { "\(humanBytes($0.used))  ·  \($0.encrypted ? "已加密" : "未加密")" }),
                ]
            }),
        ])
        let dimms = jsonArray(memRoot["_items"])
        if dimms.isEmpty {
            appendSections(&memorySections, [
                makeSection("内存规格", { [makeItem("类型", "统一内存 / 板载内存", "未检测到可枚举的内存插槽")] }),
            ])
        } else {
            for (i, d) in dimms.enumerated() {
                if let s = makeSection("内存条 \(i + 1)  ·  \(jsonString(d, ["_name"]) ?? "插槽")", {
                    [
                        makeItem("容量", jsonString(d, ["dimm_size"])),
                        makeItem("类型", jsonString(d, ["dimm_type"])),
                        makeItem("频率", jsonString(d, ["dimm_speed"])),
                        makeItem("厂商", jsonString(d, ["dimm_manufacturer"])),
                        makeItem("部件号", jsonString(d, ["dimm_part_number"])),
                        makeItem("序列号", jsonString(d, ["dimm_serial_number"])),
                        makeItem("状态", prettify(jsonString(d, ["dimm_status"]) ?? "")),
                    ]
                }, brand: BrandDetector.key(for: jsonString(d, ["dimm_manufacturer"]) ?? "")) { memorySections.append(s) }
            }
        }
        if let v = vm {
            appendSections(&memorySections, [
                makeSection("虚拟内存明细（页计数换算）", {
                    [
                        makeItem("联动内存 (Wired)", humanBytes(v.bytes(v.wired))),
                        makeItem("活跃 (Active)", humanBytes(v.bytes(v.active))),
                        makeItem("非活跃 (Inactive)", humanBytes(v.bytes(v.inactive))),
                        makeItem("压缩内存", humanBytes(v.bytes(v.compressed))),
                        makeItem("空闲 (Free)", humanBytes(v.bytes(v.free))),
                        makeItem("推测页 (Speculative)", humanBytes(v.bytes(v.speculative))),
                        makeItem("可清除 (Purgeable)", humanBytes(v.bytes(v.purgeable))),
                        makeItem("内部页 / 外部页", "\(v.internalPages) / \(v.externalPages) 页"),
                        makeItem("换入 / 换出", "\(v.pageins) / \(v.pageouts) 页"),
                        makeItem("Swap 换入 / 换出", "\(v.swapins) / \(v.swapouts) 页"),
                        makeItem("缺页异常", "\(v.faults) 次"),
                    ]
                }),
            ])
        }
        let memoryGroup = HWGroup(id: "memory", title: "内存", symbol: "memorychip", sections: memorySections)

        // ---------- 显卡与显示器 ----------
        var displaySections: [HWSection] = []
        let gpus = jsonArray(prof["SPDisplaysDataType"])
        if gpus.isEmpty {
            appendSections(&displaySections, [makeSection("图形处理器", { [makeItem("状态", "未检测到图形设备信息")] })])
        }
        for (i, g) in gpus.enumerated() {
            if let s = makeSection("显卡 \(i + 1)  ·  \(jsonString(g, ["_name"]) ?? "GPU")", {
                [
                    makeItem("名称", jsonString(g, ["sppci_model", "_name"])),
                    makeItem("厂商", prettify(jsonString(g, ["spdisplays_vendor"]) ?? "")),
                    makeItem("显存", jsonString(g, ["spdisplays_vram", "spdisplays_vram_shared"])),
                    makeItem("设备 ID", jsonString(g, ["spdisplays_device-id"])),
                    makeItem("修订 ID", jsonString(g, ["spdisplays_revision-id"])),
                    makeItem("总线", prettify(jsonString(g, ["sppci_bus"]) ?? "")),
                    makeItem("链路宽度", jsonString(g, ["spdisplays_pcie_width"])),
                    makeItem("Metal 支持", prettify(jsonString(g, ["spdisplays_mtlgpufamilysupport"]) ?? "")),
                ]
            }, brand: BrandDetector.key(for: (jsonString(g, ["_name"]) ?? "") + " " +
                                        (jsonString(g, ["spdisplays_vendor"]) ?? ""))) { displaySections.append(s) }
            for d in jsonArray(g["spdisplays_ndrvs"]) {
                let dp = jsonDict(d["_spdisplays_displayport_device"])
                if let s = makeSection("显示器  ·  \(jsonString(d, ["_name"]) ?? "内置显示器")", {
                    [
                        makeItem("名称", jsonString(d, ["_name"])),
                        makeItem("分辨率", jsonString(d, ["spdisplays_resolution", "_spdisplays_resolution"])),
                        makeItem("像素密度", jsonString(d, ["spdisplays_pixelresolution"]).map(prettify)),
                        makeItem("刷新率", jsonString(d, ["spdisplays_refresh_rate"])),
                        makeItem("UI 外观", jsonString(d, ["spdisplays_ui_appearance"])),
                        makeItem("主显示器", jsonString(d, ["spdisplays_main"]).map(prettify)),
                        makeItem("连接类型", jsonString(d, ["spdisplays_connection_type"]).map(prettify)),
                        makeItem("DisplayPort 带宽", jsonString(dp, ["spdisplays_displayport_current_bandwidth"])),
                        makeItem("DisplayPort 通道", jsonString(dp, ["spdisplays_displayport_current_lanes"]).map { "×\($0)" }),
                        makeItem("产品 ID", jsonString(d, ["_spdisplays_display-product-id"])),
                        makeItem("显示器序列号", jsonString(d, ["_spdisplays_display-serial-number"])),
                        makeItem("生产年 / 周", joined([
                            jsonString(d, ["_spdisplays_display-year"]),
                            jsonString(d, ["_spdisplays_display-week"]),
                        ])),
                        makeItem("HDCP", jsonString(dp, ["spdisplays_displayport_hdcp_capability"]).map(prettify)),
                    ]
                }, brand: displayBrandKey(jsonString(d, ["_name"]) ?? "")) { displaySections.append(s) }
            }
        }
        let graphicsGroup = HWGroup(id: "graphics", title: "显卡与显示", symbol: "display", sections: displaySections)

        // ---------- 存储 ----------
        var storageSections: [HWSection] = []
        let volumes = jsonArray(prof["SPStorageDataType"])
        var seenDrives = Set<String>()
        for v in volumes {
            let pd = jsonDict(v["physical_drive"])
            let driveKey = jsonString(pd, ["device_name"]) ?? jsonString(v, ["bsd_name"]) ?? UUID().uuidString
            guard !seenDrives.contains(driveKey) else { continue }
            seenDrives.insert(driveKey)
            if let s = makeSection("物理磁盘  ·  \(driveKey)", {
                [
                    makeItem("型号", jsonString(pd, ["device_name"])),
                    makeItem("介质名称", jsonString(pd, ["media_name"])),
                    makeItem("介质类型", prettify(jsonString(pd, ["medium_type"]) ?? "")),
                    makeItem("接口协议", jsonString(pd, ["protocol"])),
                    makeItem("内置磁盘", prettify(jsonString(pd, ["is_internal_disk"]) ?? "")),
                    makeItem("分区图", prettify(jsonString(pd, ["partition_map_type"]) ?? "")),
                    makeItem("SMART 状态", prettify(jsonString(pd, ["smart_status"]) ?? "")),
                    makeItem("磁盘总容量", jsonUInt(pd["size_in_bytes"]).map(humanBytes)),
                ]
            }, brand: BrandDetector.key(for: driveKey)) { storageSections.append(s) }
        }
        for v in volumes {
            let total = jsonUInt(v["size_in_bytes"]) ?? 0
            let free = jsonUInt(v["free_space_in_bytes"]) ?? 0
            let used = total > free ? total - free : 0
            if let s = makeSection("卷  ·  \(jsonString(v, ["_name"]) ?? "未命名")", {
                [
                    makeItem("卷名称", jsonString(v, ["_name"])),
                    makeItem("BSD 设备", jsonString(v, ["bsd_name"])),
                    makeItem("文件系统", jsonString(v, ["file_system"])),
                    makeItem("挂载点", jsonString(v, ["mount_point"])),
                    makeItem("总容量", total > 0 ? humanBytes(total) : nil),
                    makeItem("已使用", total > 0 ? "\(humanBytes(used))  ·  \(percent(Double(used) / Double(total)))" : nil),
                    makeItem("可用", total > 0 ? humanBytes(free) : nil),
                    makeItem("可写", prettify(jsonString(v, ["writable"]) ?? "")),
                    makeItem("卷 UUID", jsonString(v, ["volume_uuid"])),
                ]
            }) { storageSections.append(s) }
        }
        if storageSections.isEmpty {
            appendSections(&storageSections, [
                makeSection("启动卷 (statfs)", {
                    [makeItem("总容量", root.map { humanBytes($0.total) }),
                     makeItem("可用", root.map { humanBytes($0.available) })]
                }),
            ])
        }
        let storageGroup = HWGroup(id: "storage", title: "存储", symbol: "internaldrive", sections: storageSections)

        // ---------- 电池与电源 ----------
        let powerGroup = HWGroup(id: "power", title: "电池与电源", symbol: "battery.100",
                                 sections: batterySections(battery: battery, prof: prof))

        // ---------- 网络 ----------
        var networkSections: [HWSection] = []
        let spNets = jsonArray(prof["SPNetworkDataType"])
        for n in spNets {
            let bsd = jsonString(n, ["interface"]) ?? ""
            let iface = interfaces.first { $0.name == bsd }
            let eth = jsonDict(n["Ethernet"])
            let ip4 = jsonDict(n["IPv4"])
            let ip6 = jsonDict(n["IPv6"])
            let dns = jsonDict(n["DNS"])
            if let s = makeSection("接口  ·  \(jsonString(n, ["_name"]) ?? bsd)", {
                [
                    makeItem("服务名称", jsonString(n, ["_name"])),
                    makeItem("BSD 设备", bsd),
                    makeItem("硬件类型", jsonString(n, ["hardware", "type"])),
                    makeItem("MAC 地址", jsonString(eth, ["MAC Address"]) ?? iface?.mac),
                    makeItem("IPv4 地址", (ip4["Addresses"] as? [String])?.joined(separator: ", ") ?? iface?.ipv4.joined(separator: ", ")),
                    makeItem("IPv6 地址", (ip6["Addresses"] as? [String])?.joined(separator: ", ") ?? iface?.ipv6.joined(separator: ", ")),
                    makeItem("IPv4 配置", jsonString(ip4, ["ConfigMethod"]).map(prettify)),
                    makeItem("IPv6 配置", jsonString(ip6, ["ConfigMethod"]).map(prettify)),
                    makeItem("路由器", jsonString(ip4, ["Router"])),
                    makeItem("子网掩码", (ip4["SubnetMasks"] as? [String])?.joined(separator: ", ")),
                    makeItem("DNS", (dns["ServerAddresses"] as? [String])?.joined(separator: ", ")),
                    makeItem("接口状态", iface.map { $0.isUp ? "已启用" : "未启用" }),
                    makeItem("介质子类型", jsonString(eth, ["MediaSubType"]).map(prettify)),
                ]
            }) { networkSections.append(s) }
        }
        for ap in jsonArray(prof["SPAirPortDataType"]) {
            for itf in jsonArray(ap["spairport_airport_interfaces"]) {
                let cur = jsonDict(itf["spairport_current_network_information"])
                guard !cur.isEmpty else { continue }
                if let s = makeSection("无线局域网  ·  \(jsonString(itf, ["_name"]) ?? "Wi-Fi")", {
                    [
                        makeItem("当前网络", jsonString(cur, ["_name"]),
                                 jsonString(cur, ["_name"]) == "<redacted>"
                                    ? "系统隐私保护隐藏了 SSID，可在「系统设置 → 隐私与安全性」中授权后重试" : nil),
                        makeItem("信道 / 频段", jsonString(cur, ["spairport_network_channel"])),
                        makeItem("PHY 模式", jsonString(cur, ["spairport_network_phymode"])),
                        makeItem("信号 / 噪声", jsonString(cur, ["spairport_signal_noise"])),
                        makeItem("加密方式", prettify(jsonString(cur, ["spairport_security_mode"]) ?? "")),
                        makeItem("周边网络数", "\(jsonArray(itf["spairport_airport_other_local_wireless_networks"]).count)"),
                        makeItem("接口", jsonString(itf, ["_name"])),
                    ]
                }) { networkSections.append(s) }
            }
        }
        let listed = Set(spNets.compactMap { jsonString($0, ["interface"]) })
        for i in interfaces where !listed.contains(i.name) && (!i.ipv4.isEmpty || !i.ipv6.isEmpty) {
            if let s = makeSection("其他接口  ·  \(i.name)", {
                [
                    makeItem("BSD 设备", i.name),
                    makeItem("MAC 地址", i.mac),
                    makeItem("IPv4", i.ipv4.isEmpty ? nil : i.ipv4.joined(separator: ", ")),
                    makeItem("IPv6", i.ipv6.isEmpty ? nil : i.ipv6.joined(separator: ", ")),
                    makeItem("状态", i.isUp ? "已启用" : "未启用"),
                    makeItem("回环接口", i.isLoopback ? "是" : nil),
                ]
            }) { networkSections.append(s) }
        }
        if networkSections.isEmpty {
            appendSections(&networkSections, [makeSection("网络接口", { [makeItem("状态", "未检测到网络接口信息")] })])
        }
        let networkGroup = HWGroup(id: "network", title: "网络", symbol: "network", sections: networkSections)

        // ---------- 系统与传感器 ----------
        var systemSections: [HWSection] = []
        appendSections(&systemSections, [
            makeSection("系统信息", {
                [
                    makeItem("系统版本", osVersion),
                    makeItem("系统内部版本", Sysctl.string("kern.osversion")),
                    makeItem("Darwin 内核", Sysctl.string("kern.version")),
                    makeItem("内核架构", Sysctl.string("kern.arch") ?? Sysctl.string("hw.machine")),
                    makeItem("字节序", Sysctl.uint("hw.byteorder").map { $0 == 1234 ? "小端 (Little Endian)" : "大端 (Big Endian)" }),
                    makeItem("主机名称", ProcessInfo.processInfo.hostName),
                    makeItem("登录用户", NSUserName()),
                    makeItem("时区", TimeZone.current.localizedName(for: .standard, locale: Locale(identifier: "zh_CN"))),
                    makeItem("首选语言", Locale.preferredLanguages.first),
                    makeItem("系统运行时间", durationString(uptime)),
                    makeItem("采集时间", humanNow()),
                ]
            }),
            makeSection("安全与启动", {
                [
                    makeItem("系统完整性保护 (SIP)", prettify(jsonString(sw, ["system_integrity"]) ?? "")),
                    makeItem("安全虚拟机", prettify(jsonString(sw, ["secure_vm"]) ?? "")),
                    makeItem("启动模式", prettify(jsonString(sw, ["boot_mode"]) ?? "normal_boot")),
                    makeItem("启动卷", jsonString(sw, ["boot_volume"])),
                    makeItem("应用标识", Bundle.main.bundleIdentifier ?? "独立可执行文件"),
                ]
            }),
            makeSection("传感器与功耗", {
                [
                    makeItem("热压力状态", thermalText(), "由 Foundation 的 ProcessInfo.thermalState 提供"),
                    makeItem("电池温度", (battery?["Temperature"] as? NSNumber).map { String(format: "%.1f °C", $0.doubleValue / 10.0 - 273.15) }),
                    makeItem("CPU / 风扇转速", "—", "底层 SMC 传感器需内核驱动配合，本工具不越权读取"),
                    makeItem("当前供电", (battery?["ExternalConnected"] as? NSNumber)?.boolValue == false ? "电池供电" : "交流电源"),
                ]
            }),
        ])
        let systemGroup = HWGroup(id: "system", title: "系统与安全", symbol: "gearshape", sections: systemSections)

        // ---------- 品牌识别 ----------
        var brandSections: [HWSection] = []
        appendSections(&brandSections, [
            makeSection("整机身份", {
                [
                    makeItem("机型品牌", identity.primaryBrandName),
                    makeItem("产品名称", identity.productName),
                    makeItem("机型标识", identity.modelIdentifier),
                    makeItem("产品定位", identity.releaseHint),
                    makeItem("设备形态", identity.formFactor),
                    makeItem("原厂判定", identity.isGenuineApple ? "Apple 原厂机型" : "非原厂机型 / 模拟机型"),
                    makeItem("引导固件", identity.firmwareName),
                    makeItem("物理整机线索", identity.physicalBrandName,
                             identity.isGenuineApple ? nil : "由器件线索推断，置信度低"),
                    makeItem("识别置信度", identity.confidence),
                    makeItem("判定说明", identity.note),
                ]
            }, brand: identity.primaryBrandKey),
        ])
        var evidenceItems: [HWItem?] = []
        for (i, e) in identity.evidence.enumerated() { evidenceItems.append(makeItem("证据 \(i + 1)", e)) }
        appendSections(&brandSections, [makeSection("识别依据", { evidenceItems })])
        var brandItems: [HWItem?] = []
        for b in detectedBrands {
            let hint = b.category + " · 来源 " + b.source + (b.note.map { " · " + $0 } ?? "")
            brandItems.append(makeItem(b.name, b.model, hint))
        }
        appendSections(&brandSections, [makeSection("硬件品牌清单（\(detectedBrands.count) 项）", { brandItems })])
        let brandsGroup = HWGroup(id: "brands", title: "品牌识别", symbol: "tag", sections: brandSections)

        // ---------- 顶部指标条 ----------
        let batPct: Double? = battery.flatMap { b in
            guard let m = (b["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue,
                  let c = (b["CurrentCapacity"] as? NSNumber)?.doubleValue, m > 0 else { return nil }
            return c / m
        }
        let vitals: [HWVital] = [
            HWVital(title: "CPU 使用率", value: cpuNow.map { percent($0) } ?? "—",
                    detail: "\(logicalCPU) 逻辑核心", ratio: cpuNow),
            HWVital(title: "内存占用", value: percent(memRatio),
                    detail: "\(humanBytes(usedMem)) / \(humanBytes(totalMem))", ratio: memRatio),
            HWVital(title: "启动盘占用", value: percent(diskRatio),
                    detail: root.map { "剩余 \(humanBytes($0.available))" } ?? "—", ratio: diskRatio),
            HWVital(title: "电池电量", value: batPct.map { percent($0) } ?? "不适用",
                    detail: batPct == nil ? "未检测到电池" : "循环 \(((battery?["CycleCount"] as? NSNumber)?.intValue ?? 0)) 次",
                    ratio: batPct),
        ]

        return HWReport(
            generatedAt: isoNow(),
            deviceName: machineName,
            machineModel: modelID,
            osVersion: osVersion,
            subtitle: "\(cpuName)  ·  \(humanBytes(totalMem)) 内存  ·  \(osVersion)",
            identity: identity,
            brands: detectedBrands,
            vitals: vitals,
            groups: [overview, brandsGroup, cpuGroup, memoryGroup, graphicsGroup,
                     storageGroup, powerGroup, networkGroup, systemGroup])
    }
}

// MARK: - 辅助

/// 显示器型号名 → 品牌（EDID 未给出可读厂商名时用常见型号前缀兜底）
func displayBrandKey(_ name: String) -> String? {
    let n = name.uppercased().trimmingCharacters(in: .whitespaces)
    guard !n.isEmpty else { return nil }
    if ["VE", "VG", "VX", "ROG", "ASUS", "PA2", "PB2"].contains(where: n.hasPrefix) { return "asus" }
    if ["DELL", "U27", "U24", "P24"].contains(where: n.hasPrefix) { return "dell" }
    if ["HP ", "Z27", "Z24"].contains(where: n.hasPrefix) { return "hp" }
    if ["LG", "27GP", "27UL"].contains(where: n.hasPrefix) { return "lg" }
    if n.contains("BOE") { return "boe" }
    if n.contains("PHILIPS") { return "philips" }
    if n.contains("SAMSUNG") { return "samsung" }
    if n.contains("APPLE") { return "apple" }
    return BrandDetector.oemKey(for: name)
}

func thermalText() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return "正常"
    case .fair: return "偏高 (Fair)"
    case .serious: return "较高 (Serious)"
    case .critical: return "过高 (Critical)"
    @unknown default: return "未知"
    }
}

func batteryPercent(_ b: [String: Any]) -> String? {
    guard let m = (b["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue,
          let c = (b["CurrentCapacity"] as? NSNumber)?.doubleValue, m > 0 else { return nil }
    return percent(c / m)
}

func batterySections(battery: [String: Any]?, prof: JSONDict) -> [HWSection] {
    var sections: [HWSection] = []
    let powerItems = jsonArray(prof["SPPowerDataType"])
    let batteryMaker = powerItems.compactMap {
        jsonString(jsonDict($0["sppower_battery_model_info"]), ["sppower_battery_manufacturer"])
    }.first ?? ""
    let batteryBrand = BrandDetector.key(for: batteryMaker)
    if let b = battery {
        let max = (b["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue
            ?? (b["MaxCapacity"] as? NSNumber)?.doubleValue ?? 0
        let design = (b["DesignCapacity"] as? NSNumber)?.doubleValue ?? 0
        let current = (b["CurrentCapacity"] as? NSNumber)?.doubleValue ?? 0
        let health = design > 0 && max > 0 ? max / design : nil
        let charging = (b["IsCharging"] as? NSNumber)?.boolValue ?? false
        let external = (b["ExternalConnected"] as? NSNumber)?.boolValue ?? false
        appendSections(&sections, [
            makeSection("电池状态 (IOKit · AppleSmartBattery)", {
                [
                    makeItem("当前电量", max > 0 ? percent(current / max) : nil),
                    makeItem("充电状态", charging ? "充电中" : (external ? "已接通电源" : "使用电池")),
                    makeItem("当前容量", "\(Int(current)) mAh"),
                    makeItem("最大容量", "\(Int(max)) mAh"),
                    makeItem("设计容量", design > 0 ? "\(Int(design)) mAh" : nil),
                    makeItem("健康度", health.map { percent($0) }, health.flatMap { $0 < 0.8 ? "低于 80%，建议检修电池" : "状态良好" }),
                    makeItem("循环次数", (b["CycleCount"] as? NSNumber).map { "\($0.intValue) 次" }),
                    makeItem("电池温度", (b["Temperature"] as? NSNumber).map { String(format: "%.1f °C", $0.doubleValue / 10.0 - 273.15) }),
                    makeItem("电压", (b["Voltage"] as? NSNumber).map { String(format: "%.0f mV", $0.doubleValue) }),
                    makeItem("外接电源", external ? "已连接" : "未连接"),
                ]
            }, brand: batteryBrand),
        ])
    }
    for p in jsonArray(prof["SPPowerDataType"]) {
        let charge = jsonDict(p["sppower_battery_charge_info"])
        let health = jsonDict(p["sppower_battery_health_info"])
        let model = jsonDict(p["sppower_battery_model_info"])
        let ac = jsonDict(p["sppower_ac_charger_information"])
        if !charge.isEmpty || !model.isEmpty {
            appendSections(&sections, [
                makeSection("电池信息 (system_profiler)", {
                    [
                        makeItem("电量百分比", jsonUInt(charge["sppower_battery_state_of_charge"]).map { "\($0) %" }),
                        makeItem("最大容量", jsonUInt(charge["sppower_battery_max_capacity"]).map { "\($0) mAh" }),
                        makeItem("正在充电", jsonString(charge, ["sppower_battery_is_charging"]).map(prettify)),
                        makeItem("已充满", jsonString(charge, ["sppower_battery_fully_charged"]).map(prettify)),
                        makeItem("循环次数", jsonUInt(health["sppower_battery_cycle_count"]).map { "\($0) 次" }),
                        makeItem("健康结论", jsonString(health, ["sppower_battery_health"]).map(prettify)),
                        makeItem("电池型号", jsonString(model, ["sppower_battery_device_name"])),
                        makeItem("制造商", jsonString(model, ["sppower_battery_manufacturer"])),
                        makeItem("固件版本", jsonString(model, ["sppower_battery_firmware_version"])),
                        makeItem("电池序列号", jsonString(model, ["sppower_battery_serial_number"])),
                    ]
                }, brand: batteryBrand),
            ])
        }
        if !ac.isEmpty {
            appendSections(&sections, [
                makeSection("电源适配器", {
                    [
                        makeItem("名称", jsonString(ac, ["_name", "sppower_ac_charger_name"])),
                        makeItem("功率", jsonUInt(ac["sppower_ac_charger_watts"]).map { "\($0) W" }),
                        makeItem("序列号", jsonString(ac, ["sppower_ac_charger_serial_number"])),
                        makeItem("制造商", jsonString(ac, ["sppower_ac_charger_manufacturer"])),
                        makeItem("型号", jsonString(ac, ["sppower_ac_charger_model"])),
                    ]
                }),
            ])
        }
    }
    if sections.isEmpty {
        appendSections(&sections, [makeSection("电源", { [makeItem("电池", "本机未检测到内置电池（台式机或虚拟机）")] })])
    }
    return sections
}
