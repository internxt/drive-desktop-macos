import Foundation

enum CONNECTResponse: Equatable {
    case incomplete
    case established(leftover: Data)
    case sessionExpired
    case zoneNotAllowed
    case proxyUnavailable
}

enum CONNECTHandshake {
    static let maximumResponseHeaderLength = 16_384

    private static let headerTerminator = Data("\r\n\r\n".utf8)
    private static let supportedHTTPVersions: Set<Substring> = ["HTTP/1.1", "HTTP/1.0"]

    static func request(host: String, port: Int, region: String, token: String) -> Data {
        let authority = "\(host.contains(":") ? "[\(host)]" : host):\(port)"
        let credentials = Data("\(region):\(token)".utf8).base64EncodedString()
        return Data("CONNECT \(authority) HTTP/1.1\r\nHost: \(authority)\r\nProxy-Authorization: Basic \(credentials)\r\n\r\n".utf8)
    }

    static func readResponse(_ received: Data) -> CONNECTResponse {
        guard let terminator = received.range(of: headerTerminator) else {
            return received.count > maximumResponseHeaderLength ? .proxyUnavailable : .incomplete
        }

        switch statusCode(in: received[..<terminator.lowerBound]) {
        case 200:
            return .established(leftover: Data(received[terminator.upperBound...]))
        case 407:
            return .sessionExpired
        case 403:
            return .zoneNotAllowed
        default:
            return .proxyUnavailable
        }
    }

    private static func statusCode(in header: Data) -> Int? {
        let statusLine = String(decoding: header, as: UTF8.self).prefix { $0 != "\r\n" }
        let parts = statusLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, supportedHTTPVersions.contains(parts[0]), parts[1].count == 3 else {
            return nil
        }
        return Int(parts[1])
    }
}
