import yay.{ExpectedBool, LabelMissing, LabelTypeMismatch, LabelValueEmpty}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_bool_from_node_true_test() {
  let root = yaml_to_root("enabled: true")
  yay.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(True))
}

pub fn extract_bool_from_node_false_test() {
  let root = yaml_to_root("enabled: false")
  yay.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(False))
}

pub fn extract_bool_from_node_missing_key_test() {
  let root = yaml_to_root("enabled: true")
  yay.extract_bool_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_bool_from_node_wrong_type_test() {
  let root = yaml_to_root("enabled: yes_please")
  yay.extract_bool_from_node(root, "enabled")
  |> should.equal(
    Error(LabelTypeMismatch(
      label: "enabled",
      expected: ExpectedBool,
      found: "string",
    )),
  )
}

pub fn extract_bool_from_node_empty_test() {
  let root = yaml_to_root("enabled: ")
  yay.extract_bool_from_node(root, "enabled")
  |> should.equal(Error(LabelValueEmpty(label: "enabled")))
}
