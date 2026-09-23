import Foundation
import Combine

/// Opens a library lecture from notifications or other entry points.
@MainActor
final class LibraryDeepLink: ObservableObject {
    static let shared = LibraryDeepLink()

    struct Target: Identifiable, Equatable {
        let seriesID: String
        let chapterID: String
        var id: String { "\(seriesID)/\(chapterID)" }
    }

    @Published var pending: Target?

    func open(seriesID: String, chapterID: String) {
        guard !seriesID.isEmpty, !chapterID.isEmpty else { return }
        pending = Target(seriesID: seriesID, chapterID: chapterID)
    }

    func open(userInfo: [AnyHashable: Any]) {
        guard (userInfo["deepLink"] as? String) == "series",
              let seriesID = userInfo["seriesID"] as? String,
              let chapterID = userInfo["chapterID"] as? String
        else { return }
        open(seriesID: seriesID, chapterID: chapterID)
    }

    func clear() {
        pending = nil
    }
}
