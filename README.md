# VideoHelper

A native macOS application for adding custom thumbnails to videos with one click.

Нативное macOS приложение для добавления пользовательских миниатюр к видео в один клик.

![macOS](https://img.shields.io/badge/macOS-26.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features / Возможности

### 🎬 Video Processing
- **Custom Thumbnail Insertion** - Replace the first frame with your custom image
- **Multiple Quality Presets** - 4K, Full HD, HD, Telegram-optimized
- **Batch Processing** - Queue multiple videos for sequential processing
- **Real-time Size Estimation** - See estimated output file size before processing
- **Drag & Drop Interface** - Simple and intuitive workflow

### 🌍 Localization
- **English** - Full interface localization
- **Russian** - Полная локализация интерфейса
- Automatically uses system language

### ⚡ Performance
- **Native macOS App** - Built with Swift and SwiftUI
- **Hardware Acceleration** - Uses AVFoundation for efficient video processing
- **Sandboxed** - Follows macOS security guidelines
- **Single Instance** - Prevents multiple app instances

## Quality Presets / Пресеты качества

| Preset | Resolution | Bitrate | Best For |
|--------|-----------|---------|----------|
| 4K (2160p) | 3840×2160 | 20 Mbps | Maximum quality |
| Full HD (1080p) | 1920×1080 | 8 Mbps | High quality |
| Telegram HD | 1920×1080 | 4 Mbps | Messaging apps |
| HD (720p) | 1280×720 | 4 Mbps | Standard quality |
| Telegram SD | 1280×720 | 2 Mbps | Smaller file size |

## Installation / Установка

### Requirements / Требования
- macOS 26.0 or later
- Xcode 16.2 or later (for building from source)

### Building from Source / Сборка из исходников

```bash
# Clone the repository / Клонируйте репозиторий
git clone https://github.com/kirich1409/VideoHelper.git
cd VideoHelper

# Open in Xcode / Откройте в Xcode
open VideoHelper.xcodeproj

# Build and run (⌘R)
```

## Usage / Использование

1. **Launch the app** / Запустите приложение
2. **Drag your video** into the blue drop zone / Перетащите видео в синюю зону
3. **Drag your thumbnail image** into the purple drop zone / Перетащите картинку в фиолетовую зону
4. **Select quality preset** / Выберите пресет качества
5. **Click "Add to Queue"** / Нажмите "Добавить в очередь"
6. **Choose output location** / Выберите куда сохранить
7. **Wait for processing** / Дождитесь обработки
8. **Click folder icon** to reveal in Finder / Нажмите иконку папки чтобы открыть в Finder

## Project Structure / Структура проекта

```
VideoHelper/
├── Models/
│   ├── ExportPreset.swift      # Quality preset definitions
│   ├── TaskStatus.swift         # Processing status enum
│   └── VideoTask.swift          # Task model
├── Services/
│   ├── VideoProcessor.swift     # Core video processing logic
│   ├── ValidationService.swift  # Input validation
│   └── NotificationManager.swift # System notifications
├── ViewModels/
│   └── ProcessingQueueViewModel.swift # Queue management
├── Views/
│   ├── ContentView.swift        # Main app interface
│   ├── DropZoneView.swift       # Drag & drop zones
│   └── QueueItemView.swift      # Queue item display
└── Resources/
    ├── en.lproj/                # English localization
    └── ru.lproj/                # Russian localization
```

## Technical Details / Технические детали

### Video Processing
- **Framework**: AVFoundation
- **Composition**: AVMutableComposition for timeline editing
- **Rendering**: AVVideoComposition with Core Animation layers
- **Export**: Hardware-accelerated encoding
- **Metadata**: Custom thumbnail embedded as artwork

### Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **Concurrency**: Swift async/await with actors
- **UI**: SwiftUI with AppKit integration for native features
- **State Management**: @Published properties with Combine

## Known Limitations / Известные ограничения

- Progress tracking removed for reliability (processing still works, just no percentage display)
- Video re-encoding required (can't preserve original codec due to thumbnail insertion)
- macOS 26.0+ required due to use of latest APIs

## Roadmap / Планы развития

- [ ] Add progress bar with reliable tracking
- [ ] Support for multiple thumbnail positions (not just first frame)
- [ ] Video trimming capabilities
- [ ] Audio replacement/mixing
- [ ] Subtitle burning
- [ ] Custom export settings

## Contributing / Участие в разработке

Contributions are welcome! Please feel free to submit a Pull Request.

Приветствуются любые предложения! Отправляйте Pull Request.

## License / Лицензия

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Этот проект распространяется под лицензией MIT.

## Credits / Авторы

Created with ❤️ using:
- [Swift](https://swift.org)
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [AVFoundation](https://developer.apple.com/av-foundation/)

Co-Authored-By: Claude Sonnet 4.5

---

**⭐ If you find this project useful, please consider giving it a star!**

**⭐ Если проект оказался полезным, поставьте звёздочку!**
