import yay.{ExpectedString, LabelMissing, LabelTypeMismatch, LabelValueEmpty}
import gleeunit/should

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}

pub fn extract_string_from_node_success_test() {
  let root = yaml_to_root("name: test_value")
  yay.extract_string_from_node(root, "name")
  |> should.equal(Ok("test_value"))
}

pub fn extract_string_from_node_missing_key_test() {
  let root = yaml_to_root("name: test_value")
  yay.extract_string_from_node(root, "missing")
  |> should.equal(Error(LabelMissing(label: "missing")))
}

pub fn extract_string_from_node_wrong_type_test() {
  let root = yaml_to_root("name: 123")
  yay.extract_string_from_node(root, "name")
  |> should.equal(
    Error(LabelTypeMismatch(
      label: "name",
      expected: ExpectedString,
      found: "int",
    )),
  )
}

pub fn extract_string_from_node_nested_test() {
  let root = yaml_to_root("outer:\n  inner: nested_value")
  yay.extract_string_from_node(root, "outer.inner")
  |> should.equal(Ok("nested_value"))
}

pub fn extract_string_from_node_empty_test() {
  let root = yaml_to_root("outer: ")
  yay.extract_string_from_node(root, "outer")
  |> should.equal(Error(LabelValueEmpty(label: "outer")))
}

pub fn extract_string_from_node_nested_empty_test() {
  let root = yaml_to_root("outer:\n  inner: ")
  yay.extract_string_from_node(root, "outer.inner")
  |> should.equal(Error(LabelValueEmpty(label: "outer.inner")))
}
