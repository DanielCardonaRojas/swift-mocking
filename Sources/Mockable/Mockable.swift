//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation

public enum MockableOptions { }

@attached(peer, names: suffixed(Spy))
public macro Mockable(_ options: [MockableOptions] = []) = #externalMacro(module: "MockableMacro", type: "MockableMacro")
