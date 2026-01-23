//
//  main.swift
//  ProcessMonitorService
//
//  Entry point for the XPC service.
//

import Foundation

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
