//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

@testable import StreamChat
import XCTest

class ChatClientConnectionStatus_Tests: XCTestCase {
    func test_wsConnectionState_isTranslatedCorrectly() {
        let testError = ClientError(with: TestError())
        let pairs: [(WebSocketConnectionState, ConnectionStatus)] = [
            (.initialized, .initialized),
            (.connecting, .connecting),
            (.waitingForConnectionId, .connecting),
            (.connected(connectionId: .unique), .connected),
            (.disconnecting(source: .noPongReceived), .disconnecting),
            (.disconnecting(source: .serverInitiated(error: testError)), .disconnecting),
            (.disconnecting(source: .systemInitiated), .disconnecting),
            (.disconnecting(source: .userInitiated), .disconnecting),
            (.disconnected(source: .userInitiated), .disconnected(error: nil)),
            (.disconnected(source: .systemInitiated), .disconnected(error: nil)),
            (.disconnected(source: .noPongReceived), .disconnected(error: nil)),
            (.disconnected(source: .serverInitiated(error: nil)), .disconnected(error: nil)),
            (.disconnected(source: .serverInitiated(error: testError)), .disconnected(error: testError))
        ]
        
        pairs.forEach {
            XCTAssertEqual($1, ConnectionStatus(webSocketConnectionState: $0))
        }
    }
}

final class WebSocketConnectionState_Tests: XCTestCase {
    func test_disconnectionSource_serverError() {
        // Create test error
        let testError = ClientError(with: TestError())
        
        // Create pairs of disconnection source and expected server error
        let testCases: [(WebSocketConnectionState.DisconnectionSource, ClientError?)] = [
            (.userInitiated, nil),
            (.systemInitiated, nil),
            (.noPongReceived, nil),
            (.serverInitiated(error: nil), nil),
            (.serverInitiated(error: testError), testError)
        ]
        
        // Iterate pairs
        testCases.forEach { source, serverError in
            // Assert returned server error matches expected one
            XCTAssertEqual(source.serverError, serverError)
        }
    }

//
//    func test_returnsNilForStopError() {
//        let stopError = WebSocketEngineError(
//            reason: "Testing stop error",
//            code: WebSocketEngineError.stopErrorCode,
//            engineError: nil
//        )
//
//        let delay = strategy.reconnectionDelay(forConnectionError: stopError)
//        XCTAssertNil(delay)
//    }
//
//    func test_returnsNilForInvalidTokenErrors() {
//        let invalidTokenErrorCodes = [40, 41, 42, 43]
//        invalidTokenErrorCodes.forEach { invalidTokenErrorCode in
//            let error = ErrorPayload(code: invalidTokenErrorCode, message: "", statusCode: 0)
//            let delay = strategy.reconnectionDelay(forConnectionError: error)
//            XCTAssertNil(delay)
//        }
//
//        // Check other error codes return a non-nil delay
//        let error = ErrorPayload(code: 66, message: "", statusCode: 0)
//        let delay = strategy.reconnectionDelay(forConnectionError: error)
//        XCTAssertNotNil(delay)
//    }
//
//    func test_returnsNilForInternetIsOfflineError() {
//        let error = WebSocketEngineError(
//            error:
//            NSError(
//                domain: NSURLErrorDomain,
//                code: NSURLErrorNotConnectedToInternet,
//                userInfo: nil
//            )
//        )
//        let delay = strategy.reconnectionDelay(forConnectionError: error)
//        XCTAssertNil(delay)
//    }
//
//    func test_returnsNil_forClientSideErrorStatusCodes() {
//        let clientSideErrorStatusCodes = 400...499
//
//        clientSideErrorStatusCodes.forEach { statusCode in
//            let error = ErrorPayload(code: 0, message: "", statusCode: statusCode)
//            let delay = strategy.reconnectionDelay(forConnectionError: error)
//            XCTAssertNil(delay)
//        }
//
//        // Check server erros return a non-nil delay
//        let error = ErrorPayload(code: 0, message: "", statusCode: 500)
//        let delay = strategy.reconnectionDelay(forConnectionError: error)
//        XCTAssertNotNil(delay)
//    }
}
