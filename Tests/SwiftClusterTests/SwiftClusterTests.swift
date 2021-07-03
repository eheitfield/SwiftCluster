    import XCTest
    import SimpleMatrixKit
    @testable import SwiftCluster

    final class SwiftClusterTests: XCTestCase {
        
        func testExample() {
            guard let fileURL = URL(string: "https://raw.githubusercontent.com/eheitfield/SwiftCluster/main/Sources/Docs/test_image_data.csv"),
                  let fileData = try? String(contentsOf: fileURL) else {
                preconditionFailure("Unable to read image data.")
            }
            let pixels = fileData
                .components(separatedBy: CharacterSet.newlines)
                .compactMap { line -> [Double]? in
                    let channels = line.components(separatedBy: ", ")
                        .compactMap { Double($0) }
                    guard channels.count == 3 else { return nil }
                    return channels
                }
            let pixelColorData = Matrix(array2D: pixels)
            let model = ClusterModel(
                data: pixelColorData,
                numberOfGroups: 8,
                initializationRule: .av,
                stoppingRules: [.distanceChange(percent: 0.01), .iterations(maximum: 15)],
                showDiagnostics: true
            )
            let (groupIDs, meanColors) = model.run()
            let pixelPosterizedColors = groupIDs.map{ meanColors.getRow($0) }
            print(pixelPosterizedColors)
        }
    }
