//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation
import MockableTypes

@attached(peer, names: suffixed(Mock), prefixed(Mock), suffixed(Witness))
public macro Mockable(_ options: MockableOptions = []) = #externalMacro(module: "MockableMacro", type: "MockableMacro")

@attached(peer, names: suffixed(Witness))
public macro Witnessed() = #externalMacro(module: "MockableMacro", type: "WitnessMacro")
