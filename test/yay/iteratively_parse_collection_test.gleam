import gleam/dict
import gleeunit/should
import test_helpers
import yay.{LabelMissing, LabelValueEmpty}

// ==== Tests ====
// * ✅ can parse collection successfully
// * ✅ can parse single item collection
// * ✅ can use params in parse function
// * ✅ surfaces missing error
// * ✅ surfaces parse error from callback
// * ✅ surfaces empty error

// Happy Path
pub fn iteratively_parse_collection_success_test() {
  let label = "services"

  let root =
    test_helpers.yaml_to_root(
      label <> ":\n  - name: service1\n  - name: service2",
    )
  let parse_service = fn(node, _params) {
    yay.extract_string_from_node(node, "name")
  }
  yay.iteratively_parse_collection(root, dict.new(), parse_service, label)
  |> should.equal(Ok(["service1", "service2"]))
}

// Single Item
pub fn iteratively_parse_collection_single_item_test() {
  let label = "services"

  let root = test_helpers.yaml_to_root(label <> ":\n  - name: only_service")
  let parse_service = fn(node, _params) {
    yay.extract_string_from_node(node, "name")
  }
  yay.iteratively_parse_collection(root, dict.new(), parse_service, label)
  |> should.equal(Ok(["only_service"]))
}

// With Params
pub fn iteratively_parse_collection_with_params_test() {
  let label = "services"

  let root =
    test_helpers.yaml_to_root(
      label <> ":\n  - name: service1\n  - name: service2",
    )
  let params = dict.from_list([#("prefix", "svc_")])
  let parse_service = fn(node, p) {
    let assert Ok(name) = yay.extract_string_from_node(node, "name")
    let assert Ok(prefix) = dict.get(p, "prefix")
    Ok(prefix <> name)
  }
  yay.iteratively_parse_collection(root, params, parse_service, label)
  |> should.equal(Ok(["svc_service1", "svc_service2"]))
}

// Missing
pub fn iteratively_parse_collection_missing_key_test() {
  let label = "services"
  let missing_label = "missing"

  let root = test_helpers.yaml_to_root(label <> ":\n  - name: service1")
  let parse_service = fn(node, _params) {
    yay.extract_string_from_node(node, "name")
  }
  yay.iteratively_parse_collection(
    root,
    dict.new(),
    parse_service,
    missing_label,
  )
  |> should.equal(Error(LabelMissing(label: missing_label)))
}

// Parse Error from Callback
pub fn iteratively_parse_collection_parse_error_test() {
  let label = "services"

  let root =
    test_helpers.yaml_to_root(
      label <> ":\n  - name: service1\n  - other: no_name",
    )
  let parse_service = fn(node, _params) {
    yay.extract_string_from_node(node, "name")
  }
  yay.iteratively_parse_collection(root, dict.new(), parse_service, label)
  |> should.equal(Error(LabelMissing(label: "name")))
}

// Empty
pub fn iteratively_parse_collection_with_no_content_test() {
  let label = "services"

  let root = test_helpers.yaml_to_root(label <> ":")
  let parse_service = fn(node, _params) {
    yay.extract_string_from_node(node, "name")
  }
  yay.iteratively_parse_collection(root, dict.new(), parse_service, label)
  |> should.equal(Error(LabelValueEmpty(label: label)))
}
