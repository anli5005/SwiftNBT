# SwiftNBT

A Swifty NBT parser and encoder

```swift
import Foundation
import SwiftNBT

let tag = StringTag(string: "Hello, world!")
let data = try! tag.encode(withName: "str")

let decodeResult = try! decodeNBT(data: data)
print(decodeResult.tag)
```
