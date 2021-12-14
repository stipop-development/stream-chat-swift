//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

/// The type that keeps track of active chat components and asks them to reconnect when it's needed
protocol ConnectionRecoveryHandler: AnyObject {}

/// The type is designed to obtain missing events that happened in watched channels while user
/// was not connected to the web-socket.
///
/// The object listens for `ConnectionStatusUpdated` events
/// and remembers the `CurrentUserDTO.lastReceivedEventDate` when status becomes `connecting`.
///
/// When the status becomes `connected` the `/sync` endpoint is called
/// with `lastReceivedEventDate` and `cids` of watched channels.
///
/// We remember `lastReceivedEventDate` when state becomes `connecting` to catch the last event date
/// before the `HealthCheck` override the `lastReceivedEventDate` with the recent date.
///
final class DefaultConnectionRecoveryHandler: ConnectionRecoveryHandler {
    // MARK: - Properties
    
    private let webSocketClient: WebSocketClient
    private let eventNotificationCenter: EventNotificationCenter
    private let backgroundTaskScheduler: BackgroundTaskScheduler?
    private let internetConnection: InternetConnection
    private let reconnectionTimerType: Timer.Type
    private var reconnectionStrategy: RetryStrategy
    private var reconnectionTimer: TimerControl?
    private var connectionObserver: EventObserver?
    private let staysConnectedInBackground: Bool
    
    // MARK: - Init
    
    init(
        webSocketClient: WebSocketClient,
        eventNotificationCenter: EventNotificationCenter,
        backgroundTaskScheduler: BackgroundTaskScheduler?,
        internetConnection: InternetConnection,
        reconnectionStrategy: RetryStrategy,
        reconnectionTimerType: Timer.Type,
        staysConnectedInBackground: Bool
    ) {
        self.webSocketClient = webSocketClient
        self.eventNotificationCenter = eventNotificationCenter
        self.backgroundTaskScheduler = backgroundTaskScheduler
        self.internetConnection = internetConnection
        self.reconnectionStrategy = reconnectionStrategy
        self.reconnectionTimerType = reconnectionTimerType
        self.staysConnectedInBackground = staysConnectedInBackground

        subscribeOnNotifications()
    }
    
    deinit {
        unsubscribeFromNotifications()
        cancelReconnectionTimer()
    }
    
    // MARK: - Subscriptions
    
    private func subscribeOnNotifications() {
        backgroundTaskScheduler?.startListeningForAppStateUpdates(
            onEnteringBackground: { [weak self] in self?.handleAppDidEnterBackground() },
            onEnteringForeground: { [weak self] in self?.handleAppDidBecomeActive() }
        )
        
        internetConnection.notificationCenter.addObserver(
            self,
            selector: #selector(didChangeInternetConnectionStatus(_:)),
            name: .internetConnectionStatusDidChange,
            object: nil
        )
        
        connectionObserver = .init(
            notificationCenter: eventNotificationCenter,
            transform: { $0 as? ConnectionStatusUpdated },
            callback: { [weak self] in
                self?.didChangeWebSocketConnectionStatus($0.webSocketConnectionState)
            }
        )
    }
    
    private func unsubscribeFromNotifications() {
        backgroundTaskScheduler?.stopListeningForAppStateUpdates()
        
        internetConnection.notificationCenter.removeObserver(
            self,
            name: .internetConnectionStatusDidChange,
            object: nil
        )
        
        connectionObserver = nil
    }

    // MARK: - Notification handlers
    
    private func handleAppDidBecomeActive() {
        backgroundTaskScheduler?.endTask()
        
        reconnectIfNeeded()
    }
    
    private func handleAppDidEnterBackground() {
        guard staysConnectedInBackground else {
            // We immediately disconnect
            disconnectWebSocket()
            return
        }
        
        guard let scheduler = backgroundTaskScheduler else { return }
        
        let succeed = scheduler.beginTask { [weak self] in
            self?.disconnectWebSocket()
        }
        
        if !succeed {
            // Can't initiate a background task, close the connection
            disconnectWebSocket()
        }
    }
    
    @objc private func didChangeInternetConnectionStatus(_ notification: Notification) {
        guard let isAvailable = notification.internetConnectionStatus?.isAvailable else { return }
        
        if isAvailable {
            reconnectIfNeeded()
        } else {
            disconnectWebSocket()
        }
    }
    
    private func didChangeWebSocketConnectionStatus(_ state: WebSocketConnectionState) {
        switch state {
        case .connecting:
            cancelReconnectionTimer()
        
        case .connected:
            reconnectionStrategy.resetConsecutiveFailures()
        
        case .disconnected:
            guard canReconnectAutomatically else { break }
            
            let delay = reconnectionStrategy.getDelayAfterTheFailure()
            reconnectionTimer = reconnectionTimerType.schedule(
                timeInterval: delay,
                queue: .main,
                onFire: { [weak self] in
                    self?.reconnectIfNeeded()
                }
            )
            
        case .initialized, .waitingForConnectionId, .disconnecting:
            break
        }
    }
    
    private func disconnectWebSocket() {
        webSocketClient.disconnect(source: .systemInitiated)
    }
    
    private func cancelReconnectionTimer() {
        reconnectionTimer?.cancel()
        reconnectionTimer = nil
    }
    
    // MARK: - Reconnection
        
    private func reconnectIfNeeded() {
        guard canReconnectAutomatically else { return }
        
        webSocketClient.connect()
    }
    
    private var canReconnectAutomatically: Bool {
        guard webSocketClient.connectionState.isAutomaticReconnectionEnabled else {
            // The web socket state does not allow to reconnect automatically
            return false
        }
        
        guard internetConnection.status.isAvailable else {
            // We are offline. Once the connection comes back we will try to reconnect again
            return false
        }
        
        guard backgroundTaskScheduler?.appIsActive ?? true else {
            // We should not reconnect if app is not active
            return false
        }
        
        guard reconnectionStrategy.consecutiveFailures < 3 else {
            // All reconnection attempts are used
            return false
        }
        
        return true
    }
}
