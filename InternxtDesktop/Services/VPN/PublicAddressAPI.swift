//
//  PublicAddressAPI.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 26/11/2026.
//

import Foundation

struct PublicAddress: Equatable {
    let ip: String
    let location: String
}

extension PublicAddress: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ip, city, region, country
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ip = try container.decode(String.self, forKey: .ip)
        guard !ip.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .ip, in: container, debugDescription: "Empty IP")
        }
        location = [CodingKeys.city, .region, .country]
            .compactMap { try? container.decodeIfPresent(String.self, forKey: $0) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

struct PublicAddressAPI {
    let baseURL: URL

    func getPublicAddress() async throws -> PublicAddress {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("json"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PublicAddress.self, from: data)
    }
}
