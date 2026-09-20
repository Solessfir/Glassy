"""Exercise release generation without changing the working tree."""
from pathlib import Path
import runpy
import tempfile


source = Path(__file__).resolve().parent.parent
tools = runpy.run_path(str(source / "Tests/prepare-release.py"))
generate = tools["generated_files"]
notes = tools["release_notes"]


with tempfile.TemporaryDirectory(prefix="glassy-release-") as directory:
    root = Path(directory)
    files = ["LATEST.md", "CHANGELOG.md", "Glassy/Modules/NewsData.lua"]
    files += [path.name for path in source.glob("*.toc")]
    for filename in files:
        target = root / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(tools["read"](source / filename), encoding="utf-8")

    version, stamp, body = notes(root)
    old_news = tools["read"](root / "Glassy/Modules/NewsData.lua")
    old_entries = [m[0] for m in tools["NEWS_ENTRY"].finditer(old_news) if m[1] != version]
    for path, text in generate(root, version, stamp, body).items():
        path.write_text(text, encoding="utf-8")
    assert all(tools["read"](path) == text for path, text in generate(root, version, stamp, body).items()), "Generation must be idempotent"
    assert all(entry in tools["read"](root / "Glassy/Modules/NewsData.lua") for entry in old_entries), "Older news must remain unchanged"

    previous = {name: tools["read"](root / name) for name in files}
    new_body = "## What's new\n\n- **Unicode**: Привет, 世界. Literal ]] and ]=] and a [link](https://example.com)."
    generated = generate(root, "99.0.0", "unreleased", new_body)
    for path, text in generated.items():
        path.write_text(text, encoding="utf-8")
    heading = "## " + version
    old_release = previous["CHANGELOG.md"][previous["CHANGELOG.md"].index(heading):]
    assert old_release in generated[root / "CHANGELOG.md"], "Older changelog releases must remain unchanged"
    assert "[==[" in generated[root / "Glassy/Modules/NewsData.lua"], "Lua strings must safely contain closing delimiters"
    assert all(tools["read"](path) == text for path, text in generate(root, "99.0.0", "unreleased", new_body).items())
    tools["validate_tag"]("99.0.0", "unreleased", "")
    for stamp, tag in [("unreleased", "v99.0.0"), ("2026-09-21", "v99.0.1")]:
        try:
            tools["validate_tag"]("99.0.0", stamp, tag)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid release tag was accepted")
    tools["validate_tag"]("99.0.0", "2026-09-21", "v99.0.0")
    dated = generate(root, "99.0.0", "2026-09-21", new_body)
    for path, text in dated.items():
        path.write_text(text, encoding="utf-8")
    assert dated[root / "CHANGELOG.md"].count("## 99.0.0") == 1
    for filename in ("Glassy.toc", "CHANGELOG.md", "Glassy/Modules/NewsData.lua"):
        path = root / filename
        original = tools["read"](path)
        changed = original.replace("99.0.0", "99.0.1", 1)
        path.write_text(changed, encoding="utf-8")
        assert generate(root, "99.0.0", "2026-09-21", new_body)[path] != changed, f"Stale {filename} must fail checking"
        path.write_text(original, encoding="utf-8")
    for filename in ("CHANGELOG.md", "Glassy/Modules/NewsData.lua"):
        path = root / filename
        original = tools["read"](path)
        stale = original.replace("Unicode", "Stale text", 1)
        path.write_text(stale, encoding="utf-8")
        assert generate(root, "99.0.0", "2026-09-21", new_body)[path] != stale, "Note content drift must fail even with matching metadata"
        path.write_text(original, encoding="utf-8")
    try:
        generate(root, "99.0.0", "2026-02-30", new_body)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid calendar date accepted")

print("PASS: release generation, history preservation, Lua escaping, idempotence, metadata drift, and tag checks")
