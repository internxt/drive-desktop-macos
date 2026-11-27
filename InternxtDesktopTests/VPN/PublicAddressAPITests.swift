//
//  PublicAddressAPITests.swift
//  InternxtDesktopTests
//
//  Created by Xavier Abad Gomez on 26/11/2026.
//

import XCTest
@testable import Internxt

final class PublicAddressAPITests: XCTestCase {
    func test_ipServiceAnswer_isReadAsTheIP() throws {
        let body = Data(#"{"ip":"185.201.12.44","city":"Frankfurt","country":"Germany","org":"x"}"#.utf8)

        let info = try JSONDecoder().decode(PublicAddress.self, from: body)

        XCTAssertEqual(info, PublicAddress(ip: "185.201.12.44"))
    }

    func test_ipServiceAnswerWithoutIP_isNotAnAddress() {
        let body = Data(#"{"ip":"","country":"Germany"}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(PublicAddress.self, from: body))
    }
}
