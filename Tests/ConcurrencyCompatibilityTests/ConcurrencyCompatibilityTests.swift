import XCTest
@testable import ConcurrencyCompatibility
import Network

final class URLSessionTests: XCTestCase {
    let requestBody = UUID().uuidString
    let responseBody = UUID().uuidString
    var url: URL!

    override func setUp() async throws {
        url = try await runHTTPServer(returning: responseBody)
    }

    func testCompatibilityDataFromURL() async throws {
        let (data, response) = try await URLSession.shared.compatibilityData(from: url) { _ in }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func testCompatibilityUploadForRequest() async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(requestBody.utf8)
        let (data, response) = try await URLSession.shared.compatibilityData(for: request) { _ in }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func testCompatibilityUploadFromData() async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.compatibilityUpload(for: request, from: Data(requestBody.utf8)) { _ in }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func testCompatibilityFromFile() async throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)
        try Data(requestBody.utf8).write(to: fileURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.compatibilityUpload(for: request, fromFile: fileURL) { _ in }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        try FileManager.default.removeItem(at: fileURL)
    }

    func testCompatibilityDownloadFromURL() async throws {
        let (destination, response) = try await URLSession.shared.compatibilityDownload(from: url) { _ in }
        let data = try Data(contentsOf: destination)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        try FileManager.default.removeItem(at: destination)
    }

    func testCompatibilityDownloadForRequest() async throws {
        let request = URLRequest(url: url)
        let (destination, response) = try await URLSession.shared.compatibilityDownload(for: request) { _ in }
        let data = try Data(contentsOf: destination)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), responseBody)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        try FileManager.default.removeItem(at: destination)
    }
}
