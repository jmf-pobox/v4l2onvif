# Design Decisions (ADRs)

Architectural Decision Records for non-trivial deviations from upstream
or non-trivial design choices in the fork.

ADR template:

```text
## ADR-NNN: <title>

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Superseded by ADR-XYZ
**Context:** What problem are we solving?
**Decision:** What did we choose?
**Alternatives considered:** What else we looked at and why we didn't pick it.
**Consequences:** What this enables, what it locks us out of, what we have to
maintain because of it.
**Tests:** Which test(s) lock this decision in.
```

## ADR-001: live555 source from rgaufman/live555 GitHub mirror

**Date:** 2026-06-07
**Status:** Accepted
**Context:** Upstream's `v4l2rtspserver/CMakeLists.txt` fetches
`http://www.live555.com/liveMedia/public/live555-latest.tar.gz` when
no system live555 is present. As of 2026-06-07, that URL returns 404.
The downloaded file is 0 bytes; the build fails on `Base64.hh: No
such file or directory`.
**Decision:** Our top-level CMake clones
`https://github.com/rgaufman/live555.git` to `v4l2rtspserver/live/`
when the directory is absent. rgaufman/live555 is an actively
maintained mirror used by other live555-dependent projects in apt.
**Alternatives considered:**
- Wait for upstream to fix the URL (their last release was 2023;
  unlikely on a useful timeline).
- Vendor a tarball into our fork (large binary in git, hard to update).
- Build live555 manually before invoking CMake (adds a manual step
  for every fresh checkout).
**Consequences:** Our fork has an extra `git clone` dependency in
build setup. Anyone using upstream's Makefile path will still hit the
404 unless they read this ADR.
**Tests:** `make check` clean build from scratch.

## ADR-002: C++20 standard for new code, modernize touched legacy

**Date:** 2026-06-07
**Status:** Accepted
**Context:** Upstream is C++11. We need RAII for fds and gSOAP allocator
contexts, `std::optional` for fallible probes, `std::string_view` for
read-only string params, `[[nodiscard]]` to surface ignored error
returns. C++17 covers most of this; C++20 adds `std::span`, designated
initializers, and ranges which we'd want for the test scaffolding.
**Decision:** Compile the whole tree with `-std=c++20`. New code uses
C++17/20 idioms freely. Existing upstream code is modernized only when
we're already editing the function for another reason.
**Alternatives considered:**
- Stay on C++11 to minimize fork delta (but: every test helper we
  write benefits from C++17+; RAII wrappers are basic hygiene).
- Bulk-rewrite everything in C++20 immediately (but: massive diff
  from upstream, hard to merge upstream patches if any arrive).
**Consequences:** Increment file-by-file modernization. PRs that
modernize must explain why the file was being touched anyway.
**Tests:** Compile under `-std=c++20 -Werror -Wpedantic`.

## ADR-003: ReferenceToken must be ≤ 64 chars; tokens are short aliases

**Date:** 2026-06-07
**Status:** Accepted
**Context:** Upstream uses the V4L2 device path
(`/dev/v4l/by-id/usb-Chicony_Tech._Inc._Dell_Webcam_WB7022_BD831C120F72-
video-index0`, ~80 chars) as the ONVIF `ReferenceToken` for video
sources. ONVIF spec caps `ReferenceToken` at 64 chars; Win11 silently
rejects responses that exceed this.
**Decision:** Tokens are short generated aliases (`VideoSource_0`,
`VideoSource_1`, …). A `ServiceContext::m_devicePaths` map translates
the token to the real device path at every V4L2 ioctl call.
**Alternatives considered:**
- Truncate the device path (collision-prone, opaque to anyone reading
  logs).
- Hash the device path (fixed length but unreadable).
- Use V4L2 device's serial number from `udevadm info` (stable but adds
  a discovery step).
**Consequences:** Every V4L2 helper in `onvif_impl.cpp` must call
`resolveDevicePath(token)` before opening the device. The mapping is
populated once in `main()` and is read-only at runtime.
**Tests:** `tests/unit/test_resolve_device_path.cpp` —
`token unknown → token returned unchanged`,
`token known → device path returned`.

## ADR-004: Win11 is L4 (smoke), not L1 (primary)

**Date:** 2026-06-07
**Status:** Accepted
**Context:** During the 2026-06-06/07 session we used Win11 round-trip
as the primary test. Six bugs were found; each took 5–20 minutes
because the cycle was: patch → restart server → user retries in Win11
→ user reports → repeat. Every one of those bugs was reproducible in
a sub-second unit or integration test we hadn't written.
**Decision:** Win11 is Layer 4 in `docs/TESTING.md` — a smoke check
run after L1+L2+L3 are green. Bug reports from Win11 must be turned
into a failing L1 or L2 test before any code change.
**Alternatives considered:**
- Keep Win11 as primary (cheaper to set up; we already had it
  running). But: 60× slower iteration, no regression coverage.
**Consequences:** First session of every new ONVIF feature adds an
integration test that drives the feature with `onvif-client.exe`.
**Tests:** This ADR is enforced by code review, not a test.
