# glaml_extended

A fork of [glaml](https://github.com/katekyy/glaml) which is a simple Gleam wrapper around [yamerl](https://hex.pm/packages/yamerl) that enables your app to read YAML.

## Changelog (deviation from glaml)

* **3.0.6** (11/25/25): Dictionary extraction will now fail on key duplication if (`fail_on_duplication: true`) passed in.
* **3.0.5** (11/25/25): Extractors now differentiate between missing keys, empty values, and wrong types.
* **3.0.4** (11/25/25): Include extraction helper methods to coalesce specific values to typed version.
* **3.0.3** (11/25/25): JS bindings and surface duplicate keys.

## Desired Further Changes

* **Error types:** right now we do a bunch of matching on error message. This is error proned and a bad practice. Should be easy to expose some basic error types like "missing", "wrong type", etc.
