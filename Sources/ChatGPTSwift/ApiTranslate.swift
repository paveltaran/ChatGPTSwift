//
//  ApiTranslate.swift
//  ChatGPTSwift
//
//  Created by Admin on 13.04.23.
//

import Foundation



extension ChatGPTAPI {
    
    
    public func getRequestTranslate() -> URLRequest {
        let url = URL(string: urlStringTranslate)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
    
    public func sendMessageTranslateDataTask(text: String,
                                             lang: String,
                                          model: String = ChatGPTAPI.Constants.defaultModel,
                                          systemText: String = ChatGPTAPI.Constants.defaultSystemText,
                                          temperature: Double = ChatGPTAPI.Constants.defaultTemperature,
                                          completion: @escaping (Result<[String], Error>) -> Void) throws -> URLSessionDataTask? {
        
        
        var urlRequest = self.getRequestTranslate()
        urlRequest.httpBody = try jsonBody(text: text, lang: lang, model: model, systemText: systemText, temperature: temperature)
        print(String(data:urlRequest.httpBody!, encoding: .utf8))
        
        return NetworkManager().send(request: urlRequest) { result in
            completion(result)
        }
        
    }
    
}
