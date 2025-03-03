//
//  CursorCommanderApp.swift
//  CursorCommander
//
//  Created by Mac on 03/03/2025.
//

import SwiftUI

@main
struct CursorCommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?
    private var statusItem: NSStatusItem?
    private var appState = AppState()
    private var lastCommands: [String] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Close the default window
        if let window = NSApplication.shared.windows.first {
            window.close()
        }
        
        // Register for accessibility notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Create the window manager and floating window
        windowManager = WindowManager()
        windowManager?.createFloatingWindow(
            with: ContentView(),
            title: "CursorCommander"
        )
        
        // Create a status bar item
        setupStatusBarItem()
        
        // Set activation policy to accessory to avoid showing in the Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permissions on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.appState.checkAccessibilityPermissions()
        }
        
        // Load saved commands from UserDefaults
        loadSavedCommands()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "CursorCommander")
            button.imagePosition = .imageLeft
            
            updateStatusMenu()
        }
    }
    
    private func updateStatusMenu() {
        let menu = NSMenu()
        
        // App title
        let titleItem = NSMenuItem(title: "Cursor Commander", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        titleItem.attributedTitle = NSAttributedString(
            string: "Cursor Commander",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Show/Hide window
        menu.addItem(NSMenuItem(title: "Show Commander", action: #selector(showWindow), keyEquivalent: "s"))
        
        // Status section
        menu.addItem(NSMenuItem.separator())
        let statusMenuHeader = NSMenuItem(title: "Status", action: nil, keyEquivalent: "")
        statusMenuHeader.isEnabled = false
        menu.addItem(statusMenuHeader)
        
        // Status indicators
        let accessibilityStatus = NSMenuItem(
            title: "Accessibility: \(appState.hasAccessibilityPermissions ? "✓" : "✗")",
            action: #selector(requestAccessibilityPermissions),
            keyEquivalent: ""
        )
        accessibilityStatus.isEnabled = !appState.hasAccessibilityPermissions
        menu.addItem(accessibilityStatus)
        
        let systemEventsStatus = NSMenuItem(
            title: "System Events: \(appState.hasSystemEventsAccess ? "✓" : "✗")",
            action: #selector(requestSystemEventsPermissions),
            keyEquivalent: ""
        )
        systemEventsStatus.isEnabled = !appState.hasSystemEventsAccess
        menu.addItem(systemEventsStatus)
        
        let cursorStatus = NSMenuItem(
            title: "Cursor: \(appState.isCursorRunning ? "Running" : "Not Running")",
            action: #selector(launchCursor),
            keyEquivalent: ""
        )
        cursorStatus.isEnabled = !appState.isCursorRunning
        menu.addItem(cursorStatus)
        
        // Recent commands section
        if !lastCommands.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let recentItem = NSMenuItem(title: "Recent Commands", action: nil, keyEquivalent: "")
            recentItem.isEnabled = false
            menu.addItem(recentItem)
            
            // Add up to 5 recent commands
            for (index, command) in lastCommands.prefix(5).enumerated() {
                let item = NSMenuItem(title: command, action: #selector(sendRecentCommand(_:)), keyEquivalent: "")
                item.tag = index
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearCommandHistory), keyEquivalent: ""))
        }
        
        // App controls
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Cursor Commander", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Fix: Properly set the menu on the statusItem
        if let item = self.statusItem {
            item.menu = menu
        }
    }
    
    @objc private func showWindow() {
        windowManager?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Cursor Commander"
        alert.informativeText = "A utility for sending commands to Cursor IDE.\n\nVersion 1.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func requestAccessibilityPermissions() {
        appState.requestAccessibilityPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateStatusMenu()
        }
    }
    
    @objc private func requestSystemEventsPermissions() {
        appState.requestSystemEventsPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateStatusMenu()
        }
    }
    
    @objc private func launchCursor() {
        appState.launchCursor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.updateStatusMenu()
        }
    }
    
    @objc private func sendRecentCommand(_ sender: NSMenuItem) {
        let index = sender.tag
        if index >= 0 && index < lastCommands.count {
            let command = lastCommands[index]
            appState.commandText = command
            appState.sendCommandToCursor()
        }
    }
    
    @objc private func clearCommandHistory() {
        lastCommands.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentCommands")
        updateStatusMenu()
    }
    
    @objc private func applicationActivated(_ notification: Notification) {
        // When switching between applications, check if we need to update permissions
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == Bundle.main.bundleIdentifier {
            DispatchQueue.main.async {
                self.appState.checkAccessibilityPermissions()
                self.updateStatusMenu()
            }
        }
    }
    
    // Save a command to history
    func saveCommand(_ command: String) {
        // Don't save empty commands
        guard !command.isEmpty else { return }
        
        // Remove the command if it already exists to avoid duplicates
        if let existingIndex = lastCommands.firstIndex(of: command) {
            lastCommands.remove(at: existingIndex)
        }
        
        // Add the command to the beginning of the array
        lastCommands.insert(command, at: 0)
        
        // Limit to 20 commands
        if lastCommands.count > 20 {
            lastCommands.removeLast()
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(lastCommands, forKey: "recentCommands")
        
        // Update the menu
        updateStatusMenu()
    }
    
    // Load saved commands from UserDefaults
    private func loadSavedCommands() {
        if let savedCommands = UserDefaults.standard.stringArray(forKey: "recentCommands") {
            lastCommands = savedCommands
        }
    }
}
