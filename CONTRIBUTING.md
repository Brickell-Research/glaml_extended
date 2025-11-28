# Contributing to yay

Thank you for your interest in contributing to yay!

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```sh
   git clone https://github.com/YOUR_USERNAME/yay.git
   cd yay
   ```
3. Install dependencies:
   ```sh
   gleam deps download
   ```

## Development

### Running Tests

Run the test suite:
```sh
gleam test
```

Watch mode (re-runs tests on file changes):
```sh
gleam test --watch
```

### Building

Build the project:
```sh
gleam build
```

### Formatting

Format your code before committing:
```sh
gleam format
```

## Submitting Changes

1. Create a new branch for your feature or fix:
   ```sh
   git checkout -b my-feature
   ```
2. Make your changes
3. Run tests to ensure everything passes:
   ```sh
   gleam test
   ```
4. Format your code:
   ```sh
   gleam format
   ```
5. Commit your changes with a clear message
6. Push to your fork:
   ```sh
   git push origin my-feature
   ```
7. Open a Pull Request on GitHub

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include tests for new functionality
- Update documentation if needed
- Ensure all tests pass before requesting review
