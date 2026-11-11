//  main.swift
//  入口：带参数时作为命令行工具，无参数时启动 macOS 图形界面

import Foundation
import AppKit
import Darwin

let args = Array(CommandLine.arguments.dropFirst())

func argumentValue(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

let usage = """
硬件检测 · Hardware Inspector  (macOS 原生 · IOKit / sysctl / Mach)

用法:
  打开 Hardware Inspector.app          启动图形界面
  HardwareInspector --cli             在终端输出完整检测报告
  HardwareInspector --json            输出 JSON 数据到标准输出
  HardwareInspector --md <路径>        导出 Markdown 报告
  HardwareInspector --json-file <路径> 导出 JSON 数据文件
  HardwareInspector --live             持续输出实时状态（Ctrl-C 结束）
  HardwareInspector --live --json      以 JSON Lines 输出实时状态
  HardwareInspector --live --interval 2  指定采样间隔秒数（1 / 2 / 5）
  HardwareInspector --self-test        界面布局自检（不显示窗口）
  HardwareInspector --help             显示本帮助

说明: 全部数据在本机离线采集，不会联网上传。
      实时模式只读取 Darwin / Mach / IOKit 计数器，不启动 system_profiler。
      system_profiler 部分字段需要完整磁盘访问权限才能读取全部内容。
"""

if args.contains("--help") || args.contains("-h") {
    print(usage)
    exit(0)
}

if args.contains("--self-test") {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    let controller = MainWindowController()
    _ = controller.window
    let report = HardwareCollector.collect()
    print("界面自检:")
    print(controller.selfTest(report))
    exit(0)
}

if args.contains("--live") {
    let jsonMode = args.contains("--json")
    let interval = max(0.5, Double(argumentValue("--interval") ?? "1") ?? 1)
    let monitor = LiveMonitor()
    monitor.primeBaseline()

    func emit(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
    if !jsonMode {
        emit("硬件检测 · 实时状态  |  每 \(String(format: "%.0f", interval)) 秒采样  |  Ctrl-C 结束")
        emit("CPU / 内存 / 磁盘占用、网络上下行速率、电池与热压力（仅本机采集）")
    }

    // 必须用串行队列：采样器内部保存上一次 CPU tick / 网络计数作为差分基线
    let liveQueue = DispatchQueue(label: "cn.hardwareinspector.live.cli", qos: .userInitiated)
    let timer = DispatchSource.makeTimerSource(queue: liveQueue)
    timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(100))
    timer.setEventHandler {
        let s = monitor.sample()
        if jsonMode {
            if let d = s.jsonData(), let line = String(data: d, encoding: .utf8) { emit(line) }
        } else {
            emit(s.oneLine)
        }
    }
    timer.resume()
    signal(SIGINT) { _ in
        FileHandle.standardOutput.write(Data("\n实时监控已结束。\n".utf8))
        exit(0)
    }
    dispatchMain()
}

let needReport = args.contains("--cli") || args.contains("--json")
    || args.contains("--md") || args.contains("--json-file")

if needReport {
    let report = HardwareCollector.collect()

    if args.contains("--cli") {
        print(ReportRenderer.text(report))
    }
    if args.contains("--json") {
        if let data = try? ReportRenderer.jsonData(report), let s = String(data: data, encoding: .utf8) {
            print(s)
        }
    }
    if let path = argumentValue("--md") {
        do {
            let p = try ReportRenderer.write(ReportRenderer.markdown(report), to: path)
            print("Markdown 报告已写入: \(p)")
        } catch { fputs("导出失败: \(error)\n", stderr); exit(1) }
    }
    if let path = argumentValue("--json-file") {
        do {
            let data = try ReportRenderer.jsonData(report)
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            try data.write(to: url)
            print("JSON 数据已写入: \(url.path)")
        } catch { fputs("导出失败: \(error)\n", stderr); exit(1) }
    }
    exit(0)
}

// 图形界面
BrandLogo.prepare()      // 建立用户自定义官方 Logo 目录（应用数据目录内）
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
