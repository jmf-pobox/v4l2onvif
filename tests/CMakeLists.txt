# Test target registration for v4l2onvif.
#
# Two helper functions:
#   v4l2onvif_add_unit_test(<name>)        — tests/unit/test_<name>.cpp
#   v4l2onvif_add_integration_test(<name>) — tests/integration/test_<name>.cpp
#
# Each test links against Catch2::Catch2WithMain and the v4l2onvif core
# library target. Integration tests additionally need libcurl for raw
# SOAP fixture replay.

find_package(Catch2 3 REQUIRED)
include(CTest)
include(Catch)

function(v4l2onvif_add_unit_test name)
    set(target "test_${name}")
    add_executable(${target} unit/${target}.cpp)
    target_link_libraries(${target} PRIVATE Catch2::Catch2WithMain
                                            v4l2onvif_core)
    target_include_directories(${target} PRIVATE
        ${CMAKE_SOURCE_DIR}/inc
        ${CMAKE_SOURCE_DIR}/gen)
    target_compile_features(${target} PRIVATE cxx_std_20)
    catch_discover_tests(${target}
        TEST_PREFIX "${name}::"
        PROPERTIES LABELS "unit")
endfunction()

function(v4l2onvif_add_integration_test name)
    set(target "test_${name}")
    add_executable(${target} integration/${target}.cpp)
    target_link_libraries(${target} PRIVATE Catch2::Catch2WithMain
                                            v4l2onvif_core CURL::libcurl)
    target_include_directories(${target} PRIVATE
        ${CMAKE_SOURCE_DIR}/inc
        ${CMAKE_SOURCE_DIR}/gen)
    target_compile_features(${target} PRIVATE cxx_std_20)
    catch_discover_tests(${target}
        TEST_PREFIX "${name}::"
        PROPERTIES LABELS "integration")
endfunction()

# Layer 1: Unit tests — pure logic, no network, no V4L2 hardware.
v4l2onvif_add_unit_test(resolve_device_path)

# As tests are written, register them here. Each entry MUST cite the
# bug or behavior it locks in (see docs/TESTING.md "Test Priority for
# the Backfill"):
#
#   v4l2onvif_add_unit_test(pixfmt_mapping)         # ADR-? / MJPG bug
#   v4l2onvif_add_unit_test(reference_token_length) # ADR-003
#   v4l2onvif_add_unit_test(profile_builder)        # empty-name bug
#   v4l2onvif_add_unit_test(streaming_capabilities) # RTP_TCP=true
#   v4l2onvif_add_unit_test(local_ip_override)      # V4L2ONVIF_IP env
#
# Layer 2: Integration tests — running server, real SOAP wire.
#
#   v4l2onvif_add_integration_test(discovery_roundtrip)
#   v4l2onvif_add_integration_test(profile_streamuri)
#   v4l2onvif_add_integration_test(win11_wireformat_fixtures)
