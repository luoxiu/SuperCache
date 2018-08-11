# SuperCache

Extremely fast memory cache, written in Swift.

## Features

- Hashable Key
- Ref/Val Type Value
- Similar Syntax to NSCache
- Cost, Count, Age Limit
- LRU
- Thread Safe
- Pure Swift
- Extremely Fast 🚀🚀🚀🚀🚀

## Benchmark

<p align="center">
<img src="https://raw.githubusercontent.com/jianstm/Hanna/master/Images/benchmark.png" width="700">
</p>

## Usage

```swift
let cache = MemoryCache<String, HeavyObject>()

cache.maxCount = 10000
cache.maxCost = 20 * 10000
cache.maxAge = 10 * 3600

cache.set(obj, forKey: "1", cost: 20)

let obj = cache.object(forKey: "1")

cache.removeObject(forKey: "1")
```

## Contributing

Hanna is now a very naive framework, any help is welcome! You can open a issue on github and email me directly!

## Roadmap

- [ ] DiskCache

## More About SuperCache

[用 Swift 写一个更快的 iOS 内存缓存](https://v2ambition.com/2018/08/write-a-faster-memory-cache-for-swift/)

## Acknowledgement

MemoryCache part is heavily inspired by [YYCache](https://github.com/ibireme/YYCache), but much faster.  : ]

