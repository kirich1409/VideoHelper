//
//  Item.swift
//  VideoHelper
//
//  Created by Kirill Rozov on 9.02.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
