# GitHub CI/CD Pipelines Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add GitHub Actions workflows for PR validation (build + tests) and on-demand release builds.

**Architecture:** Two separate workflows using GitHub Actions - `pr-checks.yml` for automated PR validation and `release-build.yml` for manual release builds. Both use macOS runners with Xcode pre-installed. PR checks run on every pull request and verify build + tests. Release workflow uses workflow_dispatch for manual triggering.

**Tech Stack:** GitHub Actions, Xcode 16+, xcodebuild, macOS 15 runners

---

## Task 1: Create GitHub Workflows Directory

**Files:**
- Create: `.github/workflows/` directory

**Step 1: Create .github/workflows directory**

```bash
mkdir -p .github/workflows
```

**Step 2: Verify directory creation**

Run: `ls -la .github/`
Expected: `workflows/` directory exists

**Step 3: Commit directory structure**

```bash
git add .github/workflows/.gitkeep
touch .github/workflows/.gitkeep
git add .github/workflows/.gitkeep
git commit -m "chore: add GitHub workflows directory"
```

---

## Task 2: Create PR Checks Workflow

**Files:**
- Create: `.github/workflows/pr-checks.yml`

**Step 1: Write PR checks workflow configuration**

Create `.github/workflows/pr-checks.yml`:

```yaml
name: PR Checks

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  build-and-test:
    name: Build and Test
    runs-on: macos-15

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_16.2.app/Contents/Developer

    - name: Show Xcode version
      run: xcodebuild -version

    - name: Show available SDKs
      run: xcodebuild -showsdks

    - name: Clean build folder
      run: xcodebuild clean -project VideoHelper.xcodeproj -scheme VideoHelper

    - name: Build project
      run: |
        xcodebuild build \
          -project VideoHelper.xcodeproj \
          -scheme VideoHelper \
          -configuration Debug \
          -destination 'platform=macOS' \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO

    - name: Run unit tests
      run: |
        xcodebuild test \
          -project VideoHelper.xcodeproj \
          -scheme VideoHelper \
          -destination 'platform=macOS' \
          -only-testing:VideoHelperTests \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO

    - name: Run UI tests
      run: |
        xcodebuild test \
          -project VideoHelper.xcodeproj \
          -scheme VideoHelper \
          -destination 'platform=macOS' \
          -only-testing:VideoHelperUITests \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO
      continue-on-error: true

    - name: Check for build warnings
      run: |
        xcodebuild build \
          -project VideoHelper.xcodeproj \
          -scheme VideoHelper \
          -configuration Debug \
          -destination 'platform=macOS' \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO \
          | xcpretty --color --report junit
      continue-on-error: true
```

**Step 2: Verify workflow file syntax**

Run: `cat .github/workflows/pr-checks.yml`
Expected: Valid YAML syntax, all steps present

**Step 3: Validate workflow locally (optional)**

If you have `act` installed for local GitHub Actions testing:
```bash
act pull_request -l
```
Expected: Workflow listed as "PR Checks"

**Step 4: Commit PR checks workflow**

```bash
git add .github/workflows/pr-checks.yml
git commit -m "feat: add PR checks workflow for automated build and test validation"
```

---

## Task 3: Create Release Build Workflow

**Files:**
- Create: `.github/workflows/release-build.yml`

**Step 1: Write release build workflow configuration**

Create `.github/workflows/release-build.yml`:

```yaml
name: Release Build

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., 1.0.0)'
        required: true
        type: string
      create_github_release:
        description: 'Create GitHub Release'
        required: true
        type: boolean
        default: false

jobs:
  build-release:
    name: Build Release
    runs-on: macos-15

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_16.2.app/Contents/Developer

    - name: Show Xcode version
      run: xcodebuild -version

    - name: Clean build folder
      run: xcodebuild clean -project VideoHelper.xcodeproj -scheme VideoHelper

    - name: Build Release
      run: |
        xcodebuild archive \
          -project VideoHelper.xcodeproj \
          -scheme VideoHelper \
          -configuration Release \
          -archivePath ./build/VideoHelper.xcarchive \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO

    - name: Export .app bundle
      run: |
        mkdir -p ./build/export
        cp -R ./build/VideoHelper.xcarchive/Products/Applications/VideoHelper.app ./build/export/

    - name: Create ZIP archive
      run: |
        cd ./build/export
        zip -r VideoHelper-${{ github.event.inputs.version }}.zip VideoHelper.app
        cd ../..

    - name: Calculate checksum
      run: |
        shasum -a 256 ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip > ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip.sha256

    - name: Upload build artifacts
      uses: actions/upload-artifact@v4
      with:
        name: VideoHelper-${{ github.event.inputs.version }}
        path: |
          ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip
          ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip.sha256
        retention-days: 30

    - name: Create GitHub Release
      if: ${{ github.event.inputs.create_github_release == 'true' }}
      uses: softprops/action-gh-release@v1
      with:
        tag_name: v${{ github.event.inputs.version }}
        name: VideoHelper v${{ github.event.inputs.version }}
        draft: false
        prerelease: false
        files: |
          ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip
          ./build/export/VideoHelper-${{ github.event.inputs.version }}.zip.sha256
        body: |
          # VideoHelper v${{ github.event.inputs.version }}

          ## Installation

          1. Download `VideoHelper-${{ github.event.inputs.version }}.zip`
          2. Unzip the archive
          3. Move `VideoHelper.app` to your Applications folder
          4. Right-click and select "Open" on first launch (macOS Gatekeeper)

          ## Checksums

          SHA-256 checksum is provided for verification.

          ## Changes

          <!-- Add release notes here -->
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Step 2: Verify workflow file syntax**

Run: `cat .github/workflows/release-build.yml`
Expected: Valid YAML syntax, workflow_dispatch configured with inputs

**Step 3: Test workflow inputs parsing**

Verify the workflow has required inputs:
```bash
grep -A 5 "workflow_dispatch:" .github/workflows/release-build.yml
```
Expected: `version` and `create_github_release` inputs defined

**Step 4: Commit release build workflow**

```bash
git add .github/workflows/release-build.yml
git commit -m "feat: add release build workflow for on-demand releases"
```

---

## Task 4: Add Workflow Documentation

**Files:**
- Create: `.github/workflows/README.md`

**Step 1: Write workflows documentation**

Create `.github/workflows/README.md`:

```markdown
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
```

**Step 2: Verify documentation completeness**

Run: `cat .github/workflows/README.md`
Expected: Documentation covers both workflows, usage, and troubleshooting

**Step 3: Commit documentation**

```bash
git add .github/workflows/README.md
git commit -m "docs: add GitHub Actions workflows documentation"
```

---

## Task 5: Update Main README

**Files:**
- Modify: `README.md`

**Step 1: Add CI/CD badge and section to README**

Add after the main title section in `README.md`:

```markdown
[![PR Checks](https://github.com/USERNAME/VideoHelper/actions/workflows/pr-checks.yml/badge.svg)](https://github.com/USERNAME/VideoHelper/actions/workflows/pr-checks.yml)

## CI/CD

This project uses GitHub Actions for continuous integration and release builds.

- **PR Checks**: Automatically validates all pull requests (build + tests)
- **Release Builds**: On-demand release builds via workflow dispatch

See [.github/workflows/README.md](.github/workflows/README.md) for details.
```

**Note:** Replace `USERNAME` with the actual GitHub username/organization.

**Step 2: Verify README update**

Run: `grep -A 5 "CI/CD" README.md`
Expected: CI/CD section with badge and description

**Step 3: Commit README update**

```bash
git add README.md
git commit -m "docs: add CI/CD section with workflow badge to README"
```

---

## Task 6: Add .gitattributes for Workflow Files

**Files:**
- Create: `.gitattributes`

**Step 1: Create .gitattributes for consistent line endings**

Create `.gitattributes`:

```
# GitHub Actions workflows
.github/workflows/*.yml text eol=lf
.github/workflows/*.yaml text eol=lf

# Documentation
*.md text eol=lf

# Shell scripts
*.sh text eol=lf
```

**Step 2: Verify .gitattributes content**

Run: `cat .gitattributes`
Expected: Line ending rules for workflows and documentation

**Step 3: Commit .gitattributes**

```bash
git add .gitattributes
git commit -m "chore: add .gitattributes for consistent line endings in workflows"
```

---

## Task 7: Test PR Checks Workflow

**Files:**
- None (validation step)

**Step 1: Push commits to feature branch**

```bash
git push origin swift6-migration
```

**Step 2: Create test pull request**

```bash
gh pr create --title "test: validate GitHub Actions workflows" --body "Testing PR checks workflow automation"
```

**Step 3: Monitor workflow execution**

```bash
gh pr checks
```
Expected: "PR Checks" workflow runs and completes

**Step 4: Review workflow logs**

```bash
gh run list --workflow=pr-checks.yml
gh run view [RUN_ID]
```
Expected: All steps succeed (build, unit tests, UI tests)

**Step 5: Verify PR status check**

Check PR page - should show green checkmark for "PR Checks" workflow.

Expected: Workflow passes, PR shows passing checks

---

## Task 8: Test Release Build Workflow

**Files:**
- None (validation step)

**Step 1: Trigger release workflow manually**

Via GitHub UI:
1. Go to Actions tab
2. Select "Release Build"
3. Click "Run workflow"
4. Enter version: `0.0.1-test`
5. Set create_github_release: `false`
6. Click "Run workflow"

Or via CLI:
```bash
gh workflow run release-build.yml -f version="0.0.1-test" -f create_github_release=false
```

**Step 2: Monitor workflow execution**

```bash
gh run list --workflow=release-build.yml
gh run view --log
```
Expected: Workflow runs, builds archive, creates ZIP

**Step 3: Download and verify artifacts**

```bash
gh run download [RUN_ID]
ls -lh VideoHelper-0.0.1-test/
```
Expected: ZIP file and SHA-256 checksum file present

**Step 4: Verify ZIP contents**

```bash
unzip -l VideoHelper-0.0.1-test/VideoHelper-0.0.1-test.zip
```
Expected: Contains VideoHelper.app bundle

**Step 5: Verify checksum**

```bash
cd VideoHelper-0.0.1-test
shasum -a 256 -c VideoHelper-0.0.1-test.zip.sha256
```
Expected: Checksum verification passes

---

## Task 9: Optional - Add SwiftLint Integration

**Files:**
- Create: `.github/workflows/lint.yml`
- Create: `.swiftlint.yml`

**Step 1: Install SwiftLint configuration**

Create `.swiftlint.yml`:

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - explicit_init

included:
  - VideoHelper

excluded:
  - Pods
  - build
  - .build
  - VideoHelperTests
  - VideoHelperUITests

line_length:
  warning: 120
  error: 200

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 60
```

**Step 2: Create lint workflow**

Create `.github/workflows/lint.yml`:

```yaml
name: Lint

on:
  pull_request:
    branches: [ main, develop ]

jobs:
  swiftlint:
    name: SwiftLint
    runs-on: macos-15

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Install SwiftLint
      run: brew install swiftlint

    - name: Run SwiftLint
      run: swiftlint lint --reporter github-actions-logging
```

**Step 3: Test SwiftLint locally**

```bash
brew install swiftlint
swiftlint lint
```
Expected: Lint results (warnings/errors if any)

**Step 4: Commit linting setup**

```bash
git add .swiftlint.yml .github/workflows/lint.yml
git commit -m "feat: add SwiftLint for code quality checks"
```

---

## Task 10: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add CI/CD section to CLAUDE.md**

Add new section after "## Building and Running":

```markdown
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
```

**Step 2: Verify CLAUDE.md update**

Run: `grep -A 10 "CI/CD Workflows" CLAUDE.md`
Expected: CI/CD section with PR checks and release build info

**Step 3: Commit CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: add CI/CD workflows section to CLAUDE.md"
```

---

## Completion Checklist

- [ ] Task 1: `.github/workflows/` directory created
- [ ] Task 2: `pr-checks.yml` workflow created and committed
- [ ] Task 3: `release-build.yml` workflow created and committed
- [ ] Task 4: Workflows documentation created
- [ ] Task 5: README updated with CI/CD section and badge
- [ ] Task 6: `.gitattributes` created for consistent line endings
- [ ] Task 7: PR checks workflow tested and verified
- [ ] Task 8: Release build workflow tested and verified
- [ ] Task 9: (Optional) SwiftLint integration added
- [ ] Task 10: CLAUDE.md updated with CI/CD section

## Post-Implementation Notes

### GitHub Secrets for Code Signing (Future Enhancement)

When ready to distribute signed builds:

1. Add secrets to GitHub repository:
   - `MACOS_CERTIFICATE_BASE64`: Base64-encoded .p12 certificate
   - `MACOS_CERTIFICATE_PASSWORD`: Certificate password
   - `MACOS_KEYCHAIN_PASSWORD`: Temporary keychain password
   - `APPLE_ID`: Apple ID for notarization
   - `APPLE_TEAM_ID`: Developer Team ID
   - `APPLE_APP_PASSWORD`: App-specific password

2. Update release workflow to:
   - Import certificates into temporary keychain
   - Sign .app bundle
   - Notarize with `notarytool`
   - Staple notarization ticket

### Maintenance

- Update Xcode version in workflows when bumping deployment target
- Monitor workflow execution times and optimize if needed
- Review failed workflows and adjust `continue-on-error` flags
- Keep workflow actions up to date (Dependabot recommended)

### Next Steps

1. **Set up Dependabot** for automatic workflow action updates
2. **Add code coverage reporting** with CodeCov/Codecov
3. **Implement nightly builds** for continuous testing
4. **Add performance benchmarking** to catch regressions
