#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
swiftc -D CLI_TESTS -parse-as-library -target "$(uname -m)-apple-macos15.0" -module-cache-path "$PWD/build/tests/ModuleCache" WEST/Shared/Model.swift WEST/Shared/Catalog.swift WEST/Shared/Localization.swift WEST/Shared/Store.swift WEST/Shared/ClockViews.swift WESTTests/CoreTests.swift -o build/tests/core-tests
build/tests/core-tests
