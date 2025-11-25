import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

/// A YAML document error containing a message — `msg` and it's location — `loc`.
///
pub type YamlError {
  UnexpectedParsingError
  ParsingError(msg: String, loc: YamlErrorLoc)
}

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
///   #(NodeStr("lib name"), NodeStr("glaml")),
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

/// Parses `selector` as a `Selector` and
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
// Extractors
// ============================================================================

/// Extracts a string from a glaml node.
pub fn extract_string_from_node(
  node: Node,
  key: String,
) -> Result(String, String) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Missing " <> key)
  })
  case query_template_node {
    NodeStr(value) -> Ok(value)
    NodeNil -> Error("Expected " <> key <> " to be non-empty")
    _ -> Error("Expected " <> key <> " to be a string")
  }
}

/// Extracts a float from a glaml node.
/// Also accepts integers and converts them to floats (since YAML/JSON parsers
/// often represent numbers like 99.0 as integers).
pub fn extract_float_from_node(node: Node, key: String) -> Result(Float, String) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Missing " <> key)
  })
  case query_template_node {
    NodeFloat(value) -> Ok(value)
    NodeInt(value) -> Ok(int.to_float(value))
    NodeNil -> Error("Expected " <> key <> " to be non-empty")
    _ -> Error("Expected " <> key <> " to be a float")
  }
}

/// Extracts an integer from a glaml node.
pub fn extract_int_from_node(node: Node, key: String) -> Result(Int, String) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Missing " <> key)
  })
  case query_template_node {
    NodeInt(value) -> Ok(value)
    NodeNil -> Error("Expected " <> key <> " to be non-empty")
    _ -> Error("Expected " <> key <> " to be an integer")
  }
}

/// Extracts a boolean from a glaml node
pub fn extract_bool_from_node(node: Node, key: String) -> Result(Bool, String) {
  use query_template_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Missing " <> key)
  })
  case query_template_node {
    NodeBool(value) -> Ok(value)
    NodeNil -> Error("Expected " <> key <> " to be non-empty")
    _ -> Error("Expected " <> key <> " to be a boolean")
  }
}

/// Extracts a list of strings from a glaml node.
/// Returns Ok([]) if the key exists but has an empty/nil value.
/// Returns Error if the key is missing or has wrong type.
pub fn extract_string_list_from_node(
  node: Node,
  key: String,
) -> Result(List(String), String) {
  use list_node <- result.try(case select_sugar(node, key) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Missing " <> key)
  })
  case list_node {
    // Empty/nil value - return empty list
    NodeNil -> Ok([])
    // Sequence - extract strings from it
    NodeSeq(_) -> {
      case select_sugar(list_node, "#0") {
        Ok(_) -> do_extract_string_list(list_node, 0)
        // Empty sequence
        Error(_) -> Ok([])
      }
    }
    // Wrong type - not a list
    NodeStr(_) -> Error("Expected " <> key <> " list item to be a string")
    _ -> Error("Expected " <> key <> " to be a list")
  }
}

fn validate_no_duplicate_keys(
  items_result: Result(List(#(String, String)), String),
  key: String,
  fail_on_key_duplication: Bool,
) -> Result(List(#(String, String)), String) {
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
    _, True ->
      Error(
        "Duplicate keys detected for "
        <> key
        <> ": "
        <> string.join(dupes_list, ", "),
      )
  }
}

/// Extracts a dictionary of string key-value pairs from a glaml node.
/// Returns Ok(empty dict) if the key exists but has an empty/nil value.
/// Returns Error if the key is missing or has wrong type.
pub fn extract_dict_strings_from_node(
  node: Node,
  key: String,
  fail_on_key_duplication fail_on_key_duplication: Bool,
) -> Result(dict.Dict(String, String), String) {
  case select_sugar(node, key) {
    Ok(dict_node) -> {
      case dict_node {
        // Empty/nil value - return empty dict
        NodeNil -> Ok(dict.new())
        // Map - extract string key-value pairs
        NodeMap(entries) -> {
          entries
          |> list.try_map(fn(entry) {
            case entry {
              #(NodeStr(dict_key), NodeStr(value)) -> Ok(#(dict_key, value))
              _ ->
                Error(
                  "Expected " <> key <> " entries to be string key-value pairs",
                )
            }
          })
          |> validate_no_duplicate_keys(key, fail_on_key_duplication)
          |> result.map(dict.from_list)
        }
        // Wrong type - not a map
        _ -> Error("Expected " <> key <> " to be a map")
      }
    }
    // Key doesn't exist
    Error(_) -> Error("Missing " <> key)
  }
}

/// Iteratively parses a collection of nodes.
pub fn iteratively_parse_collection(
  root: Node,
  params: dict.Dict(String, String),
  actual_parse_fn: fn(Node, dict.Dict(String, String)) -> Result(a, String),
  key: String,
) -> Result(List(a), String) {
  use services_node <- result.try(
    select_sugar(root, key)
    |> result.map_error(fn(_) { "Missing " <> key }),
  )
  do_parse_collection(services_node, 0, params, actual_parse_fn)
}

/// Internal parser for list of nodes, iterates over the list.
fn do_parse_collection(
  services: Node,
  index: Int,
  params: dict.Dict(String, String),
  actual_parse_fn: fn(Node, dict.Dict(String, String)) -> Result(a, String),
) -> Result(List(a), String) {
  case select_sugar(services, "#" <> int.to_string(index)) {
    Ok(service_node) -> {
      use service <- result.try(actual_parse_fn(service_node, params))
      use rest <- result.try(do_parse_collection(
        services,
        index + 1,
        params,
        actual_parse_fn,
      ))
      Ok([service, ..rest])
    }
    // TODO: fix this super hacky way of iterating over SLOs.
    Error(_) -> Ok([])
  }
}

/// Internal helper for extracting string lists from glaml nodes.
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
