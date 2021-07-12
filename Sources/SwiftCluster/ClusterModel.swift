//
//  ClusterModel.swift
//  
//
//  Created by Erik Heitfield on 6/29/21.
//

import Foundation
import SimpleMatrixKit

/// Model object used to perform k-means cluster analysis on a dataset.
///
/// Parameters of the clustering algorithm are defined when the object
/// is instantiated.  The cluster analysis performed by calling ``run``.
///
/// Depending on the size of the dataset algorithm parameters the analysis
/// can take several seconds to run, so I recommend calling ``run`` on a
/// background thread.
public struct ClusterModel {
    
    /// Options for ending cluster analysis
    public enum StopRule: Hashable {
        // Run a fixed number of times
        case iterations(maximum: Int )
        // Run until a percentage change in mean distance falls
        // below the specified threshold.
        case distanceChange(percent: Double )
        // Stop when elapsed time exceeds a threshold in seconds.
        case runTime(seconds: Double )
    }
    
    /// Options for setting up starting groups
    public enum InitializationRule {
        // Split observations into K groups and use centroid for each
        // group as the starting centroids.
        case randomPartitions
        // Forgy algorithm:
        // Select K observations as starting centroid.
        case forgy
        // Arthur & Vassilvitskii algorithm:
        // Select k observations as starting centroids with a method
        // weighted towards observations that are farther apart (K-means++)
        case av
    }
    
    /// Input data matrix where each row is an observation and each column is a variable.
    public let data: Matrix<Double>
    
    /// Number of cluster groups (usually denoted K)
    public let nGroups: Int
    
    /// All applicable stopping rule.
    ///
    /// The algorithm will stop when any of the listed rules are satisfied
    public let stoppingRules: Set<StopRule>
    
    /// Rule used to group observations into initial sets
    public let initializationRule: InitializationRule
    
    /// Set to true print algorithm progress data
    public let showDiagnostics: Bool
    
    /// Number of observations
    public var nObservations: Int { return data.rows }
    
    /// Number of variables
    public var nAttributes: Int { return data.cols }
    
    /// List of group IDs
    public var allGroupIDs: Range<Int> { return 0..<nGroups }
    
    /// Create a new cluster model
    /// - Parameters:
    ///   - data: n x m matrix where each row is an observation and each column is a variable
    ///   - numberOfGroups: desired number of clusters
    ///   - initializationRule: algorithm for creating starting clusters
    ///   - stoppingRules: set of conditions for terminating optimization
    ///   - showDiagnostics: flag to log progress to the console
    public init(data: Matrix<Double>,
         numberOfGroups: Int,
         initializationRule: InitializationRule = .randomPartitions,
         stoppingRules: Set<StopRule> = [.distanceChange(percent: 0.01)],
         showDiagnostics: Bool = false
    ) {
        guard !data.isEmpty else {
            preconditionFailure("ClusterModel initialized with no data.")
        }
        self.data = data
        self.nGroups = numberOfGroups
        self.initializationRule = initializationRule
        self.stoppingRules = stoppingRules.isEmpty ? [.distanceChange(percent: 0.01)] : stoppingRules
        self.showDiagnostics = showDiagnostics
    }
    
    /// Run cluster analysis
    /// - Returns: (groups,groupMeans)
    ///     - groups: n-array of group IDs for each observation
    ///     - groupMeans: n x k matrix of group centroids
    ///
    /// Each ID in `groups` is an integer from 0 to k-1 corresponding
    /// one of the rows of `groupMeans`.
    public func run() -> (groups: [Int], groupMeans: Matrix<Double>) {
        var generator = SystemRandomNumberGenerator()
        return self.run(using: &generator)
    }
    
    
    /// Run cluster analysis
    /// - Parameter generator: a user supplied random number generator
    /// - Returns: (groups,groupMeans)
    ///     - groups: n-array of group IDs for each observation
    ///     - groupMeans: n x k matrix of group centroids
    ///
    /// Each ID in `groups` is an integer from 0 to k-1 corresponding
    /// one of the rows of `groupMeans`.
    public func run<G: RandomNumberGenerator>(using generator: inout G) -> (groups: [Int], groupMeans: Matrix<Double>) {
        let startTimeTic = DispatchTime.now().uptimeNanoseconds
        var elapsedTIme: Double {
            Double(DispatchTime.now().uptimeNanoseconds - startTimeTic)/1.0e9
        }
        if showDiagnostics {
            print("Starting cluster analysis of \(nObservations) observations in \(nGroups) groups.")
            print("Iter.    Dist.    %Cng.     Time")
        }
        var oldMeanDistance = Double.greatestFiniteMagnitude
        var groups = createStartingGroups(using: &generator)
        var iter = 0
        var endIterations = false
        while !endIterations {
            iter += 1
            let groupMeans = self.groupMeans(groups)
            let distances = rowDistance(m1: data, m2: groupMeans)
            let distToNewGroup = distances.allRows.map { return minWithIndex(a: $0) }
            groups = distToNewGroup.map { $0.1 }
            let meanDistance = distToNewGroup
                .map { $0.0 }
                .reduce(0.0, { $0 + $1 } ) / Double(nObservations)
            let distChange = (oldMeanDistance-meanDistance)/meanDistance
            oldMeanDistance = meanDistance
            if showDiagnostics {
                let outStr = String(
                    format: "%5d %8.2g %8.2g %8.3g",
                    iter,
                    meanDistance,
                    distChange*100,
                    elapsedTIme
                )
                print(outStr)
            }
            groups = rebalancedGroups(groups)
            for stopRule in stoppingRules {
                switch stopRule {
                case .iterations(let maxIter):
                    endIterations = iter >= maxIter
                    if endIterations && showDiagnostics {
                        print("Reached maximum iterations.")
                    }
                case .distanceChange(let changeThreshold):
                    endIterations = distChange < changeThreshold
                    if endIterations && showDiagnostics {
                        print("Reached minimum change threshold.")
                    }
                case .runTime(let maxRunTime):
                    endIterations = elapsedTIme > maxRunTime
                    if endIterations && showDiagnostics {
                        print("Reached maximum run time.")
                    }
                }
                if endIterations { break }
            }
        }
        if showDiagnostics {
            print(String(format: "Finished\n%.5g Seconds", elapsedTIme))
        }
        return (groups, groupMeans(groups))
    }
    
    /// Compute centroid for each group
    /// - Parameter groups: group ID for each observation
    /// - Returns: N x K matrix of group means
    private func groupMeans(_ groups: [Int]) -> Matrix<Double> {
        let groupMeans = allGroupIDs.compactMap { groupID -> [Double]? in
            let dataInGroup = zip(groups,data.allRows)
                .filter { $0.0==groupID }
                .map { $0.1 }
            if dataInGroup.count > 0 {
                return columnMeans(m: Matrix(array2D: dataInGroup))
            } else {
                return nil
            }
        }
        return Matrix(array2D: groupMeans)
    }
    
    /// If some groups have no members splits the largest group in two.  Repeats
    /// until all groups have nonzero members
    /// - Parameter groups: list of group IDs where some groups may have zero members
    /// - Returns: list of groups where all groups have some members
    private func rebalancedGroups(_ groups: [Int]) -> [Int] {
        guard nGroups < 2*data.rows else { return groups }
        var groups = groups
        var groupCounts = (0 ..< nGroups).map { i in
            groups.reduce(0) { $0 + ($1==i ? 1 : 0) }
        }
        while groupCounts.contains(0) {
            let emptyGroup = groupCounts.firstIndex { $0 == 0 }!
            let largestGroup = groupCounts.firstIndex { $0 == groupCounts.max() }!
            var swap = true
            for (i,g) in groups.enumerated() {
                if g == largestGroup {
                    swap.toggle()
                    if swap { groups[i] = emptyGroup }
                }
            }
            groupCounts = (0 ..< nGroups).map { i in
                groups.reduce(0) { $0 + ($1==i ? 1 : 0) }
            }
        }
        return groups
    }
    
    /// Assign observations to initial groups
    /// - Returns: N array of group IDs for each observation
    private func createStartingGroups<G: RandomNumberGenerator>(using generator: inout G) -> Array<Int> {
        var groups = [Int]()
        switch initializationRule {
        case .randomPartitions:
            for i in 0 ..< data.rows {
                groups.append(i % nGroups)
            }
            groups.shuffle(using: &generator)
        case .forgy:
            let sampleIndexes = Array((0..<data.rows).shuffled())[0..<nGroups]
            let groupMeans = Matrix(array2D:
                                        data.allRows.enumerated()
                                        .compactMap { (index,element) -> [Double]? in
                                            return sampleIndexes.contains(index) ? element : nil
                                        }
            )
            let distances = rowDistance(m1: data, m2: groupMeans)
            let distToNewGroup = distances.allRows.map { return minWithIndex(a: $0) }
            groups = distToNewGroup.map { $0.1 }
        case .av:
            var meanRows = [data.allRows[Int.random(in: 0..<data.rows, using: &generator)]]
            while meanRows.count < nGroups {
                let distances = rowDistance(m1: data, m2: Matrix(array2D: meanRows))
                let weights = distances.allRows.map { d -> Double in
                    if d.contains(0.0) {
                        return 0.0
                    } else {
                        let d2 = d.max() ?? 0.0
                        return d2*d2
                    }
                }
                meanRows.append(data.allRows[Int.random(weights: weights, generator: &generator)])
            }
            let distances = rowDistance(m1: data, m2: Matrix(array2D: meanRows))
            let distToNewGroup = distances.allRows.map { return minWithIndex(a: $0) }
            groups = distToNewGroup.map { $0.1 }
        }
        return groups
    }
    
    /// Compute distances between all pairs of rows of two matrices
    /// - Parameters:
    ///   - m1: N1 x K matrix
    ///   - m2: N2 x K matrix
    /// - Returns:  N1 X N2 matrix where the i,j element is the euclidian distance from
    ///             the ith row of m1 to the jth row of m2
    private func rowDistance(m1: Matrix<Double>, m2: Matrix<Double>) -> Matrix<Double> {
        guard m1.cols == m2.cols else {
            fatalError("Attempted to compute distances for nonconformable matrixes")
        }
        var result = Matrix(rows: m1.rows, cols: m2.rows, constantValue: 0.0)
        for (i,rowVec1) in m1.allRows.enumerated() {
            for (j,rowVec2) in m2.allRows.enumerated() {
                result[i,j] = (0..<m1.cols)
                    .map { pow(rowVec1[$0]-rowVec2[$0],2) }
                    .reduce(0.0) { $0+$1 }
            }
        }
        return result
    }
    
    /// Compute means of each column of a matrix
    /// - Parameter m: N x K matrix
    /// - Returns: K array of column means
    private func columnMeans(m: Matrix<Double>) -> [Double] {
        let cumsum = m.reduce(Array(repeating: 0.0, count: m.cols)) { cumRows, nextRow in
            return zip(cumRows,nextRow).map { $0.0 + $0.1 }
        }
        return cumsum.map { $0/Double(m.rows) }
    }
    
    /// Compute the value and index of the smallest element of an array
    /// - Parameter a: an array od data
    /// - Returns: (smallest value, index of smallest value)
    private func minWithIndex(a: [Double]) -> (minValue: Double, minIndex: Int) {
        guard let result = a.enumerated().min(by: { $0.1 < $1.1 }) else {
            fatalError("Attempted to find minimum of empty array.")
        }
        return (result.1,result.0)
    }
        
}



fileprivate extension Int {
    
    /// Returns a random integer drawn from an arbitrary discrete distribution.
    /// - Parameters:
    ///   - weights: array of probability weights for each integer in the range ``0..<weights.count``
    ///   - generator: a random number generator
    /// - Returns: random integer in the range ``0..<weights.count``
    static func random<G: RandomNumberGenerator>(weights: [Double], generator: inout G) -> Int {
        guard weights.count > 1 else { return 0 }
        var cumWeights = [weights[0]]
        for i in 1..<weights.count {
            cumWeights.append(cumWeights[i-1]+weights[i])
        }
        let totalWeights = cumWeights.last!
        guard totalWeights > 0 else { return 0 }
        let u = Double.random(in: 0.0...1.0, using: &generator)
        return cumWeights.firstIndex { ($0/totalWeights) > u } ?? cumWeights.count - 1
    }
    
}

