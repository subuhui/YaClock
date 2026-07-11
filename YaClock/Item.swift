//
//  Item.swift
//  YaClock
//
//  Created by 张哲铭 on 2026/7/11.
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
