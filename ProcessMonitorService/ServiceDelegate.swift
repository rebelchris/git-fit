//
//  ServiceDelegate.swift
//  ProcessMonitorService
//
//  XPC Service delegate that handles incoming connections.
//

import Foundation

class ServiceDelegate: NSObject, NSXPCListenerDelegate {

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: ProcessMonitorProtocol.self)
        newConnection.exportedObject = ProcessMonitorService()

        // Resume the connection
        newConnection.resume()

        return true
    }
}
