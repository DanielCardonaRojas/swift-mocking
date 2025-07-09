//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation
import Shared


@attached(peer, names: suffixed(Mock))
public macro Mockable(_ options: [MockableOptions] = []) = #externalMacro(module: "MockableMacro", type: "MockableMacro")
