import gleeunit
import gleeunit/should

import glaml
import gleam/dict

pub fn main() {
  gleeunit.main()
}

// Helper function to parse YAML string to root node
fn yaml_to_root(yaml_str: String) -> glaml.Node {
  let assert Ok([doc]) = glaml.parse_string(yaml_str)
  glaml.document_root(doc)
}

pub fn parse_string_test() {
  let assert Ok([a, b]) =
    glaml.parse_string("x: 2048\ny: 4096\nz: 1024\n---\nx: 0\ny: 0\nz: 0")

  should.equal(
    a,
    glaml.Document(
      glaml.NodeMap([
        #(glaml.NodeStr("x"), glaml.NodeInt(2048)),
        #(glaml.NodeStr("y"), glaml.NodeInt(4096)),
        #(glaml.NodeStr("z"), glaml.NodeInt(1024)),
      ]),
    ),
  )

  should.equal(
    b,
    glaml.Document(
      glaml.NodeMap([
        #(glaml.NodeStr("x"), glaml.NodeInt(0)),
        #(glaml.NodeStr("y"), glaml.NodeInt(0)),
        #(glaml.NodeStr("z"), glaml.NodeInt(0)),
      ]),
    ),
  )
}

pub fn parse_file_test() {
  let assert Ok(docs) = glaml.parse_file("./test/multi_document.yaml")

  should.equal(docs, [
    glaml.Document(glaml.NodeMap([#(glaml.NodeStr("doc"), glaml.NodeInt(1))])),
    glaml.Document(glaml.NodeMap([#(glaml.NodeStr("doc"), glaml.NodeInt(2))])),
    glaml.Document(glaml.NodeMap([#(glaml.NodeStr("doc"), glaml.NodeInt(3))])),
  ])
}

pub fn selector_test() {
  let assert Ok([doc]) = glaml.parse_file("./test/test.yaml")

  glaml.document_root(doc)
  |> glaml.select(
    glaml.Selector([
      glaml.SelectSeq(0),
      glaml.SelectMap(glaml.NodeStr("item_count")),
    ]),
  )
  |> should.equal(Ok(glaml.NodeInt(7)))
}

pub fn sugar_test() {
  let assert Ok([doc]) = glaml.parse_file("./test/test.yaml")

  glaml.select_sugar(glaml.document_root(doc), "#0.display name")
  |> should.equal(Ok(glaml.NodeStr("snow leopard")))
}

pub fn unicode_test() {
  let assert Ok([doc]) = glaml.parse_file("./test/unicode_test.yaml")

  glaml.select_sugar(glaml.document_root(doc), "records.#0.title")
  |> should.equal(Ok(glaml.NodeStr("健康サポート")))
}

pub fn error_test() {
  let node =
    glaml.NodeSeq([glaml.NodeMap([#(glaml.NodeStr("valid"), glaml.NodeNil)])])

  glaml.select(
    from: node,
    selector: glaml.Selector([
      glaml.SelectSeq(0),
      glaml.SelectMap(glaml.NodeStr("invalid")),
    ]),
  )
  |> should.equal(Error(glaml.NodeNotFound(1)))

  glaml.parse_selector("#invalid index")
  |> should.equal(Error(glaml.SelectorParseError))
}

pub fn duplicate_key_test() {
  let assert Ok(docs) = glaml.parse_file("./test/duplicate_keys.yaml")

  should.equal(docs, [
    glaml.Document(
      glaml.NodeMap([
        #(glaml.NodeStr("doc"), glaml.NodeInt(1)),
        #(glaml.NodeStr("doc"), glaml.NodeInt(2)),
      ]),
    ),
    glaml.Document(
      glaml.NodeMap([
        #(
          glaml.NodeStr("doc"),
          glaml.NodeMap([
            #(
              glaml.NodeStr("inputs"),
              glaml.NodeMap([
                #(glaml.NodeStr("foo"), glaml.NodeInt(1)),
                #(glaml.NodeStr("foo"), glaml.NodeInt(2)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

// ============================================================================
// Extractors Tests
// ============================================================================

// extract_string_from_node tests
pub fn extract_string_from_node_success_test() {
  let root = yaml_to_root("name: test_value")
  glaml.extract_string_from_node(root, "name")
  |> should.equal(Ok("test_value"))
}

pub fn extract_string_from_node_missing_key_test() {
  let root = yaml_to_root("name: test_value")
  glaml.extract_string_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_string_from_node_wrong_type_test() {
  let root = yaml_to_root("name: 123")
  glaml.extract_string_from_node(root, "name")
  |> should.equal(Error("Expected name to be a string"))
}

pub fn extract_string_from_node_nested_test() {
  let root = yaml_to_root("outer:\n  inner: nested_value")
  glaml.extract_string_from_node(root, "outer.inner")
  |> should.equal(Ok("nested_value"))
}

// extract_int_from_node tests
pub fn extract_int_from_node_success_test() {
  let root = yaml_to_root("count: 42")
  glaml.extract_int_from_node(root, "count")
  |> should.equal(Ok(42))
}

pub fn extract_int_from_node_missing_key_test() {
  let root = yaml_to_root("count: 42")
  glaml.extract_int_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_int_from_node_wrong_type_test() {
  let root = yaml_to_root("count: not_a_number")
  glaml.extract_int_from_node(root, "count")
  |> should.equal(Error("Expected count to be an integer"))
}

pub fn extract_int_from_node_negative_test() {
  let root = yaml_to_root("count: -10")
  glaml.extract_int_from_node(root, "count")
  |> should.equal(Ok(-10))
}

pub fn extract_int_from_node_zero_test() {
  let root = yaml_to_root("count: 0")
  glaml.extract_int_from_node(root, "count")
  |> should.equal(Ok(0))
}

// extract_float_from_node tests
pub fn extract_float_from_node_success_test() {
  let root = yaml_to_root("threshold: 99.9")
  glaml.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(99.9))
}

pub fn extract_float_from_node_missing_key_test() {
  let root = yaml_to_root("threshold: 99.9")
  glaml.extract_float_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_float_from_node_from_int_test() {
  // YAML parsers often represent whole numbers as integers
  let root = yaml_to_root("threshold: 100")
  glaml.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(100.0))
}

pub fn extract_float_from_node_negative_test() {
  let root = yaml_to_root("threshold: -3.14")
  glaml.extract_float_from_node(root, "threshold")
  |> should.equal(Ok(-3.14))
}

pub fn extract_float_from_node_wrong_type_test() {
  let root = yaml_to_root("threshold: not_a_number")
  glaml.extract_float_from_node(root, "threshold")
  |> should.equal(Error("Expected threshold to be a float"))
}

// extract_bool_from_node tests
pub fn extract_bool_from_node_true_test() {
  let root = yaml_to_root("enabled: true")
  glaml.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(True))
}

pub fn extract_bool_from_node_false_test() {
  let root = yaml_to_root("enabled: false")
  glaml.extract_bool_from_node(root, "enabled")
  |> should.equal(Ok(False))
}

pub fn extract_bool_from_node_missing_key_test() {
  let root = yaml_to_root("enabled: true")
  glaml.extract_bool_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_bool_from_node_wrong_type_test() {
  let root = yaml_to_root("enabled: yes_please")
  glaml.extract_bool_from_node(root, "enabled")
  |> should.equal(Error("Expected enabled to be a boolean"))
}

// extract_string_list_from_node tests
pub fn extract_string_list_from_node_success_test() {
  let root = yaml_to_root("items:\n  - first\n  - second\n  - third")
  glaml.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["first", "second", "third"]))
}

pub fn extract_string_list_from_node_single_item_test() {
  let root = yaml_to_root("items:\n  - only_one")
  glaml.extract_string_list_from_node(root, "items")
  |> should.equal(Ok(["only_one"]))
}

pub fn extract_string_list_from_node_missing_key_test() {
  let root = yaml_to_root("items:\n  - first")
  glaml.extract_string_list_from_node(root, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn extract_string_list_from_node_wrong_item_type_test() {
  let root = yaml_to_root("items:\n  - 123\n  - 456")
  glaml.extract_string_list_from_node(root, "items")
  |> should.equal(Error("Expected list item to be a string"))
}

pub fn extract_string_list_from_node_not_a_list_test() {
  let root = yaml_to_root("items: not_a_list")
  glaml.extract_string_list_from_node(root, "items")
  |> should.equal(Error("Expected items list item to be a string"))
}

// extract_dict_strings_from_node tests
pub fn extract_dict_strings_from_node_success_test() {
  let root = yaml_to_root("labels:\n  env: production\n  team: platform")
  let assert Ok(result) = glaml.extract_dict_strings_from_node(root, "labels")
  dict.get(result, "env")
  |> should.equal(Ok("production"))
  dict.get(result, "team")
  |> should.equal(Ok("platform"))
}

pub fn extract_dict_strings_from_node_missing_returns_empty_dict_test() {
  let root = yaml_to_root("other: value")
  glaml.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Ok(dict.new()))
}

pub fn extract_dict_strings_from_node_not_a_map_test() {
  let root = yaml_to_root("labels: not_a_map")
  glaml.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Error("Expected labels to be a map"))
}

pub fn extract_dict_strings_from_node_non_string_value_test() {
  let root = yaml_to_root("labels:\n  count: 123")
  glaml.extract_dict_strings_from_node(root, "labels")
  |> should.equal(Error("Expected labels entries to be string key-value pairs"))
}

pub fn extract_dict_strings_from_node_single_entry_test() {
  let root = yaml_to_root("labels:\n  key: value")
  let assert Ok(result) = glaml.extract_dict_strings_from_node(root, "labels")
  dict.size(result)
  |> should.equal(1)
  dict.get(result, "key")
  |> should.equal(Ok("value"))
}

// iteratively_parse_collection tests
pub fn iteratively_parse_collection_success_test() {
  let root = yaml_to_root("services:\n  - name: service1\n  - name: service2")
  let parse_service = fn(node, _params) {
    glaml.extract_string_from_node(node, "name")
  }
  glaml.iteratively_parse_collection(
    root,
    dict.new(),
    parse_service,
    "services",
  )
  |> should.equal(Ok(["service1", "service2"]))
}

pub fn iteratively_parse_collection_missing_key_test() {
  let root = yaml_to_root("services:\n  - name: service1")
  let parse_service = fn(node, _params) {
    glaml.extract_string_from_node(node, "name")
  }
  glaml.iteratively_parse_collection(root, dict.new(), parse_service, "missing")
  |> should.equal(Error("Missing missing"))
}

pub fn iteratively_parse_collection_empty_list_test() {
  let root = yaml_to_root("services: []")
  let parse_service = fn(node, _params) {
    glaml.extract_string_from_node(node, "name")
  }
  glaml.iteratively_parse_collection(
    root,
    dict.new(),
    parse_service,
    "services",
  )
  |> should.equal(Ok([]))
}

pub fn iteratively_parse_collection_single_item_test() {
  let root = yaml_to_root("services:\n  - name: only_service")
  let parse_service = fn(node, _params) {
    glaml.extract_string_from_node(node, "name")
  }
  glaml.iteratively_parse_collection(
    root,
    dict.new(),
    parse_service,
    "services",
  )
  |> should.equal(Ok(["only_service"]))
}

pub fn iteratively_parse_collection_parse_error_test() {
  let root = yaml_to_root("services:\n  - name: service1\n  - other: no_name")
  let parse_service = fn(node, _params) {
    glaml.extract_string_from_node(node, "name")
  }
  glaml.iteratively_parse_collection(
    root,
    dict.new(),
    parse_service,
    "services",
  )
  |> should.equal(Error("Missing name"))
}

pub fn iteratively_parse_collection_with_params_test() {
  let root = yaml_to_root("services:\n  - name: service1\n  - name: service2")
  let params = dict.from_list([#("prefix", "svc_")])
  let parse_service = fn(node, p) {
    let assert Ok(name) = glaml.extract_string_from_node(node, "name")
    let assert Ok(prefix) = dict.get(p, "prefix")
    Ok(prefix <> name)
  }
  glaml.iteratively_parse_collection(root, params, parse_service, "services")
  |> should.equal(Ok(["svc_service1", "svc_service2"]))
}
