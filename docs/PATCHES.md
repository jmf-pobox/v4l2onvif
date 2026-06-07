# Fork Patches

This document tracks every deviation from upstream
[mpromonet/v4l2onvif](https://github.com/mpromonet/v4l2onvif), with
rationale and the test that locks it in.

The patches landed during the 2026-06-06/07 session are listed below
as **untested** until the corresponding regression test exists. Each
patch will be amended once its test is committed.

## Active Patches

| # | Area | Description | ADR | Test | Status |
|---|------|-------------|-----|------|--------|
| 1 | `onvif_impl.cpp::getLocalIp` | Read `V4L2ONVIF_IP` env var; if set, return it verbatim — used for the WS-Discovery Hello XAddr and StreamUri | — | `tests/unit/test_local_ip_override.cpp` | **untested** |
| 2 | `ws-discovery/gsoap/wsd-server.cpp::wsd_server` | After the default `INADDR_ANY` group join, iterate `getifaddrs()` and join the multicast group on every non-loopback IPv4 interface. Without this, the responder only listens on the default-route interface (wifi on the dev host), and Win11 probes from the virbr0 VM subnet never arrive | — | `tests/integration/test_multi_interface_join.cpp` | **untested** |
| 3 | `serverDevice.cpp` GetCapabilities | Set `StreamingCapabilities.RTP_TCP = true` and `RTP_RTSP_TCP = true` | — | `tests/unit/test_streaming_capabilities.cpp` | **untested** |
| 4 | `onvif_impl.cpp::getMediaServiceCapabilities` | Set the same `RTP_TCP` / `RTP_RTSP_TCP` flags on the per-service response | — | `tests/unit/test_streaming_capabilities.cpp` | **untested** |
| 5 | `serverMedia.cpp::GetVideoSources` | Set `Framerate = 30.0f` on the response (was unset → serialized as 0) | — | `tests/unit/test_get_video_sources.cpp` | **untested** |
| 6 | `onvif-server.cpp` token generation | Replace device-path tokens with short `VideoSource_<idx>` aliases; populate `ServiceContext::m_devicePaths` for translation | ADR-003 | `tests/unit/test_resolve_device_path.cpp` | **partial** (resolution tested; token-emission path needs its own test) |
| 7 | `inc/onvif_impl.h` + `onvif_impl.cpp` | Add `m_devicePaths` map and `resolveDevicePath(token)` helper; route every `open(token.c_str())` in `getFormat`, `getFrameRate`, `getCtrlValue`, `setCtrlValue`, `getCtrlRange`, `getName`, `getIdentification`, `getVideoEncoderCfgOptions` through it | ADR-003 | `tests/unit/test_resolve_device_path.cpp` | **partial** |
| 8 | `onvif_impl.cpp::getProfile` | Webcam Profile no longer emits empty `PTZConfiguration`, `VideoAnalyticsConfiguration`, `MetadataConfiguration` subtrees; set to `NULL` instead | — | `tests/unit/test_profile_builder.cpp` | **untested** |
| 9 | `onvif_impl.cpp::getVideoSourceCfg` | Set `Name = token` (was empty) | — | `tests/unit/test_profile_builder.cpp` | **untested** |
| 10 | `onvif_impl.cpp::getVideoEncoderCfg` + `getVideoEncoderCfgOptions` | Treat `V4L2_PIX_FMT_MJPEG` the same as `V4L2_PIX_FMT_JPEG` (both → `tt__VideoEncoding__JPEG`). Without this, MJPG-only cameras (most UVC webcams) report no usable encoder option | — | `tests/unit/test_pixfmt_mapping.cpp` | **untested** |
| 11 | `serverDevice.cpp::GetSystemDateAndTime` | Hardcode `TimeZone.TZ = "UTC"`. Upstream assigns from `ctx->m_timezone` which gets corrupted by an earlier request (heap corruption symptom), triggering `std::bad_alloc` in `std::string::operator=`. Hardcoding is a stopgap; the real bug is upstream heap corruption that needs a TSan / ASan investigation | — | `tests/integration/test_repeated_get_system_time.cpp` | **untested**; underlying corruption not root-caused |
| 12 | `onvif-server.cpp::main` | Unbuffer `std::cout`; install `std::set_terminate(crash_backtrace)` so the next bad_alloc/SEGV dumps `backtrace_symbols` to stderr before `abort()` | — | (instrumentation; no test needed) | **infra** |

## Patches Backlog

Once the table above is all **tested**, the next set of cleanups:

- Replace patch 11's `TZ = "UTC"` hardcode with the actual fix: find
  what overwrites `m_timezone` (likely heap corruption from gSOAP
  allocator misuse in an earlier handler). Run under ASan with
  `ASAN_OPTIONS=halt_on_error=1`.
- Add a clang-tidy check that flags `open(token.c_str(), ...)` without
  `resolveDevicePath`. Currently a code-review concern only.
- Upstream contribution: ADR-003 (short tokens) is a general bug, not
  fork-specific. PR it upstream once we have the test suite to prove it.

## How to Update This File

When you land a patch:

1. Add a row to the table above.
2. Write the test that locks the patch.
3. Flip the row from **untested** to **tested** in the same commit that
   adds the test.
4. If the patch encodes a design decision (e.g., env-var override),
   add an ADR in `docs/DESIGN.md` and cross-reference.
