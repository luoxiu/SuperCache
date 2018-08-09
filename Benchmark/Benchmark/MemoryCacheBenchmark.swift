//
//  MemoryCache.swift
//  Benchmark
//
//  Created by Quentin Jin on 2018/8/9.
//  Copyright © 2018年 Quentin. All rights reserved.
//

import Foundation
import YYCache
import PINCache

func memoryCacheBenchmark() {
    
    let cache = MemoryCache<String, NSNumber>()
    let nscache = NSCache<NSString, NSNumber>()
    let yycache = YYMemoryCache()
    let pincache = PINMemoryCache()
    
    var keys: [String] = []
    var values: [NSNumber] = []
    
    let count = 200000;
    count.times {
        keys.append("\($0)")
        values.append(NSNumber(integerLiteral: $0))
    }

    // MARK: Memory cache set 200000 key-value pairs
    print("\nMemory cache set 200000 key-value pairs\n")
    measure("cache") {
        count.times { i in
            cache.set(values[i], forKey: keys[i])
        }
    }

    measure("nscache") {
        count.times { i in
            nscache.setObject(values[i], forKey: keys[i] as NSString)
        }
    }

    measure("yycache") {
        count.times { i in
            yycache.setObject(values[i], forKey: keys[i] as NSString)
        }
    }

    measure("pincache") {
        count.times { i in
            pincache.setObject(values[i], forKey: keys[i])
        }
    }
    
    // MARK: Memory cache set 200000 key-value pairs without resize
    print("\nMemory cache set 200000 key-value pairs without resize\n");
    measure("cache") {
        count.times { i in
            cache.set(values[i], forKey: keys[i])
        }
    }

    measure("nscache") {
        count.times { i in
            nscache.setObject(values[i], forKey: keys[i] as NSString)
        }
    }

    measure("yycache") {
        count.times { i in
            yycache.setObject(values[i], forKey: keys[i] as NSString)
        }
    }

    measure("pincache") {
        count.times { i in
            pincache.setObject(values[i], forKey: keys[i])
        }
    }

    // MARK: Memory cache get 200000 key-value pairs
    print("\nMemory cache get 200000 key-value pairs\n")
    measure("cache") {
        count.times { i in
            _ = cache.object(forKey: keys[i])
        }
    }

    measure("nscache") {
        count.times { i in
            _ = nscache.object(forKey: keys[i] as NSString)
        }
    }

    measure("yycache") {
        count.times { i in
            _ = yycache.object(forKey: keys[i] as NSString)
        }
    }

    measure("pincache") {
        count.times { i in
            _ = pincache.object(forKey: keys[i])
        }
    }

    // MARK: Memory cache get 200000 key-value pairs randomly
    print("\nMemory cache get 200000 key-value pairs randomly\n");

    keys.count.times { i in
        keys.swapAt(i, Int(arc4random_uniform(UInt32(i))))
    }

    measure("cache") {
        count.times { i in
            _ = cache.object(forKey: keys[i])
        }
    }

    measure("nscache") {
        count.times { i in
            _ = nscache.object(forKey: keys[i] as NSString)
        }
    }

    measure("yycache") {
        count.times { i in
            _ = yycache.object(forKey: keys[i] as NSString)
        }
    }

    measure("pincache") {
        count.times { i in
            _ = pincache.object(forKey: keys[i])
        }
    }
    
    // MARK: Memory cache get 200000 key-value pairs none exist
    print("\nMemory cache get 200000 key-value pairs none exist\n")

    count.times { i in
        keys.append("\(count + i)")
    }

    keys.count.times { i in
        keys.swapAt(i, Int(arc4random_uniform(UInt32(i))))
    }

    measure("cache") {
        count.times { i in
            _ = cache.object(forKey: keys[i])
        }
    }

    measure("nscache") {
        count.times { i in
            _ = nscache.object(forKey: keys[i] as NSString)
        }
    }

    measure("yycache") {
        count.times { i in
            _ = yycache.object(forKey: keys[i] as NSString)
        }
    }

    measure("pincache") {
        count.times { i in
            _ = pincache.object(forKey: keys[i])
        }
    }

    print("========== end ==========")
}


