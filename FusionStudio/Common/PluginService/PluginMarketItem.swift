import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Market Item

struct PluginMarketItem: Identifiable {
    let id: String
    let name: String
    let author: String
    let description: String
    let version: String
    let downloads: Int
    let rating: Double
    let iconName: String
    let isInstalled: Bool
    let hasUpdate: Bool
}
