import Testing
@testable import LockInCore

struct CustomDomainTests {
    @Test(arguments: [
        ("reddit.com", "reddit.com"),
        ("  Reddit.COM ", "reddit.com"),
        ("https://www.reddit.com/r/swift?x=1", "www.reddit.com"),
        ("http://news.ycombinator.com:443/", "news.ycombinator.com"),
        ("m.youtube.com/watch", "m.youtube.com"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(CustomDomain.normalize(input) == expected)
    }

    @Test(arguments: ["", "   ", "localhost", "not a domain", "https://", "foo..com", ".com", "exa_mple.com"])
    func rejects(input: String) {
        #expect(CustomDomain.normalize(input) == nil)
    }

    @Test func addingDedupesAndCapsAt50() {
        var domains: [String] = []
        #expect(CustomDomain.add("reddit.com", to: &domains) == .added)
        #expect(CustomDomain.add("REDDIT.com", to: &domains) == .duplicate)
        #expect(CustomDomain.add("nope", to: &domains) == .invalid)
        for i in 1..<50 { _ = CustomDomain.add("site\(i).com", to: &domains) }
        #expect(domains.count == 50)
        #expect(CustomDomain.add("one-too-many.com", to: &domains) == .limitReached)
    }
}
