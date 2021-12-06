import Foundation
import Network
import XCTest

extension XCTestCase {
    func runHTTPServer(returning string: String, status: Int = 200) async throws -> URL {
        let queue = DispatchQueue(label: "\(self)")
        let listener = try NWListener(using: .tcp)
        addTeardownBlock(listener.cancel)

        listener.newConnectionHandler = { [string, queue] connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: .max) { data, context, complete, error in
                if error != nil {
                    connection.cancel()
                    return
                }
                let response = Data("""
                HTTP/1.1 200 OK\r
                Content-Length: \(string.utf8.count)\r
                \r
                \(string)
                """.utf8)
                connection.send(content: response, isComplete: true, completion: .contentProcessed { error in
                    // Wait for the client to close the connection
                    connection.receiveMessage { data, context, complete, error in
                        connection.cancel()
                    }
                })
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.sync {
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        continuation.resume()
                    case .failed(let error):
                        continuation.resume(throwing: error)
                    default:
                        break
                    }
                }
            }
            listener.start(queue: queue)
        }

        let port = try XCTUnwrap(listener.port)
        let url = try XCTUnwrap(URL(string: "http://localhost:\(port.rawValue)/"))
        return url
    }
}
