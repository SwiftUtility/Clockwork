import XCTest
@testable import InteractivityStencil
@testable import Facility
@testable import FacilityPure
final class StencilTests: XCTestCase {
  func makeQuery(_ name: String) -> Generate { .init(
    template: name,
    templates: [
      "testSubscript": "{{custom.members[env.login].mention}}",
      "testRegexp": #"""
        {% filter regexp:custom.jiraRegexp,"{{_.1}}<link|{{_.2}}>{{_.3}}" %}
        {{ env.CI_MERGE_REQUEST_TITLE }}
        {% endfilter %}
        """#,
      "testFilterChaining": #"""
        {% filter regexp:"&","&amp;"|regexp:"\<","&lt;"|regexp:"\>","&gt;" %}
        {{ env.text }}
        {% endfilter %}
        """#,
      "testIncrement": #"""
        {{ env.version | filter:"incremented" }}
        """#,
      "testScanInplace": #"{% scan ".*(\d+)\.(\d+)\.(\d+).*" %}asd 1.2.3{%patch%}{{_.1}}.{{_.2 | filter:"incremented"}}.{{_.3}}{%endscan%}"#,
      "testScan": #"""
        {% scan custom.versionRegexp %}{#
          #}{{ custom.versionString }}{#
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
    ],
    context: AnyCodable.map([
      "env": .map([
        "login": .value(.string("user")),
        "text": .value(.string(#"<Mr-123> & Co"#)),
        "CI_MERGE_REQUEST_TITLE": .value(.string(#"MR-123, MB-234 ME-123: asd "asdas" [MR-234], RF-345'"#)),
        "version": .value(.string("11")),
      ]),
      "custom": .map([
        "members": .map([
          "user": .map([
            "mention": .value(.string("<@USERID>")),
          ]),
        ]),
        "jiraRegexp": .value(.string(#"( |^)([A-Z]+-\d+)( )"#)),
        "versionRegexp": .value(.string(#".*(\d+)\.(\d+)\.(\d+).*"#)),
        "versionString": .value(.string(#"release/1.2.4"#)),
      ]),
      "issues": .list([.value(.string("some"))]),
    ])
  )}
  func testSubscript() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testSubscript"))
    XCTAssertEqual(result, "<@USERID>")
  }
  func testRegexp() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testRegexp"))
    XCTAssertEqual(result, #"MR-123, <link|MB-234> ME-123: asd "asdas" [MR-234], RF-345'"#)
  }
  func testFilterChaining() throws {
    let result = try StencilParser(notation: .json)
      .generate(query: makeQuery("testFilterChaining"))
    XCTAssertEqual(result, #"&lt;Mr-123&gt; &amp; Co"#)
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
}
