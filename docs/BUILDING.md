# Building v4l2onvif

This document covers building, toolchain, quality gates, and packaging.
Read it in full before writing any code.

## Build Commands

The fork uses CMake. The upstream Makefile is preserved at the top level
for one-shot builds, but `make check` and all gates drive CMake.

```bash
cmake --preset debug                          # Configure (build/, Debug)
cmake --build build                           # Build server, client, tests
ctest --test-dir build --output-on-failure    # Run unit + integration tests
./build/onvif-server -H 8080 -R 8554 -i /dev/video0    # Run the daemon
```

### Sanitizer Build (ASan + UBSan)

```bash
cmake --preset asan                           # Configure (build-asan/)
cmake --build build-asan
ctest --test-dir build-asan --output-on-failure
```

### ThreadSanitizer Build (nightly)

```bash
cmake --preset tsan
cmake --build build-tsan
ctest --test-dir build-tsan --output-on-failure
```

### Dependencies (apt)

```bash
sudo apt install \
    g++ cmake pkg-config autoconf automake libtool \
    gsoap libgsoap-dev libssl-dev zlib1g-dev \
    catch2 \
    clang-format clang-tidy cppcheck markdownlint \
    v4l2loopback-dkms gstreamer1.0-tools
```

`v4l2loopback-dkms` is required for integration tests (synthetic camera).
`catch2` for unit tests. The first row matches the snapcraft manifest of
upstream; the rest is the new test/toolchain surface.

### live555 Source

`v4l2rtspserver` needs live555 source at `v4l2rtspserver/live/`. Upstream's
CMakeLists tries to download `http://www.live555.com/liveMedia/public/
live555-latest.tar.gz`, which 404s as of 2026-06-07. Our top-level CMake
will clone `https://github.com/rgaufman/live555.git` to that path if it's
absent. See ADR-001 in `docs/DESIGN.md`.

## Modern C++ Standard

This fork targets **C++20**. Upstream is C++11. New code uses:

- `std::string_view` for read-only string parameters
- `std::optional<T>` for "might fail" returns
- `std::filesystem` for path manipulation
- Structured bindings, `auto`, `constexpr` where appropriate
- RAII wrappers for `fd`, sockets, gSOAP allocator contexts
- `[[nodiscard]]` on every fallible function
- No raw `new` / `delete` in our code; smart pointers only

Existing upstream code is modernized incrementally — when we touch a
function, we bring it to C++20 standards. We do not bulk-rewrite files.

## Makefile

The top-level Makefile is the human-friendly wrapper around CMake. Run
`make help` to see every target.

| Target | Purpose |
|--------|---------|
| `make build` | Configure + build (debug) |
| `make test` | Run unit + integration tests (debug) |
| `make asan` | Configure + build (asan) |
| `make asan-test` | Run ctest under ASan + UBSan |
| `make protocol-test` | Layer 3 compliance suite |
| `make check` | All CI gates locally |
| `make format` | clang-format in-place |
| `make format-check` | clang-format dry-run |
| `make tidy` | clang-tidy on src/, tests/ |
| `make cppcheck` | Static analysis |
| `make lint` | Markdown lint |
| `make clean` | Remove build/, build-asan/ |
| `make distclean` | Remove all generated files including live/ |

## Quality Gates

Run `make check` before every PR. It runs all gates in sequence:

1. `format-check` — clang-format dry-run on src/, inc/, tests/
2. `tidy` — clang-tidy
3. `cppcheck` — cppcheck on src/, tests/
4. `lint` — markdownlint
5. `test` — ctest debug build (unit + integration)
6. `asan-test` — ctest ASan + UBSan
7. `protocol-test` — Layer 3 compliance against real ONVIF clients

Zero warnings, zero errors, all tests green. Never let CI catch
something you could have caught locally.

### Compiler Warnings Policy

Base warning set:

```text
-Wall -Wextra -Wpedantic -Werror
-Wconversion -Wshadow -Wdouble-promotion
-Wformat=2 -Wformat-overflow=2
-Wnull-dereference -Wuninitialized
```

For `gen/*` (gSOAP-generated): warnings disabled per-file (the generator
emits code that doesn't pass strict warnings; we don't own it).

For `v4l2rtspserver/`, `ws-discovery/`, `live/`: warnings disabled
(submodules / third-party).

### Sanitizer Builds

ASan + UBSan run in CI on every PR. TSan and MSan are periodic deep
checks. Sanitizers are not optional — they are how we found yesterday's
`std::bad_alloc` was actually heap corruption from an earlier request,
not an OOM.

## CI Workflows (target shape)

| Workflow | Triggers | What it runs |
|----------|----------|--------------|
| `lint.yml` | Push, PR | clang-format, clang-tidy, cppcheck, markdownlint |
| `test.yml` | Push, PR | Matrix: Debug + ASan, ctest |
| `protocol.yml` | Push, PR | Layer 3 against gst, python-onvif-zeep |
| `nightly.yml` | Cron | TSan, MSan, valgrind |
