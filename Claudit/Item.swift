//
//  Item.swift
//  Claudit
//
//  Created by Ravi Shankar on 13/01/26.
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
