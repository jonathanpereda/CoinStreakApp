import Foundation
import Combine

final class LeaderboardVM: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id: String          // installId
        let name: String        // displayName from API
        let streak: Int
    }

    @Published var headsTop: [Entry] = []
    @Published var tailsTop: [Entry] = []
    @Published var isLoading = false

    @MainActor
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        async let h = ScoreboardAPI.fetchLeaderboard(side: "H", limit: 5)
        async let t = ScoreboardAPI.fetchLeaderboard(side: "T", limit: 5)
        let (heads, tails) = await (h, t)

        // NOTE: ScoreboardAPI.fetchLeaderboard returns a DTO where
        // entries have: installId, displayName, streak
        self.headsTop = heads.map { Entry(id: $0.installId, name: $0.displayName, streak: $0.currentStreak) }
        self.tailsTop = tails.map { Entry(id: $0.installId, name: $0.displayName, streak: $0.currentStreak) }
    }
}



//***************IM PRETTY SURE THIS IS DEPRICATED AND CAN BE DELETED BUT IM SCARED********************
//***************THERES NO REFRENCE TO IT IN ANY FILE
