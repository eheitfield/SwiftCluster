//
//  File.swift
//  
//
//  Created by Erik Heitfield on 7/4/21.
//

import Foundation

/// A pseudorandom number generator that takes an initial seed.
///
/// **This random number generator is not cryptographically secure. It
/// is provided as a convenience for replication and testing purposes; it should
/// not be used in applications where very long sequences of pseudorandom numbers
/// are required.**
///
/// This struct implements a simple linear congruential generator (LCG). LCG
/// parameters suggested by Numerical Recipes for 32-bit numbers are used to
/// create a pair of 32-bit pseudorandom draws, which are then concatenated
/// to produce a 64-but pseudorandom draw compatible with `RandomNumberGenerator`
/// protocol.
public struct SeededRandomNumberGenerator: RandomNumberGenerator {

    private var currentValue: UInt32
    
    public init(seed: UInt32) {
        self.currentValue = seed
    }
    
    public mutating func next() -> UInt64 {
        let next1 = next32BitLCG(x: UInt64(currentValue))
        let next2 = next32BitLCG(x: next1)
        self.currentValue = UInt32(next2 % UInt64(UInt32.max))
        return  next1 ^ (next2 << 32)
    }
    
    private func next32BitLCG(x: UInt64) -> UInt64 {
        // 32 bit LCG parameters from Numerical Recipes
        let a: UInt64 = 1664525
        let c: UInt64 = 1013904332
        let m: UInt64 = UInt64(UInt32.max)+1
        return (a*x + c) % m
    }
    
    
}
