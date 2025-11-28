import yay.{ExpectedFloat, LabelMissing, LabelTypeMismatch, LabelValueEmpty}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_float_from_node_success_test() {
  let root = yaml_to_root("threshold: 99.9")
  yay.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(99.9))
}

pub fn extract_float_from_node_missing_key_test() {
  let root = yaml_to_root("threshold: 99.9")
  yay.extract_float_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_float_from_node_from_int_test() {
  // YAML parsers often represent whole numbers as integers
  let root = yaml_to_root("threshold: 100")
  yay.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(100.0))
}

pub fn extract_float_from_node_negative_test() {
  let root = yaml_to_root("threshold: -3.14")
  yay.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(-3.14))
}

pub fn extract_float_from_node_wrong_type_test() {
  let root = yaml_to_root("threshold: not_a_number")
  yay.extract_float_from_node(root, "threshold")
  |> should.equal(Error(LabelTypeMismatch(
    label: "threshold",
    expected: ExpectedFloat,
    found: "string",
  )))
}

pub fn extract_float_from_node_empty_test() {
  let root = yaml_to_root("threshold: ")
  yay.extract_float_from_node(root, "threshold")
  |> should.equal(Error(LabelValueEmpty(label: "threshold")))
}
