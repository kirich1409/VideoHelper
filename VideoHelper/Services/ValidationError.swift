import Foundation

enum ValidationError: LocalizedError {
    case fileNotFound(String)
    case fileNotReadable(String)
    case unsupportedVideoFormat(String)
    case unsupportedImageFormat(String)
    case corruptedFile(String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case noWritePermission(URL)
    case outputFileExists(URL)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Файл не найден: \(path)"
        case .fileNotReadable(let path):
            return "Нет доступа к файлу: \(path)"
        case .unsupportedVideoFormat(let path):
            return "Неподдерживаемый формат видео: \(path)"
        case .unsupportedImageFormat(let path):
            return "Неподдерживаемый формат изображения: \(path)"
        case .corruptedFile(let path):
            return "Файл поврежден: \(path)"
        case .insufficientDiskSpace(let required, let available):
            return "Недостаточно места на диске. Требуется: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), доступно: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .noWritePermission(let url):
            return "Нет прав на запись в папку: \(url.path)"
        case .outputFileExists(let url):
            return "Файл уже существует: \(url.lastPathComponent)"
        }
    }
}
