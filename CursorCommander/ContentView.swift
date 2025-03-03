//
//  ContentView.swift
//  CursorCommander
//
//  Created by Mac on 03/03/2025.
//

import SwiftUI

struct CommandHistoryItem: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let timestamp: Date
    let isSuccess: Bool
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    @FocusState private var isTextFieldFocused: Bool
    @State private var timerActive = false
    @State private var commandHistory: [CommandHistoryItem] = []
    @State private var showHistory = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app icon and title
            HStack {
                Image(systemName: "terminal.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.blue)
                
                Text("Cursor Commander")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Toggle for history view
                Button(action: {
                    withAnimation {
                        showHistory.toggle()
                    }
                }) {
                    Image(systemName: showHistory ? "chevron.up" : "clock")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Command History")
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Tab view for different sections
            if !appState.hasAccessibilityPermissions || !appState.hasSystemEventsAccess || !appState.isCursorRunning {
                setupView
                    .transition(.opacity)
            } else {
                // Main command interface
                VStack(spacing: 12) {
                    // Command input field
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14, weight: .bold))
                        
                        TextField("Type command for Cursor...", text: $appState.commandText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                sendCommand()
                            }
                        
                        Button(action: {
                            sendCommand()
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                        .disabled(appState.commandText.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Status indicator
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Ready to send commands")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Command history section
                    if showHistory {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent Commands")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            if commandHistory.isEmpty {
                                Text("No commands yet")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        ForEach(commandHistory) { item in
                                            HStack {
                                                Image(systemName: item.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                                    .foregroundStyle(item.isSuccess ? .green : .red)
                                                    .font(.caption)
                                                
                                                Text(item.command)
                                                    .font(.callout)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Text(timeString(from: item.timestamp))
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                appState.commandText = item.command
                                                isTextFieldFocused = true
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.primary.opacity(0.05))
                                                    .opacity(appState.commandText == item.command ? 0.5 : 0)
                                            )
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(height: min(CGFloat(commandHistory.count) * 36, 150))
                            }
                            
                            HStack {
                                Spacer()
                                
                                Button(action: {
                                    commandHistory.removeAll()
                                }) {
                                    Label("Clear", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .disabled(commandHistory.isEmpty)
                                .padding(.trailing)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, maxWidth: .infinity)
        .frame(minHeight: showHistory ? 300 : 120, maxHeight: .infinity)
        .onAppear {
            // Focus the text field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
            
            // Initial checks
            appState.checkIfCursorIsRunning()
            
            // Avoid setting up multiple timers
            if !timerActive {
                timerActive = true
                
                // Set up a timer with a safer approach
                DispatchQueue.global(qos: .background).async {
                    // Run the first check after a delay
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    while true {
                        DispatchQueue.main.async {
                            appState.checkIfCursorIsRunning()
                        }
                        
                        // Wait before checking System Events
                        Thread.sleep(forTimeInterval: 2.0)
                        
                        DispatchQueue.main.async {
                            appState.checkSystemEventsAccess()
                        }
                        
                        // Wait before next cycle
                        Thread.sleep(forTimeInterval: 8.0)
                    }
                }
            }
        }
    }
    
    // Setup view for permissions and requirements
    var setupView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
                .padding(.top, 16)
            
            Text("Setup Required")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                if !appState.hasAccessibilityPermissions {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Accessibility Permissions")
                            .font(.subheadline)
                        Spacer()
                        Button("Enable") {
                            appState.requestAccessibilityPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if !appState.hasSystemEventsAccess && appState.hasAccessibilityPermissions {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("System Events Access")
                            .font(.subheadline)
                        Spacer()
                        Button("Fix") {
                            appState.requestSystemEventsPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if !appState.isCursorRunning {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Cursor App Not Running")
                            .font(.subheadline)
                        Spacer()
                        Button("Launch") {
                            appState.launchCursor()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.bottom, 16)
    }
    
    // Helper function to format time
    func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Function to send command and update history
    func sendCommand() {
        guard !appState.commandText.isEmpty else { return }
        
        // Save to history before sending
        let command = appState.commandText
        
        // Send the command
        appState.sendCommandToCursor()
        
        // Add to history (assuming success for now)
        // In a real implementation, you'd want to get the actual success status from the AppState
        let historyItem = CommandHistoryItem(
            command: command,
            timestamp: Date(),
            isSuccess: true
        )
        
        // Insert at the beginning of the array
        commandHistory.insert(historyItem, at: 0)
        
        // Limit history to 20 items
        if commandHistory.count > 20 {
            commandHistory.removeLast()
        }
    }
}

#Preview {
    ContentView()
}
