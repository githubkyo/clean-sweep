import Testing
@testable import CleanSweep

@Suite("Scanner Tests")
struct ScannerTests {

    // MARK: - Docker Size Parsing (CE-007, CE-008)

    @Test("DockerサイズパースGB括弧あり")
    func parseDockerSizeWithParens() {
        #expect(DockerScanner.parseDockerSize("42.97GB (62%)") == 42_970_000_000)
    }

    @Test("DockerサイズパースGB括弧なし")
    func parseDockerSizeWithoutParens() {
        #expect(DockerScanner.parseDockerSize("21.13GB") == 21_130_000_000)
    }

    @Test("DockerサイズパースMB")
    func parseDockerSizeMB() {
        #expect(DockerScanner.parseDockerSize("97.02MB") == 97_020_000)
    }

    @Test("DockerサイズパースkB")
    func parseDockerSizekB() {
        #expect(DockerScanner.parseDockerSize("512kB") == 512_000)
    }

    @Test("DockerサイズパースTB")
    func parseDockerSizeTB() {
        #expect(DockerScanner.parseDockerSize("1.5TB") == 1_500_000_000_000)
    }

    @Test("Dockerサイズパース0B")
    func parseDockerSizeZero() {
        #expect(DockerScanner.parseDockerSize("0B") == 0)
    }

    @Test("Dockerサイズパース不正文字列")
    func parseDockerSizeInvalid() {
        #expect(DockerScanner.parseDockerSize("invalid") == 0)
        #expect(DockerScanner.parseDockerSize("") == 0)
    }

    // MARK: - APFS Snapshot Parsing (CE-009)

    @Test("APFSスナップショット解析")
    func parseAPFSSnapshots() {
        let sampleOutput = """
        Snapshots for disk3s1 (2 found)
        |
        +-- A39C6D59-A221-480E-A291-97F0A9AE6C54
        |   Name:        com.apple.os.update-ABC123
        |   XID:         2625929
        |   Purgeable:   No
        |
        +-- 88918EE2-0681-4B9F-972D-94642A7285D4
            Name:        com.apple.os.update-DEF456
            XID:         4782211
            Purgeable:   Yes
        """
        let items = APFSSnapshotScanner.parseSnapshots(sampleOutput)
        #expect(items.count == 2)
        #expect(items[0].category == .apfsSnapshots)
        #expect(items[0].path == "com.apple.os.update-ABC123")
        #expect(items[1].path == "com.apple.os.update-DEF456")
        // Verify sudoCommand deletion method
        if case .sudoCommand(let cmd) = items[0].deletionMethod {
            #expect(cmd.contains("tmutil deletelocalsnapshots"))
            #expect(cmd.contains("com.apple.os.update-ABC123"))
        } else {
            #expect(Bool(false), "Expected .sudoCommand")
        }
    }

    @Test("APFSスナップショット解析 空出力")
    func parseAPFSSnapshotsEmpty() {
        #expect(APFSSnapshotScanner.parseSnapshots("No snapshots found").isEmpty)
    }

    @Test("APFSスナップショット 長い名前は切り詰め")
    func parseAPFSSnapshotsTruncation() {
        let longName = String(repeating: "A", count: 80)
        let output = """
        Name:        \(longName)
        Purgeable:   No
        """
        let items = APFSSnapshotScanner.parseSnapshots(output)
        #expect(items.count == 1)
        #expect(items[0].name.contains("..."))
        #expect(items[0].path == longName)  // Full name preserved in path
    }

    // MARK: - ShellExecutor (CE-010, CE-011)

    @Test("ShellExecutor既存ディレクトリのサイズ取得")
    func shellExecutorExistingDir() {
        let size = ShellExecutor.shared.directorySize("/tmp")
        #expect(size != nil)
        #expect(size! >= 0)
    }

    @Test("ShellExecutor存在しないパスでnil")
    func shellExecutorNonExisting() {
        #expect(ShellExecutor.shared.directorySize("/nonexistent/path/12345") == nil)
    }

    @Test("ShellExecutor echoコマンド実行")
    func shellExecutorRun() {
        let result = ShellExecutor.shared.run("echo", "hello")
        #expect(result?.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }

    @Test("ShellExecutor 失敗コマンドでnil")
    func shellExecutorFailedCommand() {
        let result = ShellExecutor.shared.run(["false"])
        #expect(result == nil)
    }

    // MARK: - Mock-based Scanner Tests

    @Test("DockerScanner mockでスキャン")
    func dockerScannerWithMock() async {
        let mock = MockShellExecutor()
        mock.commandResults["docker system df --format {{.Type}}\t{{.Size}}\t{{.Reclaimable}}"] =
            "Images\t10GB\t5.5GB (55%)\nContainers\t1GB\t500MB (50%)"
        mock.directorySizes["/test/Library/Containers/com.docker.docker"] = 15_000_000_000

        let scanner = DockerScanner(shell: mock, home: "/test")
        let items = await scanner.scan()

        // 5.5GB images + 500MB containers (both >10MB) + docker disk image
        #expect(items.count == 3)
        let reclaimable = items.first { $0.name.contains("Images") }
        #expect(reclaimable != nil)
        #expect(reclaimable!.size == 5_500_000_000)
        if case .dockerPrune = reclaimable!.deletionMethod { } else {
            #expect(Bool(false), "Expected .dockerPrune")
        }

        let diskImage = items.first { $0.name.contains("ディスクイメージ") }
        #expect(diskImage != nil)
        #expect(diskImage!.safety == .dangerous)
    }

    @Test("DockerScanner Docker未起動で空")
    func dockerScannerNotRunning() async {
        let mock = MockShellExecutor()
        // No commandResults = docker not running
        let scanner = DockerScanner(shell: mock, home: "/test")
        let items = await scanner.scan()
        #expect(items.isEmpty)
    }

    @Test("XcodeScanner mockでスキャン")
    func xcodeScannerWithMock() async {
        let mock = MockShellExecutor()
        mock.directorySizes["/test/Library/Developer/Xcode/DerivedData"] = 5_000_000_000
        mock.directorySizes["/test/Library/Developer/Xcode/Archives"] = 3_000_000_000
        // DeviceSupport and CoreSimulator are below threshold

        let scanner = XcodeScanner(shell: mock, home: "/test")
        let items = await scanner.scan()

        #expect(items.count == 2)
        let derived = items.first { $0.name.contains("DerivedData") }
        #expect(derived?.safety == .safe)
        let archives = items.first { $0.name.contains("Archives") }
        #expect(archives?.safety == .caution)
    }

    @Test("XcodeScanner Xcode未インストールで空")
    func xcodeScannerNotInstalled() async {
        let mock = MockShellExecutor()
        let scanner = XcodeScanner(shell: mock, home: "/test")
        #expect(await scanner.scan().isEmpty)
    }

    @Test("GradleScanner 閾値以下でスキップ")
    func gradleScannerBelowThreshold() async {
        let mock = MockShellExecutor()
        mock.directorySizes["/test/.gradle"] = 50_000_000  // 50MB < 100MB threshold
        let scanner = GradleScanner(shell: mock, home: "/test")
        #expect(await scanner.scan().isEmpty)
    }

    @Test("GradleScanner 閾値以上で検出")
    func gradleScannerAboveThreshold() async {
        let mock = MockShellExecutor()
        mock.directorySizes["/test/.gradle"] = 500_000_000
        let scanner = GradleScanner(shell: mock, home: "/test")
        let items = await scanner.scan()
        #expect(items.count == 1)
        #expect(items[0].safety == .safe)
    }

    @Test("FlutterScanner mockでスキャン")
    func flutterScannerWithMock() async {
        let mock = MockShellExecutor()
        mock.directorySizes["/test/.pub-cache"] = 800_000_000
        // CocoaPods not present
        let scanner = FlutterScanner(shell: mock, home: "/test")
        let items = await scanner.scan()
        #expect(items.count == 1)
        #expect(items[0].name.contains("pub"))
    }

    @Test("SystemCacheScanner 複数キャッシュ検出")
    func systemCacheScannerMultiple() async {
        let mock = MockShellExecutor()
        mock.directorySizes["/test/Library/Caches/Google"] = 500_000_000
        mock.directorySizes["/test/Library/Caches/Homebrew"] = 200_000_000
        mock.directorySizes["/test/Library/Caches/pip"] = 10_000_000  // Below 30MB threshold
        let scanner = SystemCacheScanner(shell: mock, home: "/test")
        let items = await scanner.scan()
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.safety == .safe })
    }
}
