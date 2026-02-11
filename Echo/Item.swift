//
//  Item.swift
//  Echo
//
//  Created by Siegfried on 2026/2/7.
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
