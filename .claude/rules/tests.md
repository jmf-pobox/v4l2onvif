---
paths:
  - "tests/**"
---

# Test Conventions

Read `docs/TESTING.md` for the full 4-layer testing guide.

## Frameworks

- **Catch2 v3** for unit tests (header-only, easy fixtures, clean
  matchers).
- **CTest** as the runner. Tests registered via
  `v4l2onvif_add_unit_test()` and `v4l2onvif_add_integration_test()`
  helpers in `tests/CMakeLists.txt`.

## File Layout

- `tests/unit/test_<source>.cpp` — one test file per `src/` file when
  practical (some files are too big; split by class/scope).
- `tests/integration/test_<scenario>.cpp` — one file per scenario
  (e.g., `test_discovery_roundtrip.cpp`,
  `test_profile_streamuri.cpp`).
- `tests/fixtures/` — captured SOAP envelopes, pcaps, golden XML.
- `tests/support/` — shared helpers (fake V4L2 backend, soap fixture).

## Unit Test Pattern

```cpp
#include <catch2/catch_test_macros.hpp>
#include "onvif_impl.h"

TEST_CASE("resolveDevicePath: unknown token returns input unchanged",
          "[onvif_impl][resolve_device_path]") {
    ServiceContext ctx;
    REQUIRE(ctx.resolveDevicePath("VideoSource_42") == "VideoSource_42");
}

TEST_CASE("resolveDevicePath: known token returns mapped device path",
          "[onvif_impl][resolve_device_path]") {
    ServiceContext ctx;
    ctx.m_devicePaths["VideoSource_0"] = "/dev/video99";
    REQUIRE(ctx.resolveDevicePath("VideoSource_0") == "/dev/video99");
}
```

Test names are sentences. Tags group related tests for `ctest -R`.

## Integration Test Pattern

For tests that need a running server:

1. Fork-exec `onvif-server.exe` bound to `127.0.0.1` on a test-only
   port (Catch2 `BeforeAll`-equivalent fixture).
2. Drive it with `onvif-client.exe` or raw libcurl + a SOAP envelope
   string from `tests/fixtures/`.
3. Assert on the response XML (string match on key fields, schema
   validation for envelope correctness).
4. Tear down the server.

Server-under-test runs against `/dev/video99` (a v4l2loopback fed by
gst-launch from the test fixture).

## Sanitizer Posture

- Every test compiles and runs under both Debug and ASan + UBSan
  presets. CI matches.
- A test that segfaults under ASan but "works" under Debug is a
  passing failure — fix it, don't ignore.

## Fixtures

| Name | What it provides |
|------|------------------|
| `synthetic_v4l2` | Loads `v4l2loopback` if absent, opens `/dev/video99` |
| `soap_context` | Per-test `soap*` with `soap_new` + teardown |
| `service_context_with_devices` | Pre-populated `ServiceContext::m_devices` and `m_devicePaths` |
| `running_onvif_server` | Forks `onvif-server.exe` on a test port |

## Don't Test

- Real cameras (CI doesn't have them). Use v4l2loopback fixture.
- Real Win11 (CI doesn't have it). That's the L4 manual check.
- Timing-sensitive paths (frame rates from real hardware). Test the
  rate-control logic separately from the camera capture loop.
- Live live555 internals. The submodule is black-box.

## Regression Test Rule

Every bug fix commit must reference the test that catches it. Format:

```text
Regression: tests/unit/test_<file>.cpp::<test name>
```

If the bug isn't representable as a test, the bug isn't understood yet.
