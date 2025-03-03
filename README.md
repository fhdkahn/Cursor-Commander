# Cursor Commander

Cursor Commander is a native macOS utility app that acts as an always-on-top floating command panel. It allows you to send commands to the Cursor IDE while keeping your browser in focus, enabling a seamless workflow between viewing your website in the browser and updating it via the Cursor chat interface.

## What Problem Does This Solve?

When you're developing a website using Cursor IDE (chat/composer) and running it on localhost, you typically need to:
1. Make changes in Cursor
2. Switch to your browser to see the changes
3. Switch back to Cursor to make more changes
4. Repeat this cycle many times

This constant context switching breaks your flow and reduces productivity. **Cursor Commander** solves this by:
- Floating on top of your browser window
- Allowing you to send commands directly to Cursor chat without switching focus
- Keeping you in the "flow state" while viewing your website

This means you can stay in full-screen browser mode, see your website changes in real-time while in full control, and still communicate with Cursor's AI assistant without ever leaving your browser!

## Features

- Minimal, floating UI that stays on top of other windows
- Single text input field for typing commands
- Sends commands to Cursor application without switching focus from your browser
- Uses AppleScript with fallback to lower-level CGEvent APIs
- Status bar icon for easy access
- Command history for quick access to previous commands
- Accessibility permissions management
  
![Screenshot 2025-03-03 at 8 00 27 PM](https://github.com/user-attachments/assets/8d18ff33-c56c-49aa-9120-197871d96cb7)

## Requirements

- macOS 11.0 or later
- Cursor IDE installed (https://cursor.sh)
- Accessibility permissions enabled in System Preferences

## Installation

### Option 1: Download Pre-built App
1. Download the latest release from the [Releases page](https://github.com/fhdkahn/Cursor-Commander/releases)
2. Move CursorCommander.app to your Applications folder
3. Launch the app through X code app
4. When prompted, grant Accessibility permissions in System Preferences by adding the app with plus icon in the Setting/Privacy & Security/accessibility and adding your launch app


### Option 2: Build from Source

#### Prerequisites
- Xcode 13 or later
- macOS 11.0 or later
- Command Line Tools for Xcode

#### Build Steps
1. Clone this repository:
   ```bash
   git clone https://github.com/fhdkahn/Cursor-Commander.git
   cd Cursor-Commander
   ```

2. Open the project in Xcode:
   ```bash
   open CursorCommander.xcodeproj
   ```

3. Select your development team in Xcode:
   - Click on the project in the Project Navigator
   - Select the "CursorCommander" target
   - Go to the "Signing & Capabilities" tab
   - Select your development team

4. Build the project:
   - Select Product > Build (⌘B)
   - Or select Product > Archive to create a distributable app

5. After building, run the post-build script to set up permissions:
   ```bash
   chmod +x post_build.sh
   ./post_build.sh /path/to/built/CursorCommander.app
   ```
   Note: Replace `/path/to/built/CursorCommander.app` with the actual path to your built app.

## Usage

1. Start both Cursor IDE and your browser
2. Launch Cursor Commander
3. The app will appear as a small floating window on top of your browser
4. Type your command in the text field
5. Press Enter or click the send button
6. The command will be sent to Cursor while keeping your browser in focus
7. View the status message to confirm the command was sent successfully

### Tips for Effective Use
- Position the Cursor Commander window in a corner of your browser where it won't interfere with your website view
- Use the command history feature to quickly reuse previous commands
- Keep Cursor IDE visible on a second monitor if possible, so you can see the responses

## Troubleshooting

### Accessibility Permissions Issues

If you encounter issues with accessibility permissions:

1. **Manual Permission Granting**:
   - Open System Preferences > Security & Privacy > Privacy > Accessibility
   - Click the lock icon to make changes (you'll need to enter your password)
   - Make sure CursorCommander is checked in the list
   - If it's not in the list, click the "+" button and add it from your Applications folder

2. **Reset Permissions**:
   - If permissions aren't working, try running the included post_build.sh script:
     ```
     ./post_build.sh /Applications/CursorCommander.app
     ```
   - This requires administrator privileges

3. **App Not Responding**:
   - If the app window appears but doesn't respond, try restarting the app
   - Make sure both your browser and Cursor are running before using CursorCommander

4. **Window Not Visible**:
   - If the window disappears, click the CursorCommander icon in the status bar and select "Show CursorCommander"

### Common Error Messages

- "Accessibility: Not vending elements because elementWindow is lower than shield" - This is usually resolved by granting proper accessibility permissions
- "Failed to get or decode unavailable reasons" - This is often a macOS internal message and not directly related to app functionality

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License

## Acknowledgements

- Built with SwiftUI and Cocoa
- Uses AppleScript and Accessibility APIs for inter-application communication 
