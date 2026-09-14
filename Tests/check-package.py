"""Validate the release tree without loading WoW or contacting upload services."""
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

source = Path(__file__).resolve().parent.parent
package = Path(sys.argv[1]).resolve()
toc = (package / "Glassy.toc").read_text(encoding="utf-8-sig")
version = re.search(r"^## Version: (.+)$", toc, re.M).group(1).strip()
init = (package / "Glassy/init.lua").read_text()
assert 'GetAddOnMetadata(AddonName, "Version")' in init, "Runtime version must come from TOC metadata"
assert not re.search(r'Core\.Version\s*=\s*["\']\d', init), "Runtime version must not be hardcoded"
assert re.search(rf"^# {re.escape(version)} \(\d{{4}}-\d{{2}}-\d{{2}}\)$", (source / "LATEST.md").read_text(), re.M), "Latest release notes mismatch"
assert f' name = "{version} (' in (source / "Glassy/Modules/News.lua").read_text(), "In-game release notes mismatch"
assert "## X-Curse-Project-ID: 1695833" in toc, "Incorrect CurseForge project"
assert "## X-Wago-ID: qGYZPRNg" in toc, "Incorrect Wago project"
for locale in ("deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"):
    assert (package / f"Glassy/Locales/{locale}.lua").is_file(), f"Missing {locale} locale"
tag = os.environ.get("RELEASE_TAG", "")
if tag:
    assert tag == f"v{version}", f"Tag {tag!r} does not match version {version!r}"

visited = set()


def check_file(path):
    path = path.resolve()
    assert path.is_relative_to(package), f"File escapes addon folder: {path}"
    assert path.is_file(), f"Missing packaged file: {path.relative_to(package)}"
    if path in visited:
        return
    visited.add(path)
    if path.suffix.lower() == ".xml":
        for element in ET.parse(path).iter():
            if element.tag.rsplit("}", 1)[-1] in ("Script", "Include"):
                filename = element.get("file")
                if filename:
                    check_file(path.parent / filename.replace("\\", "/"))


for line in toc.splitlines():
    line = line.strip()
    if line and not line.startswith("#"):
        check_file(package / line.replace("\\", "/"))
for name in ("LICENSE", "README.md", "Media/Icon.tga", "Glassy/Assets/overlayMask.tga", "Glassy/Assets/snapToBottomIcon.tga"):
    check_file(package / name)
for name in ("Tests", "tests", ".git", ".github", ".travis.yml", ".luacheckrc", ".pkgmeta"):
    assert not (package / name).exists(), f"Development file in package: {name}"
print(f"PASS: Glassy {version}, metadata, {len(visited)} referenced files, and clean package contents")
