import gleeunit/should
import test_helpers
import yay.{ExpectedString, LabelMissing, LabelTypeMismatch, LabelValueEmpty}

// ==== Tests ====
// * ✅ can extract string value
// * ✅ can extract nested string value
// * ✅ surfaces missing error
// * ✅ surfaces wrong type error
// * ✅ surfaces empty error
// * ✅ surfaces nested empty error

// Happy Path
pub fn extract_string_from_node_success_test() {
  let label = "name"

  yay.extract_string_from_node(
    test_helpers.yaml_to_root(label <> ": test_value"),
    label,
  )
  |> should.equal(Ok("test_value"))
}

// Nested Happy Path
pub fn extract_string_from_node_nested_test() {
  let label = "outer.inner"

  yay.extract_string_from_node(
    test_helpers.yaml_to_root("outer:\n  inner: nested_value"),
    label,
  )
  |> should.equal(Ok("nested_value"))
}

// Missing
pub fn extract_string_from_node_missing_key_test() {
  let label = "name"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ": test_value")
  yay.extract_string_from_node(root, missing_label)
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Wrong Type
pub fn extract_string_from_node_wrong_type_test() {
  let label = "name"

  let root = test_helpers.yaml_to_root(label <> ": 123")
  yay.extract_string_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedString,
      found: "int",
    )),
  )
}

// Empty
pub fn extract_string_from_node_empty_test() {
  let label = "outer"

  let root = test_helpers.yaml_to_root(label <> ": ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}

// Nested Empty
pub fn extract_string_from_node_nested_empty_test() {
  let label = "outer.inner"

  let root = test_helpers.yaml_to_root("outer:\n  inner: ")
  yay.extract_string_from_node(root, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}
