#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -target arm64-apple-macosx15.0 -parse-as-library "$project_dir/Tests/ChartLayoutTests.swift" "$project_dir/App/Visualizations.swift" "$project_dir/App/AppLanguage.swift" -o "$test_dir/chart-layout-tests"
"$test_dir/chart-layout-tests"
