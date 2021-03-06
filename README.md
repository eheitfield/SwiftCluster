# SwiftCluster

## Overview

This package supports [k-means cluster analysis](https://en.wikipedia.org/wiki/K-means_clustering) in Swift. Cluster analysis involves sorting a large number of observations into a much smaller number of statistically similar groups.  It is most commonly used for exploratory data analysis, but also has application in data compression, image processing, and machine learning.

Clustering data with SwiftCluster involves three steps. First, input data must be organized into  an *n* x *m* matrix of `Double`s where each row corresponds to an observation and each column corresponds to a variable.  For details on the matrix structures used by SwiftCluster, see [SimpleMatrixKit](https://github.com/eheitfield/SimpleMatrixKit.git).   Second, a `ClusterModel` struct is configured with the input data matrix and other parameters defining how the cluster analysis should be run.  Finally, the `ClusterModel` struct's `run()` method is called to perform the analysis.  `run()` returns an *n*-element `Int` array of group identifiers arranged in the same order as the input data and a *k* x *m* matrix of mean variable values for each group. 

## Algorithm Options

K-means cluster analysis attempts to group *n* observations on *m* variables into *k* clusters that minimizes the distance between observations within each cluster. An iterative optimization algorithm is used to minimize within-group mean distances.  Observations are first sorted into *k* initial clusters.  The center of each group -- the group centroid -- is then is computed as the *m*-vector of variable means for members of the group.  Next, the distance from of the *n* observations to each of the *k* centroids is computed and each observation is reassigned to the group it is closest to.  Group centroids are then recomputed and the process is repeated until a convergence criteria is satisfied.  Importantly, this algorithm in not invariant to how groups are initialized; different initial group assignments may lead to different final clusters. In addition, the convergence criteria used to stop the algorithm can have a significant effect on how long the algorithm takes to run and on the quality of the final result. SwiftCluster includes options for specifying both group initialization rules and convergence criteria.  

### Initialization Rules

The enum `ClusterModel.InitializationRule` lists three algorithms that can be used to assign observations to starting clusters.
*   `.randomPartitions` -- Each observation is randomly assigned to one of *k* equal-sized groups.
*   `.forgy` -- *k* initial observations are drawn at random from the dataset. Each of the other *k-n* observations is then grouped with the initial observation it is closest to. In contrast to random partitions, the initial groups created using the Forgy algorithm may have very different sizes.
*   `.av` -- The Arthur-Vassilvetskii algorithm is similar to the Forgy algorithm but captures the idea that the analysis may be more robust if the initial groups are chosen to be as different from one another as possible.  *k* initial observations are randomly drawn using a weighting scheme that is biased toward selecting observations that are farther apart.

Each of these initialization methods has distinct advantages and disadvantages. The [Wikipedia page](https://en.wikipedia.org/wiki/K-means_clustering) on k-means cluster analysis includes a useful discussion of practical considerations involved in choosing among them.

### Stopping rules

There is no practical way to determine whether the iterative k-means algorithm has reached a global minimum. In practice the algorithm is run until a pre-specified stopping rule is satisfied. The enum `ClusterModel.StopRule` lists three rules that can be used alone or in combination to determine when the algorithm should be terminated.
*   `.distanceChange(percent: Double)` -- The algorithm ends when the percentage change in the average within-group mean distance from one iteration to the next  falls below `percent:` where `percent:` is expressed as a decimal value between 0.0 and 1.0.
*   `.iterations(maximum: Int)` -- The algorithm ends after `maximum:` iterations.
*   `.runTime(seconds: Double)` -- The algorithm repeats until `seconds:` have elapsed.

`ClusterModel` initializers take a set of stopping rules. If more than one rule is included, the algorithm will run until any of the listed criteria are satisfied. For example, if `ClusterModel` is initialized with `[.iterations(maximum: 10), .runTime(seconds: 5.0)]` the algorithm will run for 10 iterations or 5 seconds, whichever comes first.

### Random Number Generators

All of the initialization rules described above involve randomly assigning observations to groups.  By default, `ClusterModel`'s `run()` method uses `SystemRandomNumberGenerator` to draw random samples.  Alternatively, a user-supplied generator conforming to the Swift Standard Library's `RandomNumberGenerator` protocol can be used by calling `ClusterModels`'s `run(using generator:)` method.  

For convenience, SwiftCluster includes `SeededRandomNumberGenerator`, a rudimentary linear congruential generator that is initialized with a `UInt32` seed value.  This generator produces a consistent sequence of pseudorandom numbers for a given seed, which can be useful for testing and replication purposes. Note, however, that `SeededRandomNumberGenerator` is not as robust as `SystemRandomNumberGenerator` and it should not be used in situations where a very long sequence of random numbers is needed.

## Usage Example

The image below is a 50 x 50 bitmap of a photo of a peony I took at the [United States Botanical Garden](https://www.usbg.gov) in Washington, DC.  

![Peony](https://github.com/eheitfield/SwiftCluster/blob/main/Sources/Docs/peony.jpeg)

In this example we will use SwiftCluster to create a "posterized" version the image in which the hundreds of distinct colors in the original image are replaced with just eight representative colors.

The file [test_image_data.csv](https://github.com/eheitfield/SwiftCluster/blob/main/Sources/Docs/test_image_data.csv) contains red, green, and blue color channel levels for each of the 2,500 pixels in the peony image.  The code snippet below loads the csv data into a 2500 x 3 matrix in which the rows corresponds pixels and the columns correspond to the three color channels.
```
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
```
Having organized our data into a format that SwiftCluster can understand, we next configure an instance of `ClusterModel`, which will be responsible for performing the analysis.
```
let model = ClusterModel(
    data: pixelColorData,
    numberOfGroups: 8,
    initializationRule: .av,
    stoppingRules: [.distanceChange(percent: 0.01), .iterations(maximum: 15)],
    showDiagnostics: true
)
```
`model` is configured to group the color data into eight clusters.  Groups are initialized using the Arthur-Vassilvetskii. algorithm  The optimization routine is set to end after 15 iterations or when the within-cluster mean criteria improves by less than one percent.

We can now run the analysis and store our results.
```
let (groupIDs, meanColors) = model.run()
```
Since we have set `showDiagnostics` to `true`, the method logs information on optimization progress to the console.
```
Starting cluster analysis of 2500 observations in 8 groups.
Iter.    Dist.    %Cng.     Time
    1  9.3e+02 1.9e+307     1.08
    2  8.2e+02       13     1.31
    3    8e+02      3.2     1.56
    4  7.9e+02      1.1      1.8
    5  7.8e+02     0.99     2.02
Reached minimum change threshold.
Finished
2.0303 Seconds
```

`groupIDs` is a 2,500 element `Int` array.  Each element of the array corresponds to one of the rows of `pixelColorData` and contains an integer between 0 and 7 indicating the group to which the pixel belongs.  `meanColors` is an 8 x 3 `Matrix<Double>` where each row corresponds to one of the eight clusters and the columns contain mean red, green, and blue color channel values for each group.  The identifiers in `groupIDs` are matched to the rows of `meanColors` so we can create a synthetic dataset of posterized pixel color information as follows:
```
let pixelPosterizedColors = groupIDs.map{ meanColors.getRow($0) }
```
When the pixel colors represented in `pixelPosterizedColors` are arranged on a 50 x 50 grid, the resulting posterized image looks like this.

![Posterized Peony](https://github.com/eheitfield/SwiftCluster/blob/main/Sources/Docs/peony_8_colors.jpeg)

## License

This project is licensed under the terms of the MIT license.

