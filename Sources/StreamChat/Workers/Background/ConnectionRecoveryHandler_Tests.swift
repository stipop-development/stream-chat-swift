//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import CoreData
@testable import StreamChat
@testable import StreamChatTestTools
import XCTest

final class ConnectionRecoveryHandler_Tests: XCTestCase {
    var handler: DefaultConnectionRecoveryHandler!
    var mockChatClient: ChatClientMock!
    var mockConnectionMonitor: InternetConnectionMonitorMock!
    var mockBackgroundTaskScheduler: MockBackgroundTaskScheduler!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        mockConnectionMonitor = InternetConnectionMonitorMock()
        mockBackgroundTaskScheduler = MockBackgroundTaskScheduler()
        mockChatClient = ChatClientMock(config: .init(apiKeyString: .unique))
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: false)
    }
    
    override func tearDown() {
        AssertAsync.canBeReleased(&handler)
        AssertAsync.canBeReleased(&mockChatClient)
        AssertAsync.canBeReleased(&mockConnectionMonitor)
        AssertAsync.canBeReleased(&mockBackgroundTaskScheduler)
        
        super.tearDown()
    }
    
    // MARK: - Client not connected
    
    func test_whenClientWasNotConnectedAndInternetComesBack_reconnectionDoesNotHappen() {
        // Simulate connection going down
        mockConnectionMonitor.status = .unavailable
        
        // Assert disconnect is not called
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        
        // Simulate connection comming back
        mockConnectionMonitor.status = .available(.great)
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenActiveInBackgroundClientWasNotConnectedAndAppGoesToForeground_reconnectionDoesNotHappen() {
        // Create connection recovery handler that does not cut connection in background
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: true)
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Background task is not started
        XCTAssertFalse(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenPassiveInBackgroundClientWasNotConnectedAndAppGoesToForeground_reconnectionDoesNotHappen() {
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Background task is not started
        XCTAssertFalse(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    // MARK: - Client connected and disconnected by the user
    
    func test_whenClientWasManuallyDisconnectedAndInternetComesBack_reconnectionDoesNotHappen() {
        // Connect chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Manually disconnect chat client
        mockChatClient.disconnect()
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .userInitiated))
        
        // Reset values
        mockChatClient.mockWebSocketClient.disconnect_calledCounter = 0

        // Simulate connection going down and comming back
        mockConnectionMonitor.status = .unavailable
        
        // Assert disconnect is not called for one more time
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        
        // Simulate connection comming back
        mockConnectionMonitor.status = .available(.great)
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenActiveClientWasManuallyDisconnectedAndAppGoesToForeground_reconnectionDoesNotHappen() {
        // Create connection recovery handler that does not cut connection in background
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: true)
        
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Manually disconnect chat client
        mockChatClient.disconnect()
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .userInitiated))
        
        // Reset values
        mockChatClient.mockWebSocketClient.disconnect_calledCounter = 0
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called for one more time
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Assert background task is not started
        XCTAssertFalse(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenPassiveClientWasManuallyDisconnectedAndAppGoesToForeground_reconnectionDoesNotHappen() {
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Manually disconnect chat client
        mockChatClient.disconnect()
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .userInitiated))
        
        // Reset values
        mockChatClient.mockWebSocketClient.disconnect_calledCounter = 0
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called for one more time
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Assert background task is not started
        XCTAssertFalse(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does not happen
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    // MARK: - Client connected and disconnected by the system
    
    func test_whenClientWasConnectedAndInternetComesBack_reconnectionHappens() {
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Simulate connection going down
        mockConnectionMonitor.status = .unavailable
        
        // Assert disconnection is initiated by the system
        XCTAssertTrue(mockChatClient.mockWebSocketClient.disconnect_called)
        XCTAssertEqual(mockChatClient.mockWebSocketClient.disconnect_source, .systemInitiated)
        
        // Simulate client disconnection
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .systemInitiated))
        
        // Simulate connection comming back
        mockConnectionMonitor.status = .available(.great)
        
        // Assert the reconnection happens
        XCTAssertTrue(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenPassiveInBackgroundClientWasConnectedAndAppGoesToForeground_reconnectionHappens() {
        // Connect chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnection is initiated by the system
        XCTAssertTrue(mockChatClient.mockWebSocketClient.disconnect_called)
        XCTAssertEqual(mockChatClient.mockWebSocketClient.disconnect_source, .systemInitiated)
        
        // Simulate client disconnection
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .systemInitiated))
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert reconnection does happen
        XCTAssertTrue(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenBackgroundTaskWasInterruptedAndAppGoesToForegroundWithInternetConnectionAvailable_reconnectionHappens() {
        // Create connection recovery handler that does not cut connection in background
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: true)
        
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called because it should stay connected in background
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Assert background task is started so client stays connected in background
        XCTAssertTrue(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate backgroud task interruption
        mockBackgroundTaskScheduler.beginBackgroundTask_expirationHandler?()
        
        // Assert disconnect is initiated by the system
        XCTAssertTrue(mockChatClient.mockWebSocketClient.disconnect_called)
        XCTAssertEqual(mockChatClient.mockWebSocketClient.disconnect_source, .systemInitiated)
        
        // Simulate client disconnection
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .systemInitiated))
        
        // Simulate internet connection being available
        mockConnectionMonitor.status = .available(.great)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does happens
        XCTAssertTrue(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenBackgroundTaskWasInterruptedAndAppGoesToForegroundWithInternetConnectionNotAvailable_reconnectionDoesNotHappens() {
        // Create connection recovery handler that does not cut connection in background
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: true)
        
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called because it should stay connected in background
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Assert background task is started so client stays connected in background
        XCTAssertTrue(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate backgroud task interruption
        mockBackgroundTaskScheduler.beginBackgroundTask_expirationHandler?()
        
        // Assert disconnect is initiated by the system
        XCTAssertTrue(mockChatClient.mockWebSocketClient.disconnect_called)
        XCTAssertEqual(mockChatClient.mockWebSocketClient.disconnect_source, .systemInitiated)
        
        // Simulate client disconnection
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.disconnected(source: .systemInitiated))
        
        // Simulate internet connection being NOT available
        mockConnectionMonitor.status = .unavailable
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert the reconnection does not happens
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    func test_whenBackgroundTaskWasNotInterruptedAndAppGoesToForeground_reconnectionDoesNotHappen() {
        // Create connection recovery handler that does not cut connection in background
        handler = makeConnectionRecoveryHandler(staysConnectedInBackground: true)
        
        // Connect a chat client
        mockChatClient.connectGuestUser(userInfo: .init(id: .unique))
        mockChatClient.mockWebSocketClient.simulateConnectionStatus(.connected(connectionId: .unique))
        
        // Simulate app going to background
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onBackground?()
        
        // Assert disconnect is not called because it should stay connected in background
        XCTAssertFalse(mockChatClient.mockWebSocketClient.disconnect_called)
        // Assert background task is started so client stays connected in background
        XCTAssertTrue(mockBackgroundTaskScheduler.beginBackgroundTask_called)
        
        // Simulate app going to foreground
        mockBackgroundTaskScheduler.startListeningForAppStateUpdates_onForeground?()
        
        // Assert background task is ended
        XCTAssertTrue(mockBackgroundTaskScheduler.endBackgroundTask_called)
        
        // Assert the reconnection does not happen since client was not disconnected
        XCTAssertFalse(mockChatClient.mockWebSocketClient.connect_called)
    }
    
    // MARK: - Private
    
    private func makeConnectionRecoveryHandler(staysConnectedInBackground: Bool) -> DefaultConnectionRecoveryHandler {
        .init(
            webSocketClient: mockChatClient.mockWebSocketClient,
            eventNotificationCenter: mockChatClient.eventNotificationCenter,
            backgroundTaskScheduler: mockBackgroundTaskScheduler,
            internetConnection: InternetConnectionMock(
                monitor: mockConnectionMonitor,
                notificationCenter: mockChatClient.eventNotificationCenter
            ),
            reconnectionStrategy: DefaultRetryStrategy(),
            reconnectionTimerType: DefaultTimer.self,
            staysConnectedInBackground: staysConnectedInBackground
        )
    }
}

extension ChannelListQuery: Equatable {
    public static func == (lhs: ChannelListQuery, rhs: ChannelListQuery) -> Bool {
        lhs.filter == rhs.filter &&
            lhs.messagesLimit == rhs.messagesLimit &&
            lhs.options == rhs.options &&
            lhs.pagination == rhs.pagination
    }
}
