import ArgumentParser
import Foundation
import Logging

let logger = Logger(label: "🚀")

@main
struct Tools: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "A collection of command line tools for ElementX",
                                                    subcommands: [BuildSDK.self,
                                                                  SetupProject.self,
                                                                  OutdatedPackages.self,
                                                                  Locheck.self,
                                                                  GenerateSDKMocks.self,
                                                                  GenerateSAS.self,
                                                                  UnusedStrings.self,
                                                                  CI.self])
}
