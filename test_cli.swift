#!/usr/bin/env swift

import Foundation
import AVFoundation
import AppKit

print("🎬 VideoHelper CLI Test Tool")
print("=" + String(repeating: "=", count: 60))

// Paths
let videoPath = "/Users/krozov/Movies/Android Broadcast/Модель разрешений/Mодель разрешений в Android ОС.mp4"
let imageDir = "/Users/krozov/Movies/Android Broadcast/Модель разрешений/Обложки"

// Find first PNG image
guard let imagePath = try? FileManager.default.contentsOfDirectory(atPath: imageDir)
    .filter({ $0.hasSuffix(".png") })
    .first
    .map({ imageDir + "/" + $0 }) else {
    print("❌ Не найдены PNG файлы в \(imageDir)")
    exit(1)
}

let videoURL = URL(fileURLWithPath: videoPath)
let imageURL = URL(fileURLWithPath: imagePath)

print("\n📁 Тестовые файлы:")
print("   Видео: \(videoURL.lastPathComponent)")
print("   Картинка: \(imageURL.lastPathComponent)")

// Check files exist
let fm = FileManager.default
guard fm.fileExists(atPath: videoPath) else {
    print("❌ Видео не найдено")
    exit(1)
}
guard fm.fileExists(atPath: imagePath) else {
    print("❌ Картинка не найдена")
    exit(1)
}

print("\n✅ Файлы найдены")

// Get file sizes
if let videoAttrs = try? fm.attributesOfItem(atPath: videoPath),
   let videoSize = videoAttrs[.size] as? Int64 {
    print("📦 Размер видео: \(ByteCountFormatter.string(fromByteCount: videoSize, countStyle: .file))")
}

if let imageAttrs = try? fm.attributesOfItem(atPath: imagePath),
   let imageSize = imageAttrs[.size] as? Int64 {
    print("📦 Размер картинки: \(ByteCountFormatter.string(fromByteCount: imageSize, countStyle: .file))")
}

// Validate video
print("\n🔍 Проверка видео...")
let asset = AVURLAsset(url: videoURL)

let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        // Load basic properties
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        let videoTracks = tracks.filter { $0.mediaType == .video }

        guard !videoTracks.isEmpty else {
            print("❌ Видео не содержит видео-дорожек")
            exit(1)
        }

        let videoTrack = videoTracks[0]
        let naturalSize = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)

        print("✅ Формат видео валиден")
        print("   Разрешение: \(Int(naturalSize.width))x\(Int(naturalSize.height))")
        print("   Длительность: \(String(format: "%.1f", CMTimeGetSeconds(duration))) сек")
        print("   FPS: \(Int(frameRate))")

        // Check image
        print("\n🔍 Проверка картинки...")
        if let nsImage = NSImage(contentsOf: imageURL) {
            print("✅ Картинка загружена")
            print("   Размер: \(Int(nsImage.size.width))x\(Int(nsImage.size.height))")
        } else {
            print("❌ Не удалось загрузить картинку")
            exit(1)
        }

        // Output info
        print("\n📤 Информация о выводе:")
        let outputDir = videoURL.deletingLastPathComponent()
        print("   Папка: \(outputDir.path)")

        let basename = videoURL.deletingPathExtension().lastPathComponent
        let outputName = "\(basename)_telegram_hd.mp4"
        print("   Имя файла: \(outputName)")

        // Estimate output size
        let durationSeconds = CMTimeGetSeconds(duration)
        let videoBitrate: Int64 = 4_000_000 // 4 Mbps for HD
        let audioBitrate: Int64 = 128_000   // 128 kbps
        let estimatedSize = Int64(durationSeconds * Double(videoBitrate + audioBitrate) / 8.0)
        print("   Примерный размер: \(ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file))")

        // Check disk space
        if let attrs = try? fm.attributesOfFileSystem(forPath: outputDir.path),
           let freeSpace = attrs[.systemFreeSize] as? Int64 {
            print("   Свободно на диске: \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))")

            if freeSpace > estimatedSize * 2 {
                print("   ✅ Достаточно места")
            } else {
                print("   ⚠️  Может не хватить места")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
        print("✅ ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ!")
        print("\n💡 Готово к обработке в VideoHelper:")
        print("   1. Откройте VideoHelper")
        print("   2. Перетащите эти файлы в зоны")
        print("   3. Выберите 'Telegram HD (1080p)'")
        print("   4. Нажмите 'Добавить в очередь'")
        print("\n⏱️  Примерное время обработки: ~\(Int(durationSeconds / 60)) минут")

    } catch {
        print("❌ Ошибка: \(error.localizedDescription)")
        exit(1)
    }

    semaphore.signal()
}

semaphore.wait()
exit(0)
