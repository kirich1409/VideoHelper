import Foundation

extension TimeInterval {
    var formattedEstimate: String {
        guard self > 0 else { return "" }

        let minutes = Int(self) / 60
        let seconds = Int(self) % 60

        if minutes > 0 {
            return "~\(minutes) мин \(seconds) сек"
        } else {
            return "~\(seconds) сек"
        }
    }
}
