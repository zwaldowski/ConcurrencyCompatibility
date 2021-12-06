import Combine
import Foundation

@available(macOS, deprecated: 12, renamed: "AsyncPublisher")
@available(iOS, deprecated: 15, renamed: "AsyncPublisher")
@available(watchOS, deprecated: 8, renamed: "AsyncPublisher")
@available(tvOS, deprecated: 15, renamed: "AsyncPublisher")
public struct CompatibilityAsyncPublisher<P>: AsyncSequence where P: Publisher, P.Failure == Never {
    public typealias Element = P.Output

    public struct Iterator: AsyncIteratorProtocol {
        typealias Base = CompatibilityAsyncThrowingPublisher<P>.Iterator.Base

        @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
        class Native: CompatibilityAsyncThrowingPublisher<P>.Iterator.Base {
            var iterator: AsyncPublisher<P>.Iterator

            init(_ publisher: P) {
                self.iterator = publisher.values.makeAsyncIterator()
            }

            override func next() async -> Element? {
                await iterator.next()
            }
        }

        typealias Inner = CompatibilityAsyncThrowingPublisher<P>.Iterator.Inner

        let base: Base

        init(_ publisher: P) {
            if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
                base = Native(publisher)
            } else {
                base = Inner(publisher)
            }
        }

        public mutating func next() async -> P.Output? {
            try! await base.next()
        }
    }

    let publisher: P

    public init(_ publisher: P) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(publisher)
    }
}

@available(macOS, deprecated: 12, renamed: "AsyncThrowingPublisher")
@available(iOS, deprecated: 15, renamed: "AsyncThrowingPublisher")
@available(watchOS, deprecated: 8, renamed: "AsyncThrowingPublisher")
@available(tvOS, deprecated: 15, renamed: "AsyncThrowingPublisher")
public struct CompatibilityAsyncThrowingPublisher<P>: AsyncSequence where P: Publisher {
    public typealias Element = P.Output

    public struct Iterator: AsyncIteratorProtocol {
        class Base: AsyncIteratorProtocol {
            func next() async throws -> Element? { fatalError() }
        }

        @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
        class Native: Base {
            var iterator: AsyncThrowingPublisher<P>.Iterator

            init(_ publisher: P) {
                self.iterator = publisher.values.makeAsyncIterator()
            }

            override func next() async throws -> Element? {
                try await iterator.next()
            }
        }

        class Inner: Base, Subscriber, Cancellable {
            enum State {
                case awaitingSubscription(demand: Subscribers.Demand)
                case subscribed(Subscription)
                case terminal
            }

            let lock = NSLock()
            var state = State.awaitingSubscription(demand: .none)
            var pendingContinuations = [UnsafeContinuation<P.Output?, Error>]()

            init(_ publisher: P) {
                super.init()
                publisher.subscribe(self)
            }

            func receive(subscription: Subscription) {
                lock.lock()
                switch state {
                case .awaitingSubscription(let demand):
                    state = .subscribed(subscription)
                    lock.unlock()
                    if demand > .none {
                        subscription.request(demand)
                    }
                case .subscribed, .terminal:
                    lock.unlock()
                    subscription.cancel()
                }
            }

            func receive(_ input: Element) -> Subscribers.Demand {
                lock.lock()
                switch state {
                case .subscribed:
                    let continuation = pendingContinuations.isEmpty ? nil : pendingContinuations.removeFirst()
                    lock.unlock()
                    continuation?.resume(returning: input)
                case .awaitingSubscription, .terminal:
                    let continuationsToProcess = pendingContinuations
                    pendingContinuations.removeAll()
                    lock.unlock()
                    for continuation in continuationsToProcess {
                        continuation.resume(returning: nil)
                    }
                }
                return .none
            }

            func receive(completion: Subscribers.Completion<P.Failure>) {
                lock.lock()
                state = .terminal
                let continuationsToProcess = pendingContinuations
                pendingContinuations.removeAll()
                lock.unlock()

                if let continuation = continuationsToProcess.first {
                    switch completion {
                    case .finished:
                        continuation.resume(returning: nil)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                for continuation in continuationsToProcess.dropFirst() {
                    continuation.resume(returning: nil)
                }
            }

            func cancel() {
                lock.lock()

                let continuationsToProcess = pendingContinuations
                pendingContinuations.removeAll()

                switch state {
                case .subscribed(let upstream):
                    state = .terminal
                    lock.unlock()
                    upstream.cancel()
                case .awaitingSubscription:
                    state = .terminal
                    lock.unlock()
                case .terminal:
                    lock.unlock()
                }

                for continuation in continuationsToProcess {
                    continuation.resume(returning: nil)
                }
            }

            override func next() async throws -> Element? {
                try await withTaskCancellationHandler {
                    try await withUnsafeThrowingContinuation { continuation in
                        lock.lock()
                        switch state {
                        case .terminal:
                            lock.unlock()
                            continuation.resume(returning: nil)
                        case .subscribed(let upstream):
                            pendingContinuations.append(continuation)
                            lock.unlock()
                            upstream.request(.max(1))
                        case .awaitingSubscription(let demand):
                            pendingContinuations.append(continuation)
                            state = .awaitingSubscription(demand: demand + 1)
                            lock.unlock()
                        }
                    }
                } onCancel: {
                    cancel()
                }
            }

        }

        let base: Base

        init(_ publisher: P) {
            if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
                base = Native(publisher)
            } else {
                base = Inner(publisher)
            }
        }

        public mutating func next() async throws -> P.Output? {
            try await base.next()
        }
    }

    let publisher: P

    public init(_ publisher: P) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(publisher)
    }
}

public extension Combine.Future where Failure == Never {
    @available(iOS, deprecated: 15, renamed: "value")
    @available(macOS, deprecated: 12, renamed: "value")
    @available(tvOS, deprecated: 15, renamed: "value")
    @available(watchOS, deprecated: 8, renamed: "value")
    var compatibilityValue: Output {
        get async { // swiftlint:disable:this implicit_getter
            if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
                return await value
            }

            for await value in compatibilityValues {
                return value
            }

            preconditionFailure("\(Self.self) completes with exactly one value")
        }
    }
}

public extension Combine.Future {
    @available(iOS, deprecated: 15, renamed: "value")
    @available(macOS, deprecated: 12, renamed: "value")
    @available(tvOS, deprecated: 15, renamed: "value")
    @available(watchOS, deprecated: 8, renamed: "value")
    var compatibilityValue: Output {
        get async throws {
            if #available(macOS 12, iOS 15, watchOS 8, tvOS 15, *) {
                return try await value
            }

            for try await value in compatibilityValues {
                return value
            }

            preconditionFailure("\(Self.self) completes with exactly one value")
        }
    }
}

public extension Publisher where Failure == Never {
    @available(iOS, deprecated: 15, renamed: "values")
    @available(macOS, deprecated: 12, renamed: "values")
    @available(tvOS, deprecated: 15, renamed: "values")
    @available(watchOS, deprecated: 8, renamed: "values")
    var compatibilityValues: CompatibilityAsyncPublisher<Self> {
        CompatibilityAsyncPublisher(self)
    }
}

public extension Publisher {
    @available(iOS, deprecated: 15, renamed: "values")
    @available(macOS, deprecated: 12, renamed: "values")
    @available(tvOS, deprecated: 15, renamed: "values")
    @available(watchOS, deprecated: 8, renamed: "values")
    var compatibilityValues: CompatibilityAsyncThrowingPublisher<Self> {
        CompatibilityAsyncThrowingPublisher(self)
    }
}
