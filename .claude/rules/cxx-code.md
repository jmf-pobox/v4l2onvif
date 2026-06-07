---
paths:
  - "**/*.cpp"
  - "**/*.h"
  - "**/*.hpp"
---

# C++ Code Hygiene

## Standard

- **C++20.** Compile with `-std=c++20 -Wall -Wextra -Wpedantic -Werror`.
- Existing upstream code may be C++11-style; modernize when you touch it,
  don't bulk-rewrite ahead of need.

## Naming

- `snake_case` for free functions and variables.
- `CamelCase` for types and classes (matches upstream + ONVIF idioms).
- `kCamelCase` for constants (no `MACRO_CASE` for non-macros).
- `m_` prefix for member variables (matches upstream).
- Public API functions in a service: `ServiceContext::resolveDevicePath`,
  `ServiceContext::getLocalIp`. Static (file-scope) helpers: no prefix.

## Includes

- gSOAP-generated headers first (they pull in `stdsoap2.h`).
- System headers next, alphabetized.
- Project headers last, alphabetized.
- Include guards: `#ifndef MODULE_NAME_H` / `#define MODULE_NAME_H`
  (matches upstream; `#pragma once` is an OK alternative for new files).

## Const Correctness

- Read-only parameters: `const std::string&` or `std::string_view`.
- `const` methods on `ServiceContext` for any getter.
- Don't cast away const — if you need to, the API is wrong.

## Error Handling

- `[[nodiscard]]` on every fallible function returning a status.
- Return `std::optional<T>` for "might fail to compute T".
- Check return values of `open()`, `ioctl()`, gSOAP allocator calls.
- No silent failures — log the error path, even if recovery is "return
  empty response".

## Resource Management

- RAII for file descriptors. Wrap `open()` in a `ScopedFd` (we'll add
  it in `inc/util/scoped_fd.h`).
- Smart pointers (`std::unique_ptr`, `std::shared_ptr`) for owned
  pointers; raw pointers only for non-owning observation.
- gSOAP-allocated structs are managed by the soap context; do not
  `delete` them. Track soap context lifetime instead.

## Functions

- One responsibility per function. If it does X and also Y, split it.
- Keep functions under 50 lines where practical.
- Pure functions (no side effects) are preferred and easier to test.

## Comments

- None by default.
- Only when WHY is non-obvious: hidden constraints, workarounds, spec
  quirks ("ONVIF requires Foo to be present, even though it's optional
  in WSDL"), surprising client behavior.
- Never explain WHAT — well-named identifiers do that.
- Never reference the current task, PR, or caller — those rot.

## State

- No global mutable state in new code. Pass `ServiceContext*`.
- `static` for file-scope helpers only.
- The wsdd thread and SOAP handler thread share `ServiceContext`.
  Treat shared fields as immutable after `main()` initialization, or
  guard explicitly with a mutex.

## gSOAP Specifics

- See `.claude/rules/soap.md`.
