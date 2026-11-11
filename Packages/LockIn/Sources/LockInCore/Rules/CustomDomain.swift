import Foundation

/// Websites the user types in by hand, in addition to what the system picker offers.
public enum CustomDomain {
    public static let limit = 50

    public enum AddResult: Equatable, Sendable {
        case added, duplicate, invalid, limitReached
    }

    /// Lowercased host name from free-form input such as a pasted URL, or `nil` if it isn't a domain.
    public static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = s.range(of: "://") { s = String(s[scheme.upperBound...]) }
        if let end = s.firstIndex(where: { "/?#".contains($0) }) { s = String(s[..<end]) }
        if let port = s.firstIndex(of: ":") { s = String(s[..<port]) }

        let labels = s.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy(isValidLabel),
              let tld = labels.last, tld.count >= 2, tld.allSatisfy(\.isLetter) else { return nil }
        return s
    }

    public static func add(_ input: String, to domains: inout [String]) -> AddResult {
        guard let domain = normalize(input) else { return .invalid }
        guard !domains.contains(domain) else { return .duplicate }
        guard domains.count < limit else { return .limitReached }
        domains.append(domain)
        return .added
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.count), label.first != "-", label.last != "-" else { return false }
        return label.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" }
    }
}
