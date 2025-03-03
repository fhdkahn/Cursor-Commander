//
//  WindowManager.swift
//  CursorCommander
//
//  Created by Mac on 03/03/2025.
//

import SwiftUI
import Cocoa

class WindowManager: NSObject {
    var window: NSWindow?
    
    func createFloatingWindow(with rootView: some View, title: String) {
        // Create a hosting view for the SwiftUI content
        let hostingView = NSHostingView(rootView: rootView)
        
        // Create the window with appropriate size
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Set the content view directly
        window.contentView = hostingView
        
        // Configure window properties
        window.title = title
        window.center()
        window.setFrameAutosaveName("CursorCommander")
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        // Set the window to be visible in all spaces
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set minimum size
        window.minSize = NSSize(width: 400, height: 120)
        
        // Set the window delegate
        window.delegate = self
        
        // Make the window visible
        window.makeKeyAndOrderFront(nil)
        
        self.window = window
    }
}

// MARK: - NSWindowDelegate
extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

// MARK: - Window Style
struct FloatingWindowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            )
    }
}

extension View {
    func floatingWindowStyle() -> some View {
        self.modifier(FloatingWindowStyle())
    }
}