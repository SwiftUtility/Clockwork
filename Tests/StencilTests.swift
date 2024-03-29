import XCTest
@testable import InteractivityStencil
import InteractivityYams
@testable import Facility
@testable import FacilityPure
extension AnyCodable: GenerateContext {}
final class StencilTests: XCTestCase {
  static let templates: [String: String] = [
    "testJson": """
      {% filter escapeJson %}
      yay
      yay
      {% endfilter %}
      """,
    "testSubscript": "{{ctx.custom.members[ctx.env.login].mention}}",
    "testIncrement": #"""
      {{ ctx.env.version | incremented }}
      """#,
    "testScanInplace": #"{% scan ".*(\d+)\.(\d+)\.(\d+).*" %}asd 1.2.3{%patch%}{{_.1}}.{{_.2 | filter:"incremented"}}.{{_.3}}{%endscan%}"#,
    "testScan": #"""
      {% scan ctx.custom.versionRegexp %}{#
        #}{{ ctx.custom.versionString }}{#
      #}{% patch %}{#
        #}{{_.1}}.{{_.2 | filter:"incremented"}}.{{_.3}}{#
      #}{% endscan %}
      """#,
    "testLine": #"""
      {% line %}
      a
      b
       c
      {% endline %}
      """#,
    "testBool": #"{% if not ctx.env.bool %}good{% endif %}"#,
    "Included.stencil": #"{{ value }}"#,
  ]
  func makeQuery(_ name: String) -> Generate { .init(
    template: .name(name),
    templates: StencilTests.templates,
    allowEmpty: false,
    info: Generate.Info(event: [], args: nil, ctx: AnyCodable.map([
      "env": .map([
        "login": .value(.string("user")),
        "text": .value(.string(#"<Mr-123> & Co"#)),
        "CI_MERGE_REQUEST_TITLE": .value(.string(#"MR-123, MB-234 ME-123: asd "asdas" [MR-234], RF-345'"#)),
        "version": .value(.string("11")),
        "bool": .value(.bool(false))
      ]),
      "custom": .map([
        "members": .map([
          "user": .map([
            "mention": .value(.string("<@USERID>")),
          ]),
        ]),
        "versionRegexp": .value(.string(#".*(\d+)\.(\d+)\.(\d+).*"#)),
        "versionString": .value(.string(#"release/1.2.4"#)),
      ]),
      "issues": .list([.value(.string("some"))]),
    ]))
  )}
  func generate(template: String, context: String) throws -> String {
    let context = try YamlParser.decodeYaml(query: .init(content: context))
    let generate = Generate(
      template: .value(template),
      templates: StencilTests.templates,
      allowEmpty: false,
      info: Generate.Info(event: [], args: nil, ctx: context)
    )
    return try StencilParser(notation: .json).generate(query: generate)
  }
  func testSubscript() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testSubscript"))
    XCTAssertEqual(result, "<@USERID>")
  }
  func testIncrement() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testIncrement"))
    XCTAssertEqual(result, #"12"#)
  }
  func testScan() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testScan"))
    XCTAssertEqual(result, #"1.3.4"#)
  }
  func testScanInplace() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testScanInplace"))
    XCTAssertEqual(result, #"1.3.3"#)
  }
  func testLine() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testLine"))
    XCTAssertEqual(result, #"ab c"#)
  }
  func testBool() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testBool"))
    XCTAssertEqual(result, #"good"#)
  }
  func testJson() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testJson"))
    XCTAssertEqual(result, #""yay\nyay""#)
  }
  func testStride() throws {
    try XCTAssertEqual("[123][456][7]", generate(
      template: """
      {% for subints in ctx.ints | stride:3 %}[{% for int in subints %}{{int}}{% endfor %}]{% endfor %}
      """,
      context: #"ints: [1,2,3,4,5,6,7]"#
    ))
  }
  func testInclude() throws {
    try XCTAssertEqual("hello", generate(
      template: """
      {% include "Included.stencil" ctx %}
      """,
      context: #"value: hello"#
    ))
  }
}
