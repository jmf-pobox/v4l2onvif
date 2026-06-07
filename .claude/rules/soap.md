---
paths:
  - "src/server*.cpp"
  - "src/onvif_impl.cpp"
  - "inc/onvif_impl.h"
---

# gSOAP / ONVIF Rules

## ONVIF Spec Quirks

- `ReferenceToken` has a 64-char max length. Win11 silently drops
  responses that exceed it. Generate short tokens (ADR-003).
- Optional WSDL fields are not optional in practice for some clients.
  Win11 ignores Profiles where `<tt:Name>` is empty or where
  `VideoEncoderConfiguration.Encoding` is missing.
- `tt:Profile` allows leaving optional sub-configs out, but if you
  include one (e.g., `PTZConfiguration`), all its required nested
  fields must be present. Half-populated sub-configs are worse than
  omitted ones.

## Capability Flags

`GetCapabilities` (device-wide) and `GetServiceCapabilities` (Media)
both return streaming flags. **Patch both.** Mismatched values are
how we lost an hour this session.

For webcams:
- `RTPMulticast` = `false`
- `RTP_TCP` = `true`
- `RTP_RTSP_TCP` = `true`

## Pixel Format → ONVIF Encoding

The `V4L2_PIX_FMT_*` family has lookalike values. The encoder builder
must match all relevant ones:

| V4L2 | ONVIF Encoding |
|------|----------------|
| `V4L2_PIX_FMT_H264` | `tt__VideoEncoding__H264` |
| `V4L2_PIX_FMT_JPEG`, `V4L2_PIX_FMT_MJPEG` | `tt__VideoEncoding__JPEG` |
| `V4L2_PIX_FMT_YUYV`, `V4L2_PIX_FMT_NV12` | (raw — no ONVIF encoding; do not advertise as encoder option) |

## URL / XAddr Construction

- All XAddr fields in SOAP responses must use a host the client can
  reach. Use `ServiceContext::getServerIpFromClientIp(client_ip)` so
  the response is tailored to the client's subnet. The static
  WS-Discovery Hello must use the configured override
  (`V4L2ONVIF_IP` env var) — see ADR.
- The RTSP URL returned from `GetStreamUri` must use the same host
  selection logic as the SOAP XAddrs.

## V4L2 Helper Calls

Every helper that opens a V4L2 device by "device" string must call
`resolveDevicePath(device)` first. Tokens are short aliases; the
helpers see those aliases unless they translate. See ADR-003.

Functions that need updating when you add a new V4L2 helper:

- `getFormat`
- `getFrameRate`
- `getCtrlValue`
- `setCtrlValue`
- `getCtrlRange`
- `getName`
- `getIdentification`
- `getVideoEncoderCfgOptions`
- `getVideoSourceCfgOptions`

A linter / clang-tidy check that flags `open(token.c_str(), ...)`
without `resolveDevicePath` is a future task.

## Thread Safety

`wsd_server` runs in a dedicated `std::thread`. The SOAP handler
threads (one per request) run separately. Both touch the shared
`ServiceContext`. Treat `ServiceContext` as immutable after `main()`
initialization. If you must mutate, document the mutation with an
explicit mutex acquisition.

## Crash Hygiene

The `std::set_terminate(crash_backtrace)` handler in `onvif-server.cpp`
captures a backtrace on `std::bad_alloc` and other uncaught
exceptions. Keep it. When debugging a new crash:

1. Run under Debug build (symbols).
2. Use `addr2line -e onvif-server.exe -fiC <addrs>` to decode
   backtrace frames.
3. The actual bug is usually in the request *before* the one that
   crashed (heap corruption shows on the next allocation).
