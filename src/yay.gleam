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
// Errors
// ============================================================================

/// Represents the expected type of a YAML node value.
pub type ExpectedType {
  ExpectedString
  ExpectedInt
  ExpectedFloat
  ExpectedBool
  ExpectedList
  ExpectedMap
  ExpectedStringList
  ExpectedStringMap
}

/// An error that can occur when extracting a value from a node.
///
pub type ExtractionError {
  KeyMissing(key: String)
  KeyValueEmpty(key: String)
  KeyTypeMismatch(key: String, expected: ExpectedType, found: String)
  DuplicateKeysDetected(key: String, keys: List(String))
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

// ============================================================================
// Extractors
// ============================================================================

/// Extracts a string from a YAML node.
pub fn extract_string_from_node(
  node: Node,
  key: String,
) -> Result(String, ExtractionError) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error(KeyMissing(key: key))
  })
  case query_template_node {
    NodeStr(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: ExpectedString,
        found: node_type_name(other),
      ))
  }
}

/// Extracts a float from a YAML node.
/// Also accepts integers and converts them to floats (since YAML/JSON parsers
/// often represent numbers like 99.0 as integers).
pub fn extract_float_from_node(
  node: Node,
  key: String,
) -> Result(Float, ExtractionError) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error(KeyMissing(key: key))
  })
  case query_template_node {
    NodeFloat(value) -> Ok(value)
    NodeInt(value) -> Ok(int.to_float(value))
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: ExpectedFloat,
        found: node_type_name(other),
      ))
  }
}

/// Extracts an integer from a YAML node.
pub fn extract_int_from_node(
  node: Node,
  key: String,
) -> Result(Int, ExtractionError) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error(KeyMissing(key: key))
  })
  case query_template_node {
    NodeInt(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: ExpectedInt,
        found: node_type_name(other),
      ))
  }
}

/// Extracts a boolean from a YAML node.
pub fn extract_bool_from_node(
  node: Node,
  key: String,
) -> Result(Bool, ExtractionError) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error(KeyMissing(key: key))
  })
  case query_template_node {
    NodeBool(value) -> Ok(value)
    NodeNil -> Error(KeyValueEmpty(key: key))
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: ExpectedBool,
        found: node_type_name(other),
      ))
  }
}

/// Extracts a list of strings from a YAML node.
/// Returns Ok([]) for an explicitly empty list (`[]`).
/// Returns Error(KeyValueEmpty) for nil/null values.
/// Returns Error(KeyMissing) if the key doesn't exist.
pub fn extract_string_list_from_node(
  node: Node,
  key: String,
) -> Result(List(String), ExtractionError) {
  use list_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error(KeyMissing(key: key))
  })
  case list_node {
    // Nil value - error
    NodeNil -> Error(KeyValueEmpty(key: key))
    // Sequence - extract strings from it
    NodeSeq(_) -> {
      case select_sugar(list_node, "#0") {
        Ok(_) ->
          do_extract_string_list(list_node, 0)
          |> result.map_error(fn(_) {
            KeyTypeMismatch(
              key: key,
              expected: ExpectedStringList,
              found: "list with non-string items",
            )
          })
        // Empty sequence
        Error(_) -> Ok([])
      }
    }
    // Wrong type - not a list
    other ->
      Error(KeyTypeMismatch(
        key: key,
        expected: ExpectedList,
        found: node_type_name(other),
      ))
  }
}

fn validate_no_duplicate_keys(
  items_result: Result(List(#(String, String)), ExtractionError),
  key: String,
  fail_on_key_duplication: Bool,
) -> Result(List(#(String, String)), ExtractionError) {
  use items <- result.try(items_result)

  let #(_seen, duplicates) =
    list.fold(items, #(set.new(), set.new()), fn(acc, item) {
      let #(seen, duplicates) = acc
      case set.contains(seen, item.0) {
        True -> #(seen, set.insert(duplicates, item.0))
        False -> #(set.insert(seen, item.0), duplicates)
      }
    })

  let dupes_list = set.to_list(duplicates)
  case dupes_list, fail_on_key_duplication {
    [], _ -> Ok(items)
    _, False -> Ok(items)
    _, True -> Error(DuplicateKeysDetected(key: key, keys: dupes_list))
  }
}

/// Extracts a dictionary of string key-value pairs from a YAML node.
/// Returns Ok(empty dict) for an explicitly empty map (`{}`).
/// Returns Error(KeyValueEmpty) for nil/null values.
/// Returns Error(KeyMissing) if the key doesn't exist.
pub fn extract_dict_strings_from_node(
  node: Node,
  key: String,
  fail_on_key_duplication fail_on_key_duplication: Bool,
) -> Result(dict.Dict(String, String), ExtractionError) {
  case select_sugar(node, key) {
    Ok(dict_node) -> {
      case dict_node {
        // Nil value - error
        NodeNil -> Error(KeyValueEmpty(key: key))
        // Map - extract string key-value pairs
        NodeMap(entries) -> {
          entries
          |> list.try_map(fn(entry) {
            case entry {
              #(NodeStr(dict_key), NodeStr(value)) -> Ok(#(dict_key, value))
              _ ->
                Error(KeyTypeMismatch(
                  key: key,
                  expected: ExpectedStringMap,
                  found: "map with non-string keys or values",
                ))
            }
          })
          |> validate_no_duplicate_keys(key, fail_on_key_duplication)
          |> result.map(dict.from_list)
        }
        // Wrong type - not a map
        other ->
          Error(KeyTypeMismatch(
            key: key,
            expected: ExpectedMap,
            found: node_type_name(other),
          ))
      }
    }
    // Key doesn't exist
    Error(_) -> Error(KeyMissing(key: key))
  }
}

/// Internal helper for extracting string lists from YAML nodes.
fn do_extract_string_list(
  list_node: Node,
  index: Int,
) -> Result(List(String), String) {
  case select_sugar(list_node, "#" <> int.to_string(index)) {
    Ok(item_node) -> {
      case item_node {
        NodeStr(value) -> {
          use rest <- result.try(do_extract_string_list(list_node, index + 1))
          Ok([value, ..rest])
        }
        _ -> Error("Expected list item to be a string")
      }
    }
    Error(_) -> Ok([])
  }
}
