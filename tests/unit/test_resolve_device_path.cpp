// Regression for ADR-003.
//
// Background: upstream uses the V4L2 device path as the ONVIF
// ReferenceToken. The spec caps ReferenceToken at 64 chars, and Win11
// silently rejects responses that exceed it. Our fix is to generate
// short tokens (VideoSource_0, …) and translate them back to the real
// device path inside every V4L2 helper, via
// ServiceContext::resolveDevicePath.
//
// This file pins that translation. If anyone changes resolveDevicePath
// to drop the m_devicePaths lookup, or if anyone reverts the short-
// token generation, these tests fail before Win11 ever sees the daemon.

#include <catch2/catch_test_macros.hpp>

#include "onvif_impl.h"

TEST_CASE("resolveDevicePath: unknown token returns the input unchanged",
          "[onvif_impl][resolve_device_path]")
{
    ServiceContext ctx;
    // Pre-condition: no entries in the translation map.
    REQUIRE(ctx.m_devicePaths.empty());

    // Behavior: an unknown token round-trips. This matters because
    // upstream callers historically passed the device path directly;
    // we must not break that path.
    REQUIRE(ctx.resolveDevicePath("/dev/video0") == "/dev/video0");
    REQUIRE(ctx.resolveDevicePath("VideoSource_42") == "VideoSource_42");
    REQUIRE(ctx.resolveDevicePath("") == "");
}

TEST_CASE("resolveDevicePath: known token returns mapped device path",
          "[onvif_impl][resolve_device_path]")
{
    ServiceContext ctx;
    ctx.m_devicePaths["VideoSource_0"]
        = "/dev/v4l/by-id/usb-Chicony-Webcam-WB7022-video-index0";
    ctx.m_devicePaths["VideoSource_1"] = "/dev/video0";

    REQUIRE(ctx.resolveDevicePath("VideoSource_0")
            == "/dev/v4l/by-id/usb-Chicony-Webcam-WB7022-video-index0");
    REQUIRE(ctx.resolveDevicePath("VideoSource_1") == "/dev/video0");

    // Unknown tokens still pass through even when the map has entries.
    REQUIRE(ctx.resolveDevicePath("VideoSource_99") == "VideoSource_99");
}

TEST_CASE("resolveDevicePath: const-correct (lookup does not mutate)",
          "[onvif_impl][resolve_device_path]")
{
    ServiceContext ctx;
    ctx.m_devicePaths["VideoSource_0"] = "/dev/video0";

    const ServiceContext& cref = ctx;
    REQUIRE(cref.resolveDevicePath("VideoSource_0") == "/dev/video0");
    REQUIRE(cref.resolveDevicePath("anything") == "anything");
}
