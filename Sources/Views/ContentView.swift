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
                    Text("クリーンアップ完了")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scanner.result.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("「スキャン」を押してストレージを分析")
                        .foregroundStyle(.secondary)

                    if !PermissionChecker.hasFullDiskAccess() {
                        Button("権限設定ガイドを表示") {
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
                            Text("フルディスクアクセスが未設定 — 一部のディレクトリがスキャンできない可能性があります")
                                .font(.caption)
                            Spacer()
                            Button("設定") { showPermissionGuide = true }
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
