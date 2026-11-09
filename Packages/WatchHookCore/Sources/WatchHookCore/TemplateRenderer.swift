import Foundation

public struct TemplateContext: Sendable {
    public var text: String
    public var messageID: UUID
    public var sentAt: Date
    public var source: String

    public init(text: String, messageID: UUID, sentAt: Date, source: String) {
        self.text = text
        self.messageID = messageID
        self.sentAt = sentAt
        self.source = source
    }
}

/// 本文テンプレートの `{{name}}` を差し込む。
/// 差し込んだ値の中にある `{{...}}` は再展開しない (1 回の走査で置き換える)。
public enum TemplateRenderer {
    public static func render(_ template: String, context: TemplateContext, encoding: BodyEncoding) -> String {
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "UTC")
        let values: [String: String] = [
            "text": context.text,
            "id": context.messageID.uuidString,
            "sentAt": iso.string(from: context.sentAt),
            "source": context.source,
        ]

        var out = ""
        var rest = template[...]
        while let open = rest.range(of: "{{") {
            out += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: "}}") else {
                rest = rest[open.lowerBound...]
                break
            }
            let name = afterOpen[..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            if let value = values[name] {
                out += escape(value, for: encoding)
            } else {
                out += rest[open.lowerBound..<close.upperBound]
            }
            rest = afterOpen[close.upperBound...]
        }
        out += rest
        return out
    }

    static func escape(_ value: String, for encoding: BodyEncoding) -> String {
        switch encoding {
        case .plain:
            return value
        case .form:
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        case .json:
            var s = ""
            for scalar in value.unicodeScalars {
                switch scalar {
                case "\"": s += "\\\""
                case "\\": s += "\\\\"
                case "\n": s += "\\n"
                case "\r": s += "\\r"
                case "\t": s += "\\t"
                case _ where scalar.value < 0x20:
                    s += String(format: "\\u%04x", scalar.value)
                default:
                    s.unicodeScalars.append(scalar)
                }
            }
            return s
        }
    }
}
