# Makefile — convenience wrapper + quality gates for the v4l2onvif fork.
#
# This Makefile preserves upstream's build flow (gSOAP code generation +
# static library compilation + binary linking) but layers the fork's
# engineering process on top:
#
#   - Default target is 'help', not a build. Building takes 'make build'.
#   - Strict compiler warnings (-Werror, -Wpedantic, -Wconversion ...)
#     are ON by default. Upstream code that doesn't pass is a bug to
#     fix, not a reason to weaken the policy. Override with STRICT=0
#     during the transition period if you need to compile something to
#     observe a runtime behavior.
#   - Binaries are named 'onvif-server' / 'onvif-client'. The upstream
#     '.exe' suffix is dropped — these are ELF Linux binaries, not
#     Windows PE.
#   - 'make check' runs every CI gate: format, cppcheck, lint, tests.
#
# Run 'make help' for the target list.

# --- Configuration ---------------------------------------------------------

SYSROOT      ?= $(shell $(CXX) --print-sysroot 2>/dev/null)
PREFIX       ?= /usr
DESTDIR      ?= $(PREFIX)/bin
JOBS         ?= $(shell nproc 2>/dev/null || echo 4)
VERSION      := $(shell git describe --tags --always --dirty 2>/dev/null || echo unknown)

GSOAP_PREFIX  ?= $(SYSROOT)/usr
GSOAP_BIN     := $(GSOAP_PREFIX)/bin
GSOAP_BASE    := $(GSOAP_PREFIX)/share/gsoap
GSOAP_PLUGINS := $(GSOAP_BASE)/plugin

# Strict warnings are ON by default. STRICT=0 disables (transition escape
# hatch; CI does not allow STRICT=0).
STRICT ?= 1

STRICT_WARN := -Wall -Wextra -Wpedantic -Werror -Wconversion -Wshadow \
               -Wdouble-promotion -Wformat=2 -Wnull-dereference \
               -Wuninitialized

# Sanitizer flags (opt-in via ASAN=1).
SANITIZE_FLAGS := -fsanitize=address,undefined -fno-omit-frame-pointer -O1 \
                  -fno-sanitize-recover=all

CMAKE_CXX_FLAGS := $(CXXFLAGS)
CXXFLAGS += -std=c++20 -g2 -I inc -I ws-discovery/gsoap/
CXXFLAGS += -I gen -I $(GSOAP_PREFIX)/include -I $(GSOAP_PLUGINS)
CXXFLAGS += -DWITH_DOM -DWITH_OPENSSL -DSOAP_PURE_VIRTUAL -fpermissive -pthread
CXXFLAGS += -DVERSION=\"$(VERSION)\"

ifeq ($(STRICT),1)
CXXFLAGS += $(STRICT_WARN)
endif

ifdef ASAN
CXXFLAGS += $(SANITIZE_FLAGS)
LDFLAGS  += $(SANITIZE_FLAGS)
endif

LDFLAGS  += -L $(GSOAP_PREFIX)/lib/ -lgsoapssl++ -lz -pthread -lssl -lcrypto -ldl \
            -static-libstdc++

WSSE_SRC := $(GSOAP_PLUGINS)/wsseapi.c $(GSOAP_PLUGINS)/smdevp.c \
            $(GSOAP_PLUGINS)/mecevp.c $(GSOAP_BASE)/custom/struct_timeval.c

SOAP_SRC := $(wildcard gen/soapC_*.cpp)
SOAP_OBJ := $(SOAP_SRC:%.cpp=%.o)

SERVER_OBJ := \
  gen/soapDeviceBindingService.o gen/soapDeviceIOBindingService.o \
  gen/soapMediaBindingService.o gen/soapImagingBindingService.o \
  gen/soapPTZBindingService.o \
  gen/soapEventBindingService.o gen/soapPullPointSubscriptionBindingService.o \
  gen/soapNotificationProducerBindingService.o gen/soapSubscriptionManagerBindingService.o \
  gen/soapRecordingBindingService.o gen/soapReplayBindingService.o \
  gen/soapSearchBindingService.o gen/soapReceiverBindingService.o \
  gen/soapDisplayBindingService.o

CLIENT_OBJ := \
  gen/soapDeviceBindingProxy.o gen/soapDeviceIOBindingProxy.o \
  gen/soapMediaBindingProxy.o gen/soapImagingBindingProxy.o \
  gen/soapPTZBindingProxy.o \
  gen/soapEventBindingProxy.o gen/soapPullPointSubscriptionBindingProxy.o \
  gen/soapNotificationProducerBindingProxy.o gen/soapSubscriptionManagerBindingProxy.o \
  gen/soapRecordingBindingProxy.o gen/soapReplayBindingProxy.o \
  gen/soapReceiverBindingProxy.o gen/soapSearchBindingProxy.o \
  gen/soapDisplayBindingProxy.o

# Files that are OURS (subject to format/lint). Excludes gen/ (auto-
# generated), v4l2rtspserver/, ws-discovery/ (submodules), live/ (third-
# party).
OUR_CPP_FILES := $(shell find src inc tests -type f \
                   \( -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) \
                   2>/dev/null)

OUR_MD_FILES := $(shell find . -maxdepth 3 -type f -name '*.md' \
                 -not -path './v4l2rtspserver/*' \
                 -not -path './ws-discovery/*' \
                 -not -path './live/*' \
                 -not -path './gen/*' \
                 2>/dev/null)

.SILENT:

.PHONY: help all build rebuild test run \
        asan asan-build asan-test \
        clean distclean install uninstall \
        format format-check tidy cppcheck lint \
        modernize-audit \
        check ci

# --- Default = help (safer than building accidentally) --------------------

help: ## Show this help.
	echo "v4l2onvif build wrapper (fork of mpromonet/v4l2onvif)."
	echo "Run 'make build' to build, 'make check' to run all quality gates."
	echo
	echo "Targets:"
	awk 'BEGIN {FS = ":[^#]*## "} \
	     /^[a-zA-Z][a-zA-Z0-9_-]*:[^#]*## / { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' \
	     $(MAKEFILE_LIST)
	echo
	echo "Variables (override on command line, e.g. 'make build JOBS=2'):"
	echo "  JOBS         = $(JOBS)"
	echo "  PREFIX       = $(PREFIX)"
	echo "  DESTDIR      = $(DESTDIR)"
	echo "  GSOAP_PREFIX = $(GSOAP_PREFIX)"
	echo "  VERSION      = $(VERSION)"
	echo "  STRICT       = $(STRICT) (default on; STRICT=0 disables strict warnings)"
	echo "  ASAN         = $(if $(ASAN),on,off) (ASAN=1 enables AddressSan + UBSan)"

# --- Build (preserves upstream flow; binaries renamed without .exe) -------

all: build ## Alias for 'build'.

build: gen/onvif.h libwsdd.a liblibv4l2rtspserver.a onvif-server onvif-client ## Build server, client, and all static libraries.

rebuild: ## Wipe build artifacts and rebuild from scratch.
	$(MAKE) clean
	$(MAKE) build

# gSOAP code generation. The trailing 'make' recursion is upstream's
# pattern — soapcpp2 generates new sources that need a second pass.
gen/onvif.h: $(wildcard wsdl/*)
	mkdir -p gen
	$(GSOAP_BIN)/wsdl2h -d -Ntev -W -L -o $@ $^
	$(GSOAP_BIN)/soapcpp2 -2jx $@ -I $(GSOAP_BASE)/import -I $(GSOAP_BASE) \
	    -I inc -d gen -f1000 -w || :
	$(MAKE)

libserver.a: $(SERVER_OBJ) $(SOAP_OBJ) | gen/onvif.h
	$(AR) rcs $@ $^

libclient.a: $(CLIENT_OBJ) $(SOAP_OBJ) | gen/onvif.h
	$(AR) rcs $@ $^

ONVIF_SRC := $(wildcard src/server*.cpp)
libonvif.a: $(ONVIF_SRC:%.cpp=%.o)
	$(AR) rcs $@ $^

# ws-discovery submodule
libwsdd.a:
	git submodule update --init ws-discovery
	$(MAKE) -C ws-discovery/gsoap libwsdd.a
	cp ws-discovery/gsoap/libwsdd.a .

# v4l2rtsp submodule (also pulls live555 from rgaufman mirror; see ADR-001)
liblibv4l2rtspserver.a:
	git submodule update --recursive --init v4l2rtspserver
	if [ ! -d v4l2rtspserver/live ]; then \
	    echo "Fetching live555 from rgaufman/live555 (ADR-001) ..."; \
	    git clone --depth 1 https://github.com/rgaufman/live555.git \
	        v4l2rtspserver/live; \
	fi
	cd v4l2rtspserver && cmake -DALSA=OFF -DCMAKE_CXX_COMPILER=$(CXX) \
	    -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_FLAGS="$(CMAKE_CXX_FLAGS)" . && \
	    $(MAKE) libv4l2rtspserver
	cp v4l2rtspserver/$@ .

LIVE := v4l2rtspserver/live
CXXFLAGS += -I $(LIVE)/groupsock/include -I $(LIVE)/liveMedia/include \
            -I $(LIVE)/UsageEnvironment/include \
            -I $(LIVE)/BasicUsageEnvironment/include
CXXFLAGS += -I v4l2rtspserver/inc -I v4l2rtspserver/libv4l2cpp/inc -DNO_STD_LIB=1

onvif-server: src/onvif-server.o src/onvif_impl.o $(WSSE_SRC) libserver.a \
              libonvif.a gen/soapNotificationConsumerBindingProxy.o \
              libwsdd.a liblibv4l2rtspserver.a \
              v4l2rtspserver/libv4l2cpp/liblibv4l2cpp.a
	$(CXX) -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

onvif-client: src/onvif-client.o $(WSSE_SRC) $(GSOAP_PLUGINS)/wsaapi.c \
              libclient.a gen/soapNotificationConsumerBindingService.o libonvif.a
	$(CXX) -g -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

# --- Tests -----------------------------------------------------------------

test: build ## Run unit + integration tests (Catch2). Stubbed pending top-level CMake.
	echo "Tests not yet wired into the Makefile build."
	echo "tests/CMakeLists.txt is in place; needs top-level CMakeLists.txt to drive."
	echo "Tracked in docs/BUILDING.md."
	false

# --- Sanitizer build (opt-in via ASAN=1) ----------------------------------

asan: ## Build with AddressSanitizer + UBSan (equivalent to: make ASAN=1 build).
	$(MAKE) clean
	$(MAKE) build ASAN=1

asan-build: asan ## Alias for 'asan'.

asan-test: asan ## Build with sanitizers + run tests.
	$(MAKE) test ASAN=1

# --- Run ------------------------------------------------------------------

run: build ## Run onvif-server with sensible defaults (Dell webcam by-id).
	./onvif-server -H 8080 -R 8554 \
	    -i /dev/v4l/by-id/usb-Chicony_Tech._Inc._Dell_Webcam_WB7022_BD831C120F72-video-index0

# --- Install / uninstall --------------------------------------------------

install: build ## Install binaries to DESTDIR (default /usr/bin).
	mkdir -p $(DESTDIR)
	install -D -m 0755 onvif-server $(DESTDIR)
	install -D -m 0755 onvif-client $(DESTDIR)

uninstall: ## Remove installed binaries.
	rm -f $(DESTDIR)/onvif-server $(DESTDIR)/onvif-client

# --- Quality gates --------------------------------------------------------

format: ## Apply clang-format in-place to OUR files (src/, inc/, tests/).
	if [ -z "$(OUR_CPP_FILES)" ]; then echo "no files matched"; exit 0; fi
	clang-format -i $(OUR_CPP_FILES)
	echo "format: $(words $(OUR_CPP_FILES)) files reformatted"

format-check: ## Verify clang-format compliance without modifying files.
	if [ -z "$(OUR_CPP_FILES)" ]; then echo "no files matched"; exit 0; fi
	clang-format --dry-run --Werror $(OUR_CPP_FILES)
	echo "format-check: clean"

cppcheck: ## Static analysis on src/ + tests/ (skips gen/ and submodules).
	cppcheck \
	    --enable=warning,style,performance,portability \
	    --inline-suppr \
	    --suppress=missingIncludeSystem \
	    --suppress=unusedFunction \
	    --error-exitcode=1 \
	    --quiet \
	    --std=c++20 \
	    -I inc/ -I gen/ \
	    src/ tests/
	echo "cppcheck: clean"

tidy: build ## clang-tidy on src/ + tests/. Requires compile_commands.json.
	if [ ! -f compile_commands.json ]; then \
	    echo "tidy: SKIP (no compile_commands.json — see docs/BUILDING.md CMake plan)"; \
	    exit 0; \
	fi
	find src tests -name '*.cpp' -exec clang-tidy -p . {} +
	echo "tidy: clean"

lint: ## Markdown lint (markdownlint-cli2) on our docs.
	if [ -z "$(OUR_MD_FILES)" ]; then echo "no markdown files matched"; exit 0; fi
	markdownlint-cli2 $(OUR_MD_FILES)
	echo "lint: clean"

modernize-audit: ## Scan for legacy patterns we want to eliminate (raw new, NULL, etc.).
	echo "Legacy patterns audit (src/ + inc/):"
	echo
	echo "--- bare 'NULL' (use nullptr) ---"
	grep -rn '\bNULL\b' src/ inc/ 2>/dev/null | head -20 || true
	echo
	echo "--- raw 'new' (use std::make_unique/make_shared) ---"
	grep -rn '\bnew \+[A-Za-z_]' src/ inc/ 2>/dev/null | head -20 || true
	echo
	echo "--- 'using namespace std' (banned) ---"
	grep -rn 'using namespace std' src/ inc/ 2>/dev/null || echo "(none)"
	echo
	echo "--- functions over 50 lines (split candidates) ---"
	awk '/^[A-Za-z_].*\(.*\).*\{$$/ { start=NR; name=$$0 } \
	     /^\}$$/ { if (NR-start > 50) print FILENAME":"start": "name" ("NR-start" lines)" }' \
	     src/*.cpp 2>/dev/null | head -10 || true

check: ## Run every CI gate locally. Use before pushing.
	$(MAKE) format-check
	$(MAKE) cppcheck
	$(MAKE) lint
	$(MAKE) test
	echo
	echo "All checks passed."

ci: check ## Alias for 'check' (matches CI workflow naming).

# --- Cleanup --------------------------------------------------------------

clean: ## Remove build artifacts (objects, libraries, binaries).
	-$(MAKE) -C v4l2rtspserver clean 2>/dev/null
	-$(MAKE) -C ws-discovery/gsoap clean 2>/dev/null
	rm -rf gen src/*.o *.a onvif-server onvif-client
	rm -f onvif-server.exe onvif-client.exe

distclean: clean ## Remove everything generated, including fetched live555 source.
	rm -rf v4l2rtspserver/live
	rm -rf v4l2rtspserver/CMakeCache.txt v4l2rtspserver/CMakeFiles \
	       v4l2rtspserver/cmake_install.cmake
	rm -rf v4l2rtspserver/libv4l2cpp/CMakeCache.txt \
	       v4l2rtspserver/libv4l2cpp/CMakeFiles
