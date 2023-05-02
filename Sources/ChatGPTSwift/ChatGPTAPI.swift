//
//  ChatGPTAPI.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import Foundation
import GPTEncoder


public class ChatGPTAPI: @unchecked Sendable {
    
//    typealias CompletionHandler = (Result<StreamCompletionResponse, Error>) -> Void
    
    public enum Constants {
        public static let defaultModel = "gpt-3.5-turbo"
        public static let defaultSystemText = "You're a helpful assistant"
        public static let defaultTemperature = 0.7639320225002906
    }
    
    var urlString = "https://api.robat.ai/v1/chat/completions"
    var urlStringTranslate = "https://api.robat.ai/translate/v1/chat/completions"
    private let apiKey: String
    let gptEncoder = GPTEncoder()
    public var historyList = [Message]()

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()
    
    let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    func systemMessage(content: String) -> Message {
        .init(role: "system", content: content)
    }
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    private func generateMessages(from text: String, isTranslate: Bool = false, systemText: String, isPrompt: Bool = false) -> [Message] {
        var messages = [systemMessage(content: systemText)] + historyList //+ [Message(role: "user", content: text)]
        if isPrompt {
            messages += [Message(role: "user", content: text)]
        }
//        print("gptEncoder.encode(text: messages.content).count", gptEncoder.encode(text: messages.content).count)
        if gptEncoder.encode(text: isTranslate ? messages.contentEnglish : messages.content).count > 4096  {
            _ = historyList.removeFirst()
            messages = generateMessages(from: text, isTranslate: isTranslate, systemText: systemText, isPrompt: isPrompt)
        }
        return messages
    }
    
    func jsonBody(text: String, isTranslate: Bool = false, model: String, systemText: String, temperature: Double, stream: Bool = true, isPrompt: Bool = false) throws -> Data {
        let request = Request(model: model,
                        temperature: temperature,
                          messages: generateMessages(from: text, isTranslate: isTranslate, systemText: systemText, isPrompt: isPrompt),
                        stream: stream)
        return try JSONEncoder().encode(request)
    }
    
    private func appendToHistoryList(userText: String, responseText: String) {
        self.historyList.append(Message(role: "user", content: userText))
        self.historyList.append(Message(role: "assistant", content: responseText))
    }

    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: urlString)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }

    public func sendMessageStream(text: String,
                                  model: String = ChatGPTAPI.Constants.defaultModel,
                                  systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                  temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> (AsyncThrowingStream<(String, String), Error>, () -> Void) {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature)
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
               errorText += line
            }
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            throw "Bad Response: \(httpResponse.statusCode). \(errorText)"
        }
        
        
        var isCancelled = false
        
        func _cancel() -> Void {
            isCancelled = true
        }
        
        var cancel = _cancel
        
        let stream = AsyncThrowingStream<(String, String), Error> {  continuation in
            
            let task = Task(priority: .userInitiated) { [weak self, isCancelled] in
                do {
                    var responseText = ""
                    for try await line in result.lines {
                        if isCancelled {
                            break
                        }
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let response = try? self?.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                           let text = response.choices.first?.delta.content {
                             responseText += text
                            
                            continuation.yield((response.id, text))
                       }
                    }
                    //self?.appendToHistoryList(userText: text, responseText: responseText)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            func _cancel() -> Void {
                if !isCancelled {
                    isCancelled = true
                    if !task.isCancelled {
                        task.cancel()
                        continuation.finish(throwing: URLError(.cancelled))
                    }
                }
            }
            
            cancel = _cancel
            
        }
        
        return (stream, cancel)
    }
    
    public func sendMessageStreamDataTask(text: String,
                                          model: String = ChatGPTAPI.Constants.defaultModel,
                                          systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                          temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
                                          completion: @escaping (Result<[String], Error>) -> Void) throws -> URLSessionDataTask? {
        
        
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature)
        
        return NetworkManager().send(request: urlRequest) { result in
            completion(result)
        }
        
    }
    
    public func getRequestPromt() -> URLRequest {
        let url = URL(string: urlString+"?promt=1")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
    
    public func sendMessageDataTask(text: String,
                                    model: String = ChatGPTAPI.Constants.defaultModel,
                                    systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                    isPrompt: Bool = false,
                                    temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
                                    completion: @escaping (Result<[String], Error>) -> Void) throws -> URLSessionDataTask? {
        
        var urlRequest = self.urlRequest
        if isPrompt {
            urlRequest = getRequestPromt()
        }
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature, stream: false, isPrompt: isPrompt)
        
        return NetworkManager().send(request: urlRequest) { result in
            completion(result)
        }
    }

    public func sendMessage(text: String,
                            model: String = ChatGPTAPI.Constants.defaultModel,
                            systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                            temperature: Double = ChatGPTAPI.Constants.defaultTemperature) async throws -> String {
        
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, model: model, systemText: systemText, temperature: temperature, stream: false)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var error = "Bad Response: \(httpResponse.statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data)
            let responseText = completionResponse.choices.first?.message.content ?? ""
            //self.appendToHistoryList(userText: text, responseText: responseText)
            return responseText
        } catch {
            throw error
        }
    }
    
    public func deleteHistoryList() {
        self.historyList.removeAll()
    }
    
    public func replaceHistoryList(with messages: [Message]) {
        self.historyList = messages
    }
    
}


