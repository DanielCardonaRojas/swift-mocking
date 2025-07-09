//
//  Return.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

/// A type that represents a value that can be returned from a stubbed method.
///
/// A ``Return`` can either be a success value or an error. This is used to model the fact that a stubbed method can either return a value or throw an error.
struct Return<R> {
    typealias Deferred<V> = () -> Result<V, any Error>

    var value: Deferred<R>

    init(value: @escaping Deferred<R>) {
        self.value = value
    }

    static func error<E: Error>(_ error: E) -> Return<R> {
        Return(value: { .failure(error) })
    }

    static func value(_ value: R) -> Return<R> {
        Return(value: { .success(value) })
    }

    @discardableResult
    func get() throws -> R {
        try value().get()
    }
}

