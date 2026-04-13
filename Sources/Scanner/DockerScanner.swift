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
                    name: L("docker.reclaimable", typeName),
                    path: "docker-prune",
                    size: bytes,
                    category: .docker,
                    safety: isInUseType ? .caution : .safe,
                    detail: isInUseType
                        ? L("docker.running.detail")
                        : L("docker.prune.detail"),
                    deletionMethod: .dockerPrune
                ))
            }
        }

        let dockerPath = "\(home)/Library/Containers/com.docker.docker"
        if let size = shell.directorySize(dockerPath) {
            items.append(StorageItem(
                name: L("docker.disk.name"),
                path: dockerPath,
                size: size,
                category: .docker,
                safety: .dangerous,
                detail: L("docker.disk.detail")
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
