import SwiftUI
import Combine
import UIKit

@main
struct AzuraStoreApp: App {
    @StateObject private var store = ShopStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onOpenURL { store.handle(url: $0) }
        }
    }
}

final class ShopStore: ObservableObject {
    @Published var phase: Phase = .connecting
    @Published var storeURL: String = ""
    @Published var storeName: String = "Azura Store"
    @Published var logoURL: String?
    @Published var liveCount: Int = 0
    @Published var categories: [Category] = []
    @Published var featured: [Product] = []
    @Published var bestsellers: [Product] = []
    @Published var searchResults: [Product] = []
    @Published var cart: CartPayload = CartPayload()
    @Published var user: User?
    @Published var product: Product?
    @Published var related: [Product] = []
    @Published var zones: [Zone] = []
    @Published var orders: [Order] = []
    @Published var order: Order?
    @Published var loading = false
    @Published var error: String?
    @Published var snack: String?
    @Published var setupDraft: String = ""
    @Published var paid = false
    @Published var paymentURL: String?
    @Published var payMessage: String?
    @Published var sellerApproved = false
    @Published var sellerProfile: SellerProfile?
    @Published var sellerOrders: [Order] = []
    @Published var sellerProducts: [Product] = []
    @Published var earnings: EarningsTotals = EarningsTotals()
    @Published var earningRows: [EarningRow] = []
    @Published var tracked: Order?

    var isSeller: Bool { user?.role == "seller" }

    private let defaults = UserDefaults.standard
    private let defaultStore = "https://azuramall.shop/"
    private var cartToken: String {
        if let saved = defaults.string(forKey: "cart_token"), saved.count == 32 { return saved }
        let fresh = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        defaults.set(fresh, forKey: "cart_token")
        return fresh
    }
    private var token: String { defaults.string(forKey: "api_token") ?? "" }

    enum Phase { case connecting, setup, shop }

    init() {
        storeURL = defaults.string(forKey: "store_url") ?? defaultStore
        setupDraft = storeURL
        if let raw = defaults.string(forKey: "user_json"),
           let data = raw.data(using: .utf8) {
            user = try? JSONDecoder().decode(User.self, from: data)
        }
        Task { await boot() }
    }

    func handle(url: URL) {
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "url" })?.value
            ?? origin(from: url)
        if let value { save(url: value) }
        Task { await boot() }
    }

    @MainActor
    func boot() async {
        phase = .connecting
        var candidates: [String] = []
        if !storeURL.isEmpty { candidates.append(storeURL) }
        if let clip = UIPasteboard.general.string, looksLikeURL(clip) { candidates.append(clip) }
        for raw in candidates {
            if let live = await ping(raw) {
                save(url: live)
                phase = .shop
                await loadHome()
                return
            }
        }
        phase = storeURL.isEmpty ? .setup : .shop
        if phase == .shop { await loadHome() }
    }

    @MainActor
    func connect(to raw: String) async {
        loading = true
        defer { loading = false }
        guard let live = await ping(raw) else {
            error = "Could not reach that store address."
            return
        }
        save(url: live)
        phase = .shop
        await loadHome()
    }

    @MainActor
    func loadHome() async {
        loading = true
        defer { loading = false }
        do {
            let json = try await get("home")
            storeName = json["store_name"] as? String ?? storeName
            logoURL = json["logo_url"] as? String
            liveCount = json["live_count"] as? Int ?? 0
            categories = decodeList(json["categories"])
            featured = decodeList(json["featured"])
            bestsellers = decodeList(json["bestsellers"])
            applyCart(json)
            applyUser(json)
            if isSeller { await loadSellerMe() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func search(_ q: String, category: String = "") async {
        loading = true
        defer { loading = false }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        var path = "products?q=\(encoded)"
        if !category.isEmpty {
            path += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)"
        }
        do {
            let json = try await get(path)
            searchResults = decodeList(json["products"])
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func loadProduct(_ slug: String) async {
        loading = true
        defer { loading = false }
        do {
            let json = try await get("products/\(slug)")
            product = decode(json["product"])
            related = decodeList(json["related"])
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func addToCart(productId: Int, qty: Int = 1, variantId: Int? = nil) async {
        do {
            var body: [String: Any] = ["product_id": productId, "quantity": qty]
            if let variantId { body["variant_id"] = variantId }
            applyCart(try await post("cart/add", body))
            snack = "Added to cart"
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func loadCart() async {
        do { applyCart(try await get("cart")) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func setQty(id: Int, qty: Int) async {
        do { applyCart(try await post("cart/update", ["id": id, "quantity": qty])) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func removeItem(id: Int) async {
        do { applyCart(try await post("cart/remove", ["id": id])) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    @discardableResult
    func login(login: String, password: String) async -> Bool {
        do {
            let json = try await post("auth/login", ["login": login, "password": password])
            saveSession(json)
            applyCart(json)
            applyUser(json)
            if isSeller { await loadSellerMe() }
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @MainActor
    @discardableResult
    func register(first: String, last: String, username: String, email: String, phone: String, password: String) async -> Bool {
        do {
            let json = try await post("auth/register", [
                "first_name": first, "last_name": last, "username": username,
                "email": email, "phone": phone, "password": password,
            ])
            saveSession(json)
            applyCart(json)
            applyUser(json)
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @MainActor
    @discardableResult
    func requestReset(login: String) async -> Bool {
        do {
            _ = try await post("auth/forgot", ["login": login])
            error = nil
            snack = "OTP sent"
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @MainActor
    @discardableResult
    func applyReset(code: String, password: String) async -> Bool {
        do {
            _ = try await post("auth/reset", ["code": code, "password": password])
            error = nil
            snack = "Password updated"
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    @MainActor
    func logout() async {
        _ = try? await post("auth/logout", [:])
        defaults.removeObject(forKey: "api_token")
        defaults.removeObject(forKey: "user_json")
        user = nil
        sellerProfile = nil
        sellerApproved = false
        sellerOrders = []
        await loadCart()
    }

    @MainActor
    func track(number: String, code: String, phone: String) async {
        do {
            tracked = decode((try await post("track", [
                "order_number": number,
                "delivery_code": code,
                "delivery_phone": phone,
            ]))["order"])
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func loadSellerMe() async {
        do {
            let json = try await get("seller/me")
            applyUser(json)
            sellerApproved = json["approved"] as? Bool ?? false
            sellerProfile = decode(json["profile"])
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func loadSellerOrders() async {
        do { sellerOrders = decodeList((try await get("seller/orders"))["orders"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func loadSellerOrder(_ id: Int) async {
        do { order = decode((try await get("seller/orders/\(id)"))["order"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func verifySellerPay(_ id: Int) async {
        do {
            let json = try await post("seller/orders/\(id)/verify-pay", [:])
            paid = json["paid"] as? Bool ?? false
            payMessage = json["message"] as? String
            order = decode(json["order"])
            await loadSellerOrders()
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func markPreparing(_ id: Int) async {
        do {
            order = decode((try await post("seller/orders/\(id)/status", ["status": "preparing"]))["order"])
            await loadSellerOrders()
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func loadSellerProducts() async {
        do { sellerProducts = decodeList((try await get("seller/products"))["products"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func loadEarnings() async {
        do {
            let json = try await get("seller/earnings")
            earnings = decode(json["totals"]) ?? EarningsTotals()
            earningRows = decodeList(json["rows"])
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func loadZones() async {
        do { zones = decodeList((try await get("zones"))["zones"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func checkout(zoneId: Int, address: String, phone: String) async -> Int? {
        do {
            let json = try await post("checkout", [
                "delivery_zone_id": zoneId,
                "delivery_address": address,
                "delivery_phone": phone,
            ])
            let created: Order? = decode(json["order"])
            await loadCart()
            return created?.id
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func loadOrders() async {
        do { orders = decodeList((try await get("orders"))["orders"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func loadOrder(_ id: Int) async {
        do { order = decode((try await get("orders/\(id)"))["order"]) } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func pay(id: Int, phone: String, pin: String) async {
        do {
            var body: [String: Any] = ["phone": phone]
            if !pin.isEmpty { body["pin"] = pin }
            let json = try await post("orders/\(id)/pay", body)
            paid = json["paid"] as? Bool ?? false
            paymentURL = json["payment_url"] as? String
            payMessage = json["message"] as? String
            order = decode(json["order"])
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    func checkPay(id: Int) async {
        do {
            let json = try await get("orders/\(id)/pay-status")
            paid = json["paid"] as? Bool ?? false
            payMessage = json["message"] as? String
            order = decode(json["order"])
        } catch { self.error = error.localizedDescription }
    }

    private func save(url: String) {
        let normalized = Self.normalize(url)
        storeURL = normalized
        setupDraft = normalized
        defaults.set(normalized, forKey: "store_url")
    }

    private func saveSession(_ json: [String: Any]) {
        if let token = json["token"] as? String { defaults.set(token, forKey: "api_token") }
    }

    private func applyUser(_ json: [String: Any]) {
        if let user: User = decode(json["user"]) {
            self.user = user
            if let data = try? JSONEncoder().encode(user), let raw = String(data: data, encoding: .utf8) {
                defaults.set(raw, forKey: "user_json")
            }
        }
    }

    private func applyCart(_ json: [String: Any]) {
        let node = json["items"] != nil ? json : (json["cart"] as? [String: Any] ?? json)
        if let cart: CartPayload = decode(node as Any) { self.cart = cart }
    }

    private func ping(_ raw: String) async -> String? {
        let base = Self.normalize(raw)
        guard let url = URL(string: base + "api/bootstrap") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("AzuraApp/1.1 iOS", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool != false else { return nil }
            if let live = json["store_url"] as? String, !live.isEmpty { return Self.normalize(live) }
            return base
        } catch {
            return nil
        }
    }

    private func get(_ path: String) async throws -> [String: Any] { try await request("GET", path, nil) }
    private func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] { try await request("POST", path, body) }

    private func request(_ method: String, _ path: String, _ body: [String: Any]?) async throws -> [String: Any] {
        let url = URL(string: storeURL + "api/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("AzuraApp/1.1 iOS", forHTTPHeaderField: "User-Agent")
        req.setValue(cartToken, forHTTPHeaderField: "X-Cart-Token")
        req.setValue(Locale.current.language.languageCode?.identifier == "sw" ? "sw" : "en", forHTTPHeaderField: "X-Locale")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if method != "GET" {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body ?? [:])
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code >= 400 || json["ok"] as? Bool == false {
            throw NSError(domain: "Azura", code: code, userInfo: [NSLocalizedDescriptionKey: json["error"] as? String ?? "Request failed"])
        }
        return json
    }

    private func decode<T: Decodable>(_ any: Any?) -> T? {
        guard let any, JSONSerialization.isValidJSONObject(any) || any is [String: Any] || any is [Any] else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private func decodeList<T: Decodable>(_ any: Any?) -> [T] { decode(any) ?? [] }

    private func looksLikeURL(_ raw: String) -> Bool {
        raw.hasPrefix("http://") || raw.hasPrefix("https://") || raw.hasPrefix("azura://")
    }
    private func origin(from url: URL) -> String {
        "\(url.scheme ?? "https")://\(url.host ?? "")/"
    }
    static func normalize(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("azura://"), let parsed = URL(string: url),
           let nested = URLComponents(url: parsed, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "url" })?.value {
            url = nested
        }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://\(url)" }
        if !url.hasSuffix("/") { url += "/" }
        return url
    }
}

struct User: Codable, Identifiable {
    var id: Int = 0
    var username: String?
    var name: String?
    var email: String?
    var phone: String?
    var role: String?
}
struct SellerProfile: Codable {
    var business_name: String?
    var address: String?
    var location: String?
    var badge: String?
    var verification_status: String?
}
struct Category: Codable, Identifiable { var id: Int = 0; var name: String?; var slug: String? }
struct ProductVariant: Codable, Identifiable {
    var id: Int = 0
    var name: String?
    var hex: String?
    var stock: Int = 0
}
struct Product: Codable, Identifiable {
    var id: Int = 0
    var title: String?
    var slug: String?
    var price_label: String?
    var compare_label: String?
    var discount_percent: Int?
    var stock: Int = 0
    var image: String?
    var seller_name: String?
    var description: String?
    var images: [String]?
    var variants: [ProductVariant]?
    var status: String?
}
struct CartItem: Codable, Identifiable {
    var id: Int = 0
    var product_id: Int = 0
    var title: String?
    var slug: String?
    var quantity: Int = 0
    var image: String?
    var line_label: String?
}
struct CartPayload: Codable {
    var items: [CartItem] = []
    var count: Int = 0
    var subtotal_label: String?
}
struct Zone: Codable, Identifiable {
    var id: Int = 0
    var name: String?
    var fee_label: String?
}
struct OrderItem: Codable {
    var title: String?
    var quantity: Int = 0
    var price_label: String?
    var seller_label: String?
}
struct Order: Codable, Identifiable {
    var id: Int = 0
    var order_number: String?
    var status: String?
    var payment_status: String?
    var total_label: String?
    var seller_label: String?
    var title: String?
    var customer_name: String?
    var delivery_code: String?
    var delivery_address: String?
    var delivery_phone: String?
    var items: [OrderItem]?
}
struct EarningsTotals: Codable {
    var seller_label: String?
    var commission_label: String?
}
struct EarningRow: Codable, Identifiable {
    var id: Int = 0
    var order_number: String?
    var title: String?
    var seller_label: String?
    var status: String?
}
