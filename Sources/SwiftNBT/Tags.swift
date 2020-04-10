import Foundation

public enum NBTError: Error {
    case endOfData
    case unrecognizedTagTypeId(UInt8)
    case unrecognizedTagType(NBTTag.Type)
}

public protocol NBTTag {
    init(data: Data, length: inout Int) throws
    func tagData() throws -> Data
}

public struct EndTag: NBTTag {
    public init() {}
    
    public init(data: Data, length: inout Int) throws {
        length = 0
    }
    
    public func tagData() -> Data {
        Data()
    }
}

public extension FixedWidthInteger {
    init(data: Data, length: inout Int) throws {
        length = MemoryLayout<Self>.size
        if data.count < length {
            throw NBTError.endOfData
        }
        
        self.init(bigEndian: data[data.startIndex..<(data.startIndex + length)].advanced(by: 0).withUnsafeBytes { $0.load(as: Self.self) })
    }
    
    func tagData() -> Data {
        return withUnsafeBytes(of: bigEndian) { Data($0) }
    }
}

extension Int8: NBTTag {}
extension Int16: NBTTag {}
extension Int32: NBTTag {}
extension Int64: NBTTag {}

extension Float32: NBTTag {
    public init(data: Data, length: inout Int) throws {
        length = 4
        if data.count < length {
            throw NBTError.endOfData
        }
        
        self.init(bitPattern: data[data.startIndex..<(data.startIndex + length)].advanced(by: 0).withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) })
    }
    
    public func tagData() -> Data {
        return withUnsafeBytes(of: bitPattern.bigEndian) { Data($0) }
    }
}

extension Float64: NBTTag {
    public init(data: Data, length: inout Int) throws {
        length = 8
        if data.count < length {
            throw NBTError.endOfData
        }
        
        self.init(bitPattern: data[data.startIndex..<(data.startIndex + length)].advanced(by: 0).withUnsafeBytes { UInt64(bigEndian: $0.load(as: UInt64.self)) })
    }
    
    public func tagData() -> Data {
        return withUnsafeBytes(of: bitPattern.bigEndian) { Data($0) }
    }
}

func unbox<Length: BinaryInteger & NBTTag>(data: Data, length: inout Int, header _: Length.Type = Length.self) throws -> Data {
    var lengthLength = 0
    length = Int(try Length(data: data, length: &lengthLength))
    length += lengthLength
    if data.count < length {
        throw NBTError.endOfData
    }
    
    return data[(lengthLength + data.startIndex)..<(length + data.startIndex)]
}

extension Data: NBTTag {
    public init(data: Data, length: inout Int) throws {
        self.init(try unbox(data: data, length: &length, header: Int32.self))
    }
    
    public func tagData() -> Data {
        Int32(count).tagData() + self
    }
}

public struct StringTag: NBTTag, RawRepresentable, Hashable {
    public var rawValue: Data
    public init(rawValue: Data) {
        self.rawValue = rawValue
    }
    
    public init(string: String) {
        rawValue = Data(string.utf8)
    }
    
    public init(data: Data, length: inout Int) throws {
        self.init(rawValue: try unbox(data: data, length: &length, header: Int16.self))
    }
    
    public func tagData() -> Data {
        Int16(rawValue.count).tagData() + rawValue
    }
    
    public var string: String? {
        String(data: rawValue, encoding: .utf8)
    }
}

public struct ListTag: NBTTag {
    public var type: NBTTag.Type
    public var tags: [NBTTag]
    
    public init(type: NBTTag.Type, tags: [NBTTag]) {
        self.type = type
        self.tags = tags
    }
    
    public init<Tag: NBTTag>(_ tags: [Tag]) {
        self.init(type: Tag.self, tags: tags)
    }
    
    public init(data: Data, length: inout Int) throws {
        if data.isEmpty {
            throw NBTError.endOfData
        }
        
        guard let type = NBTTags[data.first!] else {
            throw NBTError.unrecognizedTagTypeId(data[0])
        }
        
        let listCount = Int(try Int32(data: data[(data.startIndex + 1)..<data.endIndex], length: &length))
        length += 1
        var tags = [NBTTag]()
        tags.reserveCapacity(listCount)
        
        for _ in 0..<listCount {
            var elementLength = 0
            tags.append(try type.init(data: data[(data.startIndex + length)..<data.endIndex], length: &elementLength))
            length += elementLength
        }
        
        self.init(type: type, tags: tags)
    }
    
    public func tagData() throws -> Data {
        guard let typeId = NBTTags.first(where: { $0.value == type })?.key else {
            throw NBTError.unrecognizedTagType(type)
        }
        
        var data = Data([typeId]) + Int32(tags.count).tagData()
        try tags.forEach { data += try $0.tagData() }
        return data
    }
}

public struct CompoundTag: NBTTag, RawRepresentable {
    public var rawValue: [StringTag: NBTTag]
    public init(rawValue: [StringTag: NBTTag]) {
        self.rawValue = rawValue
    }
    
    public init(data: Data, length: inout Int) throws {
        if data.isEmpty {
            throw NBTError.endOfData
        }
        
        var tags = [StringTag: NBTTag]()
        var i = data.startIndex
        while data[i] != 0 {
            guard let type = NBTTags[data[i]] else {
                throw NBTError.unrecognizedTagTypeId(data[i])
            }
                                    
            var nameLength = 0
            let name = try StringTag(data: data[(i + 1)..<data.endIndex], length: &nameLength)
            i += nameLength + 1
                        
            var tagLength = 0
            let tag = try type.init(data: data[i..<data.endIndex], length: &tagLength)
            i += tagLength
                        
            tags[name] = tag
            
            if i >= data.endIndex {
                throw NBTError.endOfData
            }
        }
        
        length = i - data.startIndex + 1
        
        self.init(rawValue: tags)
    }
    
    public func tagData() throws -> Data {
        var data = Data()
        try rawValue.forEach { pair throws in
            let tagType = type(of: pair.value)
            guard let typeId = NBTTags.first(where: { $0.value == tagType })?.key else {
                throw NBTError.unrecognizedTagType(tagType)
            }
            
            data.append(typeId)
            data += pair.key.tagData()
            data += try pair.value.tagData()
        }
        data.append(0)
        return data
    }
}

extension Array: NBTTag where Element: FixedWidthInteger {
    public init(data: Data, length: inout Int) throws {
        let count = Int(try Int16(data: data, length: &length))
        let elementSize = MemoryLayout<Element>.size
        length += elementSize * count
        if data.count < length {
            throw NBTError.endOfData
        }
        
        self.init(Self.init(unsafeUninitializedCapacity: count, initializingWith: { (pointer, initializedCount) in
            data.copyBytes(to: pointer, from: (data.startIndex + 2)..<(data.startIndex + length))
            initializedCount = count
        }).map { Element(bigEndian: $0) })
    }
    
    public func tagData() throws -> Data {
        Int16(count).tagData() + map { $0.bigEndian }.withUnsafeBytes { Data($0) }
    }
}

var NBTTags: [UInt8: NBTTag.Type] = [0: EndTag.self, 1: Int8.self, 2: Int16.self, 3: Int32.self, 4: Int64.self, 5: Float32.self, 6: Float64.self, 7: Data.self, 8: StringTag.self, 9: ListTag.self, 10: CompoundTag.self, 11: [Int32].self, 12: [Int64].self]

extension StringTag: ExpressibleByStringLiteral, CustomDebugStringConvertible {
    public init(stringLiteral: String) {
        self.init(string: stringLiteral)
    }
    
    public var debugDescription: String {
        string ?? "<Invalid UTF-8 string (length \(rawValue.count))>"
    }
}

extension ListTag: RandomAccessCollection, RangeReplaceableCollection {
    public init() {
        self.init(type: EndTag.self, tags: [])
    }
    
    public var startIndex: Int { tags.startIndex }
    public var endIndex: Int { tags.endIndex }
    
    public var count: Int { tags.count }
    
    public func formIndex(after i: inout Int) {
        tags.formIndex(after: &i)
    }
    
    public func formIndex(before i: inout Int) {
        tags.formIndex(before: &i)
    }
    
    public func formIndex(_ i: inout Int, offsetBy distance: Int) {
        tags.formIndex(&i, offsetBy: distance)
    }
    
    public subscript(position: Int) -> NBTTag {
        get {
            tags[position]
        }
        set {
            tags[position] = newValue
        }
    }
    
    public subscript(bounds: Range<Int>) -> ArraySlice<NBTTag> {
        get {
            tags[bounds]
        }
        set {
            tags[bounds] = newValue
        }
    }
}

extension CompoundTag {
    public subscript(name: StringTag) -> NBTTag? {
        get {
            rawValue[name]
        }
        set {
            rawValue[name] = newValue
        }
    }
}
