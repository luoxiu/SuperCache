//
//  MemoryCache.swift
//  SupperCache
//
//  Created by Quentin Jin on 2018/8/8.
//

import Foundation

// MARK: - Bogs

private typealias PtrBits = Int

private struct Entry {
    var prev: PtrBits = 0
    var next: PtrBits = 0
    
    var key: Int
    var value: PtrBits
    
    var cost: UInt
    var timestamp: UInt      // ns
    
    init(key: Int, value: PtrBits, cost: UInt, timestamp: UInt) {
        self.key = key
        self.value = value
        self.cost = cost
        self.timestamp = timestamp
    }
}

private extension PtrBits {
    
    @inline(__always)
    private func get(_ offset: Int) -> Int {
        guard let rawPtr = UnsafeRawPointer(bitPattern: self) else { return 0 }
        let ptr = rawPtr.advanced(by: offset).assumingMemoryBound(to: Int.self)
        return ptr.pointee
    }
    
    @inline(__always)
    private func set(_ new: Int, _ offset: Int) {
        guard let rawPtr = UnsafeRawPointer(bitPattern: self) else { return }
        let ptr = rawPtr.advanced(by: offset).assumingMemoryBound(to: Int.self)
        UnsafeMutablePointer(mutating: ptr).initialize(to: new)
    }
    
    var prev: PtrBits {
        get { return get(0) }
        set { set(newValue, 0) }
    }
    
    var next: PtrBits {
        get { return get(8) }
        set { set(newValue, 8) }
    }
    
    var key: Int {
        get { return get(16) }
        set { set(newValue, 16) }
    }
    
    var value: PtrBits {
        get { return get(24) }
        set { set(newValue, 24) }
    }
    
    var cost: UInt {
        get { return UInt(bitPattern: get(32)) }
        set {
            set(Int(bitPattern: newValue), 32)
        }
    }
    var timestamp: UInt {
        get { return UInt(bitPattern: get(40)) }
        set { set(Int(bitPattern: newValue), 40) }
    }
}


private class Box<T> {
    var val: T
    init(_ val: T) { self.val = val }
}

private var _intKeyCallBacks = CFDictionaryKeyCallBacks(version: 0,
                             retain: nil,
                             release: nil,
                             copyDescription: nil,
                             equal: { (p1, p2) -> DarwinBoolean in
                                return p1 == p2 ? true : false
                             },
                             hash: { (p) -> CFHashCode in
                                return CFHashCode(bitPattern: p)
                             })

private var _entryValueCallBacks = CFDictionaryValueCallBacks(version: 0,
                               retain: { (allocator, ptr) -> UnsafeRawPointer? in
                               guard let ptr = ptr else { return nil }
                                   let newPtr = CFAllocatorAllocate(allocator, 48, 0)
                                   newPtr?.copyMemory(from: ptr, byteCount: 48)
                                   return UnsafeRawPointer(newPtr)
                               },
                               release: { (allocator, ptr) in
                                   CFAllocatorDeallocate(allocator, UnsafeMutableRawPointer(mutating: ptr))
                               },
                               copyDescription: nil,
                               equal: nil)


// MARK: - Cache
open class MemoryCache<Key: Hashable, Value> {

    open private(set) var name: String
    open private(set) var dispose: (Value) -> Void

    open var maxCount = UInt.max
    open var maxCost = UInt.max
    open var maxAge = TimeInterval.greatestFiniteMagnitude

    open private(set) var totalCount: UInt = 0
    open private(set) var totalCost: UInt = 0

    private var _head: PtrBits = 0
    private var _tail: PtrBits = 0

    private var _dict = CFDictionaryCreateMutable(nil, 0, &_intKeyCallBacks, &_entryValueCallBacks)
    
    private var _lock = os_unfair_lock()

    private let _isVal: Bool
    
    private let _timer = DispatchSource.makeTimerSource()
    
    init(name: String = "", dispose: @escaping (Value) -> Void = { _ in }) {
        self._isVal = Value.self is AnyClass
        self.name = name
        self.dispose = dispose
        
        self._timer.setEventHandler {
            DispatchQueue.global().async { self.trim(toAge: self.maxAge) }
        }
        self._timer.schedule(deadline: .now() + .seconds(5), repeating: .seconds(5), leeway: .seconds(1))
        self._timer.activate()
    }
    
    deinit {
        _timer.cancel()
    }

    // MARK: Linked List
    private func _enqueue(_ ptrBits: inout PtrBits) {
        totalCost += ptrBits.cost
        totalCount += 1
        CFDictionarySetValue(_dict, UnsafeRawPointer(bitPattern: ptrBits.key), UnsafeRawPointer(bitPattern: ptrBits))
        if _tail == 0 {
            _head = ptrBits
            _tail = ptrBits
        } else {
            _tail.next = ptrBits
            ptrBits.prev = _tail
            _tail = ptrBits
        }
    }
    
    private func _dequeue() -> PtrBits {
        if _head == 0 { return 0 }
        defer {
            totalCost -= _head.cost
            totalCount -= 1
            CFDictionaryRemoveValue(_dict, UnsafeRawPointer(bitPattern: _head.key))
            if (_head == _tail) {
                _head = 0
                _tail = 0
            } else {
                _head = _head.next
                _head.prev = 0
            }
        }
        return _head
    }
    
    private func _delete(_ ptrBits: inout PtrBits) {
        totalCost -= ptrBits.cost
        totalCount -= 1
        CFDictionaryRemoveValue(_dict, UnsafeRawPointer(bitPattern: ptrBits.key))
        if ptrBits.prev != 0 {
            ptrBits.prev.next = ptrBits.next
        }
        if ptrBits.next != 0 {
            ptrBits.next.prev = ptrBits.prev
        }
        if _head == ptrBits { _head = ptrBits.next }
        if _tail == ptrBits { _tail = ptrBits.prev }
    }

    private func _bubble(_ ptrBits: inout PtrBits) {
        if _tail == ptrBits { return }
        if _head == ptrBits {
            _head = ptrBits.next
            _head.prev = 0
        } else {
            ptrBits.prev.next = ptrBits.next
            ptrBits.next.prev = ptrBits.prev
        }
        ptrBits.prev = _tail
        ptrBits.next = 0
        _tail.next = ptrBits
        _tail = ptrBits
    }

    private func _clear() {
        totalCost = 0
        totalCount = 0
        _head = 0
        _tail = 0
        if CFDictionaryGetCount(_dict) > 0 {
            let tmp = _dict
            _dict = CFDictionaryCreateMutable(nil, 0, &_intKeyCallBacks, &_entryValueCallBacks)
            DispatchQueue.global(qos: .background).async {
                let count = CFDictionaryGetCount(tmp)
                let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: count)
                CFDictionaryGetKeysAndValues(tmp, nil, values)
                for i in 0..<count {
                    self._dispose(PtrBits(bitPattern: values.advanced(by: i).pointee).value)
                }
            }
        }
    }

    private func _dispose(_ ptrBits: PtrBits) {
        if let rawPtr = UnsafeRawPointer(bitPattern: ptrBits) {
            let unmanaged = Unmanaged<AnyObject>.fromOpaque(rawPtr)
            if self._isVal {
                self.dispose((unmanaged.takeRetainedValue() as! Box<Value>).val)
            } else {
                self.dispose(unmanaged.takeRetainedValue() as! Value)
            }
        }
    }

    // MARK: Cache
    open var count: Int {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return CFDictionaryGetCount(_dict)
    }

    open func set(_ value: Value, forKey key: Key, cost: UInt = 0) {
        var valuePtrBits: Int
        if _isVal {
            let rawPtr = Unmanaged.passRetained(Box(value)).toOpaque()
            valuePtrBits = Int(bitPattern: rawPtr)
        } else {
            let rawPtr = Unmanaged<AnyObject>.passRetained(value as AnyObject).toOpaque()
            valuePtrBits = Int(bitPattern: rawPtr)
        }

        let hash = key.hashValue
        let now = clampAge((CFAbsoluteTimeGetCurrent() * Double(NSEC_PER_SEC)))

        os_unfair_lock_lock(&_lock)
        if let entryPtr = CFDictionaryGetValue(_dict, UnsafeRawPointer(bitPattern: hash)) {
            var entryPtrBits = Int(bitPattern: entryPtr)
            totalCost -= UInt(entryPtrBits.cost)
            totalCost += cost
            entryPtrBits.cost = cost
            entryPtrBits.timestamp = now
            entryPtrBits.value = valuePtrBits
            _bubble(&entryPtrBits)
        } else {
            var new = Entry(key: hash, value: valuePtrBits, cost: cost, timestamp: now)
            withUnsafePointer(to: &new) { (ptr) in
                var ptrBits = Int(bitPattern: ptr)
                _enqueue(&ptrBits)
            }
        }
        if totalCost > maxCost {
            DispatchQueue.global(qos: .background).async {
                self.trim(toCost: self.maxCost)
            }
        }
        if totalCount > maxCount {
            DispatchQueue.global(qos: .background).async {
                self._dispose(self._dequeue().value)
            }
        }
        os_unfair_lock_unlock(&_lock)
    }

    open func removeObject(forKey key: Key) {
        let hash = key.hashValue
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        if let entryPtr = CFDictionaryGetValue(_dict, UnsafeRawPointer(bitPattern: hash)) {
            var ptrBits = Int(bitPattern: entryPtr)
            _delete(&ptrBits)
            DispatchQueue.global(qos: .background).async {
                self._dispose(ptrBits.value)
            }
        }
    }

    open func object(forKey key: Key) -> Value? {
        let hash = key.hashValue
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        if let entryPtr = CFDictionaryGetValue(_dict, UnsafeRawPointer(bitPattern: hash)) {
            var ptrBits = Int(bitPattern: entryPtr)
            _bubble(&ptrBits)
            if let value = UnsafeRawPointer(bitPattern: ptrBits.value) {
                if _isVal {
                    return Unmanaged<Box<Value>>.fromOpaque(value).takeUnretainedValue().val
                } else {
                    return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue() as? Value
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    // MARK: Trim
    open func trim(toCost cost: UInt) {
        if os_unfair_lock_trylock(&_lock) {
            if totalCost <= cost {
                os_unfair_lock_unlock(&_lock)
                return
            } else if cost == 0 {
                _clear()
                os_unfair_lock_unlock(&_lock)
                return
            }

            var tmp = ContiguousArray<PtrBits>()
            while totalCost > cost {
                let entryPtr = _dequeue()
                if entryPtr != 0 {
                    tmp.append(entryPtr)
                }
            }
            os_unfair_lock_unlock(&_lock)
            if tmp.count > 0 {
                DispatchQueue.global(qos: .background).async {
                    for entryPtr in tmp {
                        self._dispose(entryPtr.value)
                    }
                }
            }
        } else {
            usleep(10 * 1000)
            trim(toCost: cost)
        }
    }

    open func trim(toAge age: TimeInterval) {
        let now = clampAge(CFAbsoluteTimeGetCurrent() * Double(NSEC_PER_SEC))
        let limit = clampAge(age * Double(NSEC_PER_SEC))
        if os_unfair_lock_trylock(&_lock) {
            if age <= 0 {
                _clear()
                os_unfair_lock_unlock(&_lock)
                return
            } else if _head != 0 && _head.timestamp + limit <= now {
                os_unfair_lock_unlock(&_lock)
                return
            }

            var tmp = ContiguousArray<PtrBits>()
            while _head != 0 && _head.timestamp + limit > now {
                let entryPtr = _dequeue()
                if entryPtr != 0 {
                    tmp.append(entryPtr)
                }
            }
            os_unfair_lock_unlock(&_lock)
            if tmp.count > 0 {
                DispatchQueue.global(qos: .background).async {
                    for entryPtr in tmp {
                        self._dispose(entryPtr.value)
                    }
                }
            }
        } else {
            usleep(10 * 1000)
            trim(toAge: age)
        }
    }

    open func trim(toCount count: UInt) {
        if os_unfair_lock_trylock(&_lock) {
            if totalCount < count {
                os_unfair_lock_unlock(&_lock)
                return
            } else if count == 0 {
                _clear()
                os_unfair_lock_unlock(&_lock)
                return
            }

            var tmp = ContiguousArray<PtrBits>()
            while totalCount > count {
                let entryPtr = _dequeue()
                if entryPtr != 0 {
                    tmp.append(entryPtr)
                }
            }
            os_unfair_lock_unlock(&_lock)
            if tmp.count > 0 {
                DispatchQueue.global(qos: .background).async {
                    for entryPtr in tmp {
                        self._dispose(entryPtr)
                    }
                }
            }
        } else {
            usleep(10 * 1000)
            trim(toCount: count)
        }
    }
}

@inline(__always)
private func clampAge(_ ti: TimeInterval) -> UInt {
    if ti < 0 { return 0 }
    if ti > Double(UInt.max) { return .max }
    return UInt(ti)
}

