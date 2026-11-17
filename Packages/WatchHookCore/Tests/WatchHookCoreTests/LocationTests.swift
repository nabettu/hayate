import Foundation
import Testing
@testable import WatchHookCore

@Suite("場所の付与 (任意・送り先ごと / 時計ごと)")
struct LocationTests {
    let here = MemoLocation(latitude: 35.681236, longitude: 139.767125)

    @Test func 場所は緯度経度のカンマ区切りで表す() {
        #expect(here.text == "35.681236,139.767125")
    }

    @Test func テンプレートの場所プレースホルダに差し込む() {
        let ctx = TemplateContext(text: "x", messageID: UUID(), sentAt: Date(timeIntervalSince1970: 0), source: "phone", location: here)
        let out = TemplateRenderer.render(#"{"loc":"{{location}}"}"#, context: ctx, encoding: .json)
        #expect(out == #"{"loc":"35.681236,139.767125"}"#)
    }

    @Test func 場所が無いときは空文字にする() {
        let ctx = TemplateContext(text: "x", messageID: UUID(), sentAt: Date(timeIntervalSince1970: 0), source: "phone")
        let out = TemplateRenderer.render("[{{location}}]", context: ctx, encoding: .plain)
        #expect(out == "[]")
    }

    @Test func 送り先の場所設定は前の形式でも読め既定はオフ() throws {
        // 場所を送る設定が無い (前の形式の) 保存データは、場所を送らない扱いで読める
        let json = #"{"id":"00000000-0000-0000-0000-000000000002","name":"A","kind":"custom","url":"https://example.com","method":"POST","headers":[],"bodyEncoding":"json","bodyTemplate":"{}"}"#
        let dest = try JSONDecoder().decode(Destination.self, from: Data(json.utf8))
        #expect(dest.sendsLocation == false)
    }

    @Test func 場所を送る設定は保存と読み込みで保たれる() throws {
        var dest = Destination(name: "A", kind: .custom, bodyTemplate: "{}")
        dest.sendsLocation = true
        let data = try JSONEncoder().encode(dest)
        let back = try JSONDecoder().decode(Destination.self, from: data)
        #expect(back.sendsLocation == true)
    }

    // MARK: 付けるかどうかの判断

    @Test func iPhone_で入力したメモは場所を送る送り先があれば取る() {
        var dest = Destination(name: "A", kind: .custom, bodyTemplate: "{}")
        dest.sendsLocation = true
        #expect(LocationPolicy.shouldCapture(origin: .phone, watchAttachEnabled: false, destinations: [dest]))
    }

    @Test func 場所を送らない送り先しか無ければ取らない() {
        let dest = Destination(name: "A", kind: .custom, bodyTemplate: "{}")
        #expect(!LocationPolicy.shouldCapture(origin: .phone, watchAttachEnabled: true, destinations: [dest]))
    }

    @Test func 無効にした送り先の設定は数えない() {
        var dest = Destination(name: "A", kind: .custom, bodyTemplate: "{}")
        dest.sendsLocation = true
        dest.isEnabled = false
        #expect(!LocationPolicy.shouldCapture(origin: .phone, watchAttachEnabled: true, destinations: [dest]))
    }

    @Test func 時計で入力したメモは時計側の設定がオンのときだけ取る() {
        var dest = Destination(name: "A", kind: .custom, bodyTemplate: "{}")
        dest.sendsLocation = true
        #expect(!LocationPolicy.shouldCapture(origin: .watch, watchAttachEnabled: false, destinations: [dest]))
        #expect(LocationPolicy.shouldCapture(origin: .watch, watchAttachEnabled: true, destinations: [dest]))
    }

    // MARK: メモと送信

    @Test func 場所の無い前の形式のメモも読める() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000003","text":"a","createdAt":0,"source":"watch","origin":"watch","deliveries":[],"wantsPhoneIntegrations":true}"#
        let memo = try JSONDecoder().decode(Memo.self, from: Data(json.utf8))
        #expect(memo.location == nil)
    }

    @Test func 送り先が場所を送るときだけ送信内容に場所が付く() {
        var memo = Memo(text: "x", source: "phone", origin: .phone)
        memo.location = here
        let delivery = Delivery(target: .webhook(destinationID: UUID(), name: "A"), owner: .phone, text: "x")
        #expect(memo.outgoingMessage(for: delivery, sendsLocation: true)?.location == here)
        #expect(memo.outgoingMessage(for: delivery, sendsLocation: false)?.location == nil)
    }

    @Test func webhook_の本文に場所が差し込まれる() throws {
        var dest = Destination(name: "A", kind: .custom, url: "https://example.com/hook", bodyTemplate: #"{"loc":"{{location}}"}"#)
        dest.sendsLocation = true
        let message = OutgoingMessage(text: "x", destinationID: dest.id, source: "phone", location: here)
        let request = try RequestBuilder.build(destination: dest, message: message)
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String]
        #expect(body?["loc"] == "35.681236,139.767125")
    }
}

@Suite("測位の結果の使い方")
struct LocationFixTests {
    let requested = Date(timeIntervalSince1970: 1_000)

    @Test func 要求より前の測位は使わない() {
        #expect(!LocationFix.isUsable(horizontalAccuracy: 10, timestamp: Date(timeIntervalSince1970: 999), requestedAt: requested))
    }

    @Test func 要求のあとの測位で精度が有効なら使う() {
        #expect(LocationFix.isUsable(horizontalAccuracy: 10, timestamp: Date(timeIntervalSince1970: 1_001), requestedAt: requested))
    }

    @Test func 精度が負の測位は無効として使わない() {
        #expect(!LocationFix.isUsable(horizontalAccuracy: -1, timestamp: Date(timeIntervalSince1970: 1_001), requestedAt: requested))
    }
}
