# yay

A Gleam YAML parser supporting Erlang and JavaScript (Deno) targets.

## Gleam Idioms

Follow these practices when writing Gleam code:

1. **Pattern matching**: Use exhaustive `case` expressions. The compiler enforces all cases are handled.

2. **Pipe operator**: Chain functions with `|>`. Design functions with the "subject" as the first argument.

3. **Qualified imports**: Always use module prefixes (`list.map`, `result.try`). No unqualified imports.

4. **Labeled arguments**: Use labels for clarity, especially with multiple parameters or in pipelines.
   ```gleam
   select(from: node, selector: sel)
   ```

5. **Immutability**: Variables are immutable. Use shadowing to "update" values.

6. **Result/Option**: No nulls or exceptions. Use `Result(value, error)` and `Option` types. Propagate errors with `use <- result.try`.

7. **Recursion**: No loops. Use recursion with base cases, or `list.map`/`list.fold`.

8. **Custom types**: Model your domain with custom types. Use single-variant types as records.

9. **Documentation**: Use `///` for function/type docs, `////` for module docs.

10. **todo/panic**: Use sparingly. Prefer `Result` for errors. `todo` is for unfinished code only.

## Project Structure

- `src/yay.gleam` - Main library with parsing and extraction functions
- `src/yaml_ffi.erl` - Erlang FFI (uses yamerl)
- `src/yaml_ffi.mjs` - JavaScript FFI (uses js-yaml with Deno)
- `test/yay_test.gleam` - Tests

## Commands

```sh
gleam test          # Run tests
gleam build         # Build
gleam docs build    # Generate docs
```
