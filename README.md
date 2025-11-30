# yay

[![unit_tests](https://github.com/Brickell-Research/yay/actions/workflows/unit_tests.yml/badge.svg)](https://github.com/Brickell-Research/yay/actions/workflows/test.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/yay)](https://hex.pm/packages/yay)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue)](https://hexdocs.pm/yay/index.html)

**[Y]et [A]nother [Y]aml** is a Gleam YAML parser supporting both Erlang and JavaScript targets.

> **Fork notice**: This is a fork of [glaml](https://github.com/katekyy/glaml) by [@katekyy](https://github.com/katekyy). The original glaml library provides the core YAML parsing functionality via [yamerl](https://hex.pm/packages/yamerl). This fork started by adding typed error handling, value extraction utilities, and JavaScript target support and continues to evolve.

## Installation

```sh
gleam add yay
```

**JavaScript target:** If targeting JavaScript (Deno), you also need to install js-yaml:

```sh
deno add npm:js-yaml
```

## Usage

```gleam
import yay

pub fn main() {
  // Parse a YAML string
  let assert Ok([doc]) = yay.parse_string("
name: yay
version: 1.0.0
features:
  - typed errors
  - value extraction
  - dual target support
")

  let root = yay.document_root(doc)

  // Extract values with type safety
  let assert Ok("yay") = yay.extract_string(root, "name")
  let assert Ok(features) = yay.extract_string_list(root, "features")
}
```

## Features

- **Dual target support**: Works on both Erlang (via yamerl) and JavaScript (via js-yaml)
- **Typed errors**: Pattern-matchable error types with expected vs. found type information
- **Value extraction**: Helper functions to extract typed values from nodes (`extract_string`, `extract_int`, `extract_float`, `extract_bool`, `extract_string_list`, `extract_string_map`)
- **Selector syntax**: Query nested values with dot notation (`"config.database.port"`) and array indices (`"items.#0"`)
- **Duplicate key detection**: Optionally fail on duplicate dictionary keys

## Error Handling

All extraction functions return `Result(T, ExtractionError)` where `ExtractionError` is:

```gleam
pub type ExtractionError {
  KeyMissing(key: String, failed_at_segment: Int)
  KeyValueEmpty(key: String)
  KeyTypeMismatch(key: String, expected: String, found: String)
  DuplicateKeysDetected(key: String, keys: List(String))
}
```

## Acknowledgments

Thanks to [@katekyy](https://github.com/katekyy) for creating [glaml](https://github.com/katekyy/glaml), which this library is forked from.

## License

MIT
