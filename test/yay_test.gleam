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
// General Parsing
// ============================================================================

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

pub fn parse_file_test() {
  let assert Ok(docs) =
    yay.parse_file("./test/yay/artifacts/multi_document.yaml")

  should.equal(docs, [
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(1))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(2))])),
    yay.Document(yay.NodeMap([#(yay.NodeStr("doc"), yay.NodeInt(3))])),
  ])
}

pub fn selector_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.document_root(doc)
  |> yay.select(
    yay.Selector([yay.SelectSeq(0), yay.SelectMap(yay.NodeStr("item_count"))]),
  )
  |> should.equal(Ok(yay.NodeInt(7)))
}

pub fn sugar_test() {
  let assert Ok([doc]) = yay.parse_file("./test/yay/artifacts/test.yaml")

  yay.select_sugar(yay.document_root(doc), "#0.display name")
  |> should.equal(Ok(yay.NodeStr("snow leopard")))
}

pub fn unicode_test() {
  let assert Ok([doc]) =
    yay.parse_file("./test/yay/artifacts/unicode_test.yaml")

  yay.select_sugar(yay.document_root(doc), "records.#0.title")
  |> should.equal(Ok(yay.NodeStr("健康サポート")))
}

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
// extract_string_from_node
// ============================================================================

pub fn extract_string_from_node_success_test() {
  let label = "name"

  yay.extract_string_from_node(yaml_to_root(label <> ": test_value"), label)
  |> should.equal(Ok("test_value"))
}

pub fn extract_string_from_node_nested_test() {
  let label = "outer.inner"

  yay.extract_string_from_node(
    yaml_to_root("outer:\n  inner: nested_value"),
    label,
  )
  |> should.equal(Ok("nested_value"))
}

pub fn extract_string_from_node_missing_key_test() {
  let label = "name"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": test_value")
  yay.extract_string_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

pub fn extract_string_from_node_wrong_type_test() {
  let label = "name"

  let root = yaml_to_root(label <> ": 123")
  yay.extract_string_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedString, found: "int")),
  )
}

pub fn extract_string_from_node_empty_test() {
  let label = "outer"

  let root = yaml_to_root(label <> ": ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_string_from_node_nested_empty_test() {
  let label = "outer.inner"

  let root = yaml_to_root("outer:\n  inner: ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_int_from_node
// ============================================================================

pub fn extract_int_from_node_success_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": 42"), label)
  |> should.equal(Ok(42))
}

pub fn extract_int_from_node_negative_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": -10"), label)
  |> should.equal(Ok(-10))
}

pub fn extract_int_from_node_zero_test() {
  let label = "count"

  yay.extract_int_from_node(yaml_to_root(label <> ": 0"), label)
  |> should.equal(Ok(0))
}

pub fn extract_int_from_node_missing_key_test() {
  let label = "count"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 42")
  yay.extract_int_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

pub fn extract_int_from_node_wrong_type_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_int_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedInt, found: "string")),
  )
}

pub fn extract_int_from_node_empty_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": ")
  yay.extract_int_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_float_from_node
// ============================================================================

pub fn extract_float_from_node_success_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": 99.9"), label)
  |> should.equal(Ok(99.9))
}

pub fn extract_float_from_node_from_int_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": 100"), label)
  |> should.equal(Ok(100.0))
}

pub fn extract_float_from_node_negative_test() {
  let label = "threshold"

  yay.extract_float_from_node(yaml_to_root(label <> ": -3.14"), label)
  |> should.equal(Ok(-3.14))
}

pub fn extract_float_from_node_missing_key_test() {
  let label = "threshold"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 99.9")
  yay.extract_float_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

pub fn extract_float_from_node_wrong_type_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_float_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedFloat, found: "string")),
  )
}

pub fn extract_float_from_node_empty_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": ")
  yay.extract_float_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_bool_from_node
// ============================================================================

pub fn extract_bool_from_node_true_test() {
  let label = "enabled"

  yay.extract_bool_from_node(yaml_to_root(label <> ": true"), label)
  |> should.equal(Ok(True))

  yay.extract_bool_from_node(yaml_to_root(label <> ": false"), label)
  |> should.equal(Ok(False))
}

pub fn extract_bool_from_node_missing_key_test() {
  let label = "enabled"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": true")
  yay.extract_bool_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

pub fn extract_bool_from_node_wrong_type_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": yes_please")
  yay.extract_bool_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedBool, found: "string")),
  )
}

pub fn extract_bool_from_node_empty_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": ")
  yay.extract_bool_from_node(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_string_list_from_node
// ============================================================================

pub fn extract_string_list_from_node_success_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    yaml_to_root(label <> ":\n  - first\n  - second\n  - third"),
    label,
  )
  |> should.equal(Ok(["first", "second", "third"]))
}

pub fn extract_string_list_from_node_single_item_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    yaml_to_root(label <> ":\n  - only_one"),
    label,
  )
  |> should.equal(Ok(["only_one"]))
}

pub fn extract_string_list_from_node_nil_test() {
  let label = "items"

  yay.extract_string_list_from_node(yaml_to_root(label <> ": "), label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_string_list_from_node_empty_test() {
  let label = "items"

  yay.extract_string_list_from_node(yaml_to_root(label <> ": []"), label)
  |> should.equal(Ok([]))
}

pub fn extract_string_list_from_node_missing_key_test() {
  let label = "items"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ":\n  - first")
  yay.extract_string_list_from_node(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label)))
}

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

pub fn extract_string_list_from_node_not_a_list_test() {
  let label = "items"

  let root = yaml_to_root(label <> ": not_a_list")
  yay.extract_string_list_from_node(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedList, found: "string")),
  )
}

// ============================================================================
// extract_dict_strings_from_node
// ============================================================================

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

pub fn extract_dict_strings_from_node_nil_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": ")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_dict_strings_from_node_empty_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": {}")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.new()))
}

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

pub fn extract_dict_strings_from_node_not_a_map_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": not_a_map")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: ExpectedMap, found: "string")),
  )
}

pub fn extract_dict_strings_from_node_non_string_value_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  count: 123")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: ExpectedStringMap,
      found: "map with non-string keys or values",
    )),
  )
}

pub fn extract_dict_strings_from_node_duplicate_key_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: True)
  |> should.equal(Error(DuplicateKeysDetected(key: label, keys: ["key"])))
}

pub fn extract_dict_strings_from_node_duplicate_key_do_not_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.from_list([#("key", "other_value")])))
}

// ============================================================================
// extract_optional_dict_strings
// ============================================================================

pub fn extract_optional_dict_strings_success_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  env: production\n  team: platform")
  let assert Ok(result) =
    yay.extract_optional_dict_strings(
      root,
      label,
      fail_on_key_duplication: False,
    )
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

pub fn extract_optional_dict_strings_missing_returns_empty_dict_test() {
  let missing_label = "missing"

  let root = yaml_to_root("other: value")
  yay.extract_optional_dict_strings(
    root,
    missing_label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.new()))
}

pub fn extract_optional_dict_strings_nil_returns_empty_dict_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": ")
  yay.extract_optional_dict_strings(root, label, fail_on_key_duplication: False)
  |> should.equal(Ok(dict.new()))
}

pub fn extract_optional_dict_strings_empty_returns_empty_dict_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": {}")
  yay.extract_optional_dict_strings(root, label, fail_on_key_duplication: False)
  |> should.equal(Ok(dict.new()))
}

pub fn extract_optional_dict_strings_not_a_map_returns_error_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": not_a_map")
  yay.extract_optional_dict_strings(root, label, fail_on_key_duplication: False)
  |> should.equal(Error("Expected labels to be a map, but found string"))
}

pub fn extract_optional_dict_strings_non_string_value_returns_error_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  count: 123")
  yay.extract_optional_dict_strings(root, label, fail_on_key_duplication: False)
  |> should.equal(Error(
    "Expected labels to be a map of strings, but found map with non-string keys or values",
  ))
}

pub fn extract_optional_dict_strings_duplicate_key_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_optional_dict_strings(root, label, fail_on_key_duplication: True)
  |> should.equal(Error("Duplicate keys detected for labels: key"))
}
