# glaml_extended

A fork of [glaml](https://github.com/katekyy/glaml) which is a simple Gleam wrapper around [yamerl](https://hex.pm/packages/yamerl) that enables your app to read YAML.

This is not (yet?) merged upstream nor published to hex as we add the following (which are somewhat opinionated):
* preserve duplicate keys
* add Javascript ffi bindings with ci that tests both Erlang and Javascript versions
* **WIP** - add extractors to coalesce values into an expected type
