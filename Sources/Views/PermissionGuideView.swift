import SwiftUI

struct PermissionGuideView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("フルディスクアクセスが必要です")
                .font(.title2.bold())

            Text("CleanSweepがシステムディレクトリ（/private/tmp、Xcodeキャッシュ等）をスキャンするには、フルディスクアクセス権限が必要です。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                step(number: 1, text: "「システム設定」を開く")
                step(number: 2, text: "「プライバシーとセキュリティ」→「フルディスクアクセス」")
                step(number: 3, text: "「CleanSweep」をオンにする")
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button("システム設定を開く") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("後で設定する") {
                    isPresented = false
                }
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func step(number: Int, text: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(.blue, in: Circle())
                .foregroundStyle(.white)
            Text(text)
                .font(.body)
        }
    }

    private func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
