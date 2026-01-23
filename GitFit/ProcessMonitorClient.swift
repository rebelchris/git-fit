//
//  ProcessMonitorClient.swift
//  GitFit
//
//  Client for communicating with the ProcessMonitorService XPC service.
//

import Foundation

class ProcessMonitorClient {
    private var connection: NSXPCConnection?

    static let shared = ProcessMonitorClient()

    private init() {
        setupConnection()
    }

    private func setupConnection() {
        // Connect to the XPC service embedded in the app bundle
        connection = NSXPCConnection(serviceName: "com.chrisbongers.GitFit.ProcessMonitorService")
        connection?.remoteObjectInterface = NSXPCInterface(with: ProcessMonitorProtocol.self)
        connection?.invalidationHandler = { [weak self] in
            print("⚠️ [XPC] Connection invalidated, reconnecting...")
            self?.connection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.setupConnection()
            }
        }
        connection?.interruptionHandler = {
            print("⚠️ [XPC] Connection interrupted")
        }
        connection?.resume()
    }

    func getClaudeCPUUsage(completion: @escaping (Double) -> Void) {
        guard let connection = connection else {
            print("⚠️ [XPC] No connection available")
            completion(0.0)
            return
        }

        let service = connection.remoteObjectProxyWithErrorHandler { error in
            print("⚠️ [XPC] Error: \(error)")
            completion(0.0)
        } as? ProcessMonitorProtocol

        service?.getClaudeCPUUsage(reply: completion)
    }

    func isClaudeRunning(completion: @escaping (Bool) -> Void) {
        guard let connection = connection else {
            completion(false)
            return
        }

        let service = connection.remoteObjectProxyWithErrorHandler { error in
            print("⚠️ [XPC] Error: \(error)")
            completion(false)
        } as? ProcessMonitorProtocol

        service?.isClaudeRunning(reply: completion)
    }
}
