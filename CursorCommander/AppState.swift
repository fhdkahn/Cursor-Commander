//
//  AppState.swift
//  CursorCommander
//
//  Created by Mac on 03/03/2025.
//

import SwiftUI
import Cocoa

class AppState: ObservableObject {
    @Published var commandText: String = ""
    @Published var hasAccessibilityPermissions: Bool = false
    @Published var statusMessage: String = ""
    @Published var isCursorRunning: Bool = false
    @Published var hasSystemEventsAccess: Bool = false
    
    init() {
        checkAccessibilityPermissions()
        checkIfCursorIsRunning()
        checkSystemEventsAccess()
    }
    
    func checkAccessibilityPermissions() {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async {
            self.hasAccessibilityPermissions = hasPermission
            self.statusMessage = hasPermission ? "Ready" : "Accessibility permissions required"
        }
    }
    
    func requestAccessibilityPermissions() {
        // Open the Security & Privacy preferences panel directly
        let prefUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefUrl)
        
        // Show a dialog explaining what to do
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "CursorCommander needs accessibility permissions to send commands to Cursor.\n\n1. In the Security & Privacy preferences that just opened, click the lock icon to make changes.\n2. Check the box next to CursorCommander in the list.\n3. Restart CursorCommander after granting permissions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Check permissions again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPermissions()
        }
    }
    
    func sendCommandToCursor() {
        guard !commandText.isEmpty else { return }
        
        if !hasAccessibilityPermissions {
            statusMessage = "Please enable accessibility permissions in System Preferences"
            checkAccessibilityPermissions()
            return
        }
        
        // Check if Cursor is running
        checkIfCursorIsRunning()
        if !isCursorRunning {
            statusMessage = "Error: Cursor application is not running. Please start Cursor first."
            return
        }
        
        // Debug: Log the command being sent
        print("Sending command to Cursor: '\(commandText)'")
        
        // Get the Cursor app - try multiple ways to find it
        let workspace = NSWorkspace.shared
        let cursorApp = workspace.runningApplications.first { app in
            return app.localizedName == "Cursor" || app.bundleIdentifier == "io.cursor.Cursor"
        }
        
        guard let cursorApplication = cursorApp else {
            statusMessage = "Cursor application not found. Try restarting Cursor."
            return
        }
        
        // Print debug info about the found app
        print("Found Cursor app: \(cursorApplication.localizedName ?? "unknown"), bundle: \(cursorApplication.bundleIdentifier ?? "unknown")")
        
        // Save the currently active app so we can return to it
        let currentApp = NSWorkspace.shared.frontmostApplication
        
        // Save command to history via AppDelegate
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.saveCommand(commandText)
        }
        
        // Activate Cursor app with options to bring it to front
        var activationSuccess = false
        
        if #available(macOS 14.0, *) {
            // Use the newer API for macOS 14+
            cursorApplication.activate()
            activationSuccess = true
        } else {
            // Use the older API for earlier macOS versions
            activationSuccess = cursorApplication.activate(options: [.activateIgnoringOtherApps])
        }
        
        if !activationSuccess {
            statusMessage = "Failed to activate Cursor application"
            return
        }
        
        // Wait for app to activate and gain focus
        Thread.sleep(forTimeInterval: 0.5)
        
        // Try to open the chat panel first using various keyboard shortcuts
        openCursorChatPanel()
        
        // Try multiple methods to send the command
        var commandSent = false
        
        // Method 1: Use NSWorkspace to activate and then CGEvents
        if !commandSent {
            commandSent = sendKeystrokesUsingCGEvent(text: commandText)
        }
        
        // Method 2: Use AppleScript with explicit application targeting
        if !commandSent {
            commandSent = sendKeystrokesUsingAppleScript()
        }
        
        // Method 3: Use AppleScript with System Events
        if !commandSent {
            commandSent = sendKeystrokesUsingSystemEvents()
        }
        
        if commandSent {
            statusMessage = "Command sent: \(commandText)"
            commandText = ""
        } else {
            statusMessage = "Failed to send command. Check permissions and try again."
        }
        
        // Wait before switching back
        Thread.sleep(forTimeInterval: 0.5)
        
        // Switch back to the original app
        if let originalApp = currentApp {
            if #available(macOS 14.0, *) {
                originalApp.activate()
            } else {
                originalApp.activate(options: [])
            }
        }
    }
    
    // Helper function to try different methods to open the Cursor chat panel
    private func openCursorChatPanel() {
        // Get the app name from the running application
        let appName = NSWorkspace.shared.runningApplications.first { 
            $0.localizedName == "Cursor" || $0.bundleIdentifier == "io.cursor.Cursor" 
        }?.localizedName ?? "Cursor"
        
        // Use AppleScript to open the chat panel - this is more reliable than direct CGEvents
        // and won't leave stray characters in the input field
        let openChatScript = """
        tell application "System Events"
            tell process "\(appName)"
                -- First try Cmd+K to open the command palette
                key code 40 using {command down}
                delay 0.3
                
                -- Type "chat" to find the chat option
                keystroke "chat"
                delay 0.3
                
                -- Press return to select the chat option
                key code 36
                delay 0.5
                
                -- If that doesn't work, try Cmd+J which is a direct shortcut for chat in newer versions
                key code 38 using {command down}
                delay 0.5
                
                -- Try to click on the chat composer area
                try
                    set windowSize to size of window 1
                    set windowWidth to item 1 of windowSize
                    set windowHeight to item 2 of windowSize
                    
                    -- Click near the bottom of the window where the chat input is
                    set clickX to windowWidth / 2
                    set clickY to windowHeight - 30
                    click at {clickX, clickY}
                    delay 0.2
                end try
            end tell
        end tell
        """
        
        let script = NSAppleScript(source: openChatScript)
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)
        
        if errorDict != nil {
            print("Failed to open chat panel with AppleScript: \(String(describing: errorDict))")
            
            // Fallback to CGEvent method if AppleScript fails
            let source = CGEventSource(stateID: .combinedSessionState)
            
            // Try Cmd+K to open command palette
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true), // Command key
               let kDown = CGEvent(keyboardEventSource: source, virtualKey: 0x28, keyDown: true), // K key
               let kUp = CGEvent(keyboardEventSource: source, virtualKey: 0x28, keyDown: false),
               let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) {
                
                cmdDown.flags = .maskCommand
                cmdDown.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                kDown.flags = .maskCommand
                kDown.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                kUp.flags = .maskCommand
                kUp.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                cmdUp.post(tap: .cghidEventTap)
                usleep(100000) // 100ms
                
                // Type "chat"
                for char in "chat" {
                    let keyCode = keyCodeForChar(char)
                    if let charDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                       let charUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                        charDown.post(tap: .cghidEventTap)
                        usleep(20000)
                        charUp.post(tap: .cghidEventTap)
                        usleep(20000)
                    }
                }
                
                // Press return
                if let returnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true),
                   let returnUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false) {
                    usleep(100000) // 100ms
                    returnDown.post(tap: .cghidEventTap)
                    usleep(20000)
                    returnUp.post(tap: .cghidEventTap)
                    usleep(500000) // 500ms to wait for chat to open
                }
            }
            
            // Then try Cmd+J as fallback
            if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true), // Command key
               let jDown = CGEvent(keyboardEventSource: source, virtualKey: 0x26, keyDown: true), // J key
               let jUp = CGEvent(keyboardEventSource: source, virtualKey: 0x26, keyDown: false),
               let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) {
                
                cmdDown.flags = .maskCommand
                cmdDown.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                jDown.flags = .maskCommand
                jDown.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                jUp.flags = .maskCommand
                jUp.post(tap: .cghidEventTap)
                usleep(20000) // 20ms
                
                cmdUp.post(tap: .cghidEventTap)
            }
        }
        
        // Wait for chat panel to appear
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    private func sendKeystrokesUsingCGEvent(text: String) -> Bool {
        // Get the current keyboard layout
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Try to click near the bottom of the window where the chat composer is typically located
        if let mainScreen = NSScreen.main {
            let screenRect = mainScreen.frame
            
            // Get the active window's frame if possible
            var windowFrame = screenRect
            if let cursorApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Cursor" || $0.bundleIdentifier == "io.cursor.Cursor" }),
               let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                
                for window in windowList {
                    if let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                       ownerPID == cursorApp.processIdentifier,
                       let bounds = window[kCGWindowBounds as String] as? [String: Any],
                       let x = bounds["X"] as? CGFloat,
                       let y = bounds["Y"] as? CGFloat,
                       let width = bounds["Width"] as? CGFloat,
                       let height = bounds["Height"] as? CGFloat {
                        
                        windowFrame = CGRect(x: x, y: y, width: width, height: height)
                        break
                    }
                }
            }
            
            // Calculate a point near the bottom center of the window
            // This is where the chat composer is typically located in the chat panel
            let chatPoint = CGPoint(
                x: windowFrame.origin.x + windowFrame.width / 2,
                y: windowFrame.origin.y + windowFrame.height - 30
            )
            
            // Create and post mouse down event
            if let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, 
                                      mouseCursorPosition: chatPoint, mouseButton: .left) {
                mouseDown.post(tap: .cghidEventTap)
                usleep(50000) // 50ms delay
            }
            
            // Create and post mouse up event
            if let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, 
                                    mouseCursorPosition: chatPoint, mouseButton: .left) {
                mouseUp.post(tap: .cghidEventTap)
                usleep(50000) // 50ms delay
            }
        }
        
        // Wait for focus to be established
        Thread.sleep(forTimeInterval: 0.2)
        
        // Triple-click to select all existing text (more reliable than Cmd+A in some cases)
        if let mainScreen = NSScreen.main {
            let screenRect = mainScreen.frame
            
            // Get the active window's frame if possible
            var windowFrame = screenRect
            if let cursorApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Cursor" || $0.bundleIdentifier == "io.cursor.Cursor" }),
               let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                
                for window in windowList {
                    if let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                       ownerPID == cursorApp.processIdentifier,
                       let bounds = window[kCGWindowBounds as String] as? [String: Any],
                       let x = bounds["X"] as? CGFloat,
                       let y = bounds["Y"] as? CGFloat,
                       let width = bounds["Width"] as? CGFloat,
                       let height = bounds["Height"] as? CGFloat {
                        
                        windowFrame = CGRect(x: x, y: y, width: width, height: height)
                        break
                    }
                }
            }
            
            let chatPoint = CGPoint(
                x: windowFrame.origin.x + windowFrame.width / 2,
                y: windowFrame.origin.y + windowFrame.height - 30
            )
            
            // Triple click to select all text
            for _ in 1...3 {
                if let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, 
                                          mouseCursorPosition: chatPoint, mouseButton: .left),
                   let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, 
                                        mouseCursorPosition: chatPoint, mouseButton: .left) {
                    mouseDown.post(tap: .cghidEventTap)
                    usleep(20000) // 20ms delay
                    mouseUp.post(tap: .cghidEventTap)
                    usleep(20000) // 20ms delay
                }
            }
        }
        
        // Delete key to clear selected text
        if let deleteDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
           let deleteUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
            deleteDown.post(tap: .cghidEventTap)
            usleep(20000) // 20ms
            deleteUp.post(tap: .cghidEventTap)
            usleep(50000) // 50ms delay
        }
        
        // Type each character individually with longer delays
        for char in text {
            // Convert character to keycode
            let keyCode = keyCodeForChar(char)
            if keyCode == 0 && char != "a" {
                // Skip characters we can't convert
                continue
            }
            
            // For uppercase letters or special characters, we need to handle shift
            let needsShift = char.isUppercase || "!@#$%^&*()_+{}|:\"<>?~".contains(char)
            
            // Press shift if needed
            if needsShift {
                if let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true) {
                    shiftDown.post(tap: .cghidEventTap)
                    usleep(20000) // 20ms
                }
            }
            
            // Create key down event
            if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                event.post(tap: .cghidEventTap)
            }
            
            // Small delay
            usleep(20000) // 20ms
            
            // Create key up event
            if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                event.post(tap: .cghidEventTap)
            }
            
            // Release shift if it was pressed
            if needsShift {
                if let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) {
                    shiftUp.post(tap: .cghidEventTap)
                    usleep(20000) // 20ms
                }
            }
            
            // Longer delay between characters
            usleep(30000) // 30ms
        }
        
        // Wait before pressing return
        Thread.sleep(forTimeInterval: 0.2)
        
        // Press return key
        if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true),
           let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false) {
            downEvent.post(tap: .cghidEventTap)
            usleep(20000) // 20ms
            upEvent.post(tap: .cghidEventTap)
            return true
        }
        
        return false
    }
    
    private func sendKeystrokesUsingAppleScript() -> Bool {
        let escapedText = commandText.replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "\"", with: "\\\"")
        
        // Get the app name from the running application
        let workspace = NSWorkspace.shared
        let cursorApp = workspace.runningApplications.first { app in
            return app.localizedName == "Cursor" || app.bundleIdentifier == "io.cursor.Cursor"
        }
        
        let appName = cursorApp?.localizedName ?? "Cursor"
        print("Using AppleScript with app name: \(appName)")
        
        // Modified AppleScript to open the chat panel and click on the chat composer
        let source = """
        tell application "\(appName)"
            activate
            delay 0.5
        end tell
        tell application "System Events"
            tell process "\(appName)"
                set frontmost to true
                delay 0.2
                
                -- First try Cmd+K to open the command palette
                key code 40 using {command down}
                delay 0.3
                
                -- Type "chat" to find the chat option
                keystroke "chat"
                delay 0.3
                
                -- Press return to select the chat option
                key code 36
                delay 0.5
                
                -- If that doesn't work, try Cmd+J as a direct shortcut for chat
                key code 38 using {command down}
                delay 0.5
                
                -- Try to find and click on the chat composer area
                try
                    -- Try to find by position - click near the bottom center of the window
                    set windowSize to size of window 1
                    set windowWidth to item 1 of windowSize
                    set windowHeight to item 2 of windowSize
                    set clickX to windowWidth / 2
                    set clickY to windowHeight - 30
                    click at {clickX, clickY}
                    delay 0.2
                    
                    -- Triple-click to select all text (more reliable than Cmd+A)
                    click at {clickX, clickY}
                    delay 0.05
                    click at {clickX, clickY}
                    delay 0.05
                    click at {clickX, clickY}
                    delay 0.1
                on error
                    -- If all else fails, try to use keyboard shortcut to focus chat
                    key code 40 using {command down}
                    delay 0.2
                end try
                
                -- Delete any selected text
                key code 51 -- Delete key
                delay 0.1
                
                -- Now send the text
                keystroke "\(escapedText)"
                delay 0.2
                keystroke return
            end tell
        end tell
        """
        
        let script = NSAppleScript(source: source)
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)
        
        if errorDict == nil {
            return true
        } else {
            print("AppleScript method failed: \(String(describing: errorDict))")
            return false
        }
    }
    
    private func sendKeystrokesUsingSystemEvents() -> Bool {
        let escapedText = commandText.replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "\"", with: "\\\"")
        
        // Get the app name from the running application
        let workspace = NSWorkspace.shared
        let cursorApp = workspace.runningApplications.first { app in
            return app.localizedName == "Cursor" || app.bundleIdentifier == "io.cursor.Cursor"
        }
        
        let appName = cursorApp?.localizedName ?? "Cursor"
        
        // Modified to open the chat panel and focus on the chat composer
        let source = """
        tell application "System Events"
            tell process "\(appName)"
                -- First try Cmd+K to open the command palette
                key code 40 using {command down}
                delay 0.3
                
                -- Type "chat" to find the chat option
                keystroke "chat"
                delay 0.3
                
                -- Press return to select the chat option
                key code 36
                delay 0.5
                
                -- If that doesn't work, try Cmd+J which is a direct shortcut for chat
                key code 38 using {command down}
                delay 0.5
                
                -- Try clicking at the bottom of the window
                try
                    set windowSize to size of window 1
                    set windowWidth to item 1 of windowSize
                    set windowHeight to item 2 of windowSize
                    set clickX to windowWidth / 2
                    set clickY to windowHeight - 30
                    
                    -- Click to focus
                    click at {clickX, clickY}
                    delay 0.1
                    
                    -- Triple-click to select all text
                    click at {clickX, clickY}
                    delay 0.05
                    click at {clickX, clickY}
                    delay 0.05
                    click at {clickX, clickY}
                    delay 0.1
                end try
                
                -- Delete any selected text
                key code 51 -- Delete key
                delay 0.1
                
                -- Now send the text
                keystroke "\(escapedText)"
                delay 0.2
                keystroke return
            end tell
        end tell
        """
        
        let script = NSAppleScript(source: source)
        var errorDict: NSDictionary?
        script?.executeAndReturnError(&errorDict)
        
        if errorDict == nil {
            return true
        } else {
            print("System Events method failed: \(String(describing: errorDict))")
            return false
        }
    }
    
    private func keyCodeForChar(_ char: Character) -> CGKeyCode {
        // This is a simplified mapping for common characters
        // For a complete mapping, you would need a more extensive lookup table
        switch char.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "6", "^": return 0x16
        case "5", "%": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case " ": return 0x31 // Space
        default: return 0x00 // Default to 'a' for unknown characters
        }
    }
    
    func checkIfCursorIsRunning() {
        let workspace = NSWorkspace.shared
        // Check for Cursor using both name and bundle identifier
        let isRunning = workspace.runningApplications.contains { app in
            return app.localizedName == "Cursor" || app.bundleIdentifier == "io.cursor.Cursor"
        }
        
        DispatchQueue.main.async {
            self.isCursorRunning = isRunning
            if !isRunning {
                self.statusMessage = "Cursor is not running"
            }
        }
    }
    
    func launchCursor() {
        let workspace = NSWorkspace.shared
        
        // First, try to find where Cursor is installed
        if let cursorPath = findCursorPath() {
            print("Found Cursor at: \(cursorPath)")
            do {
                if #available(macOS 11.0, *) {
                    workspace.openApplication(at: URL(fileURLWithPath: cursorPath),
                                            configuration: NSWorkspace.OpenConfiguration(),
                                            completionHandler: { (app, error) in
                        if let error = error {
                            print("Failed to open Cursor: \(error)")
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self.checkIfCursorIsRunning()
                            }
                        }
                    })
                } else {
                    // Fallback for older macOS versions
                    try workspace.launchApplication(at: URL(fileURLWithPath: cursorPath),
                                                  options: [],
                                                configuration: [:])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.checkIfCursorIsRunning()
                    }
                }
                return
            } catch {
                print("Failed to launch Cursor from path: \(error)")
            }
        }
        
        // Try to find Cursor in the Applications folder
        let appPaths = [
            "/Applications/Cursor.app",
            "/Applications/Utilities/Cursor.app",
            "~/Applications/Cursor.app",
            "/Applications/Cursor/Cursor.app"
        ]
        
        for path in appPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                if #available(macOS 11.0, *) {
                    workspace.openApplication(at: URL(fileURLWithPath: expandedPath),
                                            configuration: NSWorkspace.OpenConfiguration(),
                                            completionHandler: { (app, error) in
                        if let error = error {
                            print("Failed to open Cursor: \(error)")
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self.checkIfCursorIsRunning()
                            }
                        }
                    })
                } else {
                    do {
                        try workspace.launchApplication(at: URL(fileURLWithPath: expandedPath),
                                                      options: [],
                                                    configuration: [:])
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.checkIfCursorIsRunning()
                        }
                    } catch {
                        print("Failed to launch Cursor: \(error)")
                    }
                }
                return
            }
        }
        
        // If we couldn't find it in the standard locations, try to launch by bundle ID
        if #available(macOS 11.0, *) {
            // Use the modern API for macOS 11+
            let cursorURL = URL(string: "cursor://")
            if let url = cursorURL {
                workspace.open(url, configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                    if let error = error {
                        print("Failed to open Cursor URL: \(error)")
                        self.statusMessage = "Error: Could not find or launch Cursor application"
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.checkIfCursorIsRunning()
                        }
                    }
                }
            } else {
                statusMessage = "Error: Could not find or launch Cursor application"
            }
        } else {
            // Fallback for older macOS versions - use a simpler approach
            let success = workspace.launchApplication("Cursor")
            
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.checkIfCursorIsRunning()
                }
            } else {
                print("Failed to launch Cursor by name")
                statusMessage = "Error: Could not find or launch Cursor application"
            }
        }
    }
    
    private func findCursorPath() -> String? {
        // Use the 'mdfind' command to search for Cursor.app
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemCFBundleIdentifier == 'io.cursor.Cursor' || kMDItemDisplayName == 'Cursor.app'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Get the first result if there are multiple
                let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                if let firstPath = paths.first {
                    return firstPath
                }
            }
        } catch {
            print("Error finding Cursor path: \(error)")
        }
        
        return nil
    }
    
    func checkSystemEventsAccess() {
        // Use a simpler test that's less likely to fail
        let testScript = """
        tell application "System Events"
            return 1
        end tell
        """
        
        let script = NSAppleScript(source: testScript)
        var errorDict: NSDictionary?
        _ = script?.executeAndReturnError(&errorDict)
        
        // Use a local variable to avoid direct state updates that might cause cycles
        let hasAccess = errorDict == nil
        
        DispatchQueue.main.async {
            // Only update if the value is changing to avoid cycles
            if self.hasSystemEventsAccess != hasAccess {
                self.hasSystemEventsAccess = hasAccess
                
                // Only update status message if it's directly related to System Events
                if !hasAccess && (self.statusMessage == "Ready" || self.statusMessage.isEmpty) {
                    self.statusMessage = "System Events access required. Check permissions."
                } else if hasAccess && self.statusMessage == "System Events access required. Check permissions." {
                    self.statusMessage = "Ready"
                }
            }
            
            if let error = errorDict {
                print("System Events access test failed: \(error)")
            }
        }
    }
    
    func requestSystemEventsPermissions() {
        // Open the Security & Privacy preferences panel directly
        let prefUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefUrl)
        
        // Show a dialog explaining what to do
        let alert = NSAlert()
        alert.messageText = "System Events Permissions Required"
        alert.informativeText = "CursorCommander needs permission to control System Events to send commands to Cursor.\n\n1. In the Security & Privacy preferences that just opened, click the lock icon to make changes.\n2. Make sure CursorCommander is checked in the list.\n3. If you don't see CursorCommander in the list, try running the app again.\n4. Restart CursorCommander after granting permissions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Check permissions again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkSystemEventsAccess()
        }
    }
} 