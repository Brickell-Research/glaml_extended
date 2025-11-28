import gleam/dict
import gleeunit/should
import test_helpers
import yay.{
  DuplicateKeysDetected, ExpectedMap, ExpectedStringMap, LabelMissing,
  LabelTypeMismatch,
}

// ==== Tests ====
// * ✅ can extract dict of strings
// * ✅ can extract single entry dict
// * ✅ can extract empty dict
// * ✅ surfaces missing error
// * ✅ surfaces not a map error
// * ✅ surfaces non-string value error
// * ✅ handles duplicate keys with fail_on_key_duplication: True
// * ✅ handles duplicate keys with fail_on_key_duplication: False

// Happy Path
pub fn extract_dict_strings_from_node_success_test() {
  let label = "labels"

  let root =
    test_helpers.yaml_to_root(label <> ":\n  env: production\n  team: platform")
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

  let root = test_helpers.yaml_to_root(label <> ":\n  key: value")
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

// Empty
pub fn extract_dict_strings_from_node_empty_test() {
  let label = "labels"

  let root = test_helpers.yaml_to_root(label <> ": ")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.new()))
}

// Missing
pub fn extract_dict_strings_from_node_missing_returns_empty_dict_test() {
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root("other: value")
  yay.extract_dict_strings_from_node(
    root,
    missing_label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Not a Map
pub fn extract_dict_strings_from_node_not_a_map_test() {
  let label = "labels"

  let root = test_helpers.yaml_to_root(label <> ": not_a_map")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedMap,
      found: "string",
    )),
  )
}

// Non-String Value
pub fn extract_dict_strings_from_node_non_string_value_test() {
  let label = "labels"

  let root = test_helpers.yaml_to_root(label <> ":\n  count: 123")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedStringMap,
      found: "map with non-string keys or values",
    )),
  )
}

// Duplicate Keys - Fail on Duplication
pub fn extract_dict_strings_from_node_duplicate_key_fail_on_duplication_test() {
  let label = "labels"

  let root =
    test_helpers.yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(root, label, fail_on_key_duplication: True)
  |> should.equal(Error(DuplicateKeysDetected(label: label, keys: ["key"])))
}

// Duplicate Keys - Do Not Fail on Duplication
pub fn extract_dict_strings_from_node_duplicate_key_do_not_fail_on_duplication_test() {
  let label = "labels"

  let root =
    test_helpers.yaml_to_root(label <> ":\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(
    root,
    label,
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.from_list([#("key", "other_value")])))
}
