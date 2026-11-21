#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size-language.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
export CLANG_MODULE_CACHE_PATH="$build_dir/module-cache"
swiftc "$project_dir/App/AppLanguage.swift" "$project_dir/Tests/AppLanguageTests.swift" -o "$build_dir/tests"
"$build_dir/tests"
python3 - "$project_dir" <<'PY'
import plistlib, re, sys
from pathlib import Path
root = Path(sys.argv[1])
tables = {lang: plistlib.loads((root / 'Resources' / (lang + '.lproj') / 'Localizable.strings').read_bytes()) for lang in ('es', 'en', 'ja')}
assert tables['es'].keys() == tables['en'].keys() == tables['ja'].keys(), 'Translation tables differ'
for lang, table in tables.items():
    for key, translation in table.items():
        assert translation, f'Missing {lang} translation: {key}'
        assert re.findall(r'%(?:lld|@)', key) == re.findall(r'%(?:lld|@)', translation), f'Format mismatch in {lang}: {key}'
for file in (root / 'App').glob('*.swift'):
    if file.name == 'AppLanguage.swift':
        continue
    source = file.read_text()
    for key in re.findall(r'\b(?:L|LF)\("([^"\\]+)"', source):
        assert key in tables['en'], f'{file.name}: missing translation {key}'
print('Translation tables passed')
PY
