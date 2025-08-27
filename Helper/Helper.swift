//
//  Helper.swift
//  Helper
//
//  Created by Patricio Tovar on 27/8/25.
//

import Foundation

class Helper: NSObject, HelperProtocol {

    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc func performCalculation(firstNumber: Int, secondNumber: Int, with reply: @escaping (Int) -> Void) {
        let response = firstNumber + secondNumber
        reply(response)
    }
}
