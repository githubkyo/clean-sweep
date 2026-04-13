import SwiftUI

struct PermissionGuideView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(L("permission.title"))
                .font(.title2.bold())

            Text(L("permission.description"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                step(number: 1, text: L("permission.step1"))
                step(number: 2, text: L("permission.step2"))
                step(number: 3, text: L("permission.step3"))
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button(L("permission.open")) {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button(L("permission.later")) {
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
