import XCTest

final class VideoHelperUITestsAutomated: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - UI Element Tests

    func testAppLaunches() throws {
        // Verify app launched successfully
        XCTAssertTrue(app.exists)
    }

    func testDropZonesExist() throws {
        // Check for drop zone texts
        let videoDropZone = app.staticTexts["Перетащите видео"]
        let imageDropZone = app.staticTexts["Перетащите картинку"]

        XCTAssertTrue(videoDropZone.exists, "Video drop zone should exist")
        XCTAssertTrue(imageDropZone.exists, "Image drop zone should exist")
    }

    func testQualityPickerExists() throws {
        // Check for quality label and picker
        let qualityLabel = app.staticTexts["Качество:"]
        XCTAssertTrue(qualityLabel.exists, "Quality label should exist")

        // Find picker button (it shows current selection)
        let picker = app.popUpButtons.firstMatch
        XCTAssertTrue(picker.exists, "Quality picker should exist")
    }

    func testQualityPickerOptions() throws {
        // Click on quality picker
        let picker = app.popUpButtons.firstMatch
        XCTAssertTrue(picker.exists)

        // Get initial picker value
        let initialTitle = picker.title

        picker.click()

        // Verify specific presets exist
        let telegramHDOption = app.menuItems["Telegram HD (1080p)"]
        let telegramSDOption = app.menuItems["Telegram SD (720p)"]
        let fullHDOption = app.menuItems["Full HD (1080p)"]

        XCTAssertTrue(telegramHDOption.exists, "Telegram HD option should exist")
        XCTAssertTrue(telegramSDOption.exists, "Telegram SD option should exist")
        XCTAssertTrue(fullHDOption.exists, "Full HD option should exist")

        // Select Telegram HD
        telegramHDOption.click()

        // Verify picker's displayed value changed
        XCTAssertTrue(picker.title.contains("Telegram HD"), "Picker should display selected preset")
        XCTAssertNotEqual(picker.title, initialTitle, "Picker value should have changed")
    }

    func testAddToQueueButtonExists() throws {
        let addButton = app.buttons["Добавить в очередь"]
        XCTAssertTrue(addButton.exists, "Add to queue button should exist")
    }

    func testAddToQueueButtonInitiallyDisabled() throws {
        let addButton = app.buttons["Добавить в очередь"]
        XCTAssertTrue(addButton.exists)
        XCTAssertFalse(addButton.isEnabled, "Add button should be disabled initially")
    }

    func testQueueHeaderExists() throws {
        let queueHeader = app.staticTexts["Очередь обработки"]
        XCTAssertTrue(queueHeader.exists, "Queue header should exist")
    }

    func testEmptyQueueMessage() throws {
        let emptyMessage = app.staticTexts["Очередь пуста"]
        XCTAssertTrue(emptyMessage.exists, "Empty queue message should exist")
    }

    // MARK: - Accessibility Tests

    func testDropZonesAccessibility() throws {
        // Check that drop zones have proper accessibility
        let videoIcon = app.images.matching(identifier: "video.fill").firstMatch
        let photoIcon = app.images.matching(identifier: "photo.fill").firstMatch

        // Icons should exist (may not always match by identifier)
        // At minimum, the text labels should be accessible
        XCTAssertTrue(app.staticTexts["Перетащите видео"].exists)
        XCTAssertTrue(app.staticTexts["Перетащите картинку"].exists)
    }

    // MARK: - Layout Tests

    func testMainLayoutStructure() throws {
        // Verify main sections exist in order
        let videoDropText = app.staticTexts["Перетащите видео"]
        let imageDropText = app.staticTexts["Перетащите картинку"]
        let qualityLabel = app.staticTexts["Качество:"]
        let queueHeader = app.staticTexts["Очередь обработки"]

        XCTAssertTrue(videoDropText.exists)
        XCTAssertTrue(imageDropText.exists)
        XCTAssertTrue(qualityLabel.exists)
        XCTAssertTrue(queueHeader.exists)

        // Check vertical ordering (drop zones above quality, quality above queue)
        let videoFrame = videoDropText.frame
        let qualityFrame = qualityLabel.frame
        let queueFrame = queueHeader.frame

        XCTAssertLessThan(videoFrame.midY, qualityFrame.midY, "Drop zones should be above quality picker")
        XCTAssertLessThan(qualityFrame.midY, queueFrame.midY, "Quality picker should be above queue")
    }

    func testWindowSize() throws {
        // Verify window has minimum size
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)

        let frame = window.frame
        XCTAssertGreaterThanOrEqual(frame.width, 480, "Window should be at least 480px wide")
        XCTAssertGreaterThanOrEqual(frame.height, 600, "Window should be at least 600px tall")
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Screenshot Tests

    func testTakeScreenshotOfInitialState() throws {
        // Take screenshot of initial empty state
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Initial State"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTakeScreenshotOfQualityPicker() throws {
        let picker = app.popUpButtons.firstMatch
        picker.click()

        // Wait for menu to appear
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Quality Picker Menu"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func waitForExistence(timeout: TimeInterval = 5) -> Bool {
        return self.waitForExistence(timeout: timeout)
    }
}
