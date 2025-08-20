import Foundation

enum TestVerdict: String, Equatable, Hashable, Codable {
    case none
    case passed
    case failed
}

struct TestCase: Identifiable, Hashable, Codable {
    let id: UUID = UUID()
    var input: String
    var expected: String
    var received: String
    var lastRunMs: Int? = nil
    var timedOut: Bool = false
    var verdict: TestVerdict = .none
}


