import SwiftUI

struct HeaderView: View {
    @Environment(StorageScanner.self) private var scanner
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var scanner = scanner

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CleanSweep")
                    .font(.title2.bold())
                HStack(spacing: 16) {
                    Label(scanner.result.formattedTotal, systemImage: "internaldrive")
                        .foregroundStyle(.secondary)
                        .help("回収可能な合計サイズ")
                    Label(scanner.result.formattedSelected, systemImage: "checkmark.circle")
                        .foregroundStyle(.blue)
                        .help("選択中の合計サイズ")
                }
                .font(.callout)
            }

            Spacer()

            Toggle(isOn: $scanner.useTrash) {
                Label("ゴミ箱に移動", systemImage: scanner.useTrash ? "trash" : "trash.slash")
            }
            .toggleStyle(.switch)
            .help(scanner.useTrash ? "ファイルをゴミ箱に移動（復元可能）" : "ファイルを完全削除（復元不可）")

            Button {
                Task { await scanner.scan() }
            } label: {
                Label("スキャン", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanner.isScanning || scanner.isDeleting)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(scanner.useTrash ? "ゴミ箱へ" : "削除", systemImage: "trash")
            }
            .disabled(scanner.result.selectedSize == 0 || scanner.isScanning || scanner.isDeleting)
            .confirmationDialog(
                "選択した項目を\(scanner.useTrash ? "ゴミ箱に移動" : "完全に削除")しますか？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("\(scanner.useTrash ? "ゴミ箱に移動" : "削除")する (\(scanner.result.formattedSelected))", role: .destructive) {
                    Task { await scanner.deleteSelected() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                let dangerCount = scanner.result.items.filter { $0.isSelected && $0.safety == .dangerous }.count
                if dangerCount > 0 {
                    Text("危険レベルの項目が\(dangerCount)件含まれています。削除するとデータ損失の可能性があります。")
                } else if scanner.useTrash {
                    Text("\(scanner.result.items.filter(\.isSelected).count)件の項目をゴミ箱に移動します。Finderから復元できます。")
                } else {
                    Text("\(scanner.result.items.filter(\.isSelected).count)件の項目を完全に削除します。この操作は取り消せません。")
                }
            }
        }
        .padding()
    }
}
