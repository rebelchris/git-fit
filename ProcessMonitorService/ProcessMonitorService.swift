//
//  ProcessMonitorService.swift
//  ProcessMonitorService
//
//  XPC Service that monitors process CPU usage.
//  This service runs unsandboxed to access process information.
//

import Foundation

class ProcessMonitorService: NSObject, ProcessMonitorProtocol {

    func getClaudeCPUUsage(reply: @escaping (Double) -> Void) {
        // Use the same command that works in terminal
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "ps aux | grep -E '[c]laude|[a]nthropic' | awk '{sum += $3} END {print sum+0}'"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.environment = ["LC_ALL": "C", "LANG": "C"]

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Handle locale differences (comma vs period)
                let normalized = output.replacingOccurrences(of: ",", with: ".")
                if let cpu = Double(normalized) {
                    reply(cpu)
                    return
                }
            }
        } catch {
            // Silently fail
        }

        reply(0.0)
    }

    func isClaudeRunning(reply: @escaping (Bool) -> Void) {
        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "claude"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            reply(task.terminationStatus == 0)
        } catch {
            reply(false)
        }
    }
}
