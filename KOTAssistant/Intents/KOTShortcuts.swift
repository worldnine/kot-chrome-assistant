import AppIntents

/// Shortcuts / Spotlight に自動登録されるショートカット。
/// ターミナルからは `shortcuts run "出勤"` のように実行できる。
struct KOTShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PunchInIntent(),
            phrases: ["\(.applicationName)で出勤"],
            shortTitle: "出勤",
            systemImageName: "sunrise"
        )
        AppShortcut(
            intent: PunchOutIntent(),
            phrases: ["\(.applicationName)で退勤"],
            shortTitle: "退勤",
            systemImageName: "sunset"
        )
        AppShortcut(
            intent: StartBreakIntent(),
            phrases: ["\(.applicationName)で休憩開始"],
            shortTitle: "休憩開始",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: EndBreakIntent(),
            phrases: ["\(.applicationName)で休憩終了"],
            shortTitle: "休憩終了",
            systemImageName: "arrow.uturn.left"
        )
        AppShortcut(
            intent: GetPunchStatusIntent(),
            phrases: ["\(.applicationName)の打刻状況"],
            shortTitle: "打刻状況",
            systemImageName: "clock"
        )
    }
}
