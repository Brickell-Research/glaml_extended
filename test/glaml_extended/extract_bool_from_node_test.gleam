import glaml_extended
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml_extended.Node {
  let assert Ok([doc]) = glaml_extended.parse_string(yaml_str)
  glaml_extended.document_root(doc)
}

pub fn extract_bool_from_node_true_test() {
  let root = yaml_to_root("enabled: true")
  glaml_extended.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(True))
}

pub fn extract_bool_from_node_false_test() {
  let root = yaml_to_root("enabled: false")
  glaml_extended.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(False))
}

pub fn extract_bool_from_node_missing_key_test() {
  let root = yaml_to_root("enabled: true")
  glaml_extended.extract_bool_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_bool_from_node_wrong_type_test() {
  let root = yaml_to_root("enabled: yes_please")
  glaml_extended.extract_bool_from_node(root, "enabled")
  |> should.equal(Error("Expected enabled to be a boolean"))
}
