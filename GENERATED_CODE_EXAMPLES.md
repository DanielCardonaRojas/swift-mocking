# Generated Code Examples

Here are some examples of how `@Mockable` macro expands for different protocol definitions:

## Basic Method Signatures

### Method with `throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) throws -> Int {
        return try adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

### Method with `async`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) async -> Int {
        return await adapt(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, Async, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

### Method with `async throws`

```swift
@Mockable
protocol PricingService {
    func price(_ item: String) async throws -> Int
}
```
<details>
<summary>Generated Code</summary>

```swift
class PricingServiceMock: Mock, PricingService {
    func price(_ item: String) async throws -> Int {
        return try await adaptThrowing(super.price, item)
    }
    func price(_ item: ArgMatcher<String>) -> Interaction<String, AsyncThrows, Int> {
        Interaction(item, spy: super.price)
    }
}
```
</details>

## Complex Protocol Features

### Multiple Methods

```swift
@Mockable
protocol FeedService {
    func fetch(from url: URL) async throws -> Data
    func post(to url: URL, data: Data) async throws
}
```
<details>
<summary>Generated Code</summary>

```swift
class FeedServiceMock: Mock, FeedService {
    func fetch(from url: URL) async throws -> Data {
        return try await adaptThrowing(super.fetch, url)
    }
    func post(to url: URL, data: Data) async throws {
        return try await adaptThrowing(super.post, url, data)
    }
    func fetch(from url: ArgMatcher<URL>) -> Interaction<URL, AsyncThrows, Data> {
        Interaction(url, spy: super.fetch)
    }
    func post(to url: ArgMatcher<URL>, data: ArgMatcher<Data>) -> Interaction<URL, Data, AsyncThrows, Void> {
        Interaction(url, data, spy: super.post)
    }
}
```
</details>

### Method with No Parameters and No Return

```swift
@Mockable
protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class ServiceMock: Mock, Service {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>

## Macro Configuration Options

### Macro Option: `.prefixMock`

```swift
@Mockable([.prefixMock])
protocol MyService {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class MockMyService: Mock, MyService {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>

## Advanced Protocol Features

### Protocol with Associated Type

```swift
@Mockable
protocol MyService {
    associatedtype Item
    func item() -> Item
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock<Item>: Mock, MyService {
    typealias Item = Item
    func item() -> Item {
        return adapt(super.item)
    }
    func item() -> Interaction<Void, None, Item> {
        Interaction(.any, spy: super.item)
    }
}
```
</details>

### Protocol with Property

```swift
@Mockable
protocol MyService {
    var value: Int { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock: Mock, MyService {

    var value: Int {
        get {
            adapt(super.value)
        }
    }
    func getValue() -> Interaction<Void, None, Int > {
        Interaction(.any, spy: super.value)
    }
}
```
</details>

### Protocol with Subscript

```swift
@Mockable
protocol MyService {
    subscript(index: Int) -> String { get }
}
```
<details>
<summary>Generated Code</summary>

```swift
class MyServiceMock: Mock, MyService {
    subscript(index: Int) -> String {
        get {
            return adapt(super.subscript, index)
        }
    }
    subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
        get {
            Interaction(index, spy: super.subscript)
        }
    }
}
```
</details>

### Public Protocol

```swift
@Mockable
public protocol Service {
    func doSomething()
}
```
<details>
<summary>Generated Code</summary>

```swift
class ServiceMock: Mock, Service {
    func doSomething() {
        return adapt(super.doSomething)
    }
    func doSomething() -> Interaction<Void, None, Void> {
        Interaction(.any, spy: super.doSomething)
    }
}
```
</details>
