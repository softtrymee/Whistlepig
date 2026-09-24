import ArgumentParser
import Foundation
import Subprocess
import XcresultparserLib

struct CI: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "CI workflow commands that can be run both locally and in CI environments.",
                                                    subcommands: [
                                                        PreviewTests.self,
                                                        AccessibilityTests.self,
                                                        UnitTests.self,
                                                        UITests.self,
                                                        IntegrationTests.self,
                                                        RunTests.self
                                                    ])
    
    static let defaultOSVersion = "26.5"
    static let testOutputDirectory = "test_output"
    
    // MARK: - Linting
    
    /// Runs SwiftFormat in lint mode against the current directory.
    static func lint() async throws {
        logger.info("\n🔍 Running SwiftFormat lint…\n")
        
        do {
            try await run(.name("swiftformat"), ["--lint", "."])
        } catch {
            logger.error("\n❌ SwiftFormat failed.\n")
            annotateError(title: "SwiftFormat lint failed", "Run `swiftformat .` from the project root and commit the changes.")
            throw error
        }
        logger.info("\n✅ SwiftFormat passed.\n")
    }
    
    // MARK: - Test diagnostics
    
    /// Logs a test failure in a format useful both locally and in CI logs.
    static func annotateError(title: String, _ message: String) {
        logger.error("❌ \(title): \(message)")
    }
    
    // MARK: - Test Results
    
    /// Collects coverage from an xcresult bundle using xcresultparser (cobertura format).
    /// Failures are non-fatal — the output file simply won't be created.
    static func collectCoverage(resultBundle: String, target: String = "ElementX", outputName: String) async {
        let projectPath = URL.projectDirectory.path
        let resultBundlePath = "\(testOutputDirectory)/\(resultBundle)"
        let outputPath = "\(testOutputDirectory)/\(outputName)"
        
        guard FileManager.default.fileExists(atPath: resultBundlePath) else {
            logger.error("\n❌ Result bundle not found at \(resultBundlePath), skipping coverage collection.\n")
            return
        }
        
        do {
            let converter = try CoberturaCoverageConverter(with: URL(filePath: resultBundlePath),
                                                           projectRoot: projectPath,
                                                           coverageTargets: [target],
                                                           strictPathnames: false)
            try converter.xmlString(quiet: true).write(toFile: outputPath, atomically: true, encoding: .utf8)
            logger.info("\n📊 Coverage report: \(outputPath)\n")
        } catch {
            logger.error("\n❌ Failed to collect coverage for \(resultBundle): \(error.localizedDescription)\n")
        }
    }
    
    /// Collects test results from an xcresult bundle using xcresultparser (junit format).
    /// Failures are non-fatal — the output file simply won't be created.
    static func collectTestResults(resultBundle: String, outputName: String) async {
        let projectPath = URL.projectDirectory.path
        let resultBundlePath = "\(testOutputDirectory)/\(resultBundle)"
        let outputPath = "\(testOutputDirectory)/\(outputName)"
        
        guard FileManager.default.fileExists(atPath: resultBundlePath) else {
            logger.info(" Result bundle not found at \(resultBundlePath), skipping test result collection.")
            return
        }
        
        do {
            let junitXML = try JunitXML(with: URL(filePath: resultBundlePath), projectRoot: projectPath)
            try junitXML.xmlString.write(toFile: outputPath, atomically: true, encoding: .utf8)
            logger.info("📋 Test results: \(outputPath)")
        } catch {
            logger.error("\n❌ Failed to collect test results for \(resultBundle): \(error.localizedDescription)\n")
        }
    }
    
    /// Zips xcresult bundles in the test output directory for faster artifact uploads.
    static func zipResults(bundles: [String], outputName: String) async {
        let bundleArgs = bundles.joined(separator: " ")
        do {
            logger.info("\n📦 Zipping test results…")
            try await run(.path("/bin/zsh"), ["-cu", "cd \(testOutputDirectory) && zip -rq \(outputName) \(bundleArgs)"])
            logger.info("📦 Zipped: \(testOutputDirectory)/\(outputName)\n")
        } catch {
            logger.error("\n❌ Failed to zip results: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Shell Interaction
    
    @discardableResult
    static func run<Output: OutputProtocol, Error: ErrorOutputProtocol>(_ executable: Executable,
                                                                        _ arguments: Arguments = [],
                                                                        environment: Environment = .inherit,
                                                                        output: Output = .standardOutput,
                                                                        error: Error = .standardError) async throws -> CollectedResult<Output, Error> {
        logger.info("Running \(executable), with arguments: \(arguments)")
        
        let result = try await Subprocess.run(executable,
                                              arguments: arguments,
                                              environment: environment,
                                              output: output,
                                              error: error)
        
        if case let .exited(code) = result.terminationStatus, code != 0 {
            throw ExitCode.failure
        }
        
        return result
    }
}
