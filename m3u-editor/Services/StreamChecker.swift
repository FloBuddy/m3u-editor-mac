import Foundation
import Observation

// MARK: - Stream Status

enum StreamStatus: Equatable, Sendable {
    case unknown
    case checking
    case online(responseTime: Double)
    case redirect(location: String)
    case offline(error: String)

    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .unknown:                 return "Not checked"
        case .checking:                return "Checking…"
        case .online(let t):           return String(format: "%.0f ms", t * 1_000)
        case .redirect(let loc):       return "Redirect → \(loc)"
        case .offline(let err):        return err
        }
    }

    var systemImage: String {
        switch self {
        case .unknown:   return "minus.circle"
        case .checking:  return "arrow.clockwise"
        case .online:    return "checkmark.circle.fill"
        case .redirect:  return "arrow.uturn.right.circle"
        case .offline:   return "xmark.circle.fill"
        }
    }
}

// MARK: - StreamChecker

@Observable
final class StreamChecker {
    var statuses: [UUID: StreamStatus] = [:]
    var isRunning: Bool = false
    var checkedCount: Int = 0
    var totalCount: Int = 0

    private var checkTask: Task<Void, Never>?

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(checkedCount) / Double(totalCount)
    }

    // MARK: - Public API

    func checkAll(channels: [M3UChannel]) {
        cancel()
        statuses = [:]
        checkedCount = 0
        totalCount = channels.count
        isRunning = true

        checkTask = Task {
            await withTaskGroup(of: (UUID, StreamStatus).self) { group in
                for channel in channels {
                    group.addTask {
                        let status = await StreamChecker.checkURL(channel.url)
                        return (channel.id, status)
                    }
                }
                for await (id, status) in group {
                    guard !Task.isCancelled else { break }
                    statuses[id] = status
                    checkedCount += 1
                }
            }
            isRunning = false
        }
    }

    func checkSingle(channel: M3UChannel) async {
        statuses[channel.id] = .checking
        let status = await StreamChecker.checkURL(channel.url)
        statuses[channel.id] = status
    }

    func cancel() {
        checkTask?.cancel()
        checkTask = nil
        isRunning = false
    }

    // MARK: - Private

    private static func checkURL(_ urlString: String) async -> StreamStatus {
        guard let url = URL(string: urlString) else {
            return .offline(error: "Invalid URL")
        }
        let start = ContinuousClock.now
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = ContinuousClock.now - start
            let seconds = Double(elapsed.components.seconds)
                + Double(elapsed.components.attoseconds) * 1e-18

            if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200..<300:
                    return .online(responseTime: seconds)
                case 300..<400:
                    let loc = http.value(forHTTPHeaderField: "Location") ?? ""
                    return .redirect(location: loc)
                default:
                    return .offline(error: "HTTP \(http.statusCode)")
                }
            }
            return .online(responseTime: seconds)
        } catch {
            if Task.isCancelled { return .unknown }
            let msg = (error as NSError).localizedDescription
            return .offline(error: msg)
        }
    }
}
