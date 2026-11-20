#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
swiftc -target arm64-apple-macosx15.0 -parse-as-library "$project_dir/Tests/VolumeCapacityTests.swift" "$project_dir/App/VolumeCapacity.swift" -o "$test_dir/volume-capacity-tests"
"$test_dir/volume-capacity-tests"
