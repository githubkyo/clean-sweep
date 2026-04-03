import Foundation

struct DockerScanner: CategoryScanner {
    let category = StorageCategory.docker
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        var items: [StorageItem] = []
        let hasRunningContainers = shell.run(["docker", "ps", "-q"]).map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false

        if let output = shell.run(["docker", "system", "df", "--format", "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}"]) {
            for line in output.split(separator: "\n") {
                let parts = line.split(separator: "\t")
                guard parts.count >= 3 else { continue }
                let typeName = String(parts[0])
                let bytes = Self.parseDockerSize(String(parts[2]))
                guard bytes > 10_000_000 else { continue }

                // Volumes/Containers used by running containers can't be pruned
                let isInUseType = hasRunningContainers && (typeName == "Local Volumes" || typeName == "Containers")
                items.append(StorageItem(
                    name: "Docker \(typeName) (回収可能)",
                    path: "docker-prune",
                    size: bytes,
                    category: .docker,
                    safety: isInUseType ? .caution : .safe,
                    detail: isInUseType
                        ? "⚠️ 稼働中コンテナあり — 使用中のリソースは削除されません"
                        : "docker system prune で削除",
                    deletionMethod: .dockerPrune
                ))
            }
        }

        let dockerPath = "\(home)/Library/Containers/com.docker.docker"
        if let size = shell.directorySize(dockerPath) {
            items.append(StorageItem(
                name: "Docker ディスクイメージ",
                path: dockerPath,
                size: size,
                category: .docker,
                safety: .dangerous,
                detail: "Docker全体のディスクイメージ（削除でDocker再セットアップ必要）"
            ))
        }

        return items
    }

    static func parseDockerSize(_ str: String) -> Int64 {
        let cleaned = str.replacingOccurrences(of: #"\s*\(.*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let multipliers: [(String, Double)] = [
            ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("B", 1),
        ]
        for (suffix, mult) in multipliers {
            if cleaned.hasSuffix(suffix),
               let val = Double(cleaned.dropLast(suffix.count)) {
                return Int64(val * mult)
            }
        }
        return 0
    }
}
