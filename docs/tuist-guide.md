# Tuist Usage Guide for VideoHelper

## Overview

VideoHelper uses [Tuist](https://docs.tuist.dev/) to generate Xcode projects from Swift manifest files. This eliminates merge conflicts in .xcodeproj files and provides better project management.

## Installation

```bash
brew install --cask tuist
```

## Common Commands

### Generate Xcode Project

Always run after pulling changes or editing manifests:

```bash
tuist generate
```

### Build the App

```bash
tuist build VideoHelper
```

### Run Tests

```bash
# Run all tests
tuist test

# Run with specific configuration
tuist test --configuration Debug
```

### Edit Manifests in Xcode

```bash
tuist edit
```

This opens the manifest files (Project.swift, etc.) in Xcode for editing.

### Clean Generated Files

```bash
tuist clean
```

## Project Structure

### Manifest Files

- **Tuist.swift**: Project-scoped Tuist configuration
- **Project.swift**: Defines targets, dependencies, and project structure
- **Package.swift**: Swift package dependencies (if any)
- **xcconfigs/**: Build settings extracted from Xcode

### Targets

1. **VideoHelper**: Main macOS application
   - Sources: `VideoHelper/**/*.swift`
   - Resources: Assets, localizations
   - Bundle ID: `dev.androidbroadcast.VideoHelper`

2. **VideoHelperTests**: Unit tests
   - Depends on VideoHelper target
   - Swift 6 strict concurrency enabled

3. **VideoHelperUITests**: UI tests
   - Depends on VideoHelper target
   - Uses `SWIFT_STRICT_CONCURRENCY=minimal` for XCTest compatibility

## Modifying the Project

### Adding a New Swift File

1. Create the .swift file in the appropriate directory
2. Run `tuist generate` to regenerate the project
3. File will automatically be included (via `VideoHelper/**/*.swift` glob)

### Adding a Dependency

Edit `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0"),
]
```

Then regenerate:

```bash
tuist install  # Resolve dependencies
tuist generate # Regenerate project
```

### Changing Build Settings

1. Edit the appropriate `.xcconfig` file in `xcconfigs/`
2. Run `tuist generate`
3. Build settings will be applied

### Adding a New Target

Edit `Project.swift` and add to the `targets` array:

```swift
.target(
    name: "NewTarget",
    destinations: .macOS,
    product: .framework,
    bundleId: "dev.androidbroadcast.NewTarget",
    sources: ["NewTarget/**/*.swift"],
    dependencies: [.target(name: "VideoHelper")]
)
```

## Troubleshooting

### "No such module" Error

Run `tuist generate` to regenerate the project.

### Build Settings Not Applied

1. Check the `.xcconfig` file in `xcconfigs/`
2. Verify it's referenced in `Project.swift`
3. Run `tuist clean && tuist generate`

### Tests Not Running

Ensure test target dependencies are correct in `Project.swift`:

```swift
dependencies: [.target(name: "VideoHelper")]
```

## CI/CD Integration

GitHub Actions workflows automatically:
1. Install Tuist via Homebrew
2. Run `tuist generate`
3. Build and test using Tuist commands

See `.github/workflows/` for implementation details.

## Resources

- [Tuist Documentation](https://docs.tuist.dev/)
- [Tuist GitHub](https://github.com/tuist/tuist)
- [Migration Guide](https://docs.tuist.dev/en/guides/features/projects/adoption/migrate/xcode-project)
