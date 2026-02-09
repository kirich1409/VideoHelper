# VideoHelper - Дизайн приложения для обработки видео

**Дата**: 2026-02-09
**Статус**: Validated Design
**Автор**: Claude (brainstorming session)

## Обзор

VideoHelper - нативное macOS приложение для быстрой обработки видео для блога. Основные функции:
- Установка кастомного превью (первый кадр видео)
- Компрессия с пресетами (Оригинал, Telegram SD/HD)
- Batch обработка через Finder integration
- Очередь обработки с прогрессом в процентах и времени

## Технологический стек

- **Платформа**: macOS 15.0+ (Sequoia и Tahoe)
- **Фреймворк**: SwiftUI + Swift
- **Обработка видео**: AVFoundation (AVAssetExportSession, AVMutableComposition)
- **Архитектура**: MVVM + Combine
- **Нотификации**: UNUserNotificationCenter

## Функциональные требования

### 1. Форматы файлов

**Входные форматы**:
- Видео: MP4, MOV, M4V (все форматы поддерживаемые AVFoundation)
- Превью: JPG, PNG, HEIC

**Выходной формат**:
- MP4 (H.264 video, AAC audio)
- Fast start (moov atom в начале для стриминга)

### 2. Пресеты экспорта

#### Оригинал
- AVAssetExportPresetPassthrough или HighestQuality
- Сохраняет оригинальное качество входного видео
- Только добавляется превью-кадр в начало

#### Telegram SD (720p)
- Видео: H.264, High Profile, Level 4.1
- Битрейт: ~2 Мбит/с
- Разрешение: максимум 1280x720 (с сохранением aspect ratio)
- Аудио: AAC 128 kbps
- MP4 с fast start

#### Telegram HD (1080p)
- Видео: H.264, High Profile, Level 4.1
- Битрейт: ~4 Мбит/с
- Разрешение: максимум 1920x1080 (с сохранением aspect ratio)
- Аудио: AAC 128 kbps
- MP4 с fast start

### 3. Обработка превью

**Процесс**:
1. Определить frame rate исходного видео (например, 30 fps)
2. Вычислить длительность 1 кадра: `1.0 / frameRate` секунд
3. Конвертировать thumbnail картинку в видео-трек длиной ровно 1 кадр
4. Вставить в начало AVMutableComposition
5. Добавить полное исходное видео после превью
6. Добавить thumbnail в метаданные (AVMetadataCommonIdentifierArtwork)

**Результат** (пример для 30fps):
```
[0.000-0.033s] - картинка превью (1 кадр)
[0.033-конец] - полное исходное видео
```

### 4. Сохранение файлов

**Расположение**: Рядом с оригинальным файлом

**Именование**:
- Оригинал: `video_original.mp4`
- Telegram SD: `video_telegram_sd.mp4`
- Telegram HD: `video_telegram_hd.mp4`

Формат: `{имя_без_расширения}_{пресет}.mp4`

### 5. Очередь обработки

- **Тип**: FIFO (First In, First Out)
- **Параллелизм**: Одно видео за раз
- **Управление**:
  - Удаление задач со статусом `.pending`
  - Невозможно отменить задачу со статусом `.processing`
- **Persistence**: Очередь НЕ сохраняется между запусками
- **Автозапуск**: Обработка начинается автоматически при добавлении задачи

## Пользовательский интерфейс

### ContentView - главное окно

**Структура** (вертикальный layout):

#### 1. Drag & Drop секция (верх)
Две drop зоны рядом:

**Видео зона**:
- Пустая: "Перетащите видео" + иконка 🎬
- Заполнена: thumbnail preview + имя файла + кнопка "×"
- Accepts: `public.movie`

**Превью зона**:
- Пустая: "Перетащите картинку" + иконка 🖼
- Заполнена: thumbnail preview + имя файла + кнопка "×"
- Accepts: `public.image`

#### 2. Настройки секция (середина)
- **Picker пресета**: "Качество: [Оригинал ▼]"
  - Варианты: Оригинал, Telegram SD (720p), Telegram HD (1080p)
- **Кнопка**: "Добавить в очередь"
  - Активна только когда оба файла выбраны

#### 3. Очередь секция (низ)
List с задачами, каждая показывает:

**Элементы**:
- Миниатюра видео (слева, 60x60)
- Имя файла + пресет (например: "video.mp4 • Telegram HD")
- Статус с иконкой:
  - ⏳ "Ожидает" (`.pending`)
  - ⚙️ "Обрабатывается 47%" (`.processing`)
  - ✅ "Завершено" (`.completed`)
  - ⚠️ "Ошибка: ..." (`.failed`)
- Progress bar (для `.processing`)
- Оставшееся время: "~2 мин 30 сек"
- Кнопка действия:
  - `.pending` → 🗑 (удалить из очереди)
  - `.completed` → "Показать в Finder"
  - `.failed` → 🗑 (удалить из списка)

**Размеры окна**:
- Минимальный: 480x600
- По умолчанию: 600x700
- Resizable: да

### Finder Quick Action

**Имя**: "Обработать в VideoHelper"

**Поддерживаемые сценарии**:

1. **1 картинка + 1 видео** → создает 1 задачу
2. **1 картинка + N видео** → создает N задач (batch обработка с одной картинкой)
3. **Только видео** → открывает app с видео, нужно добавить картинку
4. **Только картинка** → открывает app с картинкой, нужно добавить видео

**Batch обработка**:
- Пользователь выбирает 1 картинку + несколько видео
- Quick Action открывает VideoHelper
- Показывается диалог: "Создать X задач с одной картинкой превью?"
- Выбор пресета (общий для всех задач)
- Кнопка "Добавить все в очередь"
- Все задачи добавляются одновременно

**Валидация**:
- Если картинок > 1 → alert "Выберите только одну картинку"

**Реализация**:
- Action Extension target в Xcode
- Shared App Group для передачи данных
- Info.plist с NSExtensionActivationRule
- Accepts: `public.movie`, `public.image`

## Архитектура

### Структура проекта

```
VideoHelper/
├── VideoHelperApp.swift           # Entry point + AppDelegate
├── Models/
│   ├── VideoTask.swift            # Модель задачи
│   ├── ExportPreset.swift         # Enum пресетов
│   └── TaskStatus.swift           # Enum статусов
├── ViewModels/
│   └── ProcessingQueueViewModel.swift  # Логика очереди
├── Views/
│   ├── ContentView.swift          # Главное окно
│   ├── DropZoneView.swift         # Drag & Drop компонент
│   └── QueueItemView.swift        # Элемент очереди
├── Services/
│   ├── VideoProcessor.swift       # Обработка видео
│   ├── ValidationService.swift    # Валидация файлов
│   └── NotificationManager.swift  # Уведомления
└── Extensions/
    └── FinderIntegration/         # Quick Action extension
        ├── ActionViewController.swift
        └── Info.plist
```

### Ключевые модели

#### VideoTask
```swift
struct VideoTask: Identifiable {
    let id: UUID
    let videoURL: URL
    let thumbnailURL: URL
    let preset: ExportPreset
    var status: TaskStatus
    var progress: Float = 0.0
    var estimatedTimeRemaining: TimeInterval?
    var outputURL: URL?
    var error: String?
}

enum TaskStatus {
    case pending
    case processing
    case completed
    case failed
}
```

#### ExportPreset
```swift
enum ExportPreset: String, CaseIterable {
    case original = "Оригинал"
    case telegramSD = "Telegram SD (720p)"
    case telegramHD = "Telegram HD (1080p)"

    var filenameSuffix: String {
        switch self {
        case .original: return "_original"
        case .telegramSD: return "_telegram_sd"
        case .telegramHD: return "_telegram_hd"
        }
    }
}
```

### ProcessingQueueViewModel

```swift
@MainActor
class ProcessingQueueViewModel: ObservableObject {
    @Published var tasks: [VideoTask] = []
    @Published var currentTask: VideoTask?

    private let videoProcessor: VideoProcessor
    private let validator: ValidationService
    private let notificationManager: NotificationManager

    // Методы
    func addTask(video: URL, thumbnail: URL, preset: ExportPreset) async throws
    func addBatchTasks(videos: [URL], thumbnail: URL, preset: ExportPreset) async throws
    func removeTask(id: UUID)
    func processQueue() async
    func showInFinder(url: URL)
}
```

**Поток обработки**:
1. Добавление задачи → валидация → добавление в массив → автозапуск очереди
2. Обработка: берем первую `.pending` → меняем на `.processing` → обрабатываем → обновляем прогресс → завершаем
3. При завершении всей очереди → отправляем notification

### VideoProcessor

**Основные методы**:
```swift
class VideoProcessor {
    func process(
        videoURL: URL,
        thumbnailURL: URL,
        preset: ExportPreset,
        progressHandler: @escaping (Float, TimeInterval?) -> Void
    ) async throws -> URL

    private func createCompositionWithThumbnail(
        video: AVAsset,
        thumbnail: CGImage,
        frameRate: Float
    ) throws -> AVMutableComposition

    private func addMetadata(
        to composition: AVMutableComposition,
        thumbnail: Data
    ) throws

    private func export(
        composition: AVMutableComposition,
        preset: ExportPreset,
        outputURL: URL,
        progressHandler: @escaping (Float) -> Void
    ) async throws
}
```

**Алгоритм**:
1. Загрузить AVAsset для видео
2. Определить frame rate
3. Создать composition с thumbnail (1 кадр) + полное видео
4. Добавить thumbnail в метаданные
5. Экспортировать с выбранным пресетом
6. Отслеживать прогресс через KVO на `exportSession.progress`
7. Оценивать оставшееся время: `(totalTime - elapsed) * (1 - progress) / progress`

### ValidationService

**Предварительные проверки** (перед добавлением в очередь):

```swift
class ValidationService {
    func validate(
        videoURL: URL,
        thumbnailURL: URL,
        preset: ExportPreset
    ) async throws

    private func checkFileExists(_ url: URL) throws
    private func checkFileReadable(_ url: URL) throws
    private func checkVideoFormat(_ url: URL) async throws
    private func checkImageFormat(_ url: URL) throws
    private func estimateOutputSize(video: AVAsset, preset: ExportPreset) -> Int64
    private func checkDiskSpace(outputDir: URL, required: Int64) throws
    private func checkWritePermissions(_ url: URL) throws
}
```

**Проверки**:
1. Файлы существуют и доступны для чтения
2. Форматы поддерживаются (AVAsset.isPlayable)
3. Оценка размера выходного файла:
   - Оригинал: размер входного × 1.1
   - Telegram SD: битрейт (2 Мбит/с) × длительность
   - Telegram HD: битрейт (4 Мбит/с) × длительность
4. Проверка места на диске (требуемое × 1.2 для запаса)
5. Права на запись в целевую папку
6. Проверка существования выходного файла → опция перезаписи

**Типы ошибок**:
```swift
enum ValidationError: LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case noWritePermission(URL)
    case corruptedFile(String)
}
```

### NotificationManager

```swift
class NotificationManager {
    func requestAuthorization()
    func notifyQueueCompleted(count: Int, successCount: Int)
}
```

**Уведомления**:
- При завершении всей очереди: "VideoHelper: Обработано 5 из 6 видео"
- Action button: "Показать" → активирует приложение
- Не отправляем при каждом видео, только когда вся очередь завершена

### Finder Integration (Show in Finder)

```swift
extension ProcessingQueueViewModel {
    func showInFinder(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
```

Вызывается при клике на задачу со статусом `.completed`.

## Lifecycle и защита данных

### Подтверждение при выходе

**AppDelegate**:
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var queueViewModel: ProcessingQueueViewModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let vm = queueViewModel else { return .terminateNow }

        let hasActiveTasks = vm.tasks.contains {
            $0.status == .processing || $0.status == .pending
        }

        if hasActiveTasks {
            let alert = NSAlert()
            alert.messageText = "Обработка видео в процессе"
            alert.informativeText = "Вы уверены что хотите выйти? Незавершенные задачи будут отменены."
            alert.addButton(withTitle: "Отмена")
            alert.addButton(withTitle: "Выйти")
            alert.alertStyle = .warning

            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }

        return .terminateNow
    }
}
```

**При принудительном выходе**:
- Вызываем `exportSession.cancelExport()` для активной задачи
- Удаляем незавершенные выходные файлы
- Очищаем временные файлы

## Обработка ошибок

### Типы ошибок

**Валидация** (до обработки):
- Неподдерживаемый формат
- Недостаточно места на диске
- Нет прав доступа
- Файл поврежден

**Обработка**:
- Ошибка экспорта AVFoundation
- Файл перемещен/удален во время обработки
- Недостаточно памяти
- Ошибка записи

**Отображение в UI**:
- Статус задачи: `.failed(error: String)`
- Красная иконка ⚠️
- Текст ошибки под именем файла
- Кнопка "🗑" для удаления из списка

## Будущие улучшения (после MVP)

1. **Persistence очереди** - сохранение между запусками
2. **Отмена активной задачи** - возможность прервать обработку
3. **Пауза/возобновление** - контроль обработки
4. **Дополнительные пресеты** - YouTube, Instagram, TikTok
5. **Параллельная обработка** - несколько видео одновременно
6. **Кастомные настройки** - ручной выбор битрейта, разрешения
7. **История обработки** - лог завершенных задач
8. **Drag & Drop в очередь** - добавление файлов напрямую в список
9. **Preview режим** - предпросмотр результата перед обработкой
10. **iOS/iPadOS версия** - портирование интерфейса

## Технические заметки

### AVFoundation особенности

**Вставка thumbnail как видео-кадра**:
- Используем `AVMutableVideoComposition` с `AVVideoCompositionInstruction`
- Создаем `AVMutableCompositionTrack` для thumbnail
- Первый фрейм из CGImage через `CVPixelBuffer`

**Fast start для MP4**:
- Устанавливаем `shouldOptimizeForNetworkUse = true` на `AVAssetExportSession`
- Это перемещает moov atom в начало файла
- Критично для стриминга в Telegram

**KVO для прогресса**:
```swift
exportSession.observe(\.progress, options: [.new]) { session, _ in
    let progress = session.progress
    // Обновляем UI
}
```

### Оценка времени

```swift
func estimateTimeRemaining(progress: Float, elapsed: TimeInterval) -> TimeInterval {
    guard progress > 0 && progress < 1 else { return 0 }
    return (elapsed / Double(progress)) * Double(1 - progress)
}
```

### Размеры файлов

**Оценка битрейта**:
- SD (720p): 2 Мбит/с = 250 КБ/с
- HD (1080p): 4 Мбит/с = 500 КБ/с

**Формула**:
```
outputSize = (videoBitrate + audioBitrate) × duration / 8
где битрейты в бит/с, duration в секундах
```

## Тестирование

### Unit тесты
- ValidationService: проверка всех типов ошибок
- VideoProcessor: mock AVFoundation для тестирования логики
- ProcessingQueueViewModel: тестирование состояния очереди

### Integration тесты
- Полный цикл: добавление → обработка → завершение
- Batch обработка через Quick Action
- Обработка ошибок на каждом этапе

### UI тесты
- Drag & Drop функциональность
- Добавление/удаление задач
- Отображение прогресса
- "Показать в Finder"

### Тестовые данные
- Видео разных форматов: MP4, MOV, M4V
- Разные разрешения: 480p, 720p, 1080p, 4K
- Разные frame rates: 24, 30, 60 fps
- Картинки: JPG, PNG, HEIC
- Поврежденные файлы
- Файлы с недостаточными правами

## Заключение

VideoHelper - простое, но мощное приложение для batch обработки видео с фокусом на user experience и нативную интеграцию с macOS. Использование SwiftUI и AVFoundation обеспечивает отличную производительность и возможность портирования на iOS/iPadOS в будущем.

Ключевые преимущества дизайна:
- Минимальный UI, максимальная эффективность
- Нативная интеграция с Finder (Quick Action)
- Batch обработка для продуктивности
- Предварительная валидация для предотвращения ошибок
- Защита от потери данных при выходе
