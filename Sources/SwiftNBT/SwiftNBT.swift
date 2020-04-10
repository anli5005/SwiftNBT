import Foundation
import Gzip

/* #if canImport(Combine)
import Combine
#endif */

public func decodeNBT(data: Data) throws -> (name: StringTag, tag: NBTTag, length: Int) {
    if data.isEmpty {
        throw NBTError.endOfData
    }
    
    guard let type = NBTTags[data.first!] else {
        throw NBTError.unrecognizedTagTypeId(data.first!)
    }
    
    var length = 0
    let name = try StringTag(data: data[(data.startIndex + 1)..<data.endIndex], length: &length)
    length += 1
    
    var tagLength = 0
    let tag = try type.init(data: data[(data.startIndex + length)..<data.endIndex], length: &tagLength)
    length += tagLength
    
    return (name: name, tag: tag, length: length)
}

public extension NBTTag {
    func encode(name: StringTag) throws -> Data {
        guard let typeId = NBTTags.first(where: { $0.value == Self.self })?.key else {
            throw NBTError.unrecognizedTagType(Self.self)
        }
    
        return try Data([typeId]) + name.tagData() + tagData()
    }
}

public extension Data {
    func gunzippedIfNeeded() -> Data {
        if isGzipped {
            if let data = try? gunzipped() {
                return data
            }
        }
        
        return self
    }
}

/* public class NBTDecoder {
    public func decode<T>(_ type: T.Type, from: Data) throws -> T where T : Decodable {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Not implemented"))
    }
}

#if canImport(Combine)
extension NBTDecoder: TopLevelDecoder {}
#endif */

/* class _NBTDecoder: Decoder {
    public var codingPath = [CodingKey]()
    public var userInfo = [CodingUserInfoKey : Any]()

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        <#code#>
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        <#code#>
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        <#code#>
    }
} */
