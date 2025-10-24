import Foundation

extension Face {
    var apiCode: String {
        switch self { case .Heads: return "H"; case .Tails: return "T" }
    }
}
