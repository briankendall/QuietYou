# Setup Guide for Quiet You!

This guide walks you through building and installing Quiet You! from source.

## Prerequisites

- macOS 13 or later
- Xcode 14.3 or later
- An Apple ID (for code signing)

## Building from Source

### 1. Clone the Repository

```bash
git clone https://github.com/briankendall/QuietYou.git
cd QuietYou
```

### 2. Open the Project in Xcode

```bash
open QuietYou.xcodeproj
```

Alternatively, you can build from the command line:

```bash
xcodebuild -project QuietYou.xcodeproj -scheme QuietYou -configuration Debug build
```

### 3. Configure Code Signing

The project is now configured to use **Automatic** code signing, which works with any Apple ID.

When you first build:
1. Xcode will prompt you to select a development team
2. Sign in with your Apple ID if you haven't already (Xcode > Settings > Accounts)
3. Xcode will automatically create and manage signing certificates for you

### 4. Build the App

- In Xcode: Press `⌘R` to build and run
- From command line: The app will be built to `~/Library/Developer/Xcode/DerivedData/QuietYou-*/Build/Products/Debug/QuietYou.app`

### 5. Install to Applications Folder

Copy the built app to your Applications folder:

```bash
# If built from Xcode
cp -r ~/Library/Developer/Xcode/DerivedData/QuietYou-*/Build/Products/Debug/QuietYou.app /Applications/

# Then launch it
open /Applications/QuietYou.app
```

## Configuration

### Grant Accessibility Permissions

The app **requires** Accessibility permissions to function:

1. When you first launch the app, it will prompt you for Accessibility permissions
2. Click "Open System Settings" or manually go to:
   - **System Settings > Privacy & Security > Accessibility**
3. Enable both **QuietYou** and **QuietYouAgent** if they appear in the list
4. You may need to unlock the settings by clicking the lock icon

Without these permissions, the app cannot detect or close notifications.

### Configure Notification Filters

1. Click the QuietYou icon in your menu bar
2. Add text strings for notifications you want to automatically close
3. Common examples:
   - "Background Items Added"
   - Any other notification text that annoys you

Any notification containing your filter text will be closed immediately (usually within a split second).

## Auto-Start at Login (Optional)

To have Quiet You! start automatically when you log in:

### Option 1: System Settings
1. Go to **System Settings > General > Login Items**
2. Click the "+" button
3. Navigate to `/Applications/QuietYou.app` and add it

### Option 2: Command Line
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/QuietYou.app", hidden:false}'
```

## How It Works

Quiet You! consists of two components:

- **QuietYou.app**: The main app with the UI and menu bar icon for configuration
- **QuietYouAgent.app**: A background helper (bundled inside the main app) that monitors and closes notifications

You only interact with the main app. It automatically manages the agent in the background.

## Troubleshooting

### App Won't Build
- Make sure you're signed in with an Apple ID in Xcode (Xcode > Settings > Accounts)
- Try cleaning the build folder: `⌘⇧K` in Xcode or `xcodebuild clean`

### Notifications Aren't Being Closed
- Check that Accessibility permissions are granted for both QuietYou and QuietYouAgent
- Verify your filter text is configured correctly
- Make sure the app is running (check menu bar for the icon)

### App Not Starting at Login
- Check **System Settings > General > Login Items** to verify it's listed
- Make sure the app path is `/Applications/QuietYou.app` (not in DerivedData)

## Technical Details

The app uses the macOS Accessibility API to:
1. Monitor for new UI elements in the Notification Center
2. Read the text content of notifications
3. Send a "press" action to the close button when a match is found

This approach has minimal CPU and memory impact since it uses event-driven observers rather than polling.

## Changes from Original

This fork includes the following improvements:
- Changed code signing from Manual to Automatic for easier building
- Removed hardcoded development team ID
- Added comprehensive setup documentation

These changes make it much easier for anyone to build and run the app locally without needing specific certificates.
