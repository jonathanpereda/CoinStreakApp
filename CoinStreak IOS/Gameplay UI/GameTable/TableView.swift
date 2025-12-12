import SwiftUI

struct TableView: View {
    let sideLetter: String
    let equippedTableImage: String
    let screenSize: CGSize

    private var baseTableImageName: String {
        if equippedTableImage.isEmpty {
            return "starter_table_\(sideLetter)"
        } else {
            return equippedTableImage
        }
    }

    private var isCallItTable: Bool {
        baseTableImageName.hasPrefix("callit_table")
    }

    var body: some View {
        ZStack {
            // Base table image: for Call It, use the special "_p" variant; otherwise use the resolved image name
            if isCallItTable {
                Image("callit_table_p")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                Image(baseTableImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            }

            // Special Call It table overlay: floating card in the bottom-right
            if isCallItTable {
                CallItTableCardOverlay(sideLetter: sideLetter, screenSize: screenSize)
            }
        }
    }
}
