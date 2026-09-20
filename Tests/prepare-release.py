"""Synchronize release metadata and notes from LATEST.md using only the standard library."""
import argparse
from datetime import date
from pathlib import Path
import re


VERSION = r"\d+\.\d+\.\d+"
HEADING = rf"# ({VERSION}) \((\d{{4}}-\d{{2}}-\d{{2}}|unreleased)\)"
NEWS_ENTRY = re.compile(
    rf'  \{{\n    name = "({VERSION}) \([^"]+\)",\n'
    r'    items = \{\[(=*)\[\n.*?\]\2\]\}\n  \},?\n', re.S
)


def read(path):
    return path.read_text(encoding="utf-8-sig")


def release_notes(root):
    heading, _, body = read(root / "LATEST.md").partition("\n")
    match = re.fullmatch(HEADING, heading)
    if not match or not body.strip():
        raise ValueError("LATEST.md needs '# VERSION (YYYY-MM-DD)' or '# VERSION (unreleased)' and release notes")
    version, stamp = match.groups()
    if stamp != "unreleased":
        date.fromisoformat(stamp)
    return version, stamp, body.strip()


def replace_section(text, pattern, heading, body):
    matches = list(re.finditer(pattern, text, re.M))
    if len(matches) > 1:
        raise ValueError(f"Duplicate release section: {heading}")
    if matches:
        start = matches[0].start()
        following = re.search(r"^## ", text[matches[0].end():], re.M)
        end = matches[0].end() + following.start() if following else len(text)
        return text[:start] + heading + "\n\n" + body + "\n\n" + text[end:]
    return None


def generated_files(root, version, stamp, body):
    if not re.fullmatch(VERSION, version):
        raise ValueError("Version must have the form 1.9.3")
    if stamp != "unreleased":
        date.fromisoformat(stamp)
    result = {root / "LATEST.md": f"# {version} ({stamp})\n\n{body}\n"}
    tocs = sorted(root.glob("*.toc"))
    if not tocs:
        raise ValueError("No TOC files found")
    for toc in tocs:
        content, count = re.subn(r"^## Version: .+$", f"## Version: {version}", read(toc), flags=re.M)
        if count != 1:
            raise ValueError(f"Expected one version in {toc.name}")
        result[toc] = content

    nested = re.sub(r"^(#{2,5}) ", r"\1# ", body, flags=re.M)
    for filename, heading, pattern, insertion in (
        ("README.md", f"## What's new in {version}" + (" (unreleased)" if stamp == "unreleased" else ""),
         rf"^## What's new in {re.escape(version)}(?: \(unreleased\))?$", r"^## What's new in "),
        ("CHANGELOG.md", f"## {version} ({stamp})",
         rf"^## {re.escape(version)} \([^)]+\)$", rf"^## {VERSION} \("),
    ):
        path = root / filename
        content = read(path)
        updated = replace_section(content, pattern, heading, nested)
        if updated is None:
            first = re.search(insertion, content, re.M)
            if first is None:
                raise ValueError(f"No release sections found in {filename}")
            updated = content[:first.start()] + heading + "\n\n" + nested + "\n\n" + content[first.start():]
        result[path] = updated

    # News uses plain text, not a Markdown renderer.
    plain = re.sub(r"^#{2,6} ", "", body, flags=re.M).replace("**", "").replace("`", "")
    plain = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", plain)
    delimiter = ""
    while "]" + delimiter + "]" in plain:
        delimiter += "="
    entry = (f'  {{\n    name = "{version} ({stamp})",\n    items = {{[{delimiter}[\n'
             f"{plain}\n    ]{delimiter}]}}\n  }},\n")
    path = root / "Glassy/Modules/NewsData.lua"
    news = read(path)
    entries = list(NEWS_ENTRY.finditer(news))
    if not entries:
        raise ValueError("No recognized release entries in NewsData.lua")
    current = [match for match in entries if match[1] == version]
    if len(current) > 1:
        raise ValueError("Duplicate in-game release entries")
    if current:
        match = current[0]
        news = news[:match.start()] + news[match.end():]
    insertion = news.index("Core.NewsEntries = {\n") + len("Core.NewsEntries = {\n")
    result[path] = news[:insertion] + entry + news[insertion:]
    return result


def validate_tag(version, stamp, tag):
    if tag and (tag != f"v{version}" or stamp == "unreleased"):
        raise ValueError("Release tags must match the version and have dated release notes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", nargs="?", help="Release version, such as 1.9.3")
    parser.add_argument("--date", dest="stamp", help="YYYY-MM-DD or unreleased; defaults to today when preparing")
    parser.add_argument("--check", action="store_true", help="Report stale generated files without modifying them")
    parser.add_argument("--tag", default="", help="Require a matching release tag and dated notes")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        version, stamp, body = release_notes(root)
        if not args.check and not args.version:
            parser.error("version is required unless --check is used")
        version = args.version or version
        stamp = args.stamp or (stamp if args.check else date.today().isoformat())
        validate_tag(version, stamp, args.tag)
        generated = generated_files(root, version, stamp, body)
        changed = [path for path, text in generated.items() if read(path) != text]
        if args.check:
            if changed:
                parser.exit(1, "Release files are out of sync: " + ", ".join(str(p.relative_to(root)) for p in changed)
                            + f"\nRun: python Tests/prepare-release.py {version} --date {stamp}\n")
            print(f"PASS: release {version} ({stamp}) is synchronized")
        else:
            for path in changed:
                path.write_text(generated[path], encoding="utf-8", newline="\n")
            print(f"Prepared {version} ({stamp}); updated {len(changed)} files")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Release preparation failed: {error}\n")


if __name__ == "__main__":
    main()
