import gleeunit/should
import test_helpers
import yay.{ExpectedList, ExpectedStringList, LabelMissing, LabelTypeMismatch}

// ==== Tests ====
// * ✅ can extract string list
// * ✅ can extract single item list
// * ✅ can extract empty list
// * ✅ surfaces missing error
// * ✅ surfaces wrong item type error
// * ✅ surfaces not a list error

// Happy Path
pub fn extract_string_list_from_node_success_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    test_helpers.yaml_to_root(label <> ":\n  - first\n  - second\n  - third"),
    label,
  )
  |> should.equal(Ok(["first", "second", "third"]))
}

// Single Item
pub fn extract_string_list_from_node_single_item_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    test_helpers.yaml_to_root(label <> ":\n  - only_one"),
    label,
  )
  |> should.equal(Ok(["only_one"]))
}

// Empty List
pub fn extract_string_list_from_node_empty_test() {
  let label = "items"

  yay.extract_string_list_from_node(
    test_helpers.yaml_to_root(label <> ": "),
    label,
  )
  |> should.equal(Ok([]))
}

// Missing
pub fn extract_string_list_from_node_missing_key_test() {
  let label = "items"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ":\n  - first")
  yay.extract_string_list_from_node(root, missing_label)
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Wrong Item Type
pub fn extract_string_list_from_node_wrong_item_type_test() {
  let label = "items"

  let root = test_helpers.yaml_to_root(label <> ":\n  - 123\n  - 456")
  yay.extract_string_list_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedStringList,
      found: "list with non-string items",
    )),
  )
}

// Not a List
pub fn extract_string_list_from_node_not_a_list_test() {
  let label = "items"

  let root = test_helpers.yaml_to_root(label <> ": not_a_list")
  yay.extract_string_list_from_node(root, label)
  |> should.equal(
    Error(LabelTypeMismatch(
      label: label,
      expected: ExpectedList,
      found: "string",
    )),
  )
}
