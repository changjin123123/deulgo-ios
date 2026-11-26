#!/usr/bin/env python3
"""Validate project/plist wiring only. This is NOT a Swift compiler or XCTest run."""
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'Deulgo.xcodeproj/project.pbxproj').read_text()
source = re.sub(r'//[^\n]*\n', '\n', source, count=1)
tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', source)
cursor = 0

def take(expected=None):
    global cursor
    token = tokens[cursor]
    cursor += 1
    if expected is not None: assert token == expected, (token, expected, cursor)
    return json.loads(token) if token.startswith('"') else token

def value():
    if tokens[cursor] == '{':
        take('{'); obj = {}
        while tokens[cursor] != '}':
            key = take(); take('='); obj[key] = value(); take(';')
        take('}'); return obj
    if tokens[cursor] == '(':
        take('('); result = []
        while tokens[cursor] != ')':
            result.append(value())
            if tokens[cursor] == ',': take(',')
            else: break
        take(')'); return result
    return take()

project = value()
assert cursor == len(tokens)
objects = project['objects']
reference_keys = {'fileRef', 'productRef', 'mainGroup', 'productRefGroup', 'productReference',
                  'buildConfigurationList', 'baseConfigurationReference', 'package', 'containerPortal',
                  'remoteGlobalIDString', 'target', 'targetProxy'}
reference_lists = {'children', 'files', 'buildPhases', 'dependencies', 'packageProductDependencies',
                   'buildConfigurations', 'targets', 'packageReferences'}
for identifier, obj in objects.items():
    for key, item in obj.items():
        if key in reference_keys: assert item in objects, (identifier, key, item)
        if key in reference_lists:
            for ref in item: assert ref in objects, (identifier, key, ref)
assert project['rootObject'] in objects

def check_group(group_id, base):
    group = objects[group_id]
    if 'path' in group: base = base / group['path']
    for child_id in group.get('children', []):
        child = objects[child_id]
        if child['isa'] == 'PBXGroup': check_group(child_id, base)
        elif child.get('sourceTree') != 'BUILT_PRODUCTS_DIR':
            assert (base / child['path']).exists(), base / child['path']
check_group(objects[project['rootObject']]['mainGroup'], root)
swift_refs = {obj['path'] for obj in objects.values() if obj.get('lastKnownFileType') == 'sourcecode.swift'}
assert swift_refs == {p.name for folder in ['Deulgo', 'DeulgoTests'] for p in (root / folder).glob('*.swift')}
plist = plistlib.loads((root / 'Deulgo/Info.plist').read_bytes())
assert set(plist['LSApplicationQueriesSchemes']) == {'nmap', 'kakaonavi-sdk'}
assert plist['KakaoNativeAppKey'] == '$(KAKAO_NATIVE_APP_KEY)'
assert not any('Location' in key and 'UsageDescription' in key for key in plist)
for path in (root / 'Deulgo/Assets.xcassets').rglob('*.json'): json.loads(path.read_text())
scheme = ET.parse(root / 'Deulgo.xcodeproj/xcshareddata/xcschemes/Deulgo.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    assert ref.attrib['BlueprintIdentifier'] in objects
if '--for-package' in sys.argv:
    assert not (root / 'Config/Local.xcconfig').exists(), 'Do not package local settings'
test_count = sum(len(re.findall(r'func test\w+\(', p.read_text())) for p in (root / 'DeulgoTests').glob('*.swift'))
resource_names = {obj['path'] for obj in objects.values() if obj.get('lastKnownFileType') in {'text.json', 'sourcecode.javascript'}}
assert resource_names == {p.name for p in (root/'Deulgo/Resources').glob('*')}
print(f'PASS: OpenStep project parsed; {len(objects)} objects and source references valid.')
print('PASS: Info.plist, URL scheme queries, shared scheme and asset JSON parsed.')
print(f'NOT RUN: Swift compilation, {test_count} XCTest cases, iPhone launch, external app handoff.')
