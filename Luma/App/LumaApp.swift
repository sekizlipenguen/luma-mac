import AppKit
import SwiftUI
import LumaCore
import LumaSupport
import LumaSystem
import LumaUI

@main
struct LumaApp: App {
    @NSApplicationDelegateAdaptor(LumaAppDelegate.self) private var appDelegate
    @StateObject private var environment: AppEnvironment
    @State private var showScheduledAlert = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.system.rawValue
    @AppStorage("luma.menuBarEnabled") private var menuBarEnabled = false
    @State private var statusItem: LumaStatusItemController?

    init() {
        let env: AppEnvironment
        do {
            env = try AppEnvironment()
        } catch {
            fatalError("Failed to create AppEnvironment: \(error)")
        }
        _environment = StateObject(wrappedValue: env)
        // Prefer preferences.json as source of truth, then keep AppStorage / Bundle lookups aligned.
        let language = AppLanguage.resolved(code: env.preferences.languageCode).rawValue
        UserDefaults.standard.set(language, forKey: AppLanguage.storageKey)
        _languageCode = AppStorage(wrappedValue: language, AppLanguage.storageKey)
        UserDefaults.standard.set(env.preferences.menuBarEnabled, forKey: "luma.menuBarEnabled")
        _menuBarEnabled = AppStorage(wrappedValue: env.preferences.menuBarEnabled, "luma.menuBarEnabled")
        AppLanguage.applyBundleLanguagePreference()
    }

    private var appLocale: Locale {
        AppLanguage.resolved(code: languageCode).locale
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(environment)
                .environment(\.locale, appLocale)
                .id(languageCode)
                .background(OpenMainWindowBridge())
                .onOpenURL { LumaServiceProvider.handleOpenURL($0) }
                .onAppear {
                    let resolved = AppLanguage.resolved(code: languageCode)
                    if languageCode != resolved.rawValue {
                        languageCode = resolved.rawValue
                    }
                    AppLanguage.applyBundleLanguagePreference()
                    handleLaunchArguments()
                    if environment.preferences.languageCode != languageCode {
                        environment.preferences.languageCode = languageCode
                        environment.savePreferences()
                    }
                    ensureStatusItem()
                    applyActivationPolicy()
                }
                .onReceive(NotificationCenter.default.publisher(for: .lumaOpenMainWindow)) { _ in
                    applyActivationPolicy(forceRegular: true)
                }
                .onChange(of: languageCode) { _, newValue in
                    let resolved = AppLanguage.resolved(code: newValue)
                    if newValue != resolved.rawValue {
                        languageCode = resolved.rawValue
                        return
                    }
                    AppLanguage.applyBundleLanguagePreference()
                    guard environment.preferences.languageCode != resolved.rawValue else { return }
                    environment.preferences.languageCode = resolved.rawValue
                    environment.savePreferences()
                }
                .onChange(of: menuBarEnabled) { _, newValue in
                    if environment.preferences.menuBarEnabled != newValue {
                        environment.preferences.menuBarEnabled = newValue
                        environment.savePreferences()
                    }
                    ensureStatusItem()
                    applyActivationPolicy()
                }
                .alert("Scheduled Maintenance", isPresented: $showScheduledAlert) {
                    Button("Open Cleaner") { showScheduledAlert = false }
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Luma was opened by your schedule. Review Cleaner rules, run Dry Run, then confirm Trash. Nothing was deleted automatically.")
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Luma Help") {}
            }
        }

        Window("Folder size", id: "folder-size") {
            FolderSizePanel(session: FolderSizeSession.shared)
        }
        .windowResizability(.contentSize)
    }

    private func ensureStatusItem() {
        if statusItem == nil {
            statusItem = LumaStatusItemController(metrics: environment.metrics)
        }
        statusItem?.setEnabled(menuBarEnabled)
    }

    private func applyActivationPolicy(forceRegular: Bool = false) {
        if isUITestLaunch || forceRegular {
            NSApp.setActivationPolicy(.regular)
            return
        }
        if menuBarEnabled, environment.preferences.menuBarHideDock {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private var isUITestLaunch: Bool {
        CommandLine.arguments.contains("--uitest")
            || ProcessInfo.processInfo.environment["LUMA_UITEST"] == "1"
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func handleLaunchArguments() {
        if CommandLine.arguments.contains("--scheduled-cleanup") {
            showScheduledAlert = true
        }
        if isUITestLaunch {
            menuBarEnabled = true
            environment.preferences.menuBarEnabled = true
            environment.preferences.menuBarHideDock = false
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// Lives inside the WindowGroup so `openWindow` is available when the menu-bar item asks to show Luma.
private struct OpenMainWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear(perform: registerOpener)
            .onReceive(NotificationCenter.default.publisher(for: .lumaOpenMainWindow)) { _ in
                registerOpener()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumaOpenFolderSizeWindow)) { _ in
                registerOpener()
                openWindow(id: "folder-size")
                NSApp.activate(ignoringOtherApps: true)
            }
    }

    private func registerOpener() {
        LumaWindowRouter.shared.openMainWindow = {
            openWindow(id: "main")
        }
        LumaWindowRouter.shared.openFolderSizeWindow = {
            openWindow(id: "folder-size")
        }
    }
}
