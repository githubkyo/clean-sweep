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
                        .help(L("header.total.help"))
                    Label(scanner.result.formattedSelected, systemImage: "checkmark.circle")
                        .foregroundStyle(.blue)
                        .help(L("header.selected.help"))
                }
                .font(.callout)
            }

            Spacer()

            Toggle(isOn: $scanner.useTrash) {
                Label(L("header.trash.toggle"), systemImage: scanner.useTrash ? "trash" : "trash.slash")
            }
            .toggleStyle(.switch)
            .help(scanner.useTrash ? L("header.trash.help.on") : L("header.trash.help.off"))

            Button {
                Task { await scanner.scan() }
            } label: {
                Label(L("header.scan"), systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(scanner.isScanning || scanner.isDeleting)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(scanner.useTrash ? L("header.trash.button") : L("header.delete.button"), systemImage: "trash")
            }
            .disabled(scanner.result.selectedSize == 0 || scanner.isScanning || scanner.isDeleting)
            .confirmationDialog(
                scanner.useTrash ? L("header.confirm.trash") : L("header.confirm.delete"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                let actionLabel = scanner.useTrash
                    ? L("header.confirm.action.trash", scanner.result.formattedSelected)
                    : L("header.confirm.action.delete", scanner.result.formattedSelected)
                Button(actionLabel, role: .destructive) {
                    scanner.deleteSelected()
                }
                Button(L("header.cancel"), role: .cancel) {}
            } message: {
                let dangerCount = scanner.result.items.filter { $0.isSelected && $0.safety == .dangerous }.count
                if dangerCount > 0 {
                    Text(L("header.warning.danger", dangerCount))
                } else if scanner.useTrash {
                    Text(L("header.info.trash", scanner.result.items.filter(\.isSelected).count))
                } else {
                    Text(L("header.info.delete", scanner.result.items.filter(\.isSelected).count))
                }
            }
        }
        .padding()
    }
}
