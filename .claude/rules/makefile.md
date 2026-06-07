# Build System Hygiene

Read `docs/BUILDING.md` for the full build and toolchain guide.

## Makefile

- `make` is the source of truth. Never re-derive flags from CI YAML.
- Wrap every compound command in a target — the user granted blanket
  `make *` permission.
- Target names: lowercase, hyphenated (`format-check` not `formatCheck`).
- All quality gates accessible via `make check`.
- `.PHONY` for all non-file targets.
- `## comment` on every target so `make help` lists it.
- Default target is `help`, not `build`. Building requires explicit
  `make build` or `make all`.

## Scoping (our files vs upstream)

The fork inherits a large upstream codebase that does not pass strict
warnings or modern lint. To avoid an unmaintainable diff:

- `format` / `format-check` run on `OUR_CPP_FILES` only (`tests/` and
  any `src/inc` files we've explicitly modernized).
- `cppcheck` runs on `src/` + `tests/` but skips `gen/` (auto-generated)
  and submodules.
- `lint` (markdown) runs on `OUR_MD_FILES` (anything not in
  `v4l2rtspserver/`, `ws-discovery/`, `live/`, `gen/`).
- Strict compiler warnings (`-Werror -Wpedantic -Wconversion …`) are
  opt-in via `STRICT=1`. The default build keeps upstream's flags so
  the build stays green.

## Compiler Warnings

- Never weaken the global warning policy.
- New files in `src/` go to the strict warning set on day one.
- Touched upstream files: add the strict flags as you modernize them.
- Suppressions: per-file via `#pragma GCC diagnostic` with a comment
  citing why the warning is wrong (not "fix later" — that's tech debt).

## Sanitizer Builds

- `make asan` builds with ASan + UBSan via `ASAN=1`.
- ASan + UBSan should run in CI on every PR (when CI exists).
- Tests run under both Debug and ASan builds (when tests exist).

## Future Work — CMake Migration

The Makefile is currently a wrapper around the upstream make-based
build. Top-level CMake is a separate transition tracked in
`docs/BUILDING.md`:

- `compile_commands.json` for clang-tidy
- Catch2 test discovery via `catch_discover_tests`
- Sanitizer presets (`debug`, `asan`, `tsan`)
- `make` thin-wraps `cmake --build`
