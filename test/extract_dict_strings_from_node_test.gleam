import yay.{
  DuplicateKeysDetected, ExpectedMap, ExpectedStringMap, LabelMissing,
  LabelTypeMismatch,
}
import gleam/dict
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_dict_strings_from_node_success_test() {
  let root = yaml_to_root("labels:\n  env: production\n  team: platform")
  let assert Ok(result) =
    yay.extract_dict_strings_from_node(
      root,
      "labels",
      fail_on_key_duplication: False,
    )
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

pub fn extract_dict_strings_from_node_missing_returns_empty_dict_test() {
  let root = yaml_to_root("other: value")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(LabelMissing(label: "labels")))
}

pub fn extract_dict_strings_from_node_not_a_map_test() {
  let root = yaml_to_root("labels: not_a_map")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(LabelTypeMismatch(
    label: "labels",
    expected: ExpectedMap,
    found: "string",
  )))
}

pub fn extract_dict_strings_from_node_empty_test() {
  let root = yaml_to_root("labels: ")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.new()))
}

pub fn extract_dict_strings_from_node_non_string_value_test() {
  let root = yaml_to_root("labels:\n  count: 123")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: False,
  )
  |> should.equal(Error(LabelTypeMismatch(
    label: "labels",
    expected: ExpectedStringMap,
    found: "map with non-string keys or values",
  )))
}

pub fn extract_dict_strings_from_node_single_entry_test() {
  let root = yaml_to_root("labels:\n  key: value")
  let assert Ok(result) =
    yay.extract_dict_strings_from_node(
      root,
      "labels",
      fail_on_key_duplication: False,
    )
  dict.size(result)
  |> should.equal(1)
  dict.get(result, "key")
  |> should.equal(Ok("value"))
}

pub fn extract_dict_strings_from_node_duplicate_key_fail_on_duplication_test() {
  let root = yaml_to_root("labels:\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: True,
  )
  |> should.equal(Error(DuplicateKeysDetected(label: "labels", keys: ["key"])))
}

pub fn extract_dict_strings_from_node_duplicate_key_do_not_fail_on_duplication_test() {
  let root = yaml_to_root("labels:\n  key: value\n  key: other_value")
  yay.extract_dict_strings_from_node(
    root,
    "labels",
    fail_on_key_duplication: False,
  )
  |> should.equal(Ok(dict.from_list([#("key", "other_value")])))
}
