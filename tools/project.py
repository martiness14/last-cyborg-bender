#!/usr/bin/env python3
"""Portable project commands. Python 3.9+, no third-party Python packages."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "dependencies.json").read_text())
CONFIG_FILE = ROOT / ".local-tools.json"
CONFIG = json.loads(CONFIG_FILE.read_text()) if CONFIG_FILE.exists() else {}


def tool(name):
    configured = os.environ.get(name.upper()) or CONFIG.get(name)
    if configured:
        found = shutil.which(configured) or str(Path(configured).expanduser())
        if Path(found).is_file():
            return found
        raise RuntimeError(f"Configured {name} does not exist: {configured}")
    for candidate in (["godot", "godot4", "Godot"] if name == "godot" else [name]):
        if found := shutil.which(candidate):
            return found
    if name == "godot" and Path("/Applications/Godot.app/Contents/MacOS/Godot").is_file():
        return "/Applications/Godot.app/Contents/MacOS/Godot"
    if name == "adb":
        sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
        if sdk:
            candidate = Path(sdk) / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
            if candidate.is_file():
                return str(candidate)
    raise RuntimeError(f"Install {name} and put it on PATH, or set {name.upper()} to its executable.")


def run(args, capture=False):
    env = os.environ.copy()
    if CONFIG.get("java_home") and not env.get("JAVA_HOME"):
        env["JAVA_HOME"] = CONFIG["java_home"]
    result = subprocess.run(args, cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.STDOUT if capture else None)
    if capture:
        print(result.stdout, end="")
    result.check_returncode()
    return result.stdout if capture else None


def extract_safe(archive, destination):
    destination = destination.resolve()
    for item in archive.infolist():
        resolved = (destination / item.filename).resolve()
        if resolved != destination and destination not in resolved.parents:
            raise RuntimeError("Unsafe path in dependency archive")
        if (item.external_attr >> 16) & 0o170000 == 0o120000:
            raise RuntimeError("Unexpected symlink in dependency archive")
    archive.extractall(destination)


def setup():
    dep = LOCK["openxr_vendors"]
    cache = ROOT / ".cache" / f"openxr-vendors-{dep['version']}.zip"
    cache.parent.mkdir(exist_ok=True)
    if not cache.exists() or hashlib.sha256(cache.read_bytes()).hexdigest() != dep["sha256"]:
        print(f"Downloading OpenXR Vendors {dep['version']} from its official release...")
        request = urllib.request.Request(dep["url"], headers={"User-Agent": "KiborgBender-Setup"})
        with urllib.request.urlopen(request, timeout=120) as response, cache.open("wb") as output:
            shutil.copyfileobj(response, output)
    if hashlib.sha256(cache.read_bytes()).hexdigest() != dep["sha256"]:
        raise RuntimeError("OpenXR download SHA256 mismatch; dependency was not installed")
    with tempfile.TemporaryDirectory(prefix="kiborg-openxr-") as temporary:
        with zipfile.ZipFile(cache) as archive:
            extract_safe(archive, Path(temporary))
        source = Path(temporary) / "asset/addons/godotopenxrvendors"
        if not (source / "plugin.gdextension").exists():
            raise RuntimeError("Downloaded archive does not contain the expected plugin")
        shutil.copytree(source, ROOT / "addons/godotopenxrvendors", dirs_exist_ok=True)
    if not (ROOT / "addons/godotopenxrvendors/plugin.gdextension").exists():
        raise RuntimeError("Downloaded archive does not contain the expected plugin")
    print("OpenXR dependency installed with its upstream license files.")


def engine():
    if not (ROOT / "addons/godotopenxrvendors/plugin.gdextension").exists():
        raise RuntimeError("Run python3 tools/project.py setup first.")
    return tool("godot")


def test():
    godot = engine()
    (ROOT / "qa").mkdir(exist_ok=True)
    run([godot, "--headless", "--xr-mode", "off", "--path", ".", "--editor", "--import", "--quit"])
    log = run([godot, "--headless", "--xr-mode", "off", "--path", ".", "--script", "tests/run_tests.gd"], capture=True)
    (ROOT / "qa/tests.log").write_text(log)
    if re.search(r"SCRIPT ERROR:|ERROR:|Parse Error:", log):
        raise RuntimeError("Runtime error in test log; refusing to continue")
    report = json.loads((ROOT / "qa/tests.json").read_text())
    if report["failures"] or report["passed"] != report["checks"]:
        raise RuntimeError("Test report contains failures")


def android_template():
    if (ROOT / "android/build/build.gradle").exists():
        return
    version = LOCK["godot"] + ".stable"
    bases = [Path.home()/"Library/Application Support/Godot/export_templates",
             Path(os.environ.get("APPDATA", str(Path.home()))) / "Godot/export_templates",
             Path(os.environ.get("XDG_DATA_HOME", str(Path.home()/".local/share"))) / "godot/export_templates"]
    source = next((base/version/"android_source.zip" for base in bases
                   if (base/version/"android_source.zip").exists()), None)
    if not source:
        raise RuntimeError("Install matching Godot export templates, then Project > Install Android Build Template.")
    destination = ROOT / "android/build"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        extract_safe(archive, destination)
    (ROOT / "android/.build_version").write_text(version)
    (ROOT / "android/.gdignore").touch()
    if (destination / "gradlew").exists():
        (destination / "gradlew").chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "test", "preview", "build", "install"])
    args = parser.parse_args()
    if args.command == "setup":
        setup()
    elif args.command == "test":
        test()
    elif args.command == "preview":
        run([engine(), "--xr-mode", "off", "--path", ".", "--", "--demo"])
    elif args.command == "build":
        test()
        android_template()
        (ROOT / "build").mkdir(exist_ok=True)
        run([engine(), "--headless", "--xr-mode", "off", "--path", ".", "--export-debug",
             "Quest Pro Hands", "build/KiborgBender-Quest.apk"])
        run([sys.executable, "tests/verify_apk.py"])
    elif args.command == "install":
        apk = ROOT / "build/KiborgBender-Quest.apk"
        if not apk.exists():
            raise RuntimeError("Build an APK first, or download the release into build/.")
        adb = tool("adb")
        # ADB refuses an ambiguous selection; ANDROID_SERIAL may select an explicit device.
        run([adb, "get-state"])
        run([adb, "install", "-r", str(apk)])
        package = re.search(r'package/unique_name="([^"]+)"', (ROOT/"export_presets.cfg").read_text()).group(1)
        run([adb, "shell", "am", "start", "-n", package+"/com.godot.game.GodotAppLauncher"])


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
