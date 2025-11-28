import gleeunit/should
import test_helpers
import yay.{ExpectedInt, LabelMissing, LabelTypeMismatch, LabelValueEmpty}

// ==== Tests ====
// * ✅ can extract int value
// * ✅ can extract negative int
// * ✅ can extract zero
// * ✅ surfaces missing error
// * ✅ surfaces wrong type error
// * ✅ surfaces empty error

// Happy Path
pub fn extract_int_from_node_success_test() {
  let label = "count"

  yay.extract_int_from_node(test_helpers.yaml_to_root(label <> ": 42"), label)
  |> should.equal(Ok(42))
}

// Negative
pub fn extract_int_from_node_negative_test() {
  let label = "count"

  yay.extract_int_from_node(test_helpers.yaml_to_root(label <> ": -10"), label)
  |> should.equal(Ok(-10))
}

// Zero
pub fn extract_int_from_node_zero_test() {
  let label = "count"

  yay.extract_int_from_node(test_helpers.yaml_to_root(label <> ": 0"), label)
  |> should.equal(Ok(0))
}

// Missing
pub fn extract_int_from_node_missing_key_test() {
  let label = "count"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ": 42")
  yay.extract_int_from_node(root, missing_label)
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Wrong Type
pub fn extract_int_from_node_wrong_type_test() {
  let label = "count"

  let root = test_helpers.yaml_to_root(label <> ": not_a_number")
  yay.extract_int_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedInt,
      found: "string",
    )),
  )
}

// Empty
pub fn extract_int_from_node_empty_test() {
  let label = "count"

  let root = test_helpers.yaml_to_root(label <> ": ")
  yay.extract_int_from_node(root, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}
