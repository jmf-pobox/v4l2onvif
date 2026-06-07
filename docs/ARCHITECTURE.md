# Architecture

This document describes the current architecture of `onvif-server`
as it lives in this fork. For deltas from upstream, see `docs/PATCHES.md`.
For design decisions, see `docs/DESIGN.md`.

## Components

```text
┌──────────────────────────────────────────────────────────────────────┐
│                          onvif-server                            │
│                                                                      │
│  ┌────────────────────┐    ┌──────────────────────────────────────┐  │
│  │  main thread       │    │  wsdd thread (std::thread)           │  │
│  │  - SOAP dispatch   │    │  - WS-Discovery responder            │  │
│  │  - HTTP listener   │    │  - sends Hello on startup            │  │
│  │    on :8080        │    │  - answers Probe on UDP 239.255.255  │  │
│  │                    │    │    .250:3702                         │  │
│  └────────────────────┘    └──────────────────────────────────────┘  │
│             │                          │                             │
│             ▼                          ▼                             │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  ServiceContext (shared, mostly-immutable after main())          ││
│  │  - m_devices:      token → RTSP URL                              ││
│  │  - m_devicePaths:  token → /dev/videoN                           ││
│  │  - m_port, m_rtspport, m_timezone, m_isdst                       ││
│  │  - V4L2 helpers (open ioctl close pattern)                       ││
│  └──────────────────────────────────────────────────────────────────┘│
│             │                                                        │
│             ▼                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  v4l2rtspserver (submodule)                                      ││
│  │  - V4l2RTSPServer + live555 RTSP listener on :8554               ││
│  │  - reads frames from /dev/videoN, serves as RTP/RTSP             ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

## SOAP Layering

- **`gen/*.cpp`** — gSOAP auto-generated stubs from the ONVIF WSDLs.
  Do not edit; regenerate from WSDL if needed.
- **`src/server*.cpp`** — per-service handler implementations
  (`DeviceBindingService`, `MediaBindingService`, etc.). One file per
  ONVIF service.
- **`src/onvif_impl.cpp`** — `ServiceContext` core: shared state,
  V4L2 helpers, profile/capability builders. Most of our bug fixes
  live here.
- **`src/onvif-server.cpp`** — `main()`. Argument parsing, listener
  setup, dispatch loop, terminate handler.

## Threading Model

- One thread for WS-Discovery (`wsd_server` in
  `ws-discovery/gsoap/wsd-server.cpp`).
- One thread per incoming SOAP request (gSOAP fork-style dispatch).
- One thread per RTSP session (handled inside live555).

Shared state (`ServiceContext`) is written only during `main()` setup.
Once the listeners are running, treat `ServiceContext` as immutable.

## Network Surface

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 TCP | HTTP / SOAP | ONVIF services |
| 8554 TCP | RTSP | v4l2rtspserver |
| 3702 UDP | WS-Discovery | Probe responder |
| 8554/UDP 8001/UDP 8000 | RTP/RTCP | live555 (data channels) |

`onvif-server -H <http_port> -R <rtsp_port> -i <device>` controls
the first two; UDP ports are picked by live555.

## Configuration

- Command-line flags (see `onvif-server -h`).
- `V4L2ONVIF_IP` environment variable: override for the host IP
  advertised in `XAddrs` and `MediaUri`. See ADR-003 and ADR for the
  env override.

## What Lives Where

| Path | Owns |
|------|------|
| `inc/` | Public headers |
| `src/` | Our code (handlers, main, ServiceContext) |
| `gen/` | gSOAP-generated bindings (regenerated from WSDLs) |
| `ws-discovery/` | Submodule: WS-Discovery responder + WSDD |
| `v4l2rtspserver/` | Submodule: RTSP server + libv4l2cpp |
| `v4l2rtspserver/live/` | live555 source (cloned from rgaufman/live555, ADR-001) |
| `tests/` | Our tests (Catch2) |
| `docs/` | Human-facing docs |
| `.claude/` | Agent + rule configuration |
