# GitHub Actions Workflows

This directory contains CI/CD workflows for VideoHelper.

## Workflows

### PR Checks (`pr-checks.yml`)

**Trigger:** Automatically runs on every pull request and push to `main` or `develop` branches.

**Purpose:** Validates code quality and functionality before merging.

**Steps:**
1. Checkout code
2. Configure Xcode 16.2
3. Clean build folder
4. Build Debug configuration
5. Run unit tests (VideoHelperTests)
6. Run UI tests (VideoHelperUITests)
7. Check for build warnings

**Runner:** `macos-15` with Xcode 16.2

**Duration:** ~5-10 minutes

### Release Build (`release-build.yml`)

**Trigger:** Manual workflow dispatch from GitHub Actions tab.

**Purpose:** Create release builds for distribution.

**Inputs:**
- `version` (required): Release version number (e.g., "1.0.0")
- `create_github_release` (optional): Whether to create a GitHub Release (default: false)

**Steps:**
1. Checkout code
2. Configure Xcode 16.2
3. Build Release configuration
4. Archive .app bundle
5. Create ZIP archive
6. Calculate SHA-256 checksum
7. Upload artifacts (retained for 30 days)
8. Optionally create GitHub Release with assets

**Runner:** `macos-15` with Xcode 16.2

**Duration:** ~8-15 minutes

## Usage

### Running PR Checks

PR checks run automatically. To trigger manually:

1. Go to Actions tab
2. Select "PR Checks" workflow
3. Click "Run workflow"
4. Select branch and run

### Creating a Release Build

1. Go to Actions tab
2. Select "Release Build" workflow
3. Click "Run workflow"
4. Enter version number (e.g., `1.0.0`)
5. Choose whether to create GitHub Release
6. Click "Run workflow" button
7. Wait for completion
8. Download artifacts from workflow run or GitHub Releases

## Code Signing Notes

Current workflows use unsigned builds for CI/CD simplicity:
- `CODE_SIGN_IDENTITY=""`
- `CODE_SIGNING_REQUIRED=NO`
- `CODE_SIGNING_ALLOWED=NO`

For distribution builds with notarization:
1. Add certificates to GitHub Secrets
2. Update workflows to use signing identity
3. Add notarization step using `notarytool`
4. Remove CODE_SIGNING_ALLOWED=NO flags

## Troubleshooting

### Build Failures

- Check Xcode version compatibility (requires 16.2+)
- Verify macOS SDK version matches deployment target
- Review build logs for specific errors

### Test Failures

- UI tests may fail in headless CI environment
- Check for hardcoded paths or timing issues
- Use `continue-on-error: true` for flaky tests during transition

### Workflow Not Triggering

- Verify branch names match trigger configuration
- Check workflow file syntax with yamllint
- Ensure workflows are on the default branch
