//
//  ApiTranslate.swift
//  ChatGPTSwift
//
//  Created by Admin on 13.04.23.
//

import Foundation



extension ChatGPTAPI {
    
    
    public func getRequestTranslate(lang: String) -> URLRequest {
        let url = URL(string: urlStringTranslate+"?lang=\(lang)")!
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
        
        
        var urlRequest = self.getRequestTranslate(lang: lang)
        urlRequest.httpBody = try jsonBody(text: text, isTranslate: true, model: model, systemText: systemText, temperature: temperature)
        print(String(data:urlRequest.httpBody!, encoding: .utf8))
        
        return NetworkManager().send(request: urlRequest) { result in
            completion(result)
        }
        
    }
    
}
