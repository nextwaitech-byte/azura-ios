# Codemagic steps — Azura Store iOS (`nextwaitech-byte/azura-ios`)

Native Swift app (not Flutter). Bundle ID: **`tz.azurastore.app`**.

## 1. Connect the repo in Codemagic

1. [Codemagic](https://codemagic.io) → **Add application** → GitHub → select **`nextwaitech-byte/azura-ios`**.
2. Choose **Use configuration from repository** (`codemagic.yaml` in repo root).
3. Team / billing must allow **mac_mini_M2** (or change `instance_type` in YAML).

## 2. Apple integration (required for upload)

In **Codemagic → Teams → Personal/Team → Integrations → Developer Portal**:

| Item | Value |
|------|--------|
| Integration label | **`applestoreconnectkey`** (must match YAML exactly) |
| Apple API key | App Store Connect API key (`.p8`), Key ID, Issuer ID |
| Role on Apple | App Manager or Admin |

If the label does not match `applestoreconnectkey`, TestFlight stays empty even when the IPA build is green.

## 3. Code signing (iOS Distribution)

1. In Codemagic → app → **Code signing identities**:
   - Upload or fetch **Apple Distribution** certificate + **App Store** provisioning profile for `tz.azurastore.app`.
2. Or enable **automatic code signing** with the Developer Portal integration so Codemagic can create/fetch profiles for `distribution_type: app_store`.

In Xcode locally, set **Team** under Signing & Capabilities (repo leaves `DEVELOPMENT_TEAM` unset on purpose).

## 4. App Store Connect app

1. Create the app in App Store Connect with bundle ID **`tz.azurastore.app`** (must already exist for profile + upload).
2. Privacy policy URL, screenshots, App Privacy, etc.
3. For apps that only use standard HTTPS, encryption: answer accordingly (Info.plist can include `ITSAppUsesNonExemptEncryption` = false if applicable).

## 5. Run a build

1. Start workflow **Azura Store iOS (IPA → App Store)**.
2. Confirm logs show **App Store Connect publish**, not only “Publishing artifact … ipa” to Codemagic.
3. App Store Connect → **TestFlight** → wait for **Processing** → **Ready**.

## 6. Version / build numbers

Current project: version **1.1**, build **1** (`Info.plist` / Xcode).  
Each new upload needs a **higher CFBundleVersion** than the last accepted build. Bump in Xcode or via `agvtool` / Codemagic env before archive.

## 7. What this repo is vs Play Store

| Platform | Repo / artifact | Status |
|----------|-----------------|--------|
| **iOS App Store** | This repo `azura-ios` | Use `codemagic.yaml` above |
| **Google Play AAB** | Separate Android project / `play-ready` | Not this Swift repo |

See workspace notes on `play-ready.zip` (AAB + PEM only; no private upload keystore in that zip).
