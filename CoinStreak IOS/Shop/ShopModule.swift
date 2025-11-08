import SwiftUI
import UIKit


private final class TableThumbCache {
    static let shared = NSCache<NSString, UIImage>()
}

private extension UIImage {
    /// Crop the **bottom** `heightPx` pixels (no scaling). Returns a new UIImage.
    func cropBottom(heightPx: Int) -> UIImage? {
        guard let cg = self.cgImage else { return nil }
        let h = max(0, min(heightPx, cg.height))
        let rect = CGRect(x: 0, y: cg.height - h, width: cg.width, height: h) // CGImage uses pixel coords
        guard let sub = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: sub, scale: self.scale, orientation: self.imageOrientation)
    }
}

private extension UIImage {
    /// Crop to the tightest rect containing non-transparent pixels (with optional padding).
    func cropAlphaTight(paddingPx: Int = 0, alphaThreshold: UInt8 = 5) -> UIImage? {
        guard let cg = self.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let bpp = 4, bpr = bpp * w, bpc = 8

        var raw = [UInt8](repeating: 0, count: Int(h * bpr))
        guard let ctx = CGContext(
            data: &raw, width: w, height: h, bitsPerComponent: bpc, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * bpr
            for x in 0..<w {
                let i = row + x * bpp
                if raw[i+3] > alphaThreshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        if maxX < 0 { return nil } // fully transparent

        let pad = max(0, paddingPx)
        let cx = max(0, minX - pad)
        let cy = max(0, minY - pad)
        let cw = min(w - cx, (maxX - minX + 1) + pad*2)
        let ch = min(h - cy, (maxY - minY + 1) + pad*2)

        guard let sub = cg.cropping(to: CGRect(x: cx, y: cy, width: cw, height: ch)) else { return nil }
        return UIImage(cgImage: sub, scale: self.scale, orientation: self.imageOrientation)
    }
}

final class ShopVM: ObservableObject {
    @Published var selectedCategory: ShopCategory = .coins

    // 2-second buy confirmation state
    @Published var confirmingItemId: String? = nil

    // Owned IDs and per-category equip state
    @Published private(set) var owned: Set<String> = []
    @Published private(set) var equipped: [ShopCategory : String] = [:]

    private let ownedKey = "shop.owned.v1"
    private let equippedKey = "shop.equipped.v1"

    init() { load() }

    // MARK: Persistence
    private func load() {
        let d = UserDefaults.standard
        if let arr = d.array(forKey: ownedKey) as? [String] {
            owned = Set(arr)
        }
        if let dict = d.dictionary(forKey: equippedKey) as? [String:String] {
            var map: [ShopCategory:String] = [:]
            for (k,v) in dict { if let c = ShopCategory(rawValue: k) { map[c] = v } }
            equipped = map
        }
        // Ensure starter table is owned & equipped by default
        if !owned.contains("starter") {
            owned.insert("starter")
        }
        if equipped[.tables] == nil {
            equipped[.tables] = "starter"
        }
        if equipped[.coins]  == nil { equipped[.coins]  = "starter" }
        save()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(Array(owned), forKey: ownedKey)
        var dict: [String:String] = [:]
        for (k,v) in equipped { dict[k.rawValue] = v }
        d.set(dict, forKey: equippedKey)
    }

    // MARK: Queries
    func isOwned(_ id: String) -> Bool { owned.contains(id) }
    func isEquipped(_ id: String, in cat: ShopCategory) -> Bool { equipped[cat] == id }

    // MARK: Confirm flow
    func beginConfirm(for id: String, affordable: Bool) {
        guard affordable else { return }
        confirmingItemId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            if self.confirmingItemId == id { self.confirmingItemId = nil }
        }
    }
    func cancelConfirm() { confirmingItemId = nil }

    // MARK: Purchase & Equip
    @discardableResult
    func purchase(_ item: ShopItem, tokenBalance: inout Int) -> Bool {
        guard !owned.contains(item.id), tokenBalance >= item.price else { return false }
        tokenBalance -= item.price
        owned.insert(item.id)
        equipped[item.category] = item.id   // auto-equip after purchase
        save()
        return true
    }

    func equip(_ item: ShopItem) {
        guard owned.contains(item.id) else { return }
        equipped[item.category] = item.id
        save()
    }
}

enum ShopCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case coins = "Coins"
    case tables = "Tables"
    var id: String { rawValue }
}

// MARK: - Catalog

struct ShopItem: Identifiable, Hashable, Codable {
    let id: String
    let category: ShopCategory
    let title: String
    let price: Int
    let symbolName: String   // placeholder SFSymbol for now
}

enum ShopCatalog {
    static func items(for category: ShopCategory) -> [ShopItem] {
        switch category {
        case .coins:
            return [
                .init(id: "starter", category: .coins, title: "Starter", price: 0,   symbolName: "circle"),
                .init(id: "silver",    category: .coins, title: "Silver",    price: 50, symbolName: "circle.fill"),
                .init(id: "voxel",    category: .coins, title: "Voxel",    price: 50, symbolName: "circle.fill"),
                .init(id: "chip",    category: .coins, title: "Chip",    price: 600, symbolName: "circle.fill"),
                .init(id: "vinyl",    category: .coins, title: "Vinyl",    price: 50, symbolName: "circle.fill"),
                .init(id: "cap",    category: .coins, title: "Cap",    price: 50, symbolName: "circle.fill"),
            ]
        case .tables:
            return [
                .init(id: "starter",    category: .tables, title: "Starter",    price: 0,   symbolName: "rectangle.dashed"),
                .init(id: "woodcrate",  category: .tables, title: "Wood Crate", price: 600, symbolName: "shippingbox"),
                .init(id: "team",  category: .tables, title: "Team", price: 50, symbolName: "shippingbox"),
                .init(id: "bamboo",  category: .tables, title: "Bamboo", price: 50, symbolName: "shippingbox"),
                .init(id: "purple",     category: .tables, title: "Purple",     price: 650, symbolName: "rectangle.fill"),
                .init(id: "picnic",     category: .tables, title: "Picnic",     price: 700, symbolName: "checkerboard.rectangle"),
                .init(id: "disco",      category: .tables, title: "Disco",      price: 900, symbolName: "sparkles.rectangle.stack"),
                .init(id: "blue",       category: .tables, title: "Blue",       price: 650, symbolName: "rectangle.portrait"),
                .init(id: "blackjack",  category: .tables, title: "Blackjack",  price: 1000, symbolName: "suit.club.fill")
            ]
        }
    }
}

private struct TableSpriteThumbCropped: View {
    let imageName: String              // e.g. "woodcrate_table_h"
    var targetWidth: CGFloat = 140
    
    var shadowRadius: CGFloat = 8
    var shadowOpacity: Double = 0.25
    var shadowYOffset: CGFloat = 2
    
    private let output: UIImage?

    init(imageName: String, targetWidth: CGFloat = 140) {
        self.imageName   = imageName
        self.targetWidth = targetWidth

        if let cached = TableThumbCache.shared.object(forKey: imageName as NSString) {
            self.output = cached
        } else if let src = UIImage(named: imageName),
                  let cropped = src.cropBottom(heightPx: 1025) {   // ⟵ exact table height
            TableThumbCache.shared.setObject(cropped, forKey: imageName as NSString)
            self.output = cropped
        } else {
            self.output = nil
        }
    }

    var body: some View {
        Group {
            if let ui = output {
                Image(uiImage: ui)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: targetWidth)
                    .clipped()
                    .compositingGroup()
                    .shadow(color: .black.opacity(shadowOpacity),
                                               radius: shadowRadius, x: 0, y: shadowYOffset)
            } else {
                // Fallback: show original (uncropped) if something went wrong
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: targetWidth)
                    .clipped()
                    .compositingGroup()
                    .shadow(color: .black.opacity(shadowOpacity),
                                               radius: shadowRadius, x: 0, y: shadowYOffset)
            }
        }
        //.clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CoinThumbCropped: View {
    let imageName: String
    var targetWidth: CGFloat = 140
    var paddingPx: Int = 6

    var shadowRadius: CGFloat = 8
    var shadowOpacity: Double = 0.25
    var shadowYOffset: CGFloat = 2

    private let output: UIImage?

    init(imageName: String, targetWidth: CGFloat = 140, paddingPx: Int = 6) {
        self.imageName = imageName
        self.targetWidth = targetWidth
        self.paddingPx = paddingPx

        let cacheKey = "\(imageName)#tight#\(paddingPx)" as NSString
        if let cached = TableThumbCache.shared.object(forKey: cacheKey) {
            self.output = cached
        } else if let src = UIImage(named: imageName),
                  let cropped = src.cropAlphaTight(paddingPx: paddingPx) {
            TableThumbCache.shared.setObject(cropped, forKey: cacheKey)
            self.output = cropped
        } else {
            self.output = UIImage(named: imageName) // fallback
        }
    }

    var body: some View {
        Group {
            if let ui = output {
                Image(uiImage: ui)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: targetWidth)
                    .compositingGroup()
                    .shadow(color: .black.opacity(shadowOpacity),
                            radius: shadowRadius, x: 0, y: shadowYOffset)
            } else {
                Color.clear.frame(width: targetWidth, height: targetWidth)
            }
        }
    }
}


// MARK: - Item Cell

private struct ShopItemCell: View {
    let item: ShopItem
    let owned: Bool
    let equipped: Bool
    let confirming: Bool
    let onTap: () -> Void
    let onBuy: () -> Void
    
    let tableThumbName: String?
    let coinThumbName: String?

    var body: some View {
        let tile = ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(equipped ? Color.yellow.opacity(0.9) : Color.white.opacity(0.25),
                                lineWidth: equipped ? 3 : 1)
                )
                .shadow(color: equipped ? .yellow.opacity(0.55) : .black.opacity(0.25),
                        radius: equipped ? 10 : 4)

            VStack(spacing: 8) {
                if confirming && !owned {
                    Button(action: onBuy) {
                        Text("Buy")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.vertical, 6).padding(.horizontal, 16)
                            .background(Color.yellow.opacity(0.9))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                } else {
                    if let name = tableThumbName {
                        // Real table thumbnail (cropped to ignore alpha headroom)
                        TableSpriteThumbCropped(imageName: name, targetWidth: 140)
                    } else if let cName = coinThumbName {
                        // Crop away alpha so the coin fills the tile nicely
                        CoinThumbCropped(imageName: cName, targetWidth: 140, paddingPx: 6)
                    } else {
                        // Fallback icon
                        Image(systemName: item.symbolName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .foregroundStyle(.white)
                            .opacity(0.95)
                    }
                }

                if !owned {
                    HStack(spacing: 6) {
                        Text("\(item.price)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Image("tokens_icon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                    //.opacity(confirming ? 0 : 1)
                }
            }
            .padding(12)
            .padding(.top, 16)
        }
        .frame(width: 180, height: 185)

        return Button(action: onTap) { tile }
            .buttonStyle(.plain)
    }
}

/// All shop overlay UI lives here (wallet now; categories/items later)
struct ShopOverlay: View {
    @ObservedObject var vm: ShopVM
    @Binding var tokenBalance: Int
    let size: CGSize

    @Binding var equippedTableImage: String
    @Binding var equippedTableKey: String
    @Binding var equippedCoinKey: String
    let sideProvider: () -> String

    private var sx: CGFloat { max(1e-6, size.width / 1320.0) }
    private var sy: CGFloat { max(1e-6, size.height / 2868.0) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // CATEGORY at x:236 y:741, size: 860×150
            categoryStrip
                .frame(width: 860 * sx, height: 175 * sy)
                .position(x: (236 + 860/2) * sx, y: (848 + 150/2) * sy)

            // ITEM STRIP at x:248 y:962, size: 839×611
            itemStrip
                .frame(width: 839 * sx, height: 450 * sy)
                .position(x: (248 + 839/2) * sx, y: (1115 + 611/2) * sy)
            
            // --- Top-right anchored wallet: grows LEFT from rightPx ---
            let rightPx: CGFloat = 1085   // was ~835 left + ~440 width; tweak if you move it
            let topPx:   CGFloat = 1114

            wallet
                .frame(width: rightPx * sx,              // container width ends exactly at rightPx
                       height: 55 * sy,
                       alignment: .trailing)             // keep wallet hugged to the container’s right edge
                .offset(x: 0, y: topPx * sy)             // push down to topPx
        }
        .frame(width: size.width, height: size.height)
        //.contentShape(Rectangle())
        //.allowsHitTesting(false)   // don't block flips
        //.zIndex(75)
    }

    private var wallet: some View {
        HStack(spacing: 12 * sx) {
            /*Image("wallet_icon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 26, height: 26)
                .opacity(0.9)*/
            // Adaptive number
            Text(tokenBalance, format: .number.grouping(.automatic))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)   // shrink as needed (down to 60%)
                .allowsTightening(true)
                .layoutPriority(1)         // give the number room before icons truncate
            Image("tokens_icon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundColor(.yellow.opacity(0.9))
        }
        .padding(.horizontal, 26 * sx)
        .padding(.vertical, 12 * sy)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 6)
    }
    
    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 85 * sx) {
                ForEach(ShopCategory.allCases) { cat in
                    let selected = (vm.selectedCategory == cat)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.selectedCategory = cat
                        }
                    } label: {
                        ZStack {
                            Image(iconName(for: cat))
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 220 * sx, height: 220 * sy)
                                .compositingGroup()
                                // Base drop shadow for depth
                                .shadow(color: Color.black.opacity(0.28), radius: 6 * sx, x: 0, y: 2 * sy)
                                // Selection glow that conforms to the image’s alpha (no container)
                                .shadow(color: Color.yellow.opacity(selected ? 0.85 : 0.0), radius: 10 * sx)
                                .shadow(color: Color.yellow.opacity(selected ? 0.55 : 0.0), radius: 18 * sx)
                                .accessibilityLabel(Text(cat.rawValue))
                        }
                        .frame(width: 160 * sx, height: 145 * sy)
                        .contentShape(Rectangle()) // generous tap target without a visible container
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 25)
            .padding(.horizontal, 14)
        }
    }
    
    // MARK: - Item Strip (x:248 y:962, size: 839×611)
    private var itemStrip: some View {
        let items = ShopCatalog.items(for: vm.selectedCategory)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14 * sx) {
                ForEach(items) { item in
                    let thumb: String? = {
                        if item.category == .tables {
                            let side = sideProvider() // "h" or "t"
                            return "\(item.id)_table_\(side)"
                        }
                        return nil
                    }()
                    let coinThumb: String? = {
                        if item.category == .coins {
                            let side = sideProvider() // "h" or "t"
                            let face = (side == "h") ? "H" : "T"
                            return "\(item.id)_coin_\(face)"
                        }
                        return nil
                    }()
                    ShopItemCell(
                        item: item,
                        owned: vm.isOwned(item.id),
                        equipped: vm.isEquipped(item.id, in: vm.selectedCategory),
                        confirming: vm.confirmingItemId == item.id,
                        onTap: {
                            if vm.isOwned(item.id) {
                                vm.equip(item)
                                if item.category == .tables {
                                    equippedTableKey = item.id
                                    let side = sideProvider()
                                    equippedTableImage = "\(item.id)_table_\(side)"
                                } else if item.category == .coins {
                                    equippedCoinKey = item.id
                                }
                            } else {
                                let affordable = (tokenBalance >= item.price)
                                if affordable {
                                    vm.beginConfirm(for: item.id, affordable: true)
                                } else {
                                    // TODO: deny haptic / sfx if desired
                                }
                            }
                        },
                        onBuy: {
                            if vm.purchase(item, tokenBalance: &tokenBalance) {
                                if item.category == .tables {
                                    equippedTableKey = item.id
                                    let side = sideProvider()
                                    equippedTableImage = "\(item.id)_table_\(side)"
                                } else if item.category == .coins {
                                    equippedCoinKey = item.id
                                }
                            }
                        },
                        tableThumbName: thumb,
                        coinThumbName: coinThumb
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

    // Helper to map ShopCategory to icon image name
    private func iconName(for cat: ShopCategory) -> String {
        switch cat {
        case .coins:  return "coins_icon"
        case .tables: return "tables_icon"
        }
    }
