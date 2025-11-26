import glaml_extended.{
  ExpectedInt, LabelMissing, LabelTypeMismatch, LabelValueEmpty,
}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml_extended.Node {
  let assert Ok([doc]) = glaml_extended.parse_string(yaml_str)
  glaml_extended.document_root(doc)
}

pub fn extract_int_from_node_success_test() {
  let root = yaml_to_root("count: 42")
  glaml_extended.extract_int_from_node(root, "count")
  |> should.equal(Ok(42))
}

pub fn extract_int_from_node_missing_key_test() {
  let root = yaml_to_root("count: 42")
  glaml_extended.extract_int_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_int_from_node_wrong_type_test() {
  let root = yaml_to_root("count: not_a_number")
  glaml_extended.extract_int_from_node(root, "count")
  |> should.equal(Error(LabelTypeMismatch(
    label: "count",
    expected: ExpectedInt,
    found: "string",
  )))
}

pub fn extract_int_from_node_negative_test() {
  let root = yaml_to_root("count: -10")
  glaml_extended.extract_int_from_node(root, "count")
  |> should.equal(Ok(-10))
}

pub fn extract_int_from_node_zero_test() {
  let root = yaml_to_root("count: 0")
  glaml_extended.extract_int_from_node(root, "count")
  |> should.equal(Ok(0))
}

pub fn extract_int_from_node_empty_test() {
  let root = yaml_to_root("count: ")
  glaml_extended.extract_int_from_node(root, "count")
  |> should.equal(Error(LabelValueEmpty(label: "count")))
}
