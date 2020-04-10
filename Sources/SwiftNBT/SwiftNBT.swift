import Foundation
import Gzip

/* #if canImport(Combine)
import Combine
#endif */

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
