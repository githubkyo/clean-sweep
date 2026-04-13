import SwiftUI

struct ContentView: View {
    @Environment(StorageScanner.self) private var scanner
    @State private var showPermissionGuide = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()

            if scanner.isScanning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(scanner.scanProgress)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.result.items.isEmpty && !scanner.deleteLog.isEmpty {
                // Post-delete state with no remaining items
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text(L("cleanup.complete"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.result.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(L("scan.prompt"))
                        .foregroundStyle(.secondary)

                    if !PermissionChecker.hasFullDiskAccess() {
                        Button(L("permission.guide.show")) {
                            showPermissionGuide = true
                        }
                        .buttonStyle(.link)
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // Warning banner if no FDA
                    if !PermissionChecker.hasFullDiskAccess() {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(L("fda.warning"))
                                .font(.caption)
                            Spacer()
                            Button(L("settings")) { showPermissionGuide = true }
                                .font(.caption)
                        }
                        .padding(8)
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(scanner.result.byCategory, id: \.category) { group in
                            CategorySectionView(
                                category: group.category,
                                items: group.items,
                                totalSize: group.totalSize
                            )
                        }
                    }
                    .padding()
                }
            }

            if !scanner.deleteLog.isEmpty {
                Divider()
                DeleteLogView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(isPresented: $showPermissionGuide)
        }
    }
}
