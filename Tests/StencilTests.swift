import XCTest
@testable import InteractivityStencil
@testable import Facility
@testable import FacilityPure
//extension AnyCodable: GenerationContext {
//  public var event: String { "" }
//  public var subevent: String { "" }
//  public var env: [String: String] { get { [:] } set {} }
//  public var ctx: AnyCodable? { get { self } set {} }
//  public var info: Gitlab.Info? { get { nil } set {} }
//  public var mark: String? { get {""} set {} }
//}
//final class StencilTests: XCTestCase {
//  func makeQuery(_ name: String) -> Generate { .init(
//    allowEmpty: false,
//    template: .name(name),
//    templates: [
//      "testJson": """
//        {% filter escapeJson %}
//        yay
//        yay
//        {% endfilter %}
//        """,
//      "testSubscript": "{{custom.members[env.login].mention}}",
//      "testFilterChaining": #"""
//        {% filter regexp:"&","&amp;"|regexp:"\<","&lt;"|regexp:"\>","&gt;" %}
//        {{ env.text }}
//        {% endfilter %}
//        """#,
//      "testIncrement": #"""
//        {{ env.version | incremented }}
//        """#,
//      "testScanInplace": #"{% scan ".*(\d+)\.(\d+)\.(\d+).*" %}asd 1.2.3{%patch%}{{_.1}}.{{_.2 | filter:"incremented"}}.{{_.3}}{%endscan%}"#,
//      "testScan": #"""
//        {% scan custom.versionRegexp %}{#
//          #}{{ custom.versionString }}{#
//        #}{% patch %}{#
//          #}{{_.1}}.{{_.2 | filter:"incremented"}}.{{_.3}}{#
//        #}{% endscan %}
//        """#,
//      "testLine": #"""
//        {% line %}
//        a
//        b
//         c
//        {% endline %}
//        """#,
//      "testBool": #"{% if not env.bool %}good{% endif %}"#,
//    ],
//    context: AnyCodable.map([
//      "env": .map([
//        "login": .value(.string("user")),
//        "text": .value(.string(#"<Mr-123> & Co"#)),
//        "CI_MERGE_REQUEST_TITLE": .value(.string(#"MR-123, MB-234 ME-123: asd "asdas" [MR-234], RF-345'"#)),
//        "version": .value(.string("11")),
//        "bool": .value(.bool(false))
//      ]),
//      "custom": .map([
//        "members": .map([
//          "user": .map([
//            "mention": .value(.string("<@USERID>")),
//          ]),
//        ]),
//        "versionRegexp": .value(.string(#".*(\d+)\.(\d+)\.(\d+).*"#)),
//        "versionString": .value(.string(#"release/1.2.4"#)),
//      ]),
//      "issues": .list([.value(.string("some"))]),
//    ])
//  )}
//  func testSubscript() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testSubscript"))
//    XCTAssertEqual(result, "<@USERID>")
//  }
//  func testFilterChaining() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testFilterChaining"))
//    XCTAssertEqual(result, #"&lt;Mr-123&gt; &amp; Co"#)
//  }
//  func testIncrement() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testIncrement"))
//    XCTAssertEqual(result, #"12"#)
//  }
//  func testScan() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testScan"))
//    XCTAssertEqual(result, #"1.3.4"#)
//  }
//  func testScanInplace() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testScanInplace"))
//    XCTAssertEqual(result, #"1.3.3"#)
//  }
//  func testLine() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testLine"))
//    XCTAssertEqual(result, #"ab c"#)
//  }
//  func testBool() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testBool"))
//    XCTAssertEqual(result, #"good"#)
//  }
//  func testJson() throws {
//    let result = try StencilParser(notation: .json)
//      .generate(query: makeQuery("testJson"))
//    XCTAssertEqual(result, #""yay\nyay""#)
//  }
//}
