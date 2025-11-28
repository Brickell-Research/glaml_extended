import yay

/// Parses a YAML string and returns the root node of the first document.
pub fn yaml_to_root(yaml_str: String) -> yay.Node {
  let assert Ok([doc]) = yay.parse_string(yaml_str)
  yay.document_root(doc)
}
