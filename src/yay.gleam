import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

/// A YAML document error containing a message — `msg` and its location — `loc`.
///
pub type YamlError {
  UnexpectedParsingError
  ParsingError(msg: String, loc: YamlErrorLoc)
}

/// The location of a YAML parsing error.
///
pub type YamlErrorLoc {
  YamlErrorLoc(line: Int, column: Int)
}

/// A YAML document.<br />
/// To get the root `Node` call `document_root` on it, like this:
///
/// ```gleam
/// let document = Document(root: NodeNil)
/// let assert NodeNil = document_root(document)
/// ```
///
pub type Document {
  Document(root: Node)
}

/// A YAML document node.
///
pub type Node {
  NodeNil
  NodeStr(String)
  NodeBool(Bool)
  NodeInt(Int)
  NodeFloat(Float)
  NodeSeq(List(Node))
  NodeMap(List(#(Node, Node)))
}

/// Parse a YAML file located in `path` into a list of YAML documents.
///
@external(erlang, "yaml_ffi", "parse_file")
@external(javascript, "./yaml_ffi.mjs", "parse_file")
pub fn parse_file(path: String) -> Result(List(Document), YamlError)

/// Parse a string into a list of YAML documents.
///
@external(erlang, "yaml_ffi", "parse_string")
@external(javascript, "./yaml_ffi.mjs", "parse_string")
pub fn parse_string(string: String) -> Result(List(Document), YamlError)

/// Gets the root `Node` of a YAML document.
///
/// ## Examples
///
/// ```gleam
/// let document = Document(root: NodeNil)
/// let assert NodeNil = document_root(document)
/// ```
///
pub fn document_root(document: Document) -> Node {
  document.root
}

/// A document selector that contains a sequence of selections leading to a `Node`.
///
pub type Selector {
  Selector(List(Selection))
}

/// A `Node` selection used by `Selector`.
///
pub type Selection {
  SelectMap(key: Node)
  SelectSeq(index: Int)
}

/// An error that can occur when selecting a node.
///
pub type SelectorError {
  NodeNotFound(at: Int)
  SelectorParseError
}

/// Parses the `selector` and queries the given `node` with it.
///
/// ## Examples
///
/// ```gleam
/// let map = NodeMap([
///   #(NodeStr("list"), NodeMap([
///     #(NodeStr("elements"), NodeSeq([NodeInt(101)]))
///   ])),
///   #(NodeStr("linked"), NodeBool(False)),
/// ])
///
/// let assert Ok(NodeInt(101)) = select_sugar(from: map, selector: "list.elements.#0")
/// ```
///
pub fn select_sugar(
  from node: Node,
  selector selector: String,
) -> Result(Node, SelectorError) {
  use selector <- result.try(parse_selector(selector))
  select(node, selector)
}

/// Queries the given `node` with a `Selector`.
///
/// ## Examples
///
/// ```gleam
/// let map = NodeMap([
///   #(NodeStr("lib name"), NodeStr("yay")),
///   #(NodeStr("stars"), NodeInt(7)),
/// ])
///
/// let assert Ok(NodeInt(7)) = select(from: map, selector: Selector([SelectMap(NodeStr("stars"))]))
/// ```
///
pub fn select(
  from node: Node,
  selector selector: Selector,
) -> Result(Node, SelectorError) {
  do_select(node, selector, 0)
}

fn do_select(
  node: Node,
  selector: Selector,
  select_idx: Int,
) -> Result(Node, SelectorError) {
  case selector {
    Selector([select, ..selector_tail]) ->
      case select {
        SelectSeq(index) ->
          case node {
            NodeSeq(seq) ->
              case list_at(seq, index) {
                option.Some(node) ->
                  do_select(node, Selector(selector_tail), select_idx + 1)
                option.None -> Error(NodeNotFound(select_idx))
              }
            _ -> Error(NodeNotFound(select_idx))
          }
        SelectMap(key) ->
          case node {
            NodeMap(pairs) ->
              case list.key_find(pairs, key) {
                Ok(node) ->
                  do_select(node, Selector(selector_tail), select_idx + 1)
                Error(_) -> Error(NodeNotFound(select_idx))
              }
            _ -> Error(NodeNotFound(select_idx))
          }
      }
    Selector([]) -> Ok(node)
  }
}

fn list_at(l: List(a), index: Int) -> option.Option(a) {
  case l {
    [head, ..tail] ->
      case index {
        0 -> option.Some(head)
        _ -> list_at(tail, index - 1)
      }
    [] -> option.None
  }
}

/// Parses a selector string into a `Selector`.
///
pub fn parse_selector(selector: String) -> Result(Selector, SelectorError) {
  use selections <- result.try(
    do_parse_selector(string.split(selector, on: "."), []),
  )
  Ok(Selector(list.reverse(selections)))
}

fn do_parse_selector(
  selector_parts: List(String),
  acc: List(Selection),
) -> Result(List(Selection), SelectorError) {
  case selector_parts {
    ["", ..tail] -> do_parse_selector(tail, acc)
    [part, ..tail] ->
      case string.starts_with(part, "#") {
        True ->
          case int.parse(string.drop_start(part, 1)) {
            Ok(index) -> do_parse_selector(tail, [SelectSeq(index), ..acc])
            Error(Nil) -> Error(SelectorParseError)
          }
        False -> do_parse_selector(tail, [SelectMap(NodeStr(part)), ..acc])
      }
    [] -> Ok(acc)
  }
}

// ============================================================================
// Extraction Errors
// ============================================================================

/// An error that can occur when extracting a value from a node.
///
pub type ExtractionError {
  KeyMissing(key: String, failed_at_segment: Int)
  KeyValueEmpty(key: String)
  KeyTypeMismatch(key: String, expected: String, found: String)
  DuplicateKeysDetected(key: String, keys: List(String))
}

/// Converts an ExtractionError to a human-readable string.
pub fn extraction_error_to_string(error: ExtractionError) -> String {
  case error {
    KeyMissing(key, failed_at_segment) ->
      "Missing "
      <> key
      <> " (failed at segment "
      <> int.to_string(failed_at_segment)
      <> ")"
    KeyValueEmpty(key) -> "Expected " <> key <> " to be non-empty"
    KeyTypeMismatch(key, expected, found) ->
      "Expected " <> key <> " to be a " <> expected <> ", but found " <> found
    DuplicateKeysDetected(key, keys) ->
      "Duplicate keys detected for " <> key <> ": " <> string.join(keys, ", ")
  }
}

/// Converts a Node to a human-readable type name.
fn node_type_name(node: Node) -> String {
  case node {
    NodeNil -> "nil"
    NodeStr(_) -> "string"
    NodeBool(_) -> "bool"
    NodeInt(_) -> "int"
    NodeFloat(_) -> "float"
    NodeSeq(_) -> "list"
    NodeMap(_) -> "map"
  }
}

/// Internal helper to select a node or return KeyMissing with position info.
fn select_or_missing(node: Node, key: String) -> Result(Node, ExtractionError) {
  case select_sugar(node, key) {
    Ok(n) -> Ok(n)
    Error(NodeNotFound(at)) ->
      Error(KeyMissing(key: key, failed_at_segment: at))
    Error(SelectorParseError) ->
      Error(KeyMissing(key: key, failed_at_segment: 0))
  }
}

// ============================================================================
// Extractors - Primitives
// ============================================================================

/// Extracts a string from a YAML node.
pub fn extract_string(
  node: Node,
  key: String,
) -> Result(String, ExtractionError) {
  use selected <- result.try(select_or_missing(node, key))
  case selected {
    NodeStr(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "string",
        found: node_type_name(other),
      ))
  }
}

/// Extracts an integer from a YAML node.
pub fn extract_int(node: Node, key: String) -> Result(Int, ExtractionError) {
  use selected <- result.try(select_or_missing(node, key))
  case selected {
    NodeInt(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "int",
        found: node_type_name(other),
      ))
  }
}

/// Extracts a float from a YAML node.
/// Also accepts integers and converts them to floats.
pub fn extract_float(node: Node, key: String) -> Result(Float, ExtractionError) {
  use selected <- result.try(select_or_missing(node, key))
  case selected {
    NodeFloat(value) -> Ok(value)
    NodeInt(value) -> Ok(int.to_float(value))
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "float",
        found: node_type_name(other),
      ))
  }
}

/// Extracts a boolean from a YAML node.
pub fn extract_bool(node: Node, key: String) -> Result(Bool, ExtractionError) {
  use selected <- result.try(select_or_missing(node, key))
  case selected {
    NodeBool(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "bool",
        found: node_type_name(other),
      ))
  }
}

// ============================================================================
// Extractors - Optional Primitives
// ============================================================================

/// Extracts an optional string from a YAML node.
/// Returns Ok(None) if the key is missing, Ok(Some(value)) if present.
/// Returns Error for type mismatches.
pub fn extract_optional_string(
  node: Node,
  key: String,
) -> Result(option.Option(String), ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(option.None)
    Ok(selected) ->
      case selected {
        NodeStr(value) -> Ok(option.Some(value))
        NodeNil -> Ok(option.None)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "string",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts an optional integer from a YAML node.
/// Returns Ok(None) if the key is missing, Ok(Some(value)) if present.
/// Returns Error for type mismatches.
pub fn extract_optional_int(
  node: Node,
  key: String,
) -> Result(option.Option(Int), ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(option.None)
    Ok(selected) ->
      case selected {
        NodeInt(value) -> Ok(option.Some(value))
        NodeNil -> Ok(option.None)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "int",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts an optional float from a YAML node.
/// Returns Ok(None) if the key is missing, Ok(Some(value)) if present.
/// Also accepts integers and converts them to floats.
/// Returns Error for type mismatches.
pub fn extract_optional_float(
  node: Node,
  key: String,
) -> Result(option.Option(Float), ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(option.None)
    Ok(selected) ->
      case selected {
        NodeFloat(value) -> Ok(option.Some(value))
        NodeInt(value) -> Ok(option.Some(int.to_float(value)))
        NodeNil -> Ok(option.None)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "float",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts an optional boolean from a YAML node.
/// Returns Ok(None) if the key is missing, Ok(Some(value)) if present.
/// Returns Error for type mismatches.
pub fn extract_optional_bool(
  node: Node,
  key: String,
) -> Result(option.Option(Bool), ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(option.None)
    Ok(selected) ->
      case selected {
        NodeBool(value) -> Ok(option.Some(value))
        NodeNil -> Ok(option.None)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "bool",
            found: node_type_name(other),
          ))
      }
  }
}

// ============================================================================
// Extractors - With Defaults
// ============================================================================

/// Extracts a string from a YAML node, returning a default if the key is missing or nil.
/// Returns Error only for type mismatches.
pub fn extract_string_or(
  node: Node,
  key: String,
  default: String,
) -> Result(String, ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(default)
    Ok(selected) ->
      case selected {
        NodeStr(value) -> Ok(value)
        NodeNil -> Ok(default)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "string",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts an integer from a YAML node, returning a default if the key is missing or nil.
/// Returns Error only for type mismatches.
pub fn extract_int_or(
  node: Node,
  key: String,
  default: Int,
) -> Result(Int, ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(default)
    Ok(selected) ->
      case selected {
        NodeInt(value) -> Ok(value)
        NodeNil -> Ok(default)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "int",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts a float from a YAML node, returning a default if the key is missing or nil.
/// Also accepts integers and converts them to floats.
/// Returns Error only for type mismatches.
pub fn extract_float_or(
  node: Node,
  key: String,
  default: Float,
) -> Result(Float, ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(default)
    Ok(selected) ->
      case selected {
        NodeFloat(value) -> Ok(value)
        NodeInt(value) -> Ok(int.to_float(value))
        NodeNil -> Ok(default)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "float",
            found: node_type_name(other),
          ))
      }
  }
}

/// Extracts a boolean from a YAML node, returning a default if the key is missing or nil.
/// Returns Error only for type mismatches.
pub fn extract_bool_or(
  node: Node,
  key: String,
  default: Bool,
) -> Result(Bool, ExtractionError) {
  case select_sugar(node, key) {
    Error(_) -> Ok(default)
    Ok(selected) ->
      case selected {
        NodeBool(value) -> Ok(value)
        NodeNil -> Ok(default)
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "bool",
            found: node_type_name(other),
          ))
      }
  }
}

// ============================================================================
// Extractors - Lists
// ============================================================================

/// Extracts a list of strings from a YAML node.
pub fn extract_string_list(
  node: Node,
  key: String,
) -> Result(List(String), ExtractionError) {
  extract_list(node, key, "string", fn(n) {
    case n {
      NodeStr(s) -> Ok(s)
      _ -> Error(Nil)
    }
  })
}

/// Extracts a list of integers from a YAML node.
pub fn extract_int_list(
  node: Node,
  key: String,
) -> Result(List(Int), ExtractionError) {
  extract_list(node, key, "int", fn(n) {
    case n {
      NodeInt(i) -> Ok(i)
      _ -> Error(Nil)
    }
  })
}

/// Extracts a list of floats from a YAML node.
/// Also accepts integers and converts them to floats.
pub fn extract_float_list(
  node: Node,
  key: String,
) -> Result(List(Float), ExtractionError) {
  extract_list(node, key, "float", fn(n) {
    case n {
      NodeFloat(f) -> Ok(f)
      NodeInt(i) -> Ok(int.to_float(i))
      _ -> Error(Nil)
    }
  })
}

/// Extracts a list of booleans from a YAML node.
pub fn extract_bool_list(
  node: Node,
  key: String,
) -> Result(List(Bool), ExtractionError) {
  extract_list(node, key, "bool", fn(n) {
    case n {
      NodeBool(b) -> Ok(b)
      _ -> Error(Nil)
    }
  })
}

/// Internal helper for extracting typed lists with index information in errors.
fn extract_list(
  node: Node,
  key: String,
  item_type: String,
  extract_item: fn(Node) -> Result(a, Nil),
) -> Result(List(a), ExtractionError) {
  use list_node <- result.try(select_or_missing(node, key))
  case list_node {
    NodeNil -> Error(KeyValueEmpty(key: key))
    NodeSeq(items) ->
      extract_list_items(items, key, item_type, extract_item, 0, [])
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "list",
        found: node_type_name(other),
      ))
  }
}

/// Helper to extract list items with index tracking for better error messages.
fn extract_list_items(
  items: List(Node),
  key: String,
  item_type: String,
  extract_item: fn(Node) -> Result(a, Nil),
  index: Int,
  acc: List(a),
) -> Result(List(a), ExtractionError) {
  case items {
    [] -> Ok(list.reverse(acc))
    [item, ..rest] ->
      case extract_item(item) {
        Ok(value) ->
          extract_list_items(rest, key, item_type, extract_item, index + 1, [
            value,
            ..acc
          ])
        Error(_) ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "list of " <> item_type <> "s",
            found: "list containing "
              <> node_type_name(item)
              <> " at index "
              <> int.to_string(index),
          ))
      }
  }
}

// ============================================================================
// Extractors - Maps
// ============================================================================

/// Extracts a map of string values from a YAML node.
pub fn extract_string_map(
  node: Node,
  key: String,
) -> Result(dict.Dict(String, String), ExtractionError) {
  extract_map(node, key, "string", fn(n) {
    case n {
      NodeStr(s) -> Ok(s)
      _ -> Error(Nil)
    }
  })
}

/// Extracts a map of integer values from a YAML node.
pub fn extract_int_map(
  node: Node,
  key: String,
) -> Result(dict.Dict(String, Int), ExtractionError) {
  extract_map(node, key, "int", fn(n) {
    case n {
      NodeInt(i) -> Ok(i)
      _ -> Error(Nil)
    }
  })
}

/// Extracts a map of float values from a YAML node.
/// Also accepts integers and converts them to floats.
pub fn extract_float_map(
  node: Node,
  key: String,
) -> Result(dict.Dict(String, Float), ExtractionError) {
  extract_map(node, key, "float", fn(n) {
    case n {
      NodeFloat(f) -> Ok(f)
      NodeInt(i) -> Ok(int.to_float(i))
      _ -> Error(Nil)
    }
  })
}

/// Extracts a map of boolean values from a YAML node.
pub fn extract_bool_map(
  node: Node,
  key: String,
) -> Result(dict.Dict(String, Bool), ExtractionError) {
  extract_map(node, key, "bool", fn(n) {
    case n {
      NodeBool(b) -> Ok(b)
      _ -> Error(Nil)
    }
  })
}

/// Internal helper for extracting typed maps with detailed error messages.
fn extract_map(
  node: Node,
  key: String,
  value_type: String,
  extract_value: fn(Node) -> Result(a, Nil),
) -> Result(dict.Dict(String, a), ExtractionError) {
  use map_node <- result.try(select_or_missing(node, key))
  case map_node {
    NodeNil -> Error(KeyValueEmpty(key: key))
    NodeMap(entries) ->
      extract_map_entries(entries, key, value_type, extract_value, [])
      |> result.map(dict.from_list)
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "map",
        found: node_type_name(other),
      ))
  }
}

/// Helper to extract map entries with detailed error messages.
fn extract_map_entries(
  entries: List(#(Node, Node)),
  key: String,
  value_type: String,
  extract_value: fn(Node) -> Result(a, Nil),
  acc: List(#(String, a)),
) -> Result(List(#(String, a)), ExtractionError) {
  case entries {
    [] -> Ok(list.reverse(acc))
    [#(NodeStr(k), value_node), ..rest] ->
      case extract_value(value_node) {
        Ok(v) ->
          extract_map_entries(rest, key, value_type, extract_value, [
            #(k, v),
            ..acc
          ])
        Error(_) ->
          Error(KeyTypeMismatch(
            key: key,
            expected: "map of " <> value_type <> "s",
            found: "map with "
              <> node_type_name(value_node)
              <> " value at key '"
              <> k
              <> "'",
          ))
      }
    [#(key_node, _), ..] ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "map of " <> value_type <> "s",
        found: "map with " <> node_type_name(key_node) <> " key",
      ))
  }
}

// ============================================================================
// Extractors - Higher-Order (for nested containers)
// ============================================================================

/// Extracts a list using a custom item extractor function.
/// Useful for extracting nested containers like List(Dict(String, String)).
///
/// ## Example
/// ```gleam
/// // Extract a list of string maps
/// extract_list_with(node, "servers", fn(item) {
///   extract_string_map(item, "")
/// })
/// ```
pub fn extract_list_with(
  node: Node,
  key: String,
  item_extractor: fn(Node) -> Result(a, ExtractionError),
) -> Result(List(a), ExtractionError) {
  use list_node <- result.try(select_or_missing(node, key))
  case list_node {
    NodeNil -> Error(KeyValueEmpty(key: key))
    NodeSeq(items) -> extract_list_items_with(items, key, item_extractor, 0, [])
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "list",
        found: node_type_name(other),
      ))
  }
}

/// Helper to extract list items with a custom extractor and index tracking.
fn extract_list_items_with(
  items: List(Node),
  key: String,
  item_extractor: fn(Node) -> Result(a, ExtractionError),
  index: Int,
  acc: List(a),
) -> Result(List(a), ExtractionError) {
  case items {
    [] -> Ok(list.reverse(acc))
    [item, ..rest] ->
      case item_extractor(item) {
        Ok(value) ->
          extract_list_items_with(rest, key, item_extractor, index + 1, [
            value,
            ..acc
          ])
        Error(err) ->
          // Wrap the error with context about which list index failed
          Error(KeyTypeMismatch(
            key: key <> ".#" <> int.to_string(index),
            expected: extraction_error_expected(err),
            found: extraction_error_found(err),
          ))
      }
  }
}

/// Extracts a map using a custom value extractor function.
/// Useful for extracting nested containers like Dict(String, List(Int)).
///
/// ## Example
/// ```gleam
/// // Extract a map of integer lists
/// extract_map_with(node, "groups", fn(item) {
///   extract_int_list(item, "")
/// })
/// ```
pub fn extract_map_with(
  node: Node,
  key: String,
  value_extractor: fn(Node) -> Result(a, ExtractionError),
) -> Result(dict.Dict(String, a), ExtractionError) {
  use map_node <- result.try(select_or_missing(node, key))
  case map_node {
    NodeNil -> Error(KeyValueEmpty(key: key))
    NodeMap(entries) ->
      extract_map_entries_with(entries, key, value_extractor, [])
      |> result.map(dict.from_list)
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "map",
        found: node_type_name(other),
      ))
  }
}

/// Helper to extract map entries with a custom value extractor.
fn extract_map_entries_with(
  entries: List(#(Node, Node)),
  key: String,
  value_extractor: fn(Node) -> Result(a, ExtractionError),
  acc: List(#(String, a)),
) -> Result(List(#(String, a)), ExtractionError) {
  case entries {
    [] -> Ok(list.reverse(acc))
    [#(NodeStr(k), value_node), ..rest] ->
      case value_extractor(value_node) {
        Ok(v) ->
          extract_map_entries_with(rest, key, value_extractor, [#(k, v), ..acc])
        Error(err) ->
          // Wrap the error with context about which map key failed
          Error(KeyTypeMismatch(
            key: key <> "." <> k,
            expected: extraction_error_expected(err),
            found: extraction_error_found(err),
          ))
      }
    [#(key_node, _), ..] ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "map with string keys",
        found: "map with " <> node_type_name(key_node) <> " key",
      ))
  }
}

/// Helper to extract the expected string from an ExtractionError.
fn extraction_error_expected(err: ExtractionError) -> String {
  case err {
    KeyMissing(_, _) -> "value"
    KeyValueEmpty(_) -> "non-empty value"
    KeyTypeMismatch(_, expected, _) -> expected
    DuplicateKeysDetected(_, _) -> "unique keys"
  }
}

/// Helper to extract the found string from an ExtractionError.
fn extraction_error_found(err: ExtractionError) -> String {
  case err {
    KeyMissing(k, _) -> "missing key: " <> k
    KeyValueEmpty(_) -> "nil"
    KeyTypeMismatch(_, _, found) -> found
    DuplicateKeysDetected(_, keys) ->
      "duplicate keys: " <> string.join(keys, ", ")
  }
}

// ============================================================================
// Extractors - Special
// ============================================================================

fn validate_no_duplicate_keys(
  items_result: Result(List(#(String, String)), ExtractionError),
  key: String,
  fail_on_key_duplication: Bool,
) -> Result(List(#(String, String)), ExtractionError) {
  use items <- result.try(items_result)

  // Short-circuit: skip validation entirely when duplicates are allowed
  case fail_on_key_duplication {
    False -> Ok(items)
    True -> {
      let #(_seen, duplicates) =
        list.fold(items, #(set.new(), set.new()), fn(acc, item) {
          let #(seen, duplicates) = acc
          case set.contains(seen, item.0) {
            True -> #(seen, set.insert(duplicates, item.0))
            False -> #(set.insert(seen, item.0), duplicates)
          }
        })

      let dupes_list = set.to_list(duplicates) |> list.sort(string.compare)
      case dupes_list {
        [] -> Ok(items)
        _ -> Error(DuplicateKeysDetected(key: key, keys: dupes_list))
      }
    }
  }
}

/// Extracts a string map with duplicate key detection.
pub fn extract_string_map_with_duplicate_detection(
  node: Node,
  key: String,
  fail_on_key_duplication fail_on_key_duplication: Bool,
) -> Result(dict.Dict(String, String), ExtractionError) {
  use dict_node <- result.try(select_or_missing(node, key))
  case dict_node {
    NodeNil -> Error(KeyValueEmpty(key: key))
    NodeMap(entries) -> {
      entries
      |> list.try_map(fn(entry) {
        case entry {
          #(NodeStr(dict_key), NodeStr(value)) -> Ok(#(dict_key, value))
          #(NodeStr(dict_key), value_node) ->
            Error(KeyTypeMismatch(
              key: key,
              expected: "map of strings",
              found: "map with "
                <> node_type_name(value_node)
                <> " value at key '"
                <> dict_key
                <> "'",
            ))
          #(key_node, _) ->
            Error(KeyTypeMismatch(
              key: key,
              expected: "map of strings",
              found: "map with " <> node_type_name(key_node) <> " key",
            ))
        }
      })
      |> validate_no_duplicate_keys(key, fail_on_key_duplication)
      |> result.map(dict.from_list)
    }
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: "map",
        found: node_type_name(other),
      ))
  }
}
