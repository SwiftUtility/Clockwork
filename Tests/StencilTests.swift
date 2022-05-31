import XCTest
@testable import InteractivityStencil
@testable import FacilityQueries
@testable import FacilityAutomates
final class StencilTests: XCTestCase {
  func makeQuery(_ name: String) -> RenderStencil { .init(
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
    ],
    context: Report.Context(
      env: [
        "login": "user",
        "text": #"<Mr-123> & Co"#,
        "CI_MERGE_REQUEST_TITLE": #"MR-123, MB-234 ME-123: asd "asdas" [MR-234], RF-345'"#
      ],
      custom: .map([
        "members": .map([
          "user": .map([
            "mention": .value(.string("<@USERID>")),
          ]),
        ]),
        "jiraRegexp": .value(.string(#"( |^)([A-Z]+-\d+)( )"#)),
      ]),
      issues: ["some"]
    )
  )}
  func testSubscript() throws {
    let result = try StencilParser(notation: .json)
      .renderStencil(query: makeQuery("testSubscript"))
    XCTAssertEqual(result, "<@USERID>")
  }
  func testRegexp() throws {
    let result = try StencilParser(notation: .json)
      .renderStencil(query: makeQuery("testRegexp"))
    XCTAssertEqual(result, #"MR-123, <link|MB-234> ME-123: asd "asdas" [MR-234], RF-345'"#)
  }
  func testFilterChaining() throws {
    let result = try StencilParser(notation: .json)
      .renderStencil(query: makeQuery("testFilterChaining"))
    XCTAssertEqual(result, #"&lt;Mr-123&gt; &amp; Co"#)
  }
}
