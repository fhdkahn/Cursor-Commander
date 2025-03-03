#!/bin/bash

# This script helps set up the proper permissions for CursorCommander after building

# Get the path to the built app
APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 /path/to/CursorCommander.app"
    exit 1
fi

echo "Setting up permissions for $APP_PATH"

# Ensure the app is properly signed
echo "Signing the app..."
codesign --force --deep --sign - "$APP_PATH"

# Add the app to accessibility database
echo "Adding app to accessibility database..."
echo "You may need to enter your password to grant accessibility permissions"

# Use tccutil if available (requires sudo)
if command -v tccutil &> /dev/null; then
    sudo tccutil reset Accessibility
    sudo tccutil reset AppleEvents
    
    # Try to add the app to the accessibility database
    BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null)
    if [ ! -z "$BUNDLE_ID" ]; then
        echo "Adding $BUNDLE_ID to accessibility database"
        sudo tccutil add Accessibility "$BUNDLE_ID"
        sudo tccutil add AppleEvents "$BUNDLE_ID"
    else
        echo "Could not determine bundle ID"
    fi
else
    echo "tccutil not available. You'll need to manually grant permissions in System Preferences"
fi

echo "Done! Please restart the app and grant permissions when prompted." 