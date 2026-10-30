import SwiftUI

private let violet = Color(red: 0.49, green: 0.23, blue: 0.93)
private let lilac = Color(red: 0.96, green: 0.93, blue: 0.99)
private let muted = Color(red: 0.42, green: 0.35, blue: 0.55)

private func L(_ en: String, _ sw: String) -> String {
    Locale.current.language.languageCode?.identifier == "sw" ? sw : en
}

struct LoginView: View {
    @EnvironmentObject var store: ShopStore
    @Environment(\.dismiss) private var dismiss
    @State private var login = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Azura Store").font(.title2.bold())
                Text(L("Online shopping mall", "Duka la mtandaoni")).foregroundStyle(muted)
                field(L("Email, username or phone", "Barua pepe, jina au simu"), text: $login)
                SecureField(L("Password", "Nenosiri"), text: $password)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if let error = store.error { Text(error).foregroundStyle(.red).font(.footnote) }
                Button(L("Sign in", "Ingia")) {
                    Task {
                        if await store.login(login: login, password: password) { dismiss() }
                    }
                }
                .buttonStyle(AzuraButtonStyle())
                .disabled(login.isEmpty || password.count < 6 || store.loading)
                NavigationLink(L("Forgot password?", "Umesahau nenosiri?")) { ForgotView() }
                    .foregroundStyle(violet)
                NavigationLink(L("Create account", "Fungua akaunti")) { RegisterView() }
                    .foregroundStyle(violet)
            }
            .padding(16)
        }
        .background(lilac)
        .navigationTitle(L("Sign in", "Ingia"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RegisterView: View {
    @EnvironmentObject var store: ShopStore
    @Environment(\.dismiss) private var dismiss
    @State private var first = ""
    @State private var last = ""
    @State private var username = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                field(L("First name", "Jina la kwanza"), text: $first)
                field(L("Last name", "Jina la ukoo"), text: $last)
                field(L("Username", "Jina la mtumiaji"), text: $username)
                field(L("Email", "Barua pepe"), text: $email).textInputAutocapitalization(.never)
                field(L("Phone", "Simu"), text: $phone).keyboardType(.phonePad)
                SecureField(L("Password", "Nenosiri"), text: $password)
                    .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                if let error = store.error { Text(error).foregroundStyle(.red).font(.footnote) }
                Button(L("Create account", "Fungua akaunti")) {
                    Task {
                        if await store.register(first: first, last: last, username: username, email: email, phone: phone, password: password) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(AzuraButtonStyle())
                .disabled(store.loading)
            }
            .padding(16)
        }
        .background(lilac)
        .navigationTitle(L("Create account", "Fungua akaunti"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ForgotView: View {
    @EnvironmentObject var store: ShopStore
    @State private var login = ""
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("We will send a 6-digit OTP to the phone on your Azura account.", "Tutakutumia OTP ya tarakimu 6 kwenye simu ya akaunti yako."))
                    .foregroundStyle(muted)
                field(L("Email, username or phone", "Barua pepe, jina au simu"), text: $login)
                if let error = store.error { Text(error).foregroundStyle(.red).font(.footnote) }
                Button(L("Send OTP", "Tuma OTP")) {
                    Task { sent = await store.requestReset(login: login) }
                }
                .buttonStyle(AzuraButtonStyle())
                .disabled(login.isEmpty || store.loading)
                if sent {
                    NavigationLink(L("Enter the SMS code", "Weka namba ya SMS")) { ResetView() }
                        .buttonStyle(AzuraButtonStyle())
                }
            }
            .padding(16)
        }
        .background(lilac)
        .navigationTitle(L("Forgot password?", "Umesahau nenosiri?"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResetView: View {
    @EnvironmentObject var store: ShopStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field(L("SMS code", "Namba ya SMS"), text: $code).keyboardType(.numberPad)
                SecureField(L("New password", "Nenosiri jipya"), text: $password)
                    .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                if let error = store.error { Text(error).foregroundStyle(.red).font(.footnote) }
                Button(L("Save password", "Hifadhi nenosiri")) {
                    Task {
                        if await store.applyReset(code: code, password: password) { dismiss() }
                    }
                }
                .buttonStyle(AzuraButtonStyle())
                .disabled(code.count < 4 || password.count < 6 || store.loading)
            }
            .padding(16)
        }
        .background(lilac)
        .navigationTitle(L("SMS code", "Namba ya SMS"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PayView: View {
    let orderId: Int
    @EnvironmentObject var store: ShopStore
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var pin = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.order?.total_label ?? "").font(.title2.bold()).foregroundStyle(violet)
                    Text(L("Enter your mobile-money number, pay on Selcom, then check the payment if the status is slow.", "Weka namba ya simu, lipa Selcom, kisha angalia malipo ikiwa hali inachelewa."))
                        .font(.footnote).foregroundStyle(muted)
                    field(L("M-Pesa / Mixx / Airtel number", "Namba ya M-Pesa / Mixx / Airtel"), text: $phone).keyboardType(.phonePad)
                    SecureField(L("Demo PIN", "PIN ya majaribio"), text: $pin)
                        .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                    if let error = store.error { Text(error).foregroundStyle(.red).font(.footnote) }
                    if let note = store.payMessage, !store.paid { Text(note).foregroundStyle(muted).font(.footnote) }
                    if store.paid {
                        Text(L("Payment confirmed", "Malipo yamethibitishwa")).font(.headline).foregroundStyle(violet)
                        Button(L("My orders", "Oda zangu")) { dismiss() }.buttonStyle(AzuraButtonStyle())
                    } else {
                        Button(L("Pay now", "Lipa sasa")) {
                            Task { await store.pay(id: orderId, phone: phone, pin: pin) }
                        }
                        .buttonStyle(AzuraButtonStyle())
                        .disabled(phone.count < 9 || store.loading)
                        if let raw = store.paymentURL, let url = URL(string: raw) {
                            Link(L("Open Selcom Pay", "Fungua Selcom Pay"), destination: url)
                            Button(L("Check Selcom payment", "Angalia malipo ya Selcom")) {
                                Task { await store.checkPay(id: orderId) }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(lilac)
            .navigationTitle(store.order?.order_number ?? L("Pay now", "Lipa sasa"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Back", "Rudi")) { dismiss() }
                }
            }
            .task {
                phone = store.user?.phone ?? ""
                await store.loadOrder(orderId)
            }
        }
    }
}

struct AzuraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(violet.opacity(configuration.isPressed ? 0.8 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func field(_ title: String, text: Binding<String>) -> some View {
    TextField(title, text: text)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
}
