import glaml_extended
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml_extended.Node {
  let assert Ok([doc]) = glaml_extended.parse_string(yaml_str)
  glaml_extended.document_root(doc)
}

pub fn extract_string_from_node_success_test() {
  let root = yaml_to_root("name: test_value")
  glaml_extended.extract_string_from_node(root, "name")
  |> should.equal(Ok("test_value"))
}

pub fn extract_string_from_node_missing_key_test() {
  let root = yaml_to_root("name: test_value")
  glaml_extended.extract_string_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_string_from_node_wrong_type_test() {
  let root = yaml_to_root("name: 123")
  glaml_extended.extract_string_from_node(root, "name")
  |> should.equal(Error("Expected name to be a string"))
}

pub fn extract_string_from_node_nested_test() {
  let root = yaml_to_root("outer:\n  inner: nested_value")
  glaml_extended.extract_string_from_node(root, "outer.inner")
  |> should.equal(Ok("nested_value"))
}
