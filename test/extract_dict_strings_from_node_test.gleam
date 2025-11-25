import glaml_extended
import gleam/dict
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml_extended.Node {
  let assert Ok([doc]) = glaml_extended.parse_string(yaml_str)
  glaml_extended.document_root(doc)
}

pub fn extract_dict_strings_from_node_success_test() {
  let root = yaml_to_root("labels:\n  env: production\n  team: platform")
  let assert Ok(result) =
    glaml_extended.extract_dict_strings_from_node(root, "labels")
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

pub fn extract_dict_strings_from_node_missing_returns_empty_dict_test() {
  let root = yaml_to_root("other: value")
  glaml_extended.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Error("Missing labels"))
}

pub fn extract_dict_strings_from_node_not_a_map_test() {
  let root = yaml_to_root("labels: not_a_map")
  glaml_extended.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Error("Expected labels to be a map"))
}

pub fn extract_dict_strings_from_node_empty_test() {
  let root = yaml_to_root("labels: ")
  glaml_extended.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Ok(dict.new()))
}

pub fn extract_dict_strings_from_node_non_string_value_test() {
  let root = yaml_to_root("labels:\n  count: 123")
  glaml_extended.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Error("Expected labels entries to be string key-value pairs"))
}

pub fn extract_dict_strings_from_node_single_entry_test() {
  let root = yaml_to_root("labels:\n  key: value")
  let assert Ok(result) =
    glaml_extended.extract_dict_strings_from_node(root, "labels")
  dict.size(result)
  |> should.equal(1)
  dict.get(result, "key")
  |> should.equal(Ok("value"))
}
