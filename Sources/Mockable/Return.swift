//
//  Return.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

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

    func get() throws -> R {
        try value().get()
    }
}

