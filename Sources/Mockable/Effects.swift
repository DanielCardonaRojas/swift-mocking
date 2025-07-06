//
//  Effects.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//


public protocol Effect { }
public enum Throws: Effect { }
public enum Async: Effect { }
public enum AsyncThrows: Effect { }
public enum None: Effect { }
