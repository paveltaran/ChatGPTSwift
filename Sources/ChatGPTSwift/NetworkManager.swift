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
    var body: String = ""
    
    typealias CompletionHandler = (Result<[String], Error>) -> Void
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
        
//        print(dataTask.currentRequest?.url?.absoluteString)
        if let isTranslate = dataTask.currentRequest?.url?.relativePath.contains("/translate/"), isTranslate {
            processResponseDataTranslate(data)
        } else if let httpBody = dataTask.originalRequest?.httpBody, dataContainsSubstringMatchingRegexp(httpBody, pattern: "\"stream\":\\s?true") {
            processResponseDataStream(data)
        } else {
            processResponseData(data)
        }
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.completionHandler?(.failure(error))
        } else {
            self.completionHandler?(.success([]))
        }
    }
    
    private func processResponseData(_ data: Data) {
//        print(String(data: data, encoding: .utf8))
        let response = try? jsonDecoder.decode(CompletionResponse.self, from: data)
        if let srcText = response?.choices.first?.message.content {
            let content = [srcText]
            self.completionHandler?(.success(content))
        }
    }
    
    // Process the response data
    private func processResponseDataStream(_ data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            self.body += text
        }
        if body.contains("\n") {
            let text = removeTextAfterLastNewline(in: body)
            body = String(body.dropFirst(text.count))
            var result: [String] = []
            for line in splitStringByNewline(text) {
                if line.hasPrefix("data: "),
                    let data = line.dropFirst(6).data(using: .utf8),
                    let response = try? jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                    let content = response.choices.first?.delta.content {
                        result.append(content)
                }
            }
            if result.count > 0 {
                self.completionHandler?(.success(result))
            }
        }
        
    }
    
    private func processResponseDataTranslate(_ data: Data) {
//        print(String(data: data, encoding: .utf8))
        let response = try? jsonDecoder.decode(CompletionResponse.self, from: data)
        if let srcText = response?.choices.first?.message.content,
            let enText = response?.choices.first?.message.contentEnglish,
           let userEnText = response?.userMessage?.contentEnglish {
            let content = [userEnText, srcText, enText]
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


func splitStringByNewline(_ input: String) -> [String] {
    return input.split(separator: "\n", omittingEmptySubsequences: false).map {String($0)}
}


func removeTextAfterLastNewline(in input: String) -> String {
    let components = input.split(separator: "\n", omittingEmptySubsequences: false)
    guard components.count > 1 else { return input }
    return components.dropLast().joined(separator: "\n")
}


func dataContainsSubstringMatchingRegexp(_ data: Data, pattern: String) -> Bool {
    // Convert Data to String
    guard let dataString = String(data: data, encoding: .utf8) else {
        print("Unable to convert Data to String.")
        return false
    }

    // Create a regular expression object
    let regexp: NSRegularExpression
    do {
        regexp = try NSRegularExpression(pattern: pattern, options: [])
    } catch {
        print("Invalid regular expression pattern: \(error.localizedDescription)")
        return false
    }

    // Check for a match
    let range = NSRange(location: 0, length: dataString.utf16.count)
    let matchRange = regexp.rangeOfFirstMatch(in: dataString, options: [], range: range)

    // Return whether a match was found
    return matchRange.location != NSNotFound
}
