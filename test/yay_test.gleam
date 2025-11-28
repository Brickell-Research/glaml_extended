import gleam/dict
import gleeunit
import gleeunit/should
import yay.{
  DuplicateKeysDetected, ExpectedBool, ExpectedFloat, ExpectedInt, ExpectedList,
  ExpectedMap, ExpectedString, ExpectedStringList, ExpectedStringMap, KeyMissing,
  KeyTypeMismatch, KeyValueEmpty,
}

pub fn main() {
  gleeunit.main()
}

// ============================================================================
// Helpers
// ============================================================================

/// Parses a YAML string and returns the root node of the first document.
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

// ============================================================================
// ==== Test ==== General Parsing
// ============================================================================

// Tests:
// * can parse multi-document string
// * can parse multi-document file
// * can select with selector
// * can select with sugar syntax
// * can parse unicode content
// * surfaces node not found error
// * surfaces selector parse error
// * preserves duplicate keys

// Parse String
pub fn parse_string_test() {
  let assert Ok([a, b]) =
    yay.parse_string("x: 2048\ny: 4096\nz: 1024\n---\nx: 0\ny: 0\nz: 0")

  should.equal(
    a,
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("x"), yay.NodeInt(2048)),
        #(yay.NodeStr("y"), yay.NodeInt(4096)),
        #(yay.NodeStr("z"), yay.NodeInt(1024)),
      ]),
    ),
  )

  should.equal(
    b,
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("x"), yay.NodeInt(0)),
        #(yay.NodeStr("y"), yay.NodeInt(0)),
        #(yay.NodeStr("z"), yay.NodeInt(0)),
      ]),
    ),
  )
}

// Parse File
pub fn parse_file_test() {
  let assert Ok(docs) =
    yay.parse_file("./test/yay/artifacts/multi_document.yaml")

  should.equal(docs, [
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(1))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(2))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(3))])),
  ])
}

// Selector
pub fn selector_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.document_root(doc)
  |> yay.select(
    yay.Selector([yay.SelectSeq(0), yay.SelectMap(yay.NodeStr("item_count"))]),
  )
  |> should.equal(Ok(yay.NodeInt(7)))
}

// Sugar Syntax
pub fn sugar_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.select_sugar(yay.document_root(doc), "#0.display name")
  |> should.equal(Ok(yay.NodeStr("snow leopard")))
}

// Unicode
pub fn unicode_test() {
  let assert Ok([doc]) =
    yay.parse_file("./test/yay/artifacts/unicode_test.yaml")

  yay.select_sugar(yay.document_root(doc), "records.#0.title")
  |> should.equal(Ok(yay.NodeStr("健康サポート")))
}

// Error - Node Not Found & Selector Parse Error
pub fn error_test() {
  let node = yay.NodeSeq([yay.NodeMap([#(yay.NodeStr("valid"), yay.NodeNil)])])

  yay.select(
    from: node,
    selector: yay.Selector([
      yay.SelectSeq(0),
      yay.SelectMap(yay.NodeStr("invalid")),
    ]),
  )
  |> should.equal(Error(yay.NodeNotFound(1)))

  yay.parse_selector("#invalid index")
  |> should.equal(Error(yay.SelectorParseError))
}

// Nil vs Empty Collections - verify parser distinguishes them
pub fn nil_vs_empty_collections_test() {
  let root = yaml_to_root("nil_list:\nempty_list: []\nnil_map:\nempty_map: {}")

  // nil values should be NodeNil
  yay.select_sugar(root, "nil_list")
  |> should.equal(Ok(yay.NodeNil))

  yay.select_sugar(root, "nil_map")
  |> should.equal(Ok(yay.NodeNil))

  // empty collections should be empty NodeSeq/NodeMap
  yay.select_sugar(root, "empty_list")
  |> should.equal(Ok(yay.NodeSeq([])))

  yay.select_sugar(root, "empty_map")
  |> should.equal(Ok(yay.NodeMap([])))
}

// Duplicate Keys
pub fn duplicate_key_test() {
  let assert Ok(docs) =
    yay.parse_file("./test/yay/artifacts/duplicate_keys.yaml")

  should.equal(docs, [
    yay.Document(
      yay.NodeMap([
        #(yay.NodeStr("doc"), yay.NodeInt(1)),
        #(yay.NodeStr("doc"), yay.NodeInt(2)),
      ]),
    ),
    yay.Document(
      yay.NodeMap([
        #(
          yay.NodeStr("doc"),
          yay.NodeMap([
            #(
              yay.NodeStr("inputs"),
              yay.NodeMap([
                #(yay.NodeStr("foo"), yay.NodeInt(1)),
                #(yay.NodeStr("foo"), yay.NodeInt(2)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

// ============================================================================
// ==== Test ==== extract_string_from_node
// ============================================================================

// Tests:
// * can extract string value
// * can extract nested string value
// * surfaces missing error
// * surfaces wrong type error
// * surfaces empty error
// * surfaces nested empty error

// Happy Path
pub fn extract_string_from_node_success_test() {
  let label = "name"

  yay.extract_string_from_node(yaml_to_root(label <> ": test_value"), label)
  |> should.equal(Ok("test_value"))
}

// Nested Happy Path
pub fn extract_string_from_node_nested_test() {
  let label = "outer.inner"

  yay.extract_string_from_node(
    yaml_to_root("outer:\n  inner: nested_value"),
    label,
  )
  |> should.equal(Ok("nested_value"))
}

// Missing
pub fn extract_string_from_node_missing_key_test() {
  let label = "name"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": test_value")
  yay.extract_string_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Wrong Type
pub fn extract_string_from_node_wrong_type_test() {
  let label = "name"

  let root = yaml_to_root(label <> ": 123")
  yay.extract_string_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedString, found: "int")),
  )
}

// Empty
pub fn extract_string_from_node_empty_test() {
  let label = "outer"

  let root = yaml_to_root(label <> ": ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// Nested Empty
pub fn extract_string_from_node_nested_empty_test() {
  let label = "outer.inner"

  let root = yaml_to_root("outer:\n  inner: ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// ==== Test ==== extract_int_from_node
// ============================================================================

// Tests:
// * can extract int value
// * can extract negative int
// * can extract zero
// * surfaces missing error
// * surfaces wrong type error
// * surfaces empty error

// Happy Path
pub fn extract_int_from_node_success_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": 42"), label)
  |> should.equal(Ok(42))
}

// Negative
pub fn extract_int_from_node_negative_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": -10"), label)
  |> should.equal(Ok(-10))
}

// Zero
pub fn extract_int_from_node_zero_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": 0"), label)
  |> should.equal(Ok(0))
}

// Missing
pub fn extract_int_from_node_missing_key_test() {
  let label = "count"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 42")
  yay.extract_int_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Wrong Type
pub fn extract_int_from_node_wrong_type_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_int_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedInt, found: "string")),
  )
}

// Empty
pub fn extract_int_from_node_empty_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": ")
  yay.extract_int_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// ==== Test ==== extract_float_from_node
// ============================================================================

// Tests:
// * can extract float value
// * can extract float from int (whole number)
// * can extract negative float
// * surfaces missing error
// * surfaces wrong type error
// * surfaces empty error

// Happy Path
pub fn extract_float_from_node_success_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": 99.9"), label)
  |> should.equal(Ok(99.9))
}

// From Int (YAML parsers often represent whole numbers as integers)
pub fn extract_float_from_node_from_int_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": 100"), label)
  |> should.equal(Ok(100.0))
}

// Negative
pub fn extract_float_from_node_negative_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": -3.14"), label)
  |> should.equal(Ok(-3.14))
}

// Missing
pub fn extract_float_from_node_missing_key_test() {
  let label = "threshold"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 99.9")
  yay.extract_float_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Wrong Type
pub fn extract_float_from_node_wrong_type_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_float_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedFloat, found: "string")),
  )
}

// Empty
pub fn extract_float_from_node_empty_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": ")
  yay.extract_float_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// ==== Test ==== extract_bool_from_node
// ============================================================================

// Tests:
// * can extract true & false
// * surfaces missing error
// * surfaces wrong type error
// * surfaces empty error

// Happy Path
pub fn extract_bool_from_node_true_test() {
  let label = "enabled"

  // True test
  yay.extract_bool_from_node(yaml_to_root(label <> ": true"), label)
  |> should.equal(Ok(True))

  // False test
  yay.extract_bool_from_node(yaml_to_root(label <> ": false"), label)
  |> should.equal(Ok(False))
}

// Missing
pub fn extract_bool_from_node_missing_key_test() {
  let label = "enabled"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": true")
  yay.extract_bool_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Wrong Type
pub fn extract_bool_from_node_wrong_type_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": yes_please")
  yay.extract_bool_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedBool, found: "string")),
  )
}

// Empty
pub fn extract_bool_from_node_empty_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": ")
  yay.extract_bool_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// ==== Test ==== extract_string_list_from_node
// ============================================================================

// Tests:
// * can extract string list
// * can extract single item list
// * can extract empty list
// * surfaces missing error
// * surfaces wrong item type error
// * surfaces not a list error

// Happy Path
pub fn extract_string_list_from_node_success_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    yaml_to_root(label <> ":\n  - first\n  - second\n  - third"),
    label,
  )
  |> should.equal(Ok(["first", "second", "third"]))
}

// Single Item
pub fn extract_string_list_from_node_single_item_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    yaml_to_root(label <> ":\n  - only_one"),
    label,
  )
  |> should.equal(Ok(["only_one"]))
}

// Nil Value - returns error
pub fn extract_string_list_from_node_nil_test() {
  let label = "items"

  yay.extract_string_list_from_node(yaml_to_root(label <> ": "), label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// Empty List - explicit [] returns Ok([])
pub fn extract_string_list_from_node_empty_test() {
  let label = "items"

  yay.extract_string_list_from_node(yaml_to_root(label <> ": []"), label)
  |> should.equal(Ok([]))
}

// Missing
pub fn extract_string_list_from_node_missing_key_test() {
  let label = "items"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ":\n  - first")
  yay.extract_string_list_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Wrong Item Type
pub fn extract_string_list_from_node_wrong_item_type_test() {
  let label = "items"

  let root = yaml_to_root(label <> ":\n  - 123\n  - 456")
  yay.extract_string_list_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: ExpectedStringList,
      found: "list with non-string items",
    )),
  )
}

// Not a List
pub fn extract_string_list_from_node_not_a_list_test() {
  let label = "items"

  let root = yaml_to_root(label <> ": not_a_list")
  yay.extract_string_list_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedList, found: "string")),
  )
}

// ============================================================================
// ==== Test ==== extract_dict_strings_from_node
// ============================================================================

// Tests:
// * can extract dict of strings
// * can extract single entry dict
// * can extract empty dict
// * surfaces missing error
// * surfaces not a map error
// * surfaces non-string value error
// * handles duplicate keys with fail_on_key_duplication: True
// * handles duplicate keys with fail_on_key_duplication: False

// Happy Path
pub fn extract_dict_strings_from_node_success_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  env: production\n  team: platform")
  let assert Ok(result) =
    yay.extract_dict_strings_from_node(
      root,
      label,
      fail_on_key_duplication: False,
    )
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

// Single Entry
pub fn extract_dict_strings_from_node_single_entry_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value")
  let assert Ok(result) =
    yay.extract_dict_strings_from_node(
      root,
      label,
      fail_on_key_duplication: False,
    )
  dict.size(result)
  |> should.equal(1)
  dict.get(result, "key")
  |> should.equal(Ok("value"))
}

// Nil Value - returns error
pub fn extract_dict_strings_from_node_nil_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": ")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: False)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// Empty Dict - explicit {} returns Ok(dict.new())
pub fn extract_dict_strings_from_node_empty_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": {}")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: False)
  |> should.equal(Ok(dict.new()))
}

// Missing
pub fn extract_dict_strings_from_node_missing_returns_empty_dict_test() {
  let missing_label = "missing"

  let root = yaml_to_root("other: value")
  yay.extract_dict_strings_from_node(
    root,
    missing_label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

// Not a Map
pub fn extract_dict_strings_from_node_not_a_map_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": not_a_map")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: False)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedMap, found: "string")),
  )
}

// Non-String Value
pub fn extract_dict_strings_from_node_non_string_value_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  count: 123")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: False)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: ExpectedStringMap,
      found: "map with non-string keys or values",
    )),
  )
}

// Duplicate Keys - Fail on Duplication
pub fn extract_dict_strings_from_node_duplicate_key_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: True)
  |> should.equal(Error(DuplicateKeysDetected(key: label, keys: ["key"])))
}

// Duplicate Keys - Do Not Fail on Duplication
pub fn extract_dict_strings_from_node_duplicate_key_do_not_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: False)
  |> should.equal(Ok(dict.from_list([#("key", "other_value")])))
}
