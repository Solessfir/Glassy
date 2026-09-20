# Development and releases

`libs/` is ignored by Git; release packaging fetches the dependencies listed in `.pkgmeta`.

`Tests/` contains Lua 5.1 regression tests. With the libraries available in `libs/`, run each test in a separate Lua process. `.luacheckrc` configures optional source linting with `luacheck Glassy`.

GitHub Actions checks branch pushes and pull requests by checking generated release notes, building a package without uploading, validating its contents, compiling the Lua files, and running the regression tests. Tests and development files are excluded from the addon ZIP.

## Releasing

1. Write the complete release notes in `LATEST.md`. This is the source of truth for the current release; do not edit its generated copies separately.
2. Run `python Tests/prepare-release.py VERSION --date YYYY-MM-DD`, replacing the placeholders with the release version and date. Omitting `--date` uses today's date. The command updates all root TOC versions, the changelog, and the in-game news while preserving older releases.
3. Run `python Tests/prepare-release.py --check` and `python Tests/test-prepare-release.py`. Commit and push; wait for the checks to pass.
4. Create an annotated tag with `git tag -a vVERSION -m "Glassy VERSION"`, then push it with `git push origin vVERSION`, using the same version as step 2.

For development notes, use `--date unreleased`, then rerun with the release date before tagging. CI rejects stale generated notes and mismatched versions or dates; release tags also reject undated notes. The command does not commit, tag, publish, or copy files into game clients. Desktop previews and store descriptions remain manual editorial tasks.

The tag workflow publishes one multi-client ZIP to [CurseForge](https://www.curseforge.com/wow/addons/glassy) and [Wago Addons](https://addons.wago.io/addons/glassy), then attaches it to GitHub Releases. It uses the repository's `CF_API_KEY` and `WAGO_API_TOKEN` secrets plus GitHub's automatic token. No separate packaging webhook is needed; enabling one could upload duplicate releases. Branch pushes and manual check runs do not publish.
