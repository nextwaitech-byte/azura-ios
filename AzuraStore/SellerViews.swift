import SwiftUI

struct BuyerOrdersView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        List {
            if store.orders.isEmpty {
                Text("No orders yet").foregroundStyle(.secondary)
            }
            ForEach(store.orders) { order in
                NavigationLink {
                    OrderDetailView(id: order.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.order_number ?? "#\(order.id)").bold()
                        Text(order.total_label ?? "")
                        Text("\(order.status ?? "") · \(order.payment_status ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("My purchases")
        .task { await store.loadOrders() }
    }
}

struct OrderDetailView: View {
    let id: Int
    @EnvironmentObject var store: ShopStore
    @State private var pay = false

    var body: some View {
        List {
            if let order = store.order {
                Text(order.order_number ?? "").font(.headline)
                Text(order.total_label ?? "")
                Text("\(order.status ?? "") · \(order.payment_status ?? "")")
                Text(order.delivery_address ?? "")
                Text(order.delivery_phone ?? "")
                if order.payment_status != "paid" {
                    Button("Pay now") { pay = true }
                }
            }
        }
        .navigationTitle("Order")
        .sheet(isPresented: $pay) { PayView(orderId: id) }
        .task { await store.loadOrder(id) }
    }
}

struct TrackView: View {
    @EnvironmentObject var store: ShopStore
    @State private var number = ""
    @State private var code = ""
    @State private var phone = ""

    var body: some View {
        Form {
            TextField("Order number", text: $number)
            TextField("Delivery code", text: $code)
            TextField("Phone", text: $phone)
            Button("Track") {
                Task { await store.track(number: number, code: code, phone: phone) }
            }
            if let error = store.error { Text(error).foregroundStyle(.red) }
            if let order = store.tracked {
                Text(order.order_number ?? "").bold()
                Text(order.status ?? "")
                Text(order.total_label ?? "")
            }
        }
        .navigationTitle("Track parcel")
    }
}

struct SellerOrdersView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            List {
                if store.sellerOrders.isEmpty {
                    Text("No shop orders yet").foregroundStyle(.secondary)
                }
                ForEach(store.sellerOrders) { order in
                    NavigationLink {
                        SellerOrderDetailView(id: order.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.order_number ?? "#\(order.id)").bold()
                            Text(order.title ?? order.seller_label ?? "")
                            Text(order.seller_label ?? "").foregroundStyle(Color(red: 0.49, green: 0.23, blue: 0.93))
                            Text("\(order.status ?? "") · \(order.payment_status ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Shop orders")
            .task { await store.loadSellerOrders() }
        }
    }
}

struct SellerOrderDetailView: View {
    let id: Int
    @EnvironmentObject var store: ShopStore

    var body: some View {
        List {
            if let order = store.order {
                Text(order.seller_label ?? order.total_label ?? "").font(.title3.bold())
                Text("\(order.status ?? "") · \(order.payment_status ?? "")")
                Text(order.customer_name ?? "")
                Text(order.delivery_phone ?? "")
                Text(order.delivery_address ?? "")
                ForEach(order.items ?? [], id: \.title) { item in
                    HStack {
                        Text("\(item.title ?? "") × \(item.quantity)")
                        Spacer()
                        Text(item.seller_label ?? item.price_label ?? "")
                    }
                }
                if order.payment_status != "paid" {
                    Button("Check Selcom payment") { Task { await store.verifySellerPay(id) } }
                } else if order.status == "paid" {
                    Button("Mark preparing") { Task { await store.markPreparing(id) } }
                }
            }
        }
        .navigationTitle(store.order?.order_number ?? "Order")
        .task { await store.loadSellerOrder(id) }
    }
}

struct SellerProductsView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            List(store.sellerProducts) { product in
                HStack {
                    ProductCard(product: product).frame(maxWidth: .infinity)
                    Text(product.status ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Products")
            .task { await store.loadSellerProducts() }
        }
    }
}

struct SellerEarningsView: View {
    @EnvironmentObject var store: ShopStore

    var body: some View {
        NavigationStack {
            List {
                Text(store.earnings.seller_label ?? "TZS 0").font(.title.bold())
                    .foregroundStyle(Color(red: 0.49, green: 0.23, blue: 0.93))
                Text("Commission \(store.earnings.commission_label ?? "")").foregroundStyle(.secondary)
                ForEach(store.earningRows) { row in
                    VStack(alignment: .leading) {
                        Text(row.order_number ?? "").bold()
                        Text(row.title ?? "")
                        Text(row.seller_label ?? "")
                    }
                }
            }
            .navigationTitle("Earnings")
            .task { await store.loadEarnings() }
        }
    }
}
