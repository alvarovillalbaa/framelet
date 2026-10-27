import Foundation
import XCTest
@testable import FrameletCore

final class RecordingCompletionTests: XCTestCase {
    private enum AuthoredFailure: Error, Equatable { case fileFailed }

    func testAcknowledgementBeforeWaitIsRetainedAndFirstResolutionWins() async throws {
        let completion = RecordingCompletion<Int>()
        XCTAssertTrue(completion.resolve(.success(7)))
        XCTAssertFalse(completion.resolve(.success(9)))
        let result = try await completion.wait(seconds: 1, operation: "Authored acknowledgement")
        XCTAssertEqual(result, 7)
    }

    func testIndependentWaitersReceiveTheSameAcknowledgement() async throws {
        let completion = RecordingCompletion<Int>()
        let first = Task { try await completion.wait(seconds: 2, operation: "Authored first waiter") }
        let second = Task { try await completion.wait(seconds: 2, operation: "Authored second waiter") }
        await Task.yield()
        completion.resolve(.success(42))
        let firstResult = try await first.value
        let secondResult = try await second.value
        XCTAssertEqual(firstResult, 42)
        XCTAssertEqual(secondResult, 42)
    }

    func testCancellingOneWaiterDoesNotCancelTheFileAcknowledgement() async throws {
        let completion = RecordingCompletion<Int>()
        let cancelled = Task { try await completion.wait(seconds: 2, operation: "Authored cancelled waiter") }
        let remaining = Task { try await completion.wait(seconds: 2, operation: "Authored remaining waiter") }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("The cancelled waiter must finish with cancellation.")
        } catch { XCTAssertTrue(error is CancellationError) }
        completion.resolve(.success(21))
        let result = try await remaining.value
        XCTAssertEqual(result, 21)
    }

    func testTimeoutDoesNotPoisonALateRealFileAcknowledgement() async throws {
        let completion = RecordingCompletion<Int>()
        do {
            _ = try await completion.wait(seconds: 0.001, operation: "Authored deadline")
            XCTFail("An unacknowledged operation must reach its deadline.")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Authored deadline")) }
        XCTAssertTrue(completion.resolve(.success(11)))
        let result = try await completion.wait(seconds: 1, operation: "Authored late acknowledgement")
        XCTAssertEqual(result, 11)
    }

    func testRealDelegateFailureIsRetainedForLaterWaiters() async {
        let completion = RecordingCompletion<Int>()
        XCTAssertTrue(completion.resolve(.failure(AuthoredFailure.fileFailed)))
        XCTAssertFalse(completion.resolve(.success(2)))
        do {
            _ = try await completion.wait(seconds: 1, operation: "Authored failed file")
            XCTFail("A failed delegate result must not turn into success.")
        } catch { XCTAssertEqual(error as? AuthoredFailure, .fileFailed) }
    }
}
