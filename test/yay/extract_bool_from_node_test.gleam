import gleeunit/should
import test_helpers
import yay.{ExpectedBool, LabelMissing, LabelTypeMismatch, LabelValueEmpty}

// ==== Tests ====
// * ✅ can extract true & false
// * ✅ surfaces missing error
// * ✅ surfaces wrong type error
// * ✅ surfaces empty error

// Happy Path
pub fn extract_bool_from_node_true_test() {
  let label = "enabled"

  // True test
  yay.extract_bool_from_node(
    test_helpers.yaml_to_root(label <> ": true"),
    label,
  )
  |> should.equal(Ok(True))

  // False test
  yay.extract_bool_from_node(
    test_helpers.yaml_to_root(label <> ": false"),
    label,
  )
  |> should.equal(Ok(False))
}

// Missing
pub fn extract_bool_from_node_missing_key_test() {
  let label = "enabled"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ": true")
  yay.extract_bool_from_node(root, missing_label)
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Wrong Type
pub fn extract_bool_from_node_wrong_type_test() {
  let label = "enabled"

  let root = test_helpers.yaml_to_root(label <> ": yes_please")
  yay.extract_bool_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedBool,
      found: "string",
    )),
  )
}

// Empty
pub fn extract_bool_from_node_empty_test() {
  let label = "enabled"

  let root = test_helpers.yaml_to_root(label <> ": ")
  yay.extract_bool_from_node(root, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}
