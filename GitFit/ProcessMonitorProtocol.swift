//
//  ProcessMonitorProtocol.swift
//  GitFit
//
//  XPC Protocol for process monitoring service.
//  This file is shared between the main app and the XPC service.
//

import Foundation

/// Protocol for the XPC service that monitors process CPU usage
@objc public protocol ProcessMonitorProtocol {
    /// Get the combined CPU usage of all Claude-related processes
    /// - Parameter reply: Callback with the total CPU percentage
    func getClaudeCPUUsage(reply: @escaping (Double) -> Void)

    /// Check if any Claude processes are running
    /// - Parameter reply: Callback with boolean indicating if Claude is running
    func isClaudeRunning(reply: @escaping (Bool) -> Void)
}
