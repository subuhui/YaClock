// MARK: - Data Layer · Service Protocol
import Foundation

public struct SystemAlarmInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let time: String
    public let repeatString: String
    public let isSimulated: Bool

    public init(id: UUID, title: String, time: String, repeatString: String, isSimulated: Bool) {
        self.id = id
        self.title = title
        self.time = time
        self.repeatString = repeatString
        self.isSimulated = isSimulated
    }
}

protocol AlarmServiceProtocol: AnyObject, Sendable {
    var isAuthorized: Bool { get }
    var systemAlarms: [SystemAlarmInfo] { get }

    func checkAuthorization()
    func requestAuthorization() async -> Bool
    func scheduleAlarm(_ entity: AlarmEntity) async throws
    func cancelAlarm(id: UUID) async throws
}

