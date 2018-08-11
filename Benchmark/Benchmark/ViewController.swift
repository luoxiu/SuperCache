//
//  ViewController.swift
//  Benchmark
//
//  Created by Quentin Jin on 2018/8/9.
//  Copyright © 2018年 Quentin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

//        refCache()
//        valCache()

        DispatchQueue.main.async {
            memoryCacheBenchmark()
        }
    }

    func refCache() {
        let cache = MemoryCache<String, C>()

        cache.set(C(1), forKey: "1")
        print(cache.object(forKey: "1")!.c)
        cache.set(C(2), forKey: "1")
        print(cache.object(forKey: "1")!.c)
        cache.set(C(3), forKey: "3")
        print(cache.object(forKey: "3")!.c)
    }

    func valCache() {
        let cache = MemoryCache<String, S>()

        cache.set(S(1), forKey: "1")
        print(cache.object(forKey: "1")!.s)
        cache.set(S(2), forKey: "1")
        print(cache.object(forKey: "1")!.s)
        cache.set(S(3), forKey: "3")
        print(cache.object(forKey: "3")!.s)
    }
}

class C {
    var c: Int
    init(_ c: Int) {
        self.c = c
    }
}

struct S {
    var s: Int
    init(_ s: Int) {
        self.s = s
    }
}
