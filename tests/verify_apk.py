#!/usr/bin/env python3
"""Verify the actual export; does not claim headset execution."""
import hashlib
import json
import os
import re
import shutil
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / 'build/KiborgBender-Quest.apk'
config_path = ROOT / '.local-tools.json'
config = json.loads(config_path.read_text()) if config_path.exists() else {}
aapt = os.environ.get('AAPT') or config.get('aapt') or shutil.which('aapt')
if not aapt:
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if sdk:
        tools = Path(sdk) / 'build-tools'
        candidates = sorted(tools.glob('*/aapt.exe' if os.name == 'nt' else '*/aapt'), reverse=True)
        if candidates:
            aapt = str(candidates[0])
if not aapt:
    raise SystemExit('Set AAPT to the Android SDK build-tools aapt executable.')
AAPT = Path(aapt)
expected_package = re.search(r'package/unique_name="([^"]+)"', (ROOT/'export_presets.cfg').read_text()).group(1)
(ROOT / 'qa').mkdir(exist_ok=True)
badging = subprocess.check_output([str(AAPT), 'dump', 'badging', str(APK)], text=True)
manifest = subprocess.check_output([str(AAPT), 'dump', 'xmltree', str(APK), 'AndroidManifest.xml'], text=True)
(ROOT / 'qa/manifest.txt').write_text(manifest)
assert f"name='{expected_package}'" in badging
assert "native-code: 'arm64-v8a'" in badging
assert 'com.oculus.permission.HAND_TRACKING' in manifest
hand = manifest.index('oculus.software.handtracking')
assert '0xffffffff' in manifest[hand:hand+300], 'Hand tracking must be required'
assert 'questpro' in manifest
assert 'com.oculus.handtracking.frequency' in manifest and '"HIGH"' in manifest
assert 'android.permission.INTERNET' not in manifest
with zipfile.ZipFile(APK) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert 'lib/arm64-v8a/libgodot_android.so' in names
    assert any('libgodotopenxrvendors.so' in n for n in names)
    assert any('main.gd' in n or 'main.tscn' in n or '.pck' in n for n in names)
    assert not any(n.startswith('assets/tests/') or n.startswith('assets/qa/') for n in names)
    assert not any('game-concept' in n or 'PROMPT' in n for n in names)
report = {'apk': 'build/KiborgBender-Quest.apk', 'bytes': APK.stat().st_size,
          'sha256': hashlib.sha256(APK.read_bytes()).hexdigest(),
          'package': expected_package, 'architecture': 'arm64-v8a',
          'required_hand_tracking': True, 'quest_pro_declared': True,
          'hand_tracking_frequency': 'HIGH', 'network_permission': False,
          'zip_integrity': 'PASS', 'physical_headset_test': False}
(ROOT / 'qa/apk-verification.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
