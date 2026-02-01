import Foundation
import ActivityKit

// Shared ActivityAttributes for Live Activities
// This must be used by both the main app and the Widget Extension

@available(iOS 16.2, *)
public struct SeennJobAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Int
        public var status: String
        public var message: String?
        public var stageName: String?
        public var stageIndex: Int?
        public var stageTotal: Int?
        public var eta: Int?
        public var resultUrl: String?
        public var errorMessage: String?

        public init(
            progress: Int,
            status: String,
            message: String? = nil,
            stageName: String? = nil,
            stageIndex: Int? = nil,
            stageTotal: Int? = nil,
            eta: Int? = nil,
            resultUrl: String? = nil,
            errorMessage: String? = nil
        ) {
            self.progress = progress
            self.status = status
            self.message = message
            self.stageName = stageName
            self.stageIndex = stageIndex
            self.stageTotal = stageTotal
            self.eta = eta
            self.resultUrl = resultUrl
            self.errorMessage = errorMessage
        }
    }

    public var jobId: String
    public var title: String
    public var jobType: String

    public init(jobId: String, title: String, jobType: String) {
        self.jobId = jobId
        self.title = title
        self.jobType = jobType
    }
}
