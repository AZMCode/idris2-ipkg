# Changelog

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ipkg-render`, reading `Idris.Package.Types.PkgDesc` JSON on stdin and writing
  a `.ipkg` on stdout.
- `FromJSON` derived by reflection for `PkgVersion`, `PkgVersionBounds`,
  `Depends` and `PkgDesc`, so the decoder follows the compiler's own record
  definition.
- Hand-written `FromJSON` instances for the two types the compiler does not allow
  to be constructed directly: `Core.FC.FC` (always `EmptyFC`) and `ModuleIdent`
  (via `mkNamespace`).
- Golden test pinning the rendered output, and a check that malformed input is
  rejected with the offending JSON path.
