# Repository Guidelines

## Project Structure & Module Organization
- `BCConnectorApp.swift`: App entry point (SwiftUI). Initializes app-wide state.
- `ContentView.swift`, `MapView.swift`: UI views and navigation.
- `ViewModels.swift`: ObservableObject view models backing the views.
- `APIClient.swift`: Networking layer (requests, decoding, error handling).
- `AuthenticationManager.swift`: Auth/session utilities (token handling).
- `SettingsManager.swift`: User defaults and app settings.
- `Assets.xcassets`, `Preview Content/`, `Info.plist`: App assets, previews, and configuration.

## Build, Test, and Development Commands
- Open in Xcode: `xed .` (or open the `.xcodeproj/.xcworkspace` at repo root).
- Build (CLI): `xcodebuild -scheme BCConnector -configuration Debug build`
  - Adjust `-destination` as needed, e.g. `platform=iOS Simulator,name=iPhone 15`.
- Run tests (Xcode): Product > Test or `Cmd+U`.
- Run tests (CLI): `xcodebuild -scheme BCConnector -configuration Debug test`.

## Coding Style & Naming Conventions
- Swift 5+; 4-space indentation; no trailing whitespace; wrap at ~120 cols.
- Types: `PascalCase` (e.g., `UserProfile`). Variables/functions: `camelCase`.
- Files: match primary type (`UserProfile.swift`), or role-based (`FooView.swift`, `BarViewModel.swift`, `BazManager.swift`).
- Prefer structs for value types; `final class` where inheritance isn’t needed.
- Use Swift concurrency (`async/await`) and `Result` over custom callbacks.

## Testing Guidelines
- Framework: XCTest. Place tests under `BCConnectorTests/` mirroring source paths.
- Name tests with intent: `test_fetchProfile_success()`.
- Aim for coverage of networking (stubbing), view models, and pure logic.
- Run focused tests in Xcode’s Test navigator or via `xcodebuild … test -only-testing:Module/Type/testName`.

## Commit & Pull Request Guidelines
- Commits: small, atomic, imperative mood (e.g., "Add login flow").
- Reference issues with `#ID` when applicable.
- PRs: include purpose, scope, screenshots for UI changes, and test notes.
- Pass build and tests; request review when green. Keep diff minimal and scoped.

## Security & Configuration Tips
- Do not commit secrets; keep keys out of `Info.plist` and code.
- Store credentials securely (Keychain) and prefer per-environment build settings.
- Centralize network config (base URLs, timeouts) in `APIClient`.
