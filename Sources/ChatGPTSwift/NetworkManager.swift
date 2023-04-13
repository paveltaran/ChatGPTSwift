//
//  NetworkManager.swift
//  ChatGPTSwift
//
//  Created by Admin on 12.04.23.
//

import Foundation


class NetworkManager: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    private var dataTask: URLSessionDataTask?
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
//        configuration.timeoutIntervalForRequest = 3000
//        configuration.timeoutIntervalForResource = 3000
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    var error: Error?
    
    typealias CompletionHandler = (Result<String, Error>) -> Void
    private var completionHandler: CompletionHandler?
    
    func cancel() {
        dataTask?.cancel()
    }

    func send(request: URLRequest, completion: @escaping CompletionHandler) -> URLSessionDataTask? {
        completionHandler = completion

        // Create a URLSessionDataTask
        dataTask = urlSession.dataTask(with: request)
        
        dataTask?.resume()
        return dataTask
    }

    // URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let statusCode = (dataTask.response as! HTTPURLResponse).statusCode
        guard 200...299 ~= statusCode else {
            var errorText = "Invalid status code: \(statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = errorResponse.message
                
            }
            let error = NSError(domain: "NetworkManager", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
            self.urlSession(session, task: dataTask, didCompleteWithError: error)
            return
        }
        print(dataTask.currentRequest?.url?.relativePath)
        if let isTranslate = dataTask.currentRequest?.url?.relativePath.contains("/translate/"), isTranslate {
            processResponseDataTranslate(data)
        } else {
            processResponseData(data)
        }
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.completionHandler?(.failure(error))
        } else {
            self.completionHandler?(.success(""))
        }
    }

    // Process the response data
    private func processResponseData(_ data: Data) {
        for line in splitDataByNewline(data) {
            if line.hasPrefix("data: "),
                let data = line.dropFirst(6).data(using: .utf8),
                let response = try? jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                let content = response.choices.first?.delta.content {
                self.completionHandler?(.success(content))
            }
        }
    }
    
    private func processResponseDataTranslate(_ data: Data) {
        let response = try? jsonDecoder.decode(CompletionResponse.self, from: data)
        if let srcText = response?.choices.first?.message.content,
            let enText = response?.choices.first?.message.contentEnglish,
           let userMessage = response?.userMessage {
            let content = "\(userMessage.contentEnglish)\n----[]----\n\(srcText)\n----[]----\n\(enText)"
            self.completionHandler?(.success(content))
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }
    
}


func splitDataByNewline(_ data: Data) -> [String] {
    if let dataString = String(data: data, encoding: .utf8) {
        let lines = dataString.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.map { String($0) }
    } else {
        return []
    }
}
