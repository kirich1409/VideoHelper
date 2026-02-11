# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VideoHelper is a native macOS application for adding custom thumbnails to videos with drag-and-drop simplicity. Built with Swift and SwiftUI, it uses AVFoundation for video processing and supports bilingual localization (English/Russian).

**Bundle ID**: `dev.androidbroadcast.VideoHelper`
**Deployment Target**: macOS 14.0+
**Architecture**: MVVM with Swift Concurrency (async/await + actors)

## Building and Running

**Note**: This project uses Tuist for Xcode project generation. Always run `tuist generate` after pulling changes or modifying manifest files.

### First Time Setup

```bash
# Install Tuist (one-time)
brew install --cask tuist

# Generate Xcode project from manifests
tuist generate

# Open project in Xcode
open VideoHelper.xcodeproj
```

### Daily Development

```bash
# Regenerate project if manifests changed
tuist generate

# Build and run (⌘R in Xcode)
# Or via command line:
tuist build VideoHelper

# Run tests
tuist test VideoHelperTests
```

### Modifying Project Structure

- Edit `Project.swift` to change targets, dependencies, or settings
- Edit `Package.swift` to add Swift package dependencies
- Run `tuist generate` to regenerate the Xcode project
- Never edit the .xcodeproj file directly (it's gitignored and regenerated)

The app is sandboxed and requires security-scoped resource access for file operations.

## CI/CD Workflows

### PR Checks (Automated)

Runs automatically on all pull requests:
- Build validation (Debug configuration)
- Unit tests (VideoHelperTests)
- UI tests (VideoHelperUITests)
- Build warnings check

See status in PR checks section. All checks must pass before merging.

### Release Builds (Manual)

Trigger via GitHub Actions tab → Release Build workflow:

```bash
gh workflow run release-build.yml -f version="1.0.0" -f create_github_release=true
```

Produces:
- Unsigned .app bundle (for testing)
- ZIP archive with version number
- SHA-256 checksum for verification
- Optional GitHub Release with assets

For signed/notarized releases, configure code signing certificates in GitHub Secrets.

### Local Testing

Before pushing, verify your changes locally:

```bash
# Build
xcodebuild clean build -project VideoHelper.xcodeproj -scheme VideoHelper

# Run tests
xcodebuild test -project VideoHelper.xcodeproj -scheme VideoHelper -destination 'platform=macOS'
```

## Core Architecture

### MVVM with Swift Concurrency

- **Models**: `VideoTask`, `ExportPreset`, `TaskStatus` - immutable data structures
- **Views**: SwiftUI views with drag-and-drop support via `DropZoneView`
- **ViewModels**: `ProcessingQueueViewModel` - `@MainActor` class managing queue state
- **Services**: Actors for thread-safe operations (`VideoProcessor`, `ValidationService`)

### Video Processing Pipeline

The video processing flow in `VideoProcessor.swift` (actor):

1. **Load assets**: Video file and thumbnail image with security-scoped access
2. **Get properties**: Extract frame rate from video track
3. **Create composition**: Build `AVMutableComposition` with video/audio tracks
4. **Insert thumbnail**: Use `AVVideoComposition` with Core Animation layers to overlay thumbnail on first frame
5. **Add metadata**: Embed thumbnail as artwork in video metadata
6. **Export**: Hardware-accelerated H.264 encoding with preset-specific bitrates

**Critical implementation detail**: The thumbnail is rendered as a Core Animation layer with opacity animation (1.0→0.0 over one frame duration) to appear only on the first frame. This approach works around AVFoundation's limitation of not allowing direct first-frame replacement without complex custom video compositor implementations.

### Concurrency Model

- **VideoProcessor**: Actor-isolated for thread-safe video processing
- **ValidationService**: Actor-isolated for async validation checks
- **ProcessingQueueViewModel**: `@MainActor` for UI state management
- **NotificationManager**: Shared singleton with async authorization

Always use `async/await` for AVFoundation operations - they're naturally asynchronous.

## Key Files

### Core Video Processing
- `VideoHelper/Services/VideoProcessor.swift` - Main video processing logic with AVFoundation
- `VideoHelper/Services/ValidationService.swift` - Pre-flight validation (format, disk space, permissions)
- `VideoHelper/Services/NotificationManager.swift` - System notifications for completion

### State Management
- `VideoHelper/ViewModels/ProcessingQueueViewModel.swift` - Queue orchestration, task lifecycle
- `VideoHelper/Models/VideoTask.swift` - Task model with ID, URLs, status, output
- `VideoHelper/Models/TaskStatus.swift` - Enum: pending, processing, completed, failed

### UI Layer
- `VideoHelper/ContentView.swift` - Main interface with drop zones, settings, queue display
- `VideoHelper/Views/DropZoneView.swift` - Reusable drag-and-drop component with UTType filtering
- `VideoHelper/Views/QueueItemView.swift` - Queue item rendering with status indicators
- `VideoHelper/VideoHelperApp.swift` - App lifecycle, single-instance enforcement, quit confirmation

### Configuration
- `VideoHelper/Models/ExportPreset.swift` - Quality presets (4K, Full HD, HD, Telegram-optimized)

## Localization

Bilingual support via `.lproj` directories:
- `VideoHelper/Resources/en.lproj/Localizable.strings`
- `VideoHelper/Resources/ru.lproj/Localizable.strings`

Always use `NSLocalizedString("key", comment: "")` for user-facing strings.

## Export Presets

Five quality presets defined in `ExportPreset.swift`:
- **4K (2160p)**: 3840×2160, 20 Mbps
- **Full HD (1080p)**: 1920×1080, 8 Mbps
- **Telegram HD**: 1920×1080, 4 Mbps (optimized for messaging)
- **HD (720p)**: 1280×720, 4 Mbps
- **Telegram SD**: 1280×720, 2 Mbps (smaller file size)

Each preset includes: `displayName`, `filenameSuffix`, `targetBitrate`, `maxResolution`.

## Sandboxing and Security

The app is fully sandboxed and uses:
- **Security-scoped resources**: Files dropped into the app grant temporary access
- **NSSavePanel**: User explicitly chooses output location for each task
- **Single instance enforcement**: Prevents multiple app instances via `NSRunningApplication` check
- **Quit confirmation**: Alerts user when quitting with active processing tasks

## Known Limitations and Technical Debt

1. **No progress tracking**: Progress updates were removed for reliability. The export happens without percentage display but completes successfully.
2. **Video re-encoding required**: Can't preserve original codec when inserting thumbnail frame - full re-encode necessary.
3. **First-frame replacement**: Current implementation uses Core Animation overlay rather than true frame replacement. This is simpler but less efficient than a custom `AVVideoCompositing` implementation.

## Common Development Patterns

### Adding a new export preset
1. Add case to `ExportPreset` enum
2. Implement `displayName`, `filenameSuffix`, `targetBitrate`, `maxResolution`
3. Add localization keys to both `en.lproj` and `ru.lproj`
4. Update `VideoProcessor.export()` if new resolution mapping needed

### Modifying video processing
- All AVFoundation operations happen in `VideoProcessor` actor
- Use `try await asset.load(.property)` for async property access
- Always wrap operations in security-scoped resource access (see `process()` method)
- Test with various video codecs (H.264, HEVC, ProRes)

### UI changes
- Main layout in `ContentView.swift` - three sections: drop zones, settings, queue
- Window size managed via SwiftUI's `.defaultSize()` and programmatic expansion
- Use `@EnvironmentObject` to share `ProcessingQueueViewModel` across views
- Maintain bilingual support by adding localization keys

## Critical Technical Patterns

### Security-Scoped Resource Access (Mandatory)

**Always** use this pattern when working with user files in sandboxed environment:

```swift
let access = url.startAccessingSecurityScopedResource()
defer {
    if access { url.stopAccessingSecurityScopedResource() }
}
// ... work with file
```

Without this, file operations will fail with permission errors despite user granting access via drag-and-drop.

### AVFoundation Async Patterns

**Correct** way to access AVAsset properties:

```swift
let asset = AVAsset(url: videoURL)
let duration = try await asset.load(.duration)
let tracks = try await asset.load(.tracks)
let isPlayable = try await asset.load(.isPlayable)
```

**Never** access properties synchronously (`asset.duration`) - deprecated and unreliable.

### Actor Isolation Rules

- **VideoProcessor** and **ValidationService** are actors → call with `await`
- **ProcessingQueueViewModel** is `@MainActor` → UI updates happen automatically on main thread
- When calling actor methods from `@MainActor` context, Swift handles thread switching
- Never use `DispatchQueue.main.async` - use `await MainActor.run { }` instead

### Error Handling Pattern

Use typed errors from `ValidationError` enum for validation failures. Always provide localized error messages:

```swift
throw ValidationError.fileNotFound(url.path)
// Not: throw NSError(...)
```

In ViewModel, catch and display errors to user via NSAlert.

## Common Pitfalls and Solutions

### 1. Progress Tracking with AVAssetExportSession

**Problem**: `exportSession.progress` is unreliable and causes crashes/freezes.

**Solution**: Don't use KVO or observe progress. Just await completion:
```swift
await exportSession.export()
```

This is why progress bars were removed - reliability > UX in this case.

### 2. Video Track Frame Rate

**Problem**: Some videos have `nominalFrameRate = 0`.

**Solution**: Always provide fallback:
```swift
let frameRate = try await videoTrack.load(.nominalFrameRate)
return frameRate > 0 ? frameRate : 30.0  // Default to 30fps
```

### 3. Core Animation Layer Timing

**Problem**: Thumbnail animation must use `AVCoreAnimationBeginTimeAtZero`, not `CACurrentMediaTime()`.

**Solution**: Always use:
```swift
animation.beginTime = AVCoreAnimationBeginTimeAtZero
```

Regular CACurrentMediaTime() causes timing desync in video composition.

### 4. Window Resize Tracking

**Problem**: SwiftUI doesn't natively detect window resize events.

**Solution**: Use `NSViewRepresentable` with `NotificationCenter` (see `WindowAccessor` in ContentView).

### 5. Sandboxing and File Dialogs

**Problem**: Can't write to arbitrary locations without user permission.

**Solution**: Always use `NSSavePanel` for output - it grants write permission to chosen location. Don't try to write to input directory automatically.

## Debugging Video Processing

### Enable Detailed Logging

Processing already has extensive print statements. Watch console for:
- `🎬` Video processing start
- `🔐` Security-scoped access status
- `📹` Asset loading
- `✅` Success checkpoints
- `❌` Error indicators

### Common Issues

**"No video track found"**: File is corrupted or not a valid video format. Check with `ffprobe`.

**"Export failed"**: Usually disk space or permissions. Check:
1. Enough free space (need ~1.2x estimated size)
2. NSSavePanel was used for output location
3. Security-scoped access is active

**"Thumbnail not visible"**: Check:
- Image loaded successfully (valid JPEG/PNG/HEIC)
- Layer opacity animation configured correctly
- `animationTool` set on `AVMutableVideoComposition`

### Testing AVFoundation Changes

Use real video files, not test stubs. Recommended test files:
- Various codecs: H.264, HEVC, ProRes
- Various containers: .mp4, .mov, .m4v
- Edge cases: 60fps video, 4K video, portrait video, videos without audio

## Performance Considerations

### Video Processing is CPU/GPU Intensive

- Use hardware acceleration (built into AVAssetExportSession)
- Don't run multiple exports in parallel - sequential queue prevents system overload
- Large files (4K, long duration) may take several minutes

### Memory Management

- AVAsset objects are lazy - they don't load entire video into memory
- Export session streams video frame-by-frame
- No special memory management needed beyond standard Swift ARC

### UI Responsiveness

- All heavy operations in actors (off main thread)
- UI updates only for state changes (`@Published` properties)
- Window expansion animated with `NSAnimationContext` for smooth UX

## Testing Notes

- UI tests in `VideoHelperUITests/` (includes automated tests)
- Manual testing should cover: various video formats, different resolutions, audio-only files, corrupted files
- Test sandboxing: verify security-scoped resource access, NSSavePanel flow
- Localization testing: switch system language between English and Russian

### Swift 6 Concurrency in Tests

**Main app and unit tests**: Use Swift 6.0 language mode with strict concurrency checking (`SWIFT_STRICT_CONCURRENCY = complete`).

**UI tests**: Use `SWIFT_STRICT_CONCURRENCY = minimal` due to XCTest/XCUIApplication concurrency issues:
- XCUIApplication and related XCTest APIs are `@MainActor` isolated in Swift 6
- Test methods need to be synchronous per XCTest requirements
- Using `minimal` allows tests to compile while maintaining type safety
- This is a temporary workaround until XCTest fully supports Swift 6 strict concurrency
- UI tests are skipped on CI (via `EXCLUDED_SOURCE_FILE_NAMES`) but work fine locally
