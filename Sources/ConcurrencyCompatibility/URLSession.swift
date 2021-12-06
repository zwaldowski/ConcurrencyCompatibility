import Foundation

extension URLSession {
    private enum CancelState {
        case pending
        case cancelled
        case active(URLSessionTask)
    }

    private func withCancellableTask<Result>(function: String = #function, beforeResuming: (URLSessionTask) -> Void, using makeTask: (CheckedContinuation<Result, Error>) -> URLSessionTask) async throws -> Result {
        let state = ManagedBuffer<CancelState, os_unfair_lock>.create(minimumCapacity: 1) { buffer in
            buffer.withUnsafeMutablePointerToElements { $0.initialize(to: os_unfair_lock()) }
            return .pending
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = makeTask(continuation)
                beforeResuming(task)
                task.resume()
                state.withUnsafeMutablePointers { pointerToState, lock in
                    os_unfair_lock_lock(lock)
                    switch pointerToState.pointee {
                    case .pending:
                        pointerToState.pointee = .active(task)
                        os_unfair_lock_unlock(lock)
                    case .cancelled:
                        pointerToState.pointee = .cancelled
                        os_unfair_lock_unlock(lock)
                        task.cancel() // important that unlock happens before cancelling the underlying task
                    case .active:
                        os_unfair_lock_unlock(lock)
                        preconditionFailure("Cannot activate twice")
                    }
                }
            }
        } onCancel: {
            state.withUnsafeMutablePointers { pointerToState, lock in
                os_unfair_lock_lock(lock)
                switch pointerToState.pointee {
                case .pending:
                    pointerToState.pointee = .cancelled
                    os_unfair_lock_unlock(lock)
                case .cancelled:
                    os_unfair_lock_unlock(lock)
                case .active(let task):
                    pointerToState.pointee = .cancelled
                    os_unfair_lock_unlock(lock)
                    task.cancel() // important that unlock happens before cancelling the underlying task
                }
            }
        }
    }

    private static func result(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Result<(Data, URLResponse), Error> {
        guard let data = data, let response = response else {
            return .failure(error!)
        }
        return .success((data, response))
    }

    func compatibilityData(for request: URLRequest, beforeResuming: (URLSessionTask) -> Void) async throws -> (Data, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            dataTask(with: request) { data, response, error in
                continuation.resume(with: Self.result(data, response, error))
            }
        }
    }

    func compatibilityData(from url: URL, beforeResuming: (URLSessionTask) -> Void) async throws -> (Data, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            dataTask(with: url) { data, response, error in
                continuation.resume(with: Self.result(data, response, error))
            }
        }
    }

    func compatibilityUpload(for request: URLRequest, fromFile fileURL: URL, beforeResuming: (URLSessionTask) -> Void) async throws -> (Data, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            uploadTask(with: request, fromFile: fileURL) { data, response, error in
                continuation.resume(with: Self.result(data, response, error))
            }
        }
    }

    func compatibilityUpload(for request: URLRequest, from bodyData: Data, beforeResuming: (URLSessionTask) -> Void) async throws -> (Data, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            uploadTask(with: request, from: bodyData) { data, response, error in
                continuation.resume(with: Self.result(data, response, error))
            }
        }
    }

    private static func preserveDownloadedFile(_ ephemeralDestination: URL?, _ response: URLResponse?, _ error: Error?) -> Result<(URL, URLResponse), Error> {
        guard let ephemeralDestination = ephemeralDestination, let response = response else {
            return .failure(error!)
        }

        return Result {
            var persistentDestination = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: ephemeralDestination, create: true)
            persistentDestination.appendPathComponent(UUID().uuidString)
            persistentDestination.appendPathExtension("tmp")
            try FileManager.default.moveItem(at: ephemeralDestination, to: persistentDestination)
            return (persistentDestination, response)
        }
    }

    func compatibilityDownload(for request: URLRequest, beforeResuming: (URLSessionTask) -> Void) async throws -> (URL, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            downloadTask(with: request) { url, response, error in
                continuation.resume(with: Self.preserveDownloadedFile(url, response, error))
            }
        }
    }

    func compatibilityDownload(from url: URL, beforeResuming: (URLSessionTask) -> Void) async throws -> (URL, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            downloadTask(with: url) { url, response, error in
                continuation.resume(with: Self.preserveDownloadedFile(url, response, error))
            }
        }
    }

    func compatibilityDownload(resumeFrom resumeData: Data, beforeResuming: (URLSessionTask) -> Void) async throws -> (URL, URLResponse) {
        try await withCancellableTask(beforeResuming: beforeResuming) { continuation in
            downloadTask(withResumeData: resumeData) { url, response, error in
                continuation.resume(with: Self.preserveDownloadedFile(url, response, error))
            }
        }
    }
}

public extension URLSession {
    /// Convenience method to load data using an `URLRequest`, creates and resumes an `URLSessionDataTask` internally.
    ///
    /// - Parameter request: The `URLRequest` for which to load data.
    /// - Returns: Data and response.
    @available(macOS, deprecated: 12, renamed: "data(for:)")
    @available(iOS, deprecated: 15, renamed: "data(for:)")
    @available(watchOS, deprecated: 8, renamed: "data(for:)")
    @available(tvOS, deprecated: 15, renamed: "data(for:)")
    func compatibilityData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await data(for: request)
        } else {
            return try await compatibilityData(for: request) { _ in }
        }
    }

    /// Convenience method to load data using an `URL`, creates and resumes an `URLSessionDataTask` internally.
    ///
    /// - Parameter url: The `URL` for which to load data.
    /// - Returns: Data and response.
    @available(macOS, deprecated: 12, renamed: "data(from:)")
    @available(iOS, deprecated: 15, renamed: "data(from:)")
    @available(watchOS, deprecated: 8, renamed: "data(from:)")
    @available(tvOS, deprecated: 15, renamed: "data(from:)")
    func compatibilityData(from url: URL) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await data(from: url)
        } else {
            return try await compatibilityData(from: url) { _ in }
        }
    }

    /// Convenience method to upload data using an `URLRequest`, creates and resumes an `URLSessionUploadTask` internally.
    ///
    /// - Parameter request: The `URLRequest` for which to upload data.
    /// - Parameter fileURL: File to upload.
    /// - Returns: Data and response.
    @available(macOS, deprecated: 12, renamed: "upload(for:fromFile:)")
    @available(iOS, deprecated: 15, renamed: "upload(for:fromFile:)")
    @available(watchOS, deprecated: 8, renamed: "upload(for:fromFile:)")
    @available(tvOS, deprecated: 15, renamed: "upload(for:fromFile:)")
    func compatibilityUpload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await upload(for: request, fromFile: fileURL)
        } else {
            return try await compatibilityUpload(for: request, fromFile: fileURL) { _ in }
        }
    }

    /// Convenience method to upload data using an `URLRequest`, creates and resumes an `URLSessionUploadTask` internally.
    ///
    /// - Parameter request: The `URLRequest` for which to upload data.
    /// - Parameter bodyData: Data to upload.
    /// - Returns: Data and response.
    @available(macOS, deprecated: 12, renamed: "upload(for:bodyData:)")
    @available(iOS, deprecated: 15, renamed: "upload(for:bodyData:)")
    @available(watchOS, deprecated: 8, renamed: "upload(for:bodyData:)")
    @available(tvOS, deprecated: 15, renamed: "upload(for:bodyData:)")
    func compatibilityUpload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await upload(for: request, from: bodyData)
        } else {
            return try await compatibilityUpload(for: request, from: bodyData) { _ in }
        }
    }

    /// Convenience method to download using an `URLRequest`, creates and resumes an `URLSessionDownloadTask` internally.
    ///
    /// - Parameter request: The `URLRequest` for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(macOS, deprecated: 12, renamed: "download(for:)")
    @available(iOS, deprecated: 15, renamed: "download(for:)")
    @available(watchOS, deprecated: 8, renamed: "download(for:)")
    @available(tvOS, deprecated: 15, renamed: "download(for:)")
    func compatibilityDownload(for request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await download(for: request)
        } else {
            return try await compatibilityDownload(for: request) { _ in }
        }
    }

    /// Convenience method to download using an `URL`, creates and resumes an `URLSessionDownloadTask` internally.
    ///
    /// - Parameter url: The `URL` for which to download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(macOS, deprecated: 12, renamed: "download(from:)")
    @available(iOS, deprecated: 15, renamed: "download(from:)")
    @available(watchOS, deprecated: 8, renamed: "download(from:)")
    @available(tvOS, deprecated: 15, renamed: "download(from:)")
    func compatibilityDownload(from url: URL) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await download(from: url)
        } else {
            return try await compatibilityDownload(from: url) { _ in }
        }
    }

    /// Convenience method to resume download, creates and resumes an `URLSessionDownloadTask` internally.
    ///
    /// - Parameter resumeData: Resume data from an incomplete download.
    /// - Returns: Downloaded file URL and response. The file will not be removed automatically.
    @available(macOS, deprecated: 12, renamed: "download(resumeFrom:)")
    @available(iOS, deprecated: 15, renamed: "download(resumeFrom:)")
    @available(watchOS, deprecated: 8, renamed: "download(resumeFrom:)")
    @available(tvOS, deprecated: 15, renamed: "download(resumeFrom:)")
    func compatibilityDownload(resumeFrom resumeData: Data) async throws -> (URL, URLResponse) {
        if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
            return try await download(resumeFrom: resumeData)
        } else {
            return try await compatibilityDownload(resumeFrom: resumeData) { _ in }
        }
    }
}
