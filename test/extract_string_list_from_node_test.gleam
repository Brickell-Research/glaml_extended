import glaml_extended
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml_extended.Node {
  let assert Ok([doc]) = glaml_extended.parse_string(yaml_str)
  glaml_extended.document_root(doc)
}

pub fn extract_string_list_from_node_success_test() {
  let root = yaml_to_root("items:\n  - first\n  - second\n  - third")
  glaml_extended.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["first", "second", "third"]))
}

pub fn extract_string_list_from_node_single_item_test() {
  let root = yaml_to_root("items:\n  - only_one")
  glaml_extended.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["only_one"]))
}

pub fn extract_string_list_from_node_missing_key_test() {
  let root = yaml_to_root("items:\n  - first")
  glaml_extended.extract_string_list_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_string_list_from_node_wrong_item_type_test() {
  let root = yaml_to_root("items:\n  - 123\n  - 456")
  glaml_extended.extract_string_list_from_node(root, "items")
  |> should.equal(Error("Expected list item to be a string"))
}

pub fn extract_string_list_from_node_not_a_list_test() {
  let root = yaml_to_root("items: not_a_list")
  glaml_extended.extract_string_list_from_node(root, "items")
  |> should.equal(Error("Expected items list item to be a string"))
}

pub fn extract_string_list_from_node_empty_test() {
  let root = yaml_to_root("items: ")
  glaml_extended.extract_string_list_from_node(root, "items")
  |> should.equal(Ok([]))
}
