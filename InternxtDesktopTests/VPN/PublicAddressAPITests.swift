//
//  PublicAddressAPITests.swift
//  InternxtDesktopTests
//
//  Created by Xavier Abad Gomez on 26/11/2026.
//

import XCTest
@testable import Internxt

final class PublicAddressAPITests: XCTestCase {
    func test_ipServiceAnswer_isReadAsCityRegionAndCountry() throws {
        let body = Data(#"{"ip":"185.201.12.44","city":"Frankfurt","region":"Hesse","country":"Germany","org":"x"}"#.utf8)

        let info = try JSONDecoder().decode(PublicAddress.self, from: body)

        XCTAssertEqual(info, PublicAddress(ip: "185.201.12.44", location: "Frankfurt, Hesse, Germany"))
    }

    func test_ipServiceAnswerWithoutCity_skipsTheMissingParts() throws {
        let body = Data(#"{"ip":"185.201.12.44","city":"","country":"Germany"}"#.utf8)

        let info = try JSONDecoder().decode(PublicAddress.self, from: body)

        XCTAssertEqual(info.location, "Germany")
    }

    func test_ipServiceAnswerWithoutIP_isNotAnAddress() {
        let body = Data(#"{"ip":"","country":"Germany"}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(PublicAddress.self, from: body))
    }
}
