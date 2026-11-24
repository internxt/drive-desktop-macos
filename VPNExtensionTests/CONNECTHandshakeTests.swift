import XCTest

final class CONNECTHandshakeTests: XCTestCase {

    func testWhenATunnelIsOpenedToAHost_thenTheProxyIsAskedForThatHostWithTheRegionAndTokenAsCredentials() throws {
        let request = try XCTUnwrap(CONNECTHandshake.request(host: "example.com", port: 443, region: "DE", token: "t"))

        XCTAssertEqual(
            String(decoding: request, as: UTF8.self),
            "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\nProxy-Authorization: Basic REU6dA==\r\n\r\n"
        )
    }

    func testWhenTheTokenContainsCharactersReservedInHeaders_thenTheCredentialsStillTravelIntact() throws {
        let request = try XCTUnwrap(CONNECTHandshake.request(host: "example.com", port: 443, region: "FR", token: "eyJ.a+b/c"))

        XCTAssertEqual(
            String(decoding: request, as: UTF8.self),
            "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\nProxy-Authorization: Basic RlI6ZXlKLmErYi9j\r\n\r\n"
        )
    }

    func testWhenTheDestinationIsAnIPv6Address_thenTheProxyReceivesItInBrackets() throws {
        let request = try XCTUnwrap(CONNECTHandshake.request(host: "2001:db8::1", port: 443, region: "DE", token: "t"))

        XCTAssertEqual(
            String(decoding: request, as: UTF8.self),
            "CONNECT [2001:db8::1]:443 HTTP/1.1\r\nHost: [2001:db8::1]:443\r\nProxy-Authorization: Basic REU6dA==\r\n\r\n"
        )
    }

    func testWhenTheHostContainsALineBreak_thenNoRequestIsBuilt() {
        let request = CONNECTHandshake.request(host: "example.com\r\nX-Injected: 1", port: 443, region: "DE", token: "t")

        XCTAssertNil(request)
    }

    func testWhenTheHostContainsASpace_thenNoRequestIsBuilt() {
        let request = CONNECTHandshake.request(host: "example.com HTTP/1.1", port: 443, region: "DE", token: "t")

        XCTAssertNil(request)
    }

    func testWhenTheHostIsEmpty_thenNoRequestIsBuilt() {
        let request = CONNECTHandshake.request(host: "", port: 443, region: "DE", token: "t")

        XCTAssertNil(request)
    }

    func testWhenTheProxyAcceptsTheTunnel_thenItIsEstablishedWithNothingPending() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 200 Connection established\r\n\r\n".utf8))

        XCTAssertEqual(response, .established(leftover: Data()))
    }

    func testWhenAnOlderProxyAcceptsTheTunnelWithHTTP10_thenItIsEstablished() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.0 200 OK\r\n\r\n".utf8))

        XCTAssertEqual(response, .established(leftover: Data()))
    }

    func testWhenTheDestinationSendsDataInTheSamePacketAsTheAcceptance_thenThatDataIsKeptForTheApp() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 200 Connection established\r\nVia: vpn\r\n\r\nSSH-2.0-server".utf8))

        XCTAssertEqual(response, .established(leftover: Data("SSH-2.0-server".utf8)))
    }

    func testWhenTheProxyRejectsTheToken_thenTheSessionIsReportedAsExpired() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic\r\n\r\n".utf8))

        XCTAssertEqual(response, .sessionExpired)
    }

    func testWhenTheUserPlanDoesNotIncludeTheRegion_thenTheZoneIsReportedAsNotAllowed() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 403 Forbidden\r\n\r\n".utf8))

        XCTAssertEqual(response, .zoneNotAllowed)
    }

    func testWhenTheProxyCannotReachTheDestination_thenTheProxyIsReportedAsUnavailable() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 502 Bad Gateway\r\n\r\n".utf8))

        XCTAssertEqual(response, .proxyUnavailable)
    }

    func testWhenTheProxyAnswersSomethingThatIsNotHTTP_thenTheProxyIsReportedAsUnavailable() {
        let response = CONNECTHandshake.readResponse(Data("SSH-2.0-OpenSSH_9.6\r\n\r\n".utf8))

        XCTAssertEqual(response, .proxyUnavailable)
    }

    func testWhenTheStatusCodeIsNotANumber_thenTheProxyIsReportedAsUnavailable() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 2OO OK\r\n\r\n".utf8))

        XCTAssertEqual(response, .proxyUnavailable)
    }

    func testWhenOnlyPartOfTheAnswerHasArrived_thenTheTunnelKeepsWaitingForTheRest() {
        let response = CONNECTHandshake.readResponse(Data("HTTP/1.1 200 Connection est".utf8))

        XCTAssertEqual(response, .incomplete)
    }

    func testWhenTheProxyKeepsSendingAHeaderThatNeverEnds_thenTheProxyIsReportedAsUnavailableInsteadOfWaitingForever() {
        let headerLongerThan16KB = Data(("HTTP/1.1 200 OK\r\nX-Padding: " + String(repeating: "a", count: 16_384)).utf8)

        let response = CONNECTHandshake.readResponse(headerLongerThan16KB)

        XCTAssertEqual(response, .proxyUnavailable)
    }
}
