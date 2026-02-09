#!/usr/bin/env swift

import Foundation
import AVFoundation
import UniformTypeIdentifiers

// Test files
let videoPath = "/Users/krozov/Movies/Android Broadcast/Модель разрешений/Mодель разрешений в Android ОС.mp4"
let imagePath = "/Users/krozov/Movies/Android Broadcast/Модель разрешений/Обложки/Система разрешений Android 16x9 (3).png"

print("🧪 VideoHelper Automated Test")
print("=" + String(repeating: "=", count: 50))

// Test 1: Check files exist
print("\n1️⃣ Проверка существования файлов...")
let fileManager = FileManager.default

if fileManager.fileExists(atPath: videoPath) {
    print("✅ Видео найдено: \(videoPath)")
} else {
    print("❌ Видео НЕ найдено: \(videoPath)")
    exit(1)
}

if fileManager.fileExists(atPath: imagePath) {
    print("✅ Картинка найдена: \(imagePath)")
} else {
    print("❌ Картинка НЕ найдена: \(imagePath)")
    exit(1)
}

// Test 2: Check file readability
print("\n2️⃣ Проверка доступа к файлам...")
if fileManager.isReadableFile(atPath: videoPath) {
    print("✅ Видео доступно для чтения")
} else {
    print("❌ Видео недоступно для чтения")
    exit(1)
}

if fileManager.isReadableFile(atPath: imagePath) {
    print("✅ Картинка доступна для чтения")
} else {
    print("❌ Картинка недоступна для чтения")
    exit(1)
}

// Test 3: Validate video format
print("\n3️⃣ Проверка формата видео...")
let videoURL = URL(fileURLWithPath: videoPath)
let asset = AVAsset(url: videoURL)

let semaphore = DispatchSemaphore(value: 0)
var videoValid = false

Task {
    do {
        let isPlayable = try await asset.load(.isPlayable)
        if isPlayable {
            print("✅ Видео воспроизводимо")

            let tracks = try await asset.load(.tracks)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            if !videoTracks.isEmpty {
                print("✅ Видео содержит видео-дорожки: \(videoTracks.count)")

                // Get video info
                if let firstTrack = videoTracks.first {
                    let size = try await firstTrack.load(.naturalSize)
                    let duration = try await asset.load(.duration)
                    let frameRate = try await firstTrack.load(.nominalFrameRate)

                    print("📹 Разрешение: \(Int(size.width))x\(Int(size.height))")
                    print("⏱️  Длительность: \(String(format: "%.2f", CMTimeGetSeconds(duration))) сек")
                    print("🎞️  FPS: \(frameRate)")
                }
                videoValid = true
            } else {
                print("❌ Видео не содержит видео-дорожек")
            }
        } else {
            print("❌ Видео не воспроизводимо")
        }
    } catch {
        print("❌ Ошибка проверки видео: \(error)")
    }
    semaphore.signal()
}

semaphore.wait()

if !videoValid {
    exit(1)
}

// Test 4: Validate image format
print("\n4️⃣ Проверка формата картинки...")
let imageURL = URL(fileURLWithPath: imagePath)
guard let contentType = UTType(filenameExtension: imageURL.pathExtension) else {
    print("❌ Не удалось определить тип файла")
    exit(1)
}

let supportedTypes: [UTType] = [.jpeg, .png, .heic]
if supportedTypes.contains(where: { $0.conforms(to: contentType) || contentType.conforms(to: $0) }) {
    print("✅ Формат картинки поддерживается: \(contentType.identifier)")
} else {
    print("❌ Формат картинки не поддерживается: \(contentType.identifier)")
    exit(1)
}

// Test 5: Check output directory permissions
print("\n5️⃣ Проверка прав на запись...")
let outputDir = videoURL.deletingLastPathComponent()
print("📁 Папка вывода: \(outputDir.path)")

let testFile = outputDir.appendingPathComponent(".videohelper_test_\(UUID().uuidString)")
do {
    try Data().write(to: testFile)
    try fileManager.removeItem(at: testFile)
    print("✅ Права на запись есть")
} catch {
    print("⚠️  Нет прав на запись: \(error.localizedDescription)")
    print("ℹ️  Это нормально для sandboxed приложения")
    print("ℹ️  Права появятся после drag & drop")
}

// Test 6: File sizes
print("\n6️⃣ Информация о размерах...")
if let videoAttrs = try? fileManager.attributesOfItem(atPath: videoPath),
   let videoSize = videoAttrs[.size] as? Int64 {
    print("📦 Размер видео: \(ByteCountFormatter.string(fromByteCount: videoSize, countStyle: .file))")
}

if let imageAttrs = try? fileManager.attributesOfItem(atPath: imagePath),
   let imageSize = imageAttrs[.size] as? Int64 {
    print("📦 Размер картинки: \(ByteCountFormatter.string(fromByteCount: imageSize, countStyle: .file))")
}

print("\n" + String(repeating: "=", count: 50))
print("✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!")
print("\n💡 Теперь можете перетащить эти файлы в приложение:")
print("   Видео: \(videoURL.lastPathComponent)")
print("   Картинка: \(imageURL.lastPathComponent)")
