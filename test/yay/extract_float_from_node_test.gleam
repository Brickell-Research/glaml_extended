import gleeunit/should
import test_helpers
import yay.{ExpectedFloat, LabelMissing, LabelTypeMismatch, LabelValueEmpty}

// ==== Tests ====
// * ✅ can extract float value
// * ✅ can extract float from int (whole number)
// * ✅ can extract negative float
// * ✅ surfaces missing error
// * ✅ surfaces wrong type error
// * ✅ surfaces empty error

// Happy Path
pub fn extract_float_from_node_success_test() {
  let label = "threshold"

  yay.extract_float_from_node(
    test_helpers.yaml_to_root(label <> ": 99.9"),
    label,
  )
  |> should.equal(Ok(99.9))
}

// From Int (YAML parsers often represent whole numbers as integers)
pub fn extract_float_from_node_from_int_test() {
  let label = "threshold"

  yay.extract_float_from_node(
    test_helpers.yaml_to_root(label <> ": 100"),
    label,
  )
  |> should.equal(Ok(100.0))
}

// Negative
pub fn extract_float_from_node_negative_test() {
  let label = "threshold"

  yay.extract_float_from_node(
    test_helpers.yaml_to_root(label <> ": -3.14"),
    label,
  )
  |> should.equal(Ok(-3.14))
}

// Missing
pub fn extract_float_from_node_missing_key_test() {
  let label = "threshold"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ": 99.9")
  yay.extract_float_from_node(root, missing_label)
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Wrong Type
pub fn extract_float_from_node_wrong_type_test() {
  let label = "threshold"

  let root = test_helpers.yaml_to_root(label <> ": not_a_number")
  yay.extract_float_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedFloat,
      found: "string",
    )),
  )
}

// Empty
pub fn extract_float_from_node_empty_test() {
  let label = "threshold"

  let root = test_helpers.yaml_to_root(label <> ": ")
  yay.extract_float_from_node(root, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}
