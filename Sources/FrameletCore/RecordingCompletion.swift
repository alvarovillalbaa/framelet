import Foundation

public enum RecordingCompletionError: LocalizedError, Equatable {
    case timedOut(operation: String)
    case invalidTimeout

    public var errorDescription: String? {
        switch self {
        case .timedOut(let operation): "\(operation) took too long. Keep the app open and try Stop again. Partial files have been retained."
        case .invalidTimeout: "The recording operation has an invalid timeout."
        }
    }
}

/// Retains an actual delegate result even if every current waiter times out or
/// cancels. A wait ending is not an acknowledgement that an OS writer stopped.
public final class RecordingCompletion<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    private var waiters: [UUID: CheckedContinuation<Value, Error>] = [:]

    public init() {}

    @discardableResult
    public func resolve(_ result: Result<Value, Error>) -> Bool {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return false }
        self.result = result
        let pending = Array(waiters.values)
        waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(with: result) }
        return true
    }

    public func wait(seconds: Double = 30, operation: String) async throws -> Value {
        guard seconds.isFinite, seconds > 0, seconds <= 3600 else {
            throw RecordingCompletionError.invalidTimeout
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let result { lock.unlock(); continuation.resume(with: result); return }
                if Task.isCancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                waiters[id] = continuation
                lock.unlock()
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    self?.expire(id, error: RecordingCompletionError.timedOut(operation: operation))
                }
            }
        } onCancel: {
            self.expire(id, error: CancellationError())
        }
    }

    private func expire(_ id: UUID, error: Error) {
        lock.lock()
        let continuation = waiters.removeValue(forKey: id)
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}
