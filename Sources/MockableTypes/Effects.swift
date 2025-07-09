//
//  Effects.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//


/// A protocol that defines the effect of a method, such as throwing an error or being asynchronous.
///
/// This protocol is used internally by the Mockable framework to generate appropriate mock implementations.
public protocol Effect { }

/// Represents a method that can throw an error.
public enum Throws: Effect { }

/// Represents an asynchronous method.
public enum Async: Effect { }

/// Represents an asynchronous method that can also throw an error.
public enum AsyncThrows: Effect { }

/// Represents a method that has no special effects (neither throws nor is asynchronous).
public enum None: Effect { }
