import gleam/dict
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import yay.{DuplicateKeysDetected, KeyMissing, KeyTypeMismatch, KeyValueEmpty}

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

  yay.select_sugar(root, "nil_list")
  |> should.equal(Ok(yay.NodeNil))

  yay.select_sugar(root, "nil_map")
  |> should.equal(Ok(yay.NodeNil))

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
// extract_string
// ============================================================================

pub fn extract_string_success_test() {
  let label = "name"

  yay.extract_string(yaml_to_root(label <> ": test_value"), label)
  |> should.equal(Ok("test_value"))
}

pub fn extract_string_nested_test() {
  let label = "outer.inner"

  yay.extract_string(yaml_to_root("outer:\n  inner: nested_value"), label)
  |> should.equal(Ok("nested_value"))
}

pub fn extract_string_missing_key_test() {
  let label = "name"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": test_value")
  yay.extract_string(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_string_wrong_type_test() {
  let label = "name"

  let root = yaml_to_root(label <> ": 123")
  yay.extract_string(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "string", found: "int")),
  )
}

pub fn extract_string_empty_test() {
  let label = "outer"

  let root = yaml_to_root(label <> ": ")
  yay.extract_string(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_string_nested_empty_test() {
  let label = "outer.inner"

  let root = yaml_to_root("outer:\n  inner: ")
  yay.extract_string(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_int
// ============================================================================

pub fn extract_int_success_test() {
  let label = "count"

  yay.extract_int(yaml_to_root(label <> ": 42"), label)
  |> should.equal(Ok(42))
}

pub fn extract_int_negative_test() {
  let label = "count"

  yay.extract_int(yaml_to_root(label <> ": -10"), label)
  |> should.equal(Ok(-10))
}

pub fn extract_int_zero_test() {
  let label = "count"

  yay.extract_int(yaml_to_root(label <> ": 0"), label)
  |> should.equal(Ok(0))
}

pub fn extract_int_missing_key_test() {
  let label = "count"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 42")
  yay.extract_int(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_int_wrong_type_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_int(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "int", found: "string")),
  )
}

pub fn extract_int_empty_test() {
  let label = "count"

  let root = yaml_to_root(label <> ": ")
  yay.extract_int(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_float
// ============================================================================

pub fn extract_float_success_test() {
  let label = "threshold"

  yay.extract_float(yaml_to_root(label <> ": 99.9"), label)
  |> should.equal(Ok(99.9))
}

pub fn extract_float_from_int_test() {
  let label = "threshold"

  yay.extract_float(yaml_to_root(label <> ": 100"), label)
  |> should.equal(Ok(100.0))
}

pub fn extract_float_negative_test() {
  let label = "threshold"

  yay.extract_float(yaml_to_root(label <> ": -3.14"), label)
  |> should.equal(Ok(-3.14))
}

pub fn extract_float_missing_key_test() {
  let label = "threshold"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": 99.9")
  yay.extract_float(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_float_wrong_type_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": not_a_number")
  yay.extract_float(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "float", found: "string")),
  )
}

pub fn extract_float_empty_test() {
  let label = "threshold"

  let root = yaml_to_root(label <> ": ")
  yay.extract_float(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_bool
// ============================================================================

pub fn extract_bool_true_test() {
  let label = "enabled"

  yay.extract_bool(yaml_to_root(label <> ": true"), label)
  |> should.equal(Ok(True))

  yay.extract_bool(yaml_to_root(label <> ": false"), label)
  |> should.equal(Ok(False))
}

pub fn extract_bool_missing_key_test() {
  let label = "enabled"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ": true")
  yay.extract_bool(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_bool_wrong_type_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": yes_please")
  yay.extract_bool(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "bool", found: "string")),
  )
}

pub fn extract_bool_empty_test() {
  let label = "enabled"

  let root = yaml_to_root(label <> ": ")
  yay.extract_bool(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

// ============================================================================
// extract_string_list
// ============================================================================

pub fn extract_string_list_success_test() {
  let label = "items"

  yay.extract_string_list(
    yaml_to_root(label <> ":\n  - first\n  - second\n  - third"),
    label,
  )
  |> should.equal(Ok(["first", "second", "third"]))
}

pub fn extract_string_list_single_item_test() {
  let label = "items"

  yay.extract_string_list(yaml_to_root(label <> ":\n  - only_one"), label)
  |> should.equal(Ok(["only_one"]))
}

pub fn extract_string_list_nil_test() {
  let label = "items"

  yay.extract_string_list(yaml_to_root(label <> ": "), label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_string_list_empty_test() {
  let label = "items"

  yay.extract_string_list(yaml_to_root(label <> ": []"), label)
  |> should.equal(Ok([]))
}

pub fn extract_string_list_missing_key_test() {
  let label = "items"
  let missing_label = "missing"

  let root = yaml_to_root(label <> ":\n  - first")
  yay.extract_string_list(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_string_list_wrong_item_type_test() {
  let label = "items"

  let root = yaml_to_root(label <> ":\n  - 123\n  - 456")
  yay.extract_string_list(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "list of strings",
      found: "list containing int at index 0",
    )),
  )
}

pub fn extract_string_list_not_a_list_test() {
  let label = "items"

  let root = yaml_to_root(label <> ": not_a_list")
  yay.extract_string_list(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "list", found: "string")),
  )
}

// ============================================================================
// extract_int_list
// ============================================================================

pub fn extract_int_list_success_test() {
  let label = "numbers"

  yay.extract_int_list(yaml_to_root(label <> ":\n  - 1\n  - 2\n  - 3"), label)
  |> should.equal(Ok([1, 2, 3]))
}

pub fn extract_int_list_wrong_item_type_test() {
  let label = "numbers"

  let root = yaml_to_root(label <> ":\n  - one\n  - two")
  yay.extract_int_list(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "list of ints",
      found: "list containing string at index 0",
    )),
  )
}

// ============================================================================
// extract_float_list
// ============================================================================

pub fn extract_float_list_success_test() {
  let label = "values"

  yay.extract_float_list(
    yaml_to_root(label <> ":\n  - 1.5\n  - 2.5\n  - 3.5"),
    label,
  )
  |> should.equal(Ok([1.5, 2.5, 3.5]))
}

pub fn extract_float_list_from_ints_test() {
  let label = "values"

  yay.extract_float_list(yaml_to_root(label <> ":\n  - 1\n  - 2\n  - 3"), label)
  |> should.equal(Ok([1.0, 2.0, 3.0]))
}

// ============================================================================
// extract_bool_list
// ============================================================================

pub fn extract_bool_list_success_test() {
  let label = "flags"

  yay.extract_bool_list(
    yaml_to_root(label <> ":\n  - true\n  - false\n  - true"),
    label,
  )
  |> should.equal(Ok([True, False, True]))
}

pub fn extract_bool_list_wrong_item_type_test() {
  let label = "flags"

  let root = yaml_to_root(label <> ":\n  - yes\n  - no")
  yay.extract_bool_list(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "list of bools",
      found: "list containing string at index 0",
    )),
  )
}

// ============================================================================
// extract_string_map
// ============================================================================

pub fn extract_string_map_success_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  env: production\n  team: platform")
  let assert Ok(result) = yay.extract_string_map(root, label)
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

pub fn extract_string_map_single_entry_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value")
  let assert Ok(result) = yay.extract_string_map(root, label)
  dict.size(result)
  |> should.equal(1)
  dict.get(result, "key")
  |> should.equal(Ok("value"))
}

pub fn extract_string_map_nil_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": ")
  yay.extract_string_map(root, label)
  |> should.equal(Error(KeyValueEmpty(key: label)))
}

pub fn extract_string_map_empty_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": {}")
  yay.extract_string_map(root, label)
  |> should.equal(Ok(dict.new()))
}

pub fn extract_string_map_missing_key_test() {
  let missing_label = "missing"

  let root = yaml_to_root("other: value")
  yay.extract_string_map(root, missing_label)
  |> should.equal(Error(KeyMissing(key: missing_label, failed_at_segment: 0)))
}

pub fn extract_string_map_not_a_map_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ": not_a_map")
  yay.extract_string_map(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(key: label, expected: "map", found: "string")),
  )
}

pub fn extract_string_map_non_string_value_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  count: 123")
  yay.extract_string_map(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "map of strings",
      found: "map with int value at key 'count'",
    )),
  )
}

// ============================================================================
// extract_int_map
// ============================================================================

pub fn extract_int_map_success_test() {
  let label = "counts"

  let root = yaml_to_root(label <> ":\n  apples: 5\n  oranges: 10")
  let assert Ok(result) = yay.extract_int_map(root, label)
  dict.get(result, "apples")
  |> should.equal(Ok(5))
  dict.get(result, "oranges")
  |> should.equal(Ok(10))
}

pub fn extract_int_map_wrong_value_type_test() {
  let label = "counts"

  let root = yaml_to_root(label <> ":\n  apples: five")
  yay.extract_int_map(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "map of ints",
      found: "map with string value at key 'apples'",
    )),
  )
}

// ============================================================================
// extract_float_map
// ============================================================================

pub fn extract_float_map_success_test() {
  let label = "prices"

  let root = yaml_to_root(label <> ":\n  apple: 1.50\n  orange: 2.25")
  let assert Ok(result) = yay.extract_float_map(root, label)
  dict.get(result, "apple")
  |> should.equal(Ok(1.5))
  dict.get(result, "orange")
  |> should.equal(Ok(2.25))
}

pub fn extract_float_map_from_ints_test() {
  let label = "prices"

  let root = yaml_to_root(label <> ":\n  apple: 1\n  orange: 2")
  let assert Ok(result) = yay.extract_float_map(root, label)
  dict.get(result, "apple")
  |> should.equal(Ok(1.0))
  dict.get(result, "orange")
  |> should.equal(Ok(2.0))
}

// ============================================================================
// extract_bool_map
// ============================================================================

pub fn extract_bool_map_success_test() {
  let label = "features"

  let root =
    yaml_to_root(label <> ":\n  dark_mode: true\n  notifications: false")
  let assert Ok(result) = yay.extract_bool_map(root, label)
  dict.get(result, "dark_mode")
  |> should.equal(Ok(True))
  dict.get(result, "notifications")
  |> should.equal(Ok(False))
}

pub fn extract_bool_map_wrong_value_type_test() {
  let label = "features"

  let root = yaml_to_root(label <> ":\n  dark_mode: yes")
  yay.extract_bool_map(root, label)
  |> should.equal(
    Error(KeyTypeMismatch(
      key: label,
      expected: "map of bools",
      found: "map with string value at key 'dark_mode'",
    )),
  )
}

// ============================================================================
// extract_string_map_with_duplicate_detection
// ============================================================================

pub fn extract_string_map_duplicate_key_fail_on_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_string_map_with_duplicate_detection(
    root,
    label,
    fail_on_key_duplication: True,
  )
  |> should.equal(Error(DuplicateKeysDetected(key: label, keys: ["key"])))
}

pub fn extract_string_map_duplicate_key_allow_duplication_test() {
  let label = "labels"

  let root = yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_string_map_with_duplicate_detection(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.from_list([#("key", "other_value")])))
}

// ============================================================================
// extract_optional_* tests
// ============================================================================

pub fn extract_optional_string_present_test() {
  let root = yaml_to_root("name: hello")
  yay.extract_optional_string(root, "name")
  |> should.equal(Ok(option.Some("hello")))
}

pub fn extract_optional_string_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_optional_string(root, "name")
  |> should.equal(Ok(option.None))
}

pub fn extract_optional_string_nil_test() {
  let root = yaml_to_root("name: ")
  yay.extract_optional_string(root, "name")
  |> should.equal(Ok(option.None))
}

pub fn extract_optional_string_wrong_type_test() {
  let root = yaml_to_root("name: 123")
  yay.extract_optional_string(root, "name")
  |> should.equal(
    Error(KeyTypeMismatch(key: "name", expected: "string", found: "int")),
  )
}

pub fn extract_optional_int_present_test() {
  let root = yaml_to_root("count: 42")
  yay.extract_optional_int(root, "count")
  |> should.equal(Ok(option.Some(42)))
}

pub fn extract_optional_int_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_optional_int(root, "count")
  |> should.equal(Ok(option.None))
}

pub fn extract_optional_int_wrong_type_test() {
  let root = yaml_to_root("count: hello")
  yay.extract_optional_int(root, "count")
  |> should.equal(
    Error(KeyTypeMismatch(key: "count", expected: "int", found: "string")),
  )
}

pub fn extract_optional_float_present_test() {
  let root = yaml_to_root("value: 3.14")
  yay.extract_optional_float(root, "value")
  |> should.equal(Ok(option.Some(3.14)))
}

pub fn extract_optional_float_from_int_test() {
  let root = yaml_to_root("value: 42")
  yay.extract_optional_float(root, "value")
  |> should.equal(Ok(option.Some(42.0)))
}

pub fn extract_optional_float_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_optional_float(root, "value")
  |> should.equal(Ok(option.None))
}

pub fn extract_optional_bool_present_test() {
  let root = yaml_to_root("enabled: true")
  yay.extract_optional_bool(root, "enabled")
  |> should.equal(Ok(option.Some(True)))
}

pub fn extract_optional_bool_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_optional_bool(root, "enabled")
  |> should.equal(Ok(option.None))
}

// ============================================================================
// extract_*_or default value tests
// ============================================================================

pub fn extract_string_or_present_test() {
  let root = yaml_to_root("name: hello")
  yay.extract_string_or(root, "name", "default")
  |> should.equal(Ok("hello"))
}

pub fn extract_string_or_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_string_or(root, "name", "default")
  |> should.equal(Ok("default"))
}

pub fn extract_string_or_nil_test() {
  let root = yaml_to_root("name: ")
  yay.extract_string_or(root, "name", "default")
  |> should.equal(Ok("default"))
}

pub fn extract_string_or_wrong_type_test() {
  let root = yaml_to_root("name: 123")
  yay.extract_string_or(root, "name", "default")
  |> should.equal(
    Error(KeyTypeMismatch(key: "name", expected: "string", found: "int")),
  )
}

pub fn extract_int_or_present_test() {
  let root = yaml_to_root("count: 42")
  yay.extract_int_or(root, "count", 0)
  |> should.equal(Ok(42))
}

pub fn extract_int_or_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_int_or(root, "count", 99)
  |> should.equal(Ok(99))
}

pub fn extract_float_or_present_test() {
  let root = yaml_to_root("value: 3.14")
  yay.extract_float_or(root, "value", 0.0)
  |> should.equal(Ok(3.14))
}

pub fn extract_float_or_from_int_test() {
  let root = yaml_to_root("value: 42")
  yay.extract_float_or(root, "value", 0.0)
  |> should.equal(Ok(42.0))
}

pub fn extract_float_or_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_float_or(root, "value", 1.5)
  |> should.equal(Ok(1.5))
}

pub fn extract_bool_or_present_test() {
  let root = yaml_to_root("enabled: true")
  yay.extract_bool_or(root, "enabled", False)
  |> should.equal(Ok(True))
}

pub fn extract_bool_or_missing_test() {
  let root = yaml_to_root("other: value")
  yay.extract_bool_or(root, "enabled", True)
  |> should.equal(Ok(True))
}

// ============================================================================
// extract_list_with / extract_map_with (higher-order extractors)
// ============================================================================

pub fn extract_list_with_string_maps_test() {
  // Use flow style to avoid JS parser duplicate key detection issue
  let root =
    yaml_to_root(
      "servers: [{name: first}, {name: second}]",
    )

  let assert Ok(servers) =
    yay.extract_list_with(root, "servers", fn(item) {
      yay.extract_string_map(item, "")
    })

  list.length(servers)
  |> should.equal(2)
}

pub fn extract_list_with_nested_error_test() {
  let root = yaml_to_root("items:\n  - name: valid\n  - name: 123")

  yay.extract_list_with(root, "items", fn(item) {
    yay.extract_string_map(item, "")
  })
  |> should.equal(
    Error(KeyTypeMismatch(
      key: "items.#1",
      expected: "map of strings",
      found: "map with int value at key 'name'",
    )),
  )
}

pub fn extract_map_with_int_lists_test() {
  let root =
    yaml_to_root("groups:\n  a:\n    - 1\n    - 2\n  b:\n    - 3\n    - 4")

  let assert Ok(groups) =
    yay.extract_map_with(root, "groups", fn(item) {
      yay.extract_int_list(item, "")
    })

  dict.get(groups, "a")
  |> should.equal(Ok([1, 2]))
  dict.get(groups, "b")
  |> should.equal(Ok([3, 4]))
}

pub fn extract_map_with_nested_error_test() {
  let root = yaml_to_root("groups:\n  valid:\n    - 1\n  invalid:\n    - bad")

  yay.extract_map_with(root, "groups", fn(item) {
    yay.extract_int_list(item, "")
  })
  |> should.equal(
    Error(KeyTypeMismatch(
      key: "groups.invalid",
      expected: "list of ints",
      found: "list containing string at index 0",
    )),
  )
}

// ============================================================================
// Edge case tests
// ============================================================================

pub fn deeply_nested_path_test() {
  let root =
    yaml_to_root(
      "a:\n  b:\n    c:\n      d:\n        e:\n          f: deep_value",
    )

  yay.extract_string(root, "a.b.c.d.e.f")
  |> should.equal(Ok("deep_value"))
}

pub fn deeply_nested_missing_middle_test() {
  let root = yaml_to_root("a:\n  b:\n    wrong: value")

  yay.extract_string(root, "a.b.c.d.e")
  |> should.equal(Error(KeyMissing(key: "a.b.c.d.e", failed_at_segment: 2)))
}

pub fn list_error_at_later_index_test() {
  let root = yaml_to_root("items:\n  - valid\n  - also_valid\n  - 123")

  yay.extract_string_list(root, "items")
  |> should.equal(
    Error(KeyTypeMismatch(
      key: "items",
      expected: "list of strings",
      found: "list containing int at index 2",
    )),
  )
}

pub fn extract_from_sequence_with_index_test() {
  let root = yaml_to_root("items:\n  - name: first\n  - name: second")

  yay.extract_string(root, "items.#1.name")
  |> should.equal(Ok("second"))
}

pub fn extract_optional_nested_missing_parent_test() {
  let root = yaml_to_root("other: value")

  yay.extract_optional_string(root, "parent.child")
  |> should.equal(Ok(option.None))
}

pub fn extract_string_map_with_duplicate_detection_non_string_value_returns_error_test() {
  let root = yaml_to_root("labels:\n  key: 123")

  yay.extract_string_map_with_duplicate_detection(
    root,
    "labels",
    fail_on_key_duplication: True,
  )
  |> should.equal(
    Error(KeyTypeMismatch(
      key: "labels",
      expected: "map of strings",
      found: "map with int value at key 'key'",
    )),
  )
}

pub fn extraction_error_to_string_test() {
  yay.extraction_error_to_string(KeyMissing(
    key: "foo.bar",
    failed_at_segment: 1,
  ))
  |> should.equal("Missing foo.bar (failed at segment 1)")

  yay.extraction_error_to_string(KeyValueEmpty(key: "name"))
  |> should.equal("Expected name to be non-empty")

  yay.extraction_error_to_string(KeyTypeMismatch(
    key: "count",
    expected: "int",
    found: "string",
  ))
  |> should.equal("Expected count to be a int, but found string")

  yay.extraction_error_to_string(
    DuplicateKeysDetected(key: "map", keys: ["a", "b"]),
  )
  |> should.equal("Duplicate keys detected for map: a, b")
}
