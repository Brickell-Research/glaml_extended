import yay.{ExpectedInt, LabelMissing, LabelTypeMismatch, LabelValueEmpty}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_int_from_node_success_test() {
  let root = yaml_to_root("count: 42")
  yay.extract_int_from_node(root, "count")
  |> should.equal(Ok(42))
}

pub fn extract_int_from_node_missing_key_test() {
  let root = yaml_to_root("count: 42")
  yay.extract_int_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_int_from_node_wrong_type_test() {
  let root = yaml_to_root("count: not_a_number")
  yay.extract_int_from_node(root, "count")
  |> should.equal(Error(LabelTypeMismatch(
    label: "count",
    expected: ExpectedInt,
    found: "string",
  )))
}

pub fn extract_int_from_node_negative_test() {
  let root = yaml_to_root("count: -10")
  yay.extract_int_from_node(root, "count")
  |> should.equal(Ok(-10))
}

pub fn extract_int_from_node_zero_test() {
  let root = yaml_to_root("count: 0")
  yay.extract_int_from_node(root, "count")
  |> should.equal(Ok(0))
}

pub fn extract_int_from_node_empty_test() {
  let root = yaml_to_root("count: ")
  yay.extract_int_from_node(root, "count")
  |> should.equal(Error(LabelValueEmpty(label: "count")))
}
