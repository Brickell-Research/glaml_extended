import yay.{ExpectedList, ExpectedStringList, LabelMissing, LabelTypeMismatch}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_string_list_from_node_success_test() {
  let root = yaml_to_root("items:\n  - first\n  - second\n  - third")
  yay.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["first", "second", "third"]))
}

pub fn extract_string_list_from_node_single_item_test() {
  let root = yaml_to_root("items:\n  - only_one")
  yay.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["only_one"]))
}

pub fn extract_string_list_from_node_missing_key_test() {
  let root = yaml_to_root("items:\n  - first")
  yay.extract_string_list_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_string_list_from_node_wrong_item_type_test() {
  let root = yaml_to_root("items:\n  - 123\n  - 456")
  yay.extract_string_list_from_node(root, "items")
  |> should.equal(Error(LabelTypeMismatch(
    label: "items",
    expected: ExpectedStringList,
    found: "list with non-string items",
  )))
}

pub fn extract_string_list_from_node_not_a_list_test() {
  let root = yaml_to_root("items: not_a_list")
  yay.extract_string_list_from_node(root, "items")
  |> should.equal(Error(LabelTypeMismatch(
    label: "items",
    expected: ExpectedList,
    found: "string",
  )))
}

pub fn extract_string_list_from_node_empty_test() {
  let root = yaml_to_root("items: ")
  yay.extract_string_list_from_node(root, "items")
  |> should.equal(Ok([]))
}
