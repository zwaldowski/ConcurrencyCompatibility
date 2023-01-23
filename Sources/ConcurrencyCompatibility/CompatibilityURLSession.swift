//
//  CompatibilityURLSession.swift
//
//  Created by Zachary Waldowski on 12/5/21.
//

import Foundation

@available(macOS, deprecated: 12, renamed: "URLSession")
@available(iOS, deprecated: 15, renamed: "URLSession")
@available(watchOS, deprecated: 8, renamed: "URLSession")
@available(tvOS, deprecated: 15, renamed: "URLSession")
public final class CompatibilityURLSession {
    let underlying: URLSession
    let forceCompatibility: Bool

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    init(withoutCompatibilityForConfiguration configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) {
        self.underlying = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        self.forceCompatibility = false
    }

    init(withCompatibilityForConfiguration configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) {
        self.underlying = URLSession(configuration: configuration, delegate: TaskManager(underlying: delegate), delegateQueue: queue)
        self.forceCompatibility = true
    }

    /// Creates a session with the specified `configuration`, `delegate`, and `queue`.
    public convenience init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate? = nil, delegateQueue queue: OperationQueue? = nil) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            self.init(withoutCompatibilityForConfiguration: configuration, delegate: delegate, delegateQueue: queue)
        } else {
            self.init(withCompatibilityForConfiguration: configuration, delegate: delegate, delegateQueue: queue)
        }
    }

    /// A copy of the configuration object for this session.
    public var configuration: URLSessionConfiguration {
        underlying.configuration
    }

    /// The delegate assigned when this object was created.
    public var delegate: URLSessionDelegate? {
        switch underlying.delegate {
        case let taskManager as TaskManager:
            return taskManager.underlying
        case let other:
            return other
        }
    }

    /// The operation queue provided when this object was created.
    public var delegateQueue: OperationQueue {
        underlying.delegateQueue
    }

    /// An app-defined descriptive label for the session.
    public var sessionDescription: String? {
        get { underlying.sessionDescription }
        set { underlying.sessionDescription = newValue }
    }

    /// Invalidates the session, allowing any outstanding tasks to finish.
    public func finishTasksAndInvalidate() {
        underlying.finishTasksAndInvalidate()
    }

    /// Cancels all outstanding tasks and then invalidates the session.
    public func invalidateAndCancel() {
        underlying.invalidateAndCancel()
    }

    /// Empties all cookies, caches and credential stores, removes disk files, flushes in-progress downloads to disk, and ensures that future requests occur on a new socket.
    public func reset() async {
        await underlying.reset()
    }

    /// Flushes cookies and credentials to disk, clears transient caches, and ensures that future requests occur on a new TCP connection.
    public func flush() async {
        await underlying.flush()
    }

    /// All data, upload, and download tasks in a session.
    public var tasks: ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) {
        get async {
            await underlying.tasks
        }
    }

    /// The list of all tasks in a session.
    public var allTasks: [URLSessionTask] {
        get async {
            await underlying.allTasks
        }
    }

    func setDelegate(_ delegate: URLSessionTaskDelegate?, for task: URLSessionTask) {
        guard let delegate = delegate, let taskManager = underlying.delegate as? TaskManager else { return }
        underlying.delegateQueue.addOperation {
            taskManager.setDelegate(delegate, for: task)
        }
    }

    /// Convenience method to load data using an URLRequest, creates and resumes an URLSessionDataTask internally.
    ///
    /// - Parameter request: The URLRequest for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    public func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.data(for: request, delegate: delegate)
        } else {
            return try await underlying.compatibilityData(for: request) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to load data using an URL, creates and resumes an URLSessionDataTask internally.
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    public func data(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.data(from: url, delegate: delegate)
        } else {
            return try await underlying.compatibilityData(from: url) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to upload data using an URLRequest, creates and resumes an URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.upload(for: request, fromFile: fileURL, delegate: delegate)
        } else {
            return try await underlying.compatibilityUpload(for: request, fromFile: fileURL) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to upload data using an URLRequest, creates and resumes an URLSessionUploadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Data and response.
    public func upload(for request: URLRequest, from bodyData: Data, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.upload(for: request, from: bodyData, delegate: delegate)
        } else {
            return try await underlying.compatibilityUpload(for: request, from: bodyData) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to download using an URLRequest, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter request: The URLRequest for which to download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    public func download(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.download(for: request, delegate: delegate)
        } else {
            return try await underlying.compatibilityDownload(for: request) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to download using an URL, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter url: The URL for which to download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    public func download(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.download(from: url, delegate: delegate)
        } else {
            return try await underlying.compatibilityDownload(from: url) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    /// Convenience method to resume download, creates and resumes an URLSessionDownloadTask internally.
    ///
    /// - Parameter resumeData: Resume data from an incomplete download.
    /// - Parameter delegate: Task-specific delegate.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    public func download(resumeFrom resumeData: Data, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *), !forceCompatibility {
            return try await underlying.download(resumeFrom: resumeData, delegate: delegate)
        } else {
            return try await underlying.compatibilityDownload(resumeFrom: resumeData) { task in
                setDelegate(delegate, for: task)
            }
        }
    }

    public func webSocketTask(with url: URL) -> URLSessionWebSocketTask {
        underlying.webSocketTask(with: url)
    }

    public func webSocketTask(with url: URL, protocols: [String]) -> URLSessionWebSocketTask {
        underlying.webSocketTask(with: url, protocols: protocols)
    }

    public func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask {
        underlying.webSocketTask(with: request)
    }
}

extension CompatibilityURLSession {
    class TaskManager: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionStreamDelegate, URLSessionWebSocketDelegate {
        let underlying: URLSessionDelegate?
        var taskDelegates = [Int: URLSessionTaskDelegate]()

        init(underlying: URLSessionDelegate?) {
            self.underlying = underlying
            super.init()
        }

        func setDelegate(_ delegate: URLSessionTaskDelegate, for task: URLSessionTask) {
            taskDelegates[task.taskIdentifier] = delegate
        }

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            underlying?.urlSession?(session, didBecomeInvalidWithError: error)
            taskDelegates.removeAll()
        }

        @available(macOS 11.0, iOS 13, tvOS 13, watchOS 6, *)
        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            underlying?.urlSessionDidFinishEvents?(forBackgroundURLSession: session)
        }

        var taskUnderlying: URLSessionTaskDelegate? {
            underlying as? URLSessionTaskDelegate
        }

        func delegate(for dataTask: URLSessionTask) -> URLSessionTaskDelegate? {
            taskDelegates[dataTask.taskIdentifier]
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
            if let callback = delegate(for: task)?.urlSession(_:task:willBeginDelayedRequest:completionHandler:) {
                callback(session, task, request, completionHandler)
            } else if let callback = taskUnderlying?.urlSession(_:task:willBeginDelayedRequest:completionHandler:) {
                callback(session, task, request, completionHandler)
            } else {
                completionHandler(.continueLoading, nil)
            }
        }

        func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
            if let callback = delegate(for: task)?.urlSession(_:taskIsWaitingForConnectivity:) {
                callback(session, task)
            } else {
                taskUnderlying?.urlSession?(session, taskIsWaitingForConnectivity: task)
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            if let callback = delegate(for: task)?.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:) {
                callback(session, task, response, request, completionHandler)
            } else if let callback = taskUnderlying?.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:) {
                callback(session, task, response, request, completionHandler)
            } else {
                completionHandler(request)
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)  {
            if let callback = delegate(for: task)?.urlSession(_:didReceive:completionHandler:) {
                callback(session, challenge, completionHandler)
            } else if let callback = taskUnderlying?.urlSession(_:didReceive:completionHandler:) {
                callback(session, challenge, completionHandler)
            } else if let callback = delegate(for: task)?.urlSession(_:task:didReceive:completionHandler:) {
                callback(session, task, challenge, completionHandler)
            } else if let callback = taskUnderlying?.urlSession(_:task:didReceive:completionHandler:) {
                callback(session, task, challenge, completionHandler)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
            if let callback = delegate(for: task)?.urlSession(_:task:needNewBodyStream:) {
                callback(session, task, completionHandler)
            } else if let callback = taskUnderlying?.urlSession(_:task:needNewBodyStream:) {
                callback(session, task, completionHandler)
            } else {
                completionHandler(nil)
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
            taskUnderlying?.urlSession?(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            if let underlying = taskDelegates[task.taskIdentifier], let callback = underlying.urlSession(_:task:didFinishCollecting:) {
                callback(session, task, metrics)
            } else {
                taskUnderlying?.urlSession?(session, task: task, didFinishCollecting: metrics)
            }
            taskDelegates.removeValue(forKey: task.taskIdentifier)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let callback = delegate(for: task)?.urlSession(_:task:didCompleteWithError:) {
                callback(session, task, error)
            } else {
                taskUnderlying?.urlSession?(session, task: task, didCompleteWithError: error)
            }
            taskDelegates.removeValue(forKey: task.taskIdentifier)
        }

        var dataUnderlying: URLSessionDataDelegate? {
            underlying as? URLSessionDataDelegate
        }

        func delegate(for dataTask: URLSessionDataTask) -> URLSessionDataDelegate? {
            taskDelegates[dataTask.taskIdentifier] as? URLSessionDataDelegate
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            if let callback = delegate(for: dataTask)?.urlSession(_:dataTask:didReceive:completionHandler:) {
                callback(session, dataTask, response) { disposition in
                    switch disposition {
                    case .becomeStream, .becomeDownload:
                        completionHandler(.allow)
                    case let other:
                        completionHandler(other)
                    }
                }
            } else if let callback = dataUnderlying?.urlSession(_:dataTask:didReceive:completionHandler:) {
                callback(session, dataTask, response, completionHandler)
            } else {
                completionHandler(.allow)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
            dataUnderlying?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
            dataUnderlying?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if let callback = delegate(for: dataTask)?.urlSession(_:dataTask:didReceive:) {
                callback(session, dataTask, data)
            } else {
                dataUnderlying?.urlSession?(session, dataTask: dataTask, didReceive: data)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
            if let callback = delegate(for: dataTask)?.urlSession(_:dataTask:willCacheResponse:completionHandler:) {
                callback(session, dataTask, proposedResponse, completionHandler)
            } else if let callback = dataUnderlying?.urlSession(_:dataTask:willCacheResponse:completionHandler:) {
                callback(session, dataTask, proposedResponse, completionHandler)
            } else {
                completionHandler(proposedResponse)
            }
        }

        var downloadUnderlying: URLSessionDownloadDelegate? {
            underlying as? URLSessionDownloadDelegate
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            downloadUnderlying?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            downloadUnderlying?.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
            downloadUnderlying?.urlSession?(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }

        var streamUnderlying: URLSessionStreamDelegate? {
            underlying as? URLSessionStreamDelegate
        }

        func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
            streamUnderlying?.urlSession?(session, readClosedFor: streamTask)
        }

        func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
            streamUnderlying?.urlSession?(session, writeClosedFor: streamTask)
        }

        func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
            streamUnderlying?.urlSession?(session, betterRouteDiscoveredFor: streamTask)
        }

        func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
            streamUnderlying?.urlSession?(session, streamTask: streamTask, didBecome: inputStream, outputStream: outputStream)
        }

        var webSocketUnderlying: URLSessionWebSocketDelegate? {
            underlying as? URLSessionWebSocketDelegate
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
            webSocketUnderlying?.urlSession?(session, webSocketTask: webSocketTask, didOpenWithProtocol: `protocol`)
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            webSocketUnderlying?.urlSession?(session, webSocketTask: webSocketTask, didCloseWith: closeCode, reason: reason)
        }
    }
}
