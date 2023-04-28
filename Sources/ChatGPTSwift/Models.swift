//
//  File.swift
//  
//
//  Created by Alfian Losari on 02/03/23.
//

import Foundation

public struct Message: Codable {
    public let role: String
    public let content: String
    public let language: String?
    public let contentEnglish: String?
    
    public init(role: String, content: String) {
        self.init(role: role, content: content, language: "")
    }
    
    public init(role: String, content: String, language: String) {
        self.init(role: role, content: content, language: language, contentEnglish: nil)    }
    
    public init(role: String, content: String, language: String, contentEnglish: String?) {
        self.role = role
        self.content = content
        self.language = language
        self.contentEnglish = contentEnglish
    }
}

//TODO: правильно счетать количество контента. Сделать отдельную структуру для перевода
extension Array where Element == Message {
    
    var contentCount: Int { map { $0.contentEnglish == nil || $0.contentEnglish! == "" ? $0.content : $0.contentEnglish }.count }
    var content: String { reduce("") { $0 + ($1.contentEnglish == nil || $1.contentEnglish! == "" ? $1.content : $1.contentEnglish ) } }
}

struct Request: Codable {
    let model: String
    let temperature: Double
    let messages: [Message]
    let stream: Bool
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
}

struct CompletionResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
    let id: String
    let userMessage: Message?
}

struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct Choice: Decodable {
    let finishReason: String?
    let message: Message
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
    let id: String
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let content: String?
    let role: String?
}
