//
//  Utils.swift
//  Benchmark
//
//  Created by Quentin Jin on 2018/8/9.
//  Copyright © 2018年 Quentin. All rights reserved.
//

import Foundation

func measure(_ name: String, _ work: () -> Void) {
    let ts = CFAbsoluteTimeGetCurrent()
    work()
    print(name.pad(to: 8), ": ", CFAbsoluteTimeGetCurrent() - ts)
}

extension Int {

    func times(_ body: (Int) -> Void) {
        guard self > 0 else { return }
        for i in 0..<self { body(i) }
    }
}

extension String {

    func pad(to length: Int) -> String {
        if count >= length { return self }
        var str = self
        (length - count).times { _ in
            str.append(" ")
        }
        return str
    }
}