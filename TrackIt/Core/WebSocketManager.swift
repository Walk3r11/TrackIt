import Foundation
import Combine

enum WebSocketStreamType: String, Codable {
    case tickets
    case ticketMessages = "ticket-messages"
    case transactions
}

struct WebSocketMessage: Codable {
    let type: String
    let data: [String: AnyCodable]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case type, data, error
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        }
    }
}

class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketManager()

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var baseURL: URL?
    private var token: String?
    private var userId: String?
    private var supportUserId: String?
    private var streamType: WebSocketStreamType?
    private var ticketId: String?

    private var messageSubject = PassthroughSubject<WebSocketMessage, Error>()
    private var connectionSubject = PassthroughSubject<Bool, Never>()

    var messages: AnyPublisher<WebSocketMessage, Error> {
        messageSubject.eraseToAnyPublisher()
    }

    var connectionStatus: AnyPublisher<Bool, Never> {
        connectionSubject.eraseToAnyPublisher()
    }

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?
    private var isConnecting = false
    private var currentUserId: String?
    private var currentStreamType: WebSocketStreamType?

    override init() {
        super.init()
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: override) {
            baseURL = url
        } else {
            baseURL = URL(string: "https://backend-production-0eac.up.railway.app")
        }
    }

    func connect(
        token: String,
        userId: String? = nil,
        supportUserId: String? = nil,
        streamType: WebSocketStreamType,
        ticketId: String? = nil
    ) {

        if isConnecting {

            if currentUserId == userId && currentStreamType == streamType {
                return
            }

            disconnect()
        }


        if webSocketTask != nil && currentUserId == userId && currentStreamType == streamType {
            return
        }

        isConnecting = true
        self.token = token
        self.userId = userId
        self.supportUserId = supportUserId
        self.streamType = streamType
        self.ticketId = ticketId
        self.currentUserId = userId
        self.currentStreamType = streamType

        guard let base = baseURL else {
            isConnecting = false
            return
        }
        var wsURL = base.absoluteString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")


        if wsURL.hasSuffix("/") {
            wsURL = String(wsURL.dropLast())
        }

        guard let url = URL(string: wsURL + "/api/ws") else {
            isConnecting = false
            return
        }

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        print("[WebSocket] Connecting to: \(url.absoluteString)")
        print("[WebSocket] Stream type: \(streamType.rawValue), ticketId: \(ticketId ?? "nil")")
    }

    func disconnect() {
        isConnecting = false
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        currentUserId = nil
        currentStreamType = nil
        connectionSubject.send(false)
    }

    private func sendAuth() {
        guard let token = token else { return }
        let message: [String: Any] = [
            "type": "auth",
            "token": token,
            "userId": userId as Any,
            "supportUserId": supportUserId as Any
        ]
        sendJSON(message)
    }

    private func sendSubscribe() {
        guard let streamType = streamType else { return }
        var message: [String: Any] = [
            "type": "subscribe",
            "streamType": streamType.rawValue
        ]
        if let ticketId = ticketId {
            message["ticketId"] = ticketId
        }
        if let userId = userId {
            message["userId"] = userId
        }
        if let supportUserId = supportUserId {
            message["supportUserId"] = supportUserId
        }
        sendJSON(message)
    }

    private func sendJSON(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return }
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {

                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    print("[WebSocket] Send error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func receiveMessage() {
        guard let task = webSocketTask, task.state == .running else {
            return
        }

        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }

                if self.webSocketTask?.state == .running {
                    self.receiveMessage()
                }
            case .failure(let error):
                if self.webSocketTask !== task {
                    return
                }
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    print("[WebSocket] Receive error: \(error.localizedDescription)")
                }
                if nsError.code != NSURLErrorCancelled {
                    self.handleDisconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("[WebSocket] Failed to parse message: \(text.prefix(200))")
            return
        }

        print("[WebSocket] Received message type: \(type)")

        if type == "auth", let authData = json["data"] as? [String: Any],
           authData["authenticated"] as? Bool == true {
            print("[WebSocket] Authenticated successfully")
            isConnecting = false
            connectionSubject.send(true)
            sendSubscribe()
        } else if type == "subscribed" {
            print("[WebSocket] Subscribed successfully to stream")
            isConnecting = false
            connectionSubject.send(true)
        } else if type == "ping" {
            sendJSON(["type": "pong"])
        } else if type == "error", let error = json["error"] as? String {
            print("[WebSocket] Error from server: \(error)")
            messageSubject.send(completion: .failure(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
        } else {
            var messageData: [String: AnyCodable] = [:]
            if let data = json["data"] as? [String: Any] {
                messageData = data.mapValues { AnyCodable($0) }
            }
            if let message = json["message"] as? [String: Any] {
                messageData["message"] = AnyCodable(message)
            }
            if let ticket = json["ticket"] as? [String: Any] {
                messageData["ticket"] = AnyCodable(ticket)
            }
            if let transaction = json["transaction"] as? [String: Any] {
                messageData["transaction"] = AnyCodable(transaction)
            }
            if let status = json["status"] as? String {
                messageData["status"] = AnyCodable(status)
            }

            print("[WebSocket] Publishing message type: \(type), has data: \(!messageData.isEmpty)")

            let message = WebSocketMessage(
                type: type,
                data: messageData.isEmpty ? nil : messageData,
                error: json["error"] as? String
            )
            messageSubject.send(message)
        }
    }

    private func handleDisconnect() {
        connectionSubject.send(false)

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = UInt64(reconnectAttempts * 1000) * 1_000_000

            reconnectTask = Task {
                try? await Task.sleep(nanoseconds: delay)
                if let token = token, let streamType = streamType {
                    connect(token: token, userId: userId, supportUserId: supportUserId, streamType: streamType, ticketId: ticketId)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnecting = false
        connectionSubject.send(true)
        reconnectAttempts = 0
        sendAuth()
        receiveMessage()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}
