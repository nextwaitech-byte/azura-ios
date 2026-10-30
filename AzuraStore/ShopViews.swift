import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        Group {
            switch store.phase {
            case .connecting:
                SplashView()
            case .setup:
                SetupView()
            case .shop:
                TabView {
                    if store.isSeller {
                        SellerOrdersView().tabItem { Label("Shop orders", systemImage: "receipt") }
                        if store.sellerApproved {
                            SellerProductsView().tabItem { Label("Products", systemImage: "cube.box") }
                            SellerEarningsView().tabItem { Label("Earnings", systemImage: "banknote") }
                        }
                        AccountView().tabItem { Label("Me", systemImage: "person") }
                    } else {
                        HomeView().tabItem { Label("Home", systemImage: "house") }
                        SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }
                        CartView().tabItem { Label("Cart", systemImage: "bag") }
                        AccountView().tabItem { Label("Me", systemImage: "person") }
                    }
                }
                .tint(Color(red: 0.49, green: 0.23, blue: 0.93))
            }
        }
        .preferredColorScheme(.light)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.02, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("A")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(LinearGradient(colors: [Color(red: 0.3, green: 0.11, blue: 0.58), Color(red: 0.85, green: 0.27, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Azura Store").font(.largeTitle.bold()).foregroundStyle(.white)
                Text("Connecting to this store…").foregroundStyle(Color(red: 0.77, green: 0.71, blue: 0.99))
            }
        }
    }
}

struct SetupView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connect to your store").font(.title.bold())
                Text("Paste the address from the Get Azura app page if the app did not pick it up automatically.")
                    .foregroundStyle(.secondary)
                TextField("https://your-azura-domain/", text: $store.setupDraft)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(red: 0.96, green: 0.93, blue: 0.99))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Open Azura") {
                    Task { await store.connect(to: store.setupDraft) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.loading)
                if let error = store.error { Text(error).foregroundStyle(.red) }
                Spacer()
            }
            .padding(24)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    categoryRow
                    if !store.bestsellers.isEmpty {
                        Text("Best sellers").font(.title3.bold())
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.bestsellers) { item in
                                    NavigationLink(value: item.slug ?? "") { ProductCard(product: item).frame(width: 168) }
                                }
                            }
                        }
                    }
                    Text("Featured").font(.title3.bold())
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.featured) { item in
                            NavigationLink(value: item.slug ?? "") { ProductCard(product: item) }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.96, green: 0.93, blue: 0.99))
            .navigationDestination(for: String.self) { slug in
                ProductView(slug: slug)
            }
            .task { await store.loadHome() }
            .navigationTitle(store.storeName)
        }
    }

    private var hero: some View {
        HStack(spacing: 12) {
            if let logo = store.logoURL, let url = URL(string: logo) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.white.opacity(0.2) }
                    .frame(width: 52, height: 52).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(store.storeName).font(.caption).foregroundStyle(.white.opacity(0.85))
                Text("Marketplace ya Tanzania").font(.title3.bold()).foregroundStyle(.white)
                Text("Verified sellers · Selcom Pay · Delivery in Dar").font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.3, green: 0.11, blue: 0.58), Color(red: 0.85, green: 0.27, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(store.categories) { cat in
                    NavigationLink(cat.name ?? "") { SearchView(initialCategory: cat.slug ?? "") }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var store: ShopStore
    var initialCategory: String = ""
    @State private var q = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search products…", text: $q)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .onSubmit { Task { await store.search(q, category: initialCategory) } }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.searchResults) { item in
                            NavigationLink(value: item.slug ?? "") { ProductCard(product: item) }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(red: 0.96, green: 0.93, blue: 0.99))
            .navigationTitle("Search")
            .navigationDestination(for: String.self) { ProductView(slug: $0) }
            .task { await store.search(q, category: initialCategory) }
        }
    }
}

struct ProductView: View {
    let slug: String
    @EnvironmentObject var store: ShopStore
    @State private var qty = 1
    @State private var variantId: Int?

    var body: some View {
        ScrollView {
            if let product = store.product {
                VStack(alignment: .leading, spacing: 12) {
                    if let src = (product.images?.first ?? product.image), let url = URL(string: src) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color(red: 0.96, green: 0.93, blue: 0.99) }
                            .frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    Text(product.title ?? "").font(.title2.bold())
                    Text(product.price_label ?? "").font(.title3.bold()).foregroundStyle(Color(red: 0.49, green: 0.23, blue: 0.93))
                    Text(product.seller_name ?? "").foregroundStyle(.secondary)
                    Text(product.description ?? "")
                    if let variants = product.variants, !variants.isEmpty {
                        Text("Color").font(.subheadline.bold())
                        Picker("Color", selection: Binding(get: { variantId ?? variants.first?.id ?? 0 }, set: { variantId = $0 })) {
                            ForEach(variants) { v in Text(v.name ?? "Color").tag(v.id) }
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack {
                        Stepper("Qty \(qty)", value: $qty, in: 1...max(1, product.stock == 0 ? 99 : product.stock))
                        Button("Add to cart") {
                            Task { await store.addToCart(productId: product.id, qty: qty, variantId: variantId) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            } else if store.loading {
                ProgressView().padding(40)
            }
        }
        .task { await store.loadProduct(slug) }
        .navigationTitle("Product")
    }
}

struct ProductCard: View {
    let product: Product
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if let src = product.image, let url = URL(string: src) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color(red: 0.96, green: 0.93, blue: 0.99) }
                        .frame(height: 140).clipped()
                }
                if let off = product.discount_percent, off > 0 {
                    Text("-\(off)%")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.pink).clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
            Text(product.title ?? "").font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(product.price_label ?? "").font(.subheadline.bold()).foregroundStyle(Color(red: 0.49, green: 0.23, blue: 0.93))
            Text(product.seller_name ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct CartView: View {
    @EnvironmentObject var store: ShopStore
    @State private var address = ""
    @State private var phone = ""
    @State private var zoneId: Int?
    @State private var paying: Int?

    var body: some View {
        NavigationStack {
            List {
                if store.cart.items.isEmpty {
                    Text("Your cart is empty").foregroundStyle(.secondary)
                } else {
                    ForEach(store.cart.items) { item in
                        HStack {
                            Text(item.title ?? "")
                            Spacer()
                            Text(item.line_label ?? "")
                        }
                    }
                    Text(store.cart.subtotal_label ?? "")
                    TextField("Delivery address", text: $address)
                    TextField("Phone", text: $phone)
                    Picker("Zone", selection: Binding(get: { zoneId ?? store.zones.first?.id ?? 0 }, set: { zoneId = $0 })) {
                        ForEach(store.zones) { zone in
                            Text("\(zone.name ?? "") · \(zone.fee_label ?? "")").tag(zone.id)
                        }
                    }
                    Button("Place order") {
                        Task {
                            if let id = await store.checkout(zoneId: zoneId ?? store.zones.first?.id ?? 0, address: address, phone: phone.isEmpty ? (store.user?.phone ?? "") : phone) {
                                store.paid = false
                                store.paymentURL = nil
                                paying = id
                            }
                        }
                    }
                    .disabled(store.user == nil || address.count < 8)
                }
            }
            .navigationTitle("Cart")
            .sheet(isPresented: Binding(get: { paying != nil }, set: { if !$0 { paying = nil } })) {
                if let id = paying {
                    PayView(orderId: id)
                }
            }
            .task {
                phone = store.user?.phone ?? phone
                await store.loadCart()
                await store.loadZones()
            }
        }
    }
}

struct AccountView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            Form {
                if let user = store.user {
                    Text(user.name ?? user.username ?? "Account").font(.title2.bold())
                    Text(user.email ?? "")
                    Text(user.role ?? "").foregroundStyle(.secondary)
                    if store.isSeller {
                        Text(store.sellerProfile?.business_name ?? "")
                        NavigationLink("Shop orders") { SellerOrdersView() }
                        NavigationLink("My purchases") { BuyerOrdersView() }
                        NavigationLink("Shop on Azura") { HomeView() }
                    } else {
                        NavigationLink("My orders") { BuyerOrdersView() }
                    }
                    NavigationLink("Track parcel") { TrackView() }
                    Button("Sign out", role: .destructive) { Task { await store.logout() } }
                } else {
                    NavigationLink("Sign in") { LoginView() }
                    NavigationLink("Create account") { RegisterView() }
                    NavigationLink("Forgot password?") { ForgotView() }
                    NavigationLink("Track parcel") { TrackView() }
                }
                Section("Store") {
                    Text(store.storeURL).font(.footnote)
                    Button("Change store address") { store.phase = .setup }
                }
            }
            .navigationTitle("Me")
        }
    }
}
