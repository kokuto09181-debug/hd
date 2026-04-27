import Foundation
import SwiftData

@Model
final class ChatThread {
    /// LLMService のチャットセッション辞書キー用 UUID
    /// SwiftData の persistentModelID とは別に保持する
    var sessionID: UUID
    var title: String
    var context: ChatContext
    var contextPayload: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]

    init(title: String, context: ChatContext, contextPayload: String? = nil) {
        self.sessionID = UUID()
        self.title = title
        self.context = context
        self.contextPayload = contextPayload
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }
}

@Model
final class ChatMessage {
    var role: ChatRole
    var content: String
    var timestamp: Date

    init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
