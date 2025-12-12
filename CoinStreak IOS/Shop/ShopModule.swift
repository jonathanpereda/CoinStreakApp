
import SwiftUI
import UIKit
import Foundation
// Remote shop price overrides with simple ETag caching.
// Reads/writes to UserDefaults and fetches from the backend on demand.
enum RemoteShop {
    private static let overridesKey = "shop.overrides.map.v1"
    private static let etagKey      = "shop.overrides.etag.v1"
    private static var loaded = false
    private static var store: [String:[String:Int]] = [:]  // e.g. ["tables": ["woodcrate": 900]]

    private static func loadFromDefaultsIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let data = UserDefaults.standard.data(forKey: overridesKey),
           let obj  = try? JSONSerialization.jsonObject(with: data) as? [String:[String:Int]] {
            store = obj
        }
    }

    static func price(for item: ShopItem) -> Int {
        loadFromDefaultsIfNeeded()
        let cat = (item.category == .coins) ? "coins" : "tables"
        if let v = store[cat]?[item.id] { return v }
        return item.price
    }

    @discardableResult
    static func fetchIfNeeded(force: Bool = false) async -> String {
        // Build URL from the same Worker base used elsewhere
        let url = ScoreboardAPI.base.appendingPathComponent("/v1/shop/catalog")
        var req = URLRequest(url: url)
        // Only attach If-None-Match when not forcing; forcing guarantees a 200 with fresh body
        if !force {
            if let et = UserDefaults.standard.string(forKey: etagKey), !et.isEmpty {
                req.addValue(et, forHTTPHeaderField: "If-None-Match")
            }
        }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                return UserDefaults.standard.string(forKey: etagKey) ?? ""
            }
            if http.statusCode == 304 {
                // Not modified
                return UserDefaults.standard.string(forKey: etagKey) ?? ""
            }
            if http.statusCode == 200 {
                // Parse: { version, updated_at, overrides: { coins:{...}, tables:{...} } }
                let obj = try JSONSerialization.jsonObject(with: data) as? [String:Any]
                let overridesObj = (obj?["overrides"] as? [String:Any]) ?? [:]
                var map: [String:[String:Int]] = [:]
                for (cat, v) in overridesObj {
                    if let dict = v as? [String:Any] {
                        var inner: [String:Int] = [:]
                        for (k, anyVal) in dict {
                            if let n = anyVal as? NSNumber { inner[k] = n.intValue }
                            else if let s = anyVal as? String, let n = Int(s) { inner[k] = n }
                        }
                        map[cat] = inner
                    }
                }
                store = map
                let etag = http.value(forHTTPHeaderField: "ETag") ?? (obj?["version"] as? String ?? "")
                if let dataToSave = try? JSONSerialization.data(withJSONObject: map) {
                    UserDefaults.standard.set(dataToSave, forKey: overridesKey)
                }
                UserDefaults.standard.set(etag, forKey: etagKey)
                return etag
            }
        } catch {
            // Ignore network errors; keep existing cache
        }
        return UserDefaults.standard.string(forKey: etagKey) ?? ""
    }
}


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
    private var confirmLockedPrice: [String:Int] = [:]

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
    func beginConfirm(for id: String, affordable: Bool, lockPrice: Int) {
        guard affordable else { return }
        confirmingItemId = id
        confirmLockedPrice[id] = lockPrice
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            if self.confirmingItemId == id {
                self.confirmingItemId = nil
                self.confirmLockedPrice.removeValue(forKey: id)
            }
        }
    }
    func cancelConfirm() {
        if let id = confirmingItemId {
            confirmLockedPrice.removeValue(forKey: id)
        }
        confirmingItemId = nil
    }

    // MARK: Purchase & Equip
    @discardableResult
    func purchase(_ item: ShopItem, tokenBalance: inout Int) -> Bool {
        let priceToCharge = confirmLockedPrice[item.id] ?? RemoteShop.price(for: item)
        guard !owned.contains(item.id), tokenBalance >= priceToCharge else { return false }
        tokenBalance -= priceToCharge
        owned.insert(item.id)
        equipped[item.category] = item.id   // auto-equip after purchase
        confirmingItemId = nil
        confirmLockedPrice.removeValue(forKey: item.id)
        save()
        return true
    }

    func equip(_ item: ShopItem) {
        // Any item that reaches here is considered legitimately owned:
        // either purchased with tokens or unlocked via a reward.
        owned.insert(item.id)
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

    /// Optional hint for items that are unlocked via minigames or other
    /// non-token mechanisms. When non-nil, the shop should treat this
    /// item as reward-only (not purchasable with tokens) and display
    /// this hint instead of a token price until unlocked.
    let unlockHint: String?

    /// Optional backend asset key used for reward-unlock mapping.
    /// When nil, we fall back to using `id` as the key.
    let assetKey: String?

    init(
        id: String,
        category: ShopCategory,
        title: String,
        price: Int,
        symbolName: String,
        unlockHint: String? = nil,
        assetKey: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.price = price
        self.symbolName = symbolName
        self.unlockHint = unlockHint
        self.assetKey = assetKey
    }
}

enum ShopCatalog {
    static func items(for category: ShopCategory) -> [ShopItem] {
        switch category {
        case .coins:
            return [
                .init(id: "starter", category: .coins, title: "Starter", price: 0,   symbolName: "circle",      unlockHint: nil),
                .init(id: "silver",  category: .coins, title: "Silver",  price: 650, symbolName: "circle.fill", unlockHint: nil),
                .init(id: "voxel",   category: .coins, title: "Voxel",   price: 700, symbolName: "circle.fill", unlockHint: nil),
                .init(id: "chip",    category: .coins, title: "Chip",    price: 1200,symbolName: "circle.fill", unlockHint: nil),
                .init(id: "vinyl",   category: .coins, title: "Vinyl",   price: 1450,symbolName: "circle.fill", unlockHint: nil),
                .init(id: "cap",     category: .coins, title: "Cap",     price: 1800,symbolName: "circle.fill", unlockHint: nil),

                // Reward-only coin unlocked via minigame rewards
                .init(
                    id: "callit",
                    category: .coins,
                    title: "Call It Coin",
                    price: 0,                  // ignored for reward-only items
                    symbolName: "circle.fill",
                    unlockHint: "Win 'Call It' minigame",
                    assetKey: "callit_coin"
                )
            ]
        case .tables:
            return [
                .init(id: "starter",   category: .tables, title: "Starter",   price: 0,    symbolName: "rectangle.dashed",   unlockHint: nil),
                .init(id: "blue",      category: .tables, title: "Blue",      price: 250,  symbolName: "rectangle.portrait", unlockHint: nil),
                .init(id: "orange",    category: .tables, title: "Orange",    price: 250,  symbolName: "rectangle.fill",     unlockHint: nil),
                .init(id: "purple",    category: .tables, title: "Purple",    price: 300,  symbolName: "rectangle.fill",     unlockHint: nil),
                .init(id: "team",      category: .tables, title: "Team",      price: 400,  symbolName: "shippingbox",        unlockHint: nil),
                .init(id: "picnic",    category: .tables, title: "Picnic",    price: 500,  symbolName: "checkerboard.rectangle", unlockHint: nil),
                .init(id: "rug",       category: .tables, title: "Rug",       price: 500,  symbolName: "checkerboard.rectangle", unlockHint: nil),
                .init(id: "bamboo",    category: .tables, title: "Bamboo",    price: 500,  symbolName: "shippingbox",        unlockHint: nil),
                .init(id: "disco",     category: .tables, title: "Disco",     price: 650,  symbolName: "sparkles.rectangle.stack", unlockHint: nil),
                .init(id: "tile",      category: .tables, title: "Tile",      price: 700,  symbolName: "rectangle.fill",     unlockHint: nil),
                .init(id: "woodcrate", category: .tables, title: "Wood Crate",price: 900,  symbolName: "shippingbox",        unlockHint: nil),
                .init(id: "road",      category: .tables, title: "Road",      price: 1000, symbolName: "rectangle.fill",     unlockHint: nil),
                .init(id: "blackjack", category: .tables, title: "Blackjack", price: 1000, symbolName: "suit.club.fill",     unlockHint: nil),

                // Reward-only table unlocked via minigame rewards
                .init(
                    id: "callit",
                    category: .tables,
                    title: "Call It Table",
                    price: 0,                  // ignored for reward-only items
                    symbolName: "shippingbox",
                    unlockHint: "Win 'Call It' minigame",
                    assetKey: "callit_table"
                )
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
    let displayPrice: Int
    let onTap: () -> Void
    let onBuy: () -> Void

    let tableThumbName: String?
    let coinThumbName: String?
    let unlockHint: String?

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
                    if let hint = unlockHint {
                        // Reward-only item that hasn't been unlocked yet:
                        // show the hint instead of a token price.
                        Text(hint)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 4)
                    } else {
                        HStack(spacing: 6) {
                            Text("\(displayPrice)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            Image("tokens_icon")
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    }
                }
            }
            .padding(12)
            .padding(.top, 16)
        }
        .frame(width: 176, height: 185)

        return Button(action: onTap) { tile }
            .buttonStyle(.plain)
    }
}

/// All shop overlay UI lives here (wallet now; categories/items later)
struct ShopOverlay: View {
    @ObservedObject var vm: ShopVM
    @ObservedObject var stats: StatsStore
    @Binding var tokenBalance: Int
    let size: CGSize

    @Binding var equippedTableImage: String
    @Binding var equippedTableKey: String
    @Binding var equippedCoinKey: String
    let sideProvider: () -> String
    @ObservedObject var unlocks: ShopUnlocksStore
    @State private var overridesVersion: String = ""

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
                .position(x: (248 + 839/2) * sx, y: (1120 + 611/2) * sy)
            
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
        .task {
            // Fetch remote price overrides and trigger a refresh when ETag changes
            overridesVersion = await RemoteShop.fetchIfNeeded()
        }
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
                    // Reward-only items are identified by a non-nil unlockHint.
                    let isRewardUnlockable = (item.unlockHint != nil)

                    // Prefer explicit backend assetKey when present; fall back to id.
                    let assetKey = item.assetKey ?? item.id

                    // If the backend has marked this assetKey as unlocked, treat it as owned
                    // even if it was never purchased with tokens.
                    let isUnlockedViaReward = isRewardUnlockable && unlocks.isUnlocked(assetKey)

                    // Unified ownership flag for UI purposes.
                    let ownedForUI = vm.isOwned(item.id) || isUnlockedViaReward

                    let displayPrice = RemoteShop.price(for: item)
                    ShopItemCell(
                        item: item,
                        owned: ownedForUI,
                        equipped: vm.isEquipped(item.id, in: vm.selectedCategory),
                        confirming: vm.confirmingItemId == item.id,
                        displayPrice: displayPrice,
                        onTap: {
                            if ownedForUI {
                                // Already owned (either purchased or unlocked via rewards): equip it.
                                vm.equip(item)
                                if item.category == .tables {
                                    equippedTableKey = item.id
                                    let side = sideProvider()
                                    equippedTableImage = "\(item.id)_table_\(side)"
                                } else if item.category == .coins {
                                    equippedCoinKey = item.id
                                }
                            } else {
                                // Not owned yet.
                                if isRewardUnlockable {
                                    // Reward-only item that hasn't been unlocked yet:
                                    // can't buy with tokens, just give a gentle denial haptic.
                                    Haptics.shared.deny()
                                } else {
                                    // Normal token-purchasable item.
                                    let affordable = (tokenBalance >= displayPrice)
                                    if affordable {
                                        vm.beginConfirm(for: item.id, affordable: true, lockPrice: displayPrice)
                                    } else {
                                        Haptics.shared.deny()
                                    }
                                }
                            }
                        },
                        onBuy: {
                            if vm.purchase(item, tokenBalance: &tokenBalance) {
                                // Track tokens spent for stats
                                stats.addTokensSpent(displayPrice)
                                SoundManager.shared.play("spend_token")
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
                        coinThumbName: coinThumb,
                        unlockHint: (ownedForUI ? nil : item.unlockHint)
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
