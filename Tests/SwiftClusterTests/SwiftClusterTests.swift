    import XCTest
    import SimpleMatrixKit
    @testable import SwiftCluster

    final class SwiftClusterTests: XCTestCase {
        
        
        /// Kolmogorov-Smirnov test statistic discrete uniform distribution
        /// - Parameters:
        ///   - x: array test data
        ///   - lb: lower bound of uniform distribution
        ///   - ub: upper bound of uniform distribution
        ///   - bins: number of bins in KS test
        /// - Returns: KS test statistic
        func ksTestUniform(x: [Int], lb: Int, ub: Int, bins: Int) -> Double {
            let uX = x.map { Double($0-lb)/Double(ub-lb) }
            let n = Double(uX.count)
            let dist = (0..<bins).map { i -> Double in
                let f = Double(i)/Double(bins)
                let freq = uX.reduce(Double(0.0)) { $0 + ( $1 < f ? 1.0 : 0.0 ) }
                return abs( (freq / n) - f )
            }
            return dist.max() ?? 1.0
        }
        
        func testSeededRNG() {
            let n = 10000
            let ub = 100000
            let lb = 0
            let bins = 300
            let seed: UInt32 = 89354
            var g = SeededRandomNumberGenerator(seed: seed)
            var rnd = [Int]()
            for _ in 0..<n {
                rnd.append(Int.random(in: lb..<ub, using: &g))
            }
            let ks = ksTestUniform(x: rnd, lb: lb, ub: ub, bins: bins)
            let p05crit = 1.36/Double(bins).squareRoot()
            print("Test of uniform random draws")
            print("K-S Test Statistic: \(ks)")
            print("5 precent critical value: \(p05crit)")
            XCTAssertLessThan(ks, p05crit)
        }
        
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
