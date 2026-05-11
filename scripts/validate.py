#!/usr/bin/env python3
"""Portable SKILL.md lint.

Walks `skills/` at two levels deep (`skills/<category>/<name>/SKILL.md`) and
validates every SKILL.md against the portability profile from
docs/skills-spec-v3.md §6.

Also cross-checks the multi-plugin layout under `plugins/*/.claude-plugin/
plugin.json` against the filesystem: every on-disk skill must be referenced
by exactly one plugin manifest, every listed skill path (resolved through
the per-plugin `skills/` symlinks) must lead to a SKILL.md on disk, and the
top-level `.claude-plugin/marketplace.json` must list each plugin directory.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
PLUGINS_DIR = REPO_ROOT / "plugins"
MARKETPLACE_JSON = REPO_ROOT / ".claude-plugin" / "marketplace.json"
UPSTREAM_MANIFEST = REPO_ROOT / "upstream" / "sources.yaml"

CORE_PLUGIN_NAME = "jylhis-skills-core"
CORE_PLUGIN_SKILLS = {"security", "ast-grep", "offline-docs"}

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
DESC_MIN = 50
DESC_MAX = 1024

ALLOWED_FRONTMATTER_KEYS = {"name", "description", "license", "compatibility", "metadata"}

REJECTED_FRONTMATTER_KEYS = {
    "allowed-tools", "disable-model-invocation", "user-invocable",
    "argument-hint", "arguments", "paths", "hooks", "context", "agent",
    "model", "effort", "tools", "disallowedTools", "mcpServers",
    "permissionMode", "isolation", "shell",
}

REJECTED_BODY_PATTERNS = [
    re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}"),
    re.compile(r"\$\{CLAUDE_SKILL_DIR\}"),
    re.compile(r"\$\{extensionPath\}"),
    re.compile(r"\$\{workspacePath\}"),
    re.compile(r"!`[^`]*`"),
    re.compile(r"!\{[^}]*\}"),
]

BLOCK_SCALAR_INDICATORS = ("|", ">", "")


# ── Frontmatter parsing ────────────────────────────────────────────────


def _split_frontmatter(text: str) -> tuple[str, str] | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    return text[4:end], text[end + 5:]


def _is_skippable(line: str) -> bool:
    return not line.strip() or line.lstrip().startswith("#")


def _is_top_level_key(line: str) -> bool:
    return bool(line) and line[0] not in (" ", "\t") and ":" in line


def _flush_block(fm: dict, key: str | None, block: list[str]) -> None:
    if key is not None and block:
        fm[key] = "\n".join(block).strip()


def _handle_top_level(line: str, fm: dict) -> str | None:
    key, _, val = line.partition(":")
    key, val = key.strip(), val.strip()
    if val in BLOCK_SCALAR_INDICATORS:
        if val == "":
            fm[key] = ""
        return key
    fm[key] = val.strip("\"'")
    return None


def _parse_yaml_lines(fm_text: str) -> dict:
    fm: dict = {}
    current_key: str | None = None
    block: list[str] = []

    for line in fm_text.splitlines():
        if _is_skippable(line):
            continue
        if _is_top_level_key(line):
            _flush_block(fm, current_key, block)
            block = []
            current_key = _handle_top_level(line, fm)
        elif current_key is not None:
            block.append(line.lstrip())

    _flush_block(fm, current_key, block)
    return fm


def parse_frontmatter(text: str) -> tuple[dict, str] | None:
    split = _split_frontmatter(text)
    if split is None:
        return None
    fm_text, body = split
    return _parse_yaml_lines(fm_text), body


def _quoted_scalar_end(value: str, quote: str) -> int | None:
    """Return the closing quote offset for a simple YAML quoted scalar."""
    i = 1
    while i < len(value):
        ch = value[i]
        if quote == '"' and ch == "\\":
            i += 2
            continue
        if ch == quote:
            if quote == "'" and i + 1 < len(value) and value[i + 1] == "'":
                i += 2
                continue
            return i
        i += 1
    return None


def _check_frontmatter_syntax(rel: Path, fm_text: str) -> list[str]:
    """Catch YAML syntax this repo's lightweight parser would otherwise mask."""
    errors: list[str] = []

    for lineno, line in enumerate(fm_text.splitlines(), start=2):
        if not _is_top_level_key(line):
            continue

        key, _, val = line.partition(":")
        val = val.strip()
        if not val or val in BLOCK_SCALAR_INDICATORS:
            continue
        if val[0] not in ("'", '"'):
            continue

        end = _quoted_scalar_end(val, val[0])
        if end is None:
            errors.append(f"{rel}:{lineno}: unterminated quoted frontmatter value for `{key}`")
            continue

        trailing = val[end + 1:].strip()
        if trailing and not trailing.startswith("#"):
            errors.append(
                f"{rel}:{lineno}: invalid trailing content after quoted "
                f"frontmatter value for `{key}`"
            )

    return errors


# ── Per-skill checks ───────────────────────────────────────────────────


def _check_encoding(rel: Path, raw: bytes) -> tuple[list[str], str | None]:
    errors: list[str] = []
    if raw.startswith(b"\xef\xbb\xbf"):
        errors.append(f"{rel}: BOM detected; files must be UTF-8 without BOM")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        errors.append(f"{rel}: not valid UTF-8: {exc}")
        return errors, None
    if "\r\n" in text:
        errors.append(f"{rel}: CRLF line endings; use LF")
    return errors, text


def _check_name(rel: Path, name: str, expected: str) -> list[str]:
    if not name:
        return [f"{rel}: missing `name`"]
    if name != expected:
        return [f"{rel}: name `{name}` does not match dir basename `{expected}`"]
    if not NAME_RE.match(name):
        return [f"{rel}: name `{name}` must be lowercase letters/numbers/hyphens, no leading/trailing/consecutive hyphens"]
    return []


def _check_description(rel: Path, desc: str) -> list[str]:
    if not desc:
        return [f"{rel}: missing `description`"]
    n = len(desc)
    if n < DESC_MIN or n > DESC_MAX:
        return [f"{rel}: description length {n} out of range [{DESC_MIN}, {DESC_MAX}]"]
    return []


def _check_frontmatter_keys(rel: Path, keys: set[str]) -> list[str]:
    errors: list[str] = []
    rejected = keys & REJECTED_FRONTMATTER_KEYS
    if rejected:
        errors.append(f"{rel}: rejected target-specific frontmatter keys: {sorted(rejected)}")
    unknown = keys - ALLOWED_FRONTMATTER_KEYS - REJECTED_FRONTMATTER_KEYS
    if unknown:
        errors.append(f"{rel}: unknown frontmatter keys: {sorted(unknown)} (allowed: {sorted(ALLOWED_FRONTMATTER_KEYS)})")
    return errors


def _check_body(rel: Path, body: str) -> list[str]:
    errors: list[str] = []
    for pat in REJECTED_BODY_PATTERNS:
        m = pat.search(body)
        if m:
            errors.append(f"{rel}: rejected target-specific syntax in body: {m.group(0)!r}")
    return errors


def validate_skill(skill_md: Path) -> list[str]:
    rel = skill_md.relative_to(REPO_ROOT)
    encoding_errors, text = _check_encoding(rel, skill_md.read_bytes())
    if text is None:
        return encoding_errors

    split = _split_frontmatter(text)
    if split is None:
        return encoding_errors + [f"{rel}: missing or malformed YAML frontmatter (must start with `---`)"]
    fm_text, body = split
    fm = _parse_yaml_lines(fm_text)

    return [
        *encoding_errors,
        *_check_frontmatter_syntax(rel, fm_text),
        *_check_name(rel, fm.get("name", ""), skill_md.parent.name),
        *_check_description(rel, fm.get("description", "")),
        *_check_frontmatter_keys(rel, set(fm.keys())),
        *_check_body(rel, body),
    ]


# ── plugin manifests cross-check ───────────────────────────────────────


def _load_json(path: Path) -> tuple[dict | None, str | None]:
    try:
        return json.loads(path.read_text()), None
    except json.JSONDecodeError as exc:
        return None, f"{path.relative_to(REPO_ROOT)}: invalid JSON: {exc}"
    except OSError as exc:
        return None, f"{path.relative_to(REPO_ROOT)}: cannot read: {exc}"


def _resolve_skill_path(plugin_manifest: Path, raw: str) -> Path:
    """Resolve a plugin.json skills[] entry to its on-disk skill directory.

    Per-plugin manifests live at `plugins/<name>/.claude-plugin/plugin.json`
    and reference `./skills/<x>` paths. The `skills/` directory is a per-plugin
    dir of symlinks pointing into the canonical `skills/<category>/<name>/`
    tree. `Path.resolve()` follows the symlink so each entry lands at the real
    skill directory.
    """
    plugin_root = plugin_manifest.parent.parent  # plugins/<name>/
    return (plugin_root / raw.lstrip("./")).resolve()


def check_plugin_manifests(skill_files: list[Path]) -> list[str]:
    """Verify per-plugin manifests cover every on-disk skill exactly once."""
    if not PLUGINS_DIR.is_dir():
        return [f"plugins/: directory not found"]

    plugin_manifests = sorted(PLUGINS_DIR.glob("*/.claude-plugin/plugin.json"))
    if not plugin_manifests:
        return ["plugins/: no plugin manifests found under plugins/*/.claude-plugin/plugin.json"]

    fs_skill_dirs = {skill_md.parent.resolve() for skill_md in skill_files}
    coverage: dict[Path, list[str]] = {}
    errors: list[str] = []
    core_seen: set[str] = set()

    for manifest_path in plugin_manifests:
        plugin_name = manifest_path.parent.parent.name
        rel = manifest_path.relative_to(REPO_ROOT)

        manifest, err = _load_json(manifest_path)
        if err or manifest is None:
            if err:
                errors.append(err)
            continue

        if manifest.get("name") != plugin_name:
            errors.append(
                f"{rel}: name {manifest.get('name')!r} does not match plugin dir {plugin_name!r}"
            )

        for raw in manifest.get("skills", []):
            target = _resolve_skill_path(manifest_path, raw)
            if target not in fs_skill_dirs:
                errors.append(
                    f"{rel}: listed skill {raw!r} resolves to {target} which has no SKILL.md"
                )
                continue
            coverage.setdefault(target, []).append(plugin_name)
            if plugin_name == CORE_PLUGIN_NAME:
                # Each entry is "./skills/<basename>"; collect basenames for the
                # CORE_PLUGIN_SKILLS contract check.
                core_seen.add(Path(raw).name)

    # Every on-disk skill must be referenced by exactly one plugin manifest.
    for skill_md in skill_files:
        skill_dir = skill_md.parent.resolve()
        owners = coverage.get(skill_dir, [])
        rel = skill_md.parent.relative_to(REPO_ROOT)
        if not owners:
            errors.append(f"{rel}: not referenced by any plugin manifest under plugins/")
        elif len(owners) > 1:
            errors.append(
                f"{rel}: referenced by multiple plugins {sorted(owners)} — must belong to one"
            )

    # The default plugin must cover exactly the cross-cutting set.
    if core_seen and core_seen != CORE_PLUGIN_SKILLS:
        errors.append(
            f"plugins/{CORE_PLUGIN_NAME}/.claude-plugin/plugin.json: core skills "
            f"{sorted(core_seen)} do not match expected {sorted(CORE_PLUGIN_SKILLS)}"
        )

    errors.extend(_check_marketplace_manifest(plugin_manifests))
    return errors


def _check_marketplace_manifest(plugin_manifests: list[Path]) -> list[str]:
    if not MARKETPLACE_JSON.exists():
        return [f"{MARKETPLACE_JSON.relative_to(REPO_ROOT)}: file not found"]

    manifest, err = _load_json(MARKETPLACE_JSON)
    if err or manifest is None:
        return [err] if err else []

    rel = MARKETPLACE_JSON.relative_to(REPO_ROOT)
    listed_sources: set[Path] = set()
    errors: list[str] = []

    for entry in manifest.get("plugins", []):
        src = entry.get("source")
        # marketplace.json supports either a relative-path string or a source object.
        if isinstance(src, str):
            target = (REPO_ROOT / src.lstrip("./")).resolve()
        elif isinstance(src, dict) and src.get("source") == "local":
            target = (REPO_ROOT / src.get("path", "").lstrip("./")).resolve()
        else:
            continue  # external sources (github/url/npm) — out of scope
        listed_sources.add(target)
        if not (target / ".claude-plugin" / "plugin.json").exists():
            errors.append(
                f"{rel}: plugin {entry.get('name')!r} source {src!r} "
                f"has no .claude-plugin/plugin.json"
            )

    on_disk = {m.parent.parent.resolve() for m in plugin_manifests}
    for path in sorted(on_disk - listed_sources):
        errors.append(
            f"{rel}: plugin dir {path.relative_to(REPO_ROOT)} not listed in marketplace.json"
        )

    return errors


# ── Optional: upstream-tracker advisory pass ───────────────────────────


def _start_new_source(body: str) -> str | None:
    inner = body[2:].lstrip()
    if not inner.startswith("id:"):
        return None
    return inner.split(":", 1)[1].strip().strip('"\'')


def _parse_field(body: str) -> tuple[str, str]:
    k, _, v = body.partition(":")
    return k.strip(), v.strip().strip('"\'')


def _is_skippable_line(stripped: str, line: str) -> bool:
    return not stripped or stripped.startswith("#") or line == "sources:"


def _read_manifest_ids() -> tuple[set[str], dict[str, str]]:
    """Return ({source-ids}, {id: reviewed-rev}) from upstream/sources.yaml.

    Restricted parser identical in shape to skills/meta/upstream-tracker/
    scripts/_lib.py — keeps validate.py dependency-free.
    """
    ids: set[str] = set()
    reviewed: dict[str, str] = {}
    state = {"current_id": None, "in_skills": False}

    for raw in UPSTREAM_MANIFEST.read_text().splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if _is_skippable_line(stripped, line):
            continue
        ind = len(line) - len(line.lstrip(" "))
        _feed_manifest_line(ind, stripped, state, ids, reviewed)
    return ids, reviewed


def _feed_manifest_line(ind: int, stripped: str, state: dict,
                        ids: set[str], reviewed: dict[str, str]) -> None:
    if ind == 2 and stripped.startswith("- "):
        new_id = _start_new_source(stripped)
        state["current_id"] = new_id
        state["in_skills"] = False
        if new_id:
            ids.add(new_id)
        return
    if state["current_id"] is None:
        return
    if ind == 4 and stripped == "skills:":
        state["in_skills"] = True
        return
    if state["in_skills"]:
        return
    if ind == 4 and ":" in stripped:
        key, value = _parse_field(stripped)
        if key == "reviewed-rev":
            reviewed[state["current_id"]] = value


def _extract_metadata(fm: dict) -> dict:
    raw = fm.get("metadata")
    if isinstance(raw, dict):
        return raw
    if not isinstance(raw, str) or not raw.strip():
        return {}
    out: dict[str, str] = {}
    for line in raw.splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            out[k.strip()] = v.strip().strip('"\'')
    return out


def _check_upstream_advisory(skill_files: list[Path], strict: bool) -> tuple[int, int]:
    """Returns (warnings, hard_errors).

    Advisory by default: emits to stderr and never raises the exit code.
    Strict mode promotes warnings to hard errors.
    """
    if not UPSTREAM_MANIFEST.exists():
        return 0, 0
    try:
        ids, reviewed = _read_manifest_ids()
    except (OSError, ValueError) as exc:
        print(f"validate.py: cannot parse {UPSTREAM_MANIFEST.relative_to(REPO_ROOT)}: {exc}",
              file=sys.stderr)
        return 0, (1 if strict else 0)

    warnings = sum(
        _check_one_upstream(skill_md, ids, reviewed) for skill_md in skill_files
    )
    return warnings, (warnings if strict else 0)


def _check_one_upstream(skill_md: Path, ids: set[str], reviewed: dict[str, str]) -> int:
    parsed = parse_frontmatter(skill_md.read_text(errors="replace"))
    if parsed is None:
        return 0
    fm, _ = parsed
    meta = _extract_metadata(fm)
    upstream_id = meta.get("upstream-id")
    if not upstream_id:
        return 0
    rel = skill_md.relative_to(REPO_ROOT)
    if upstream_id not in ids:
        print(f"{rel}: upstream-id {upstream_id!r} not in upstream/sources.yaml",
              file=sys.stderr)
        return 1
    skill_rev = meta.get("upstream-rev", "")
    cursor = reviewed.get(upstream_id, "")
    if cursor and skill_rev and not cursor.startswith(skill_rev) and not skill_rev.startswith(cursor):
        print(f"{rel}: baseline upstream-rev {skill_rev[:12]!r} differs from "
              f"manifest reviewed-rev {cursor[:12]!r} — backport may be due",
              file=sys.stderr)
        return 1
    return 0


# ── Optional: scripts language advisory pass ───────────────────────────


SCRIPT_GLOBS = (
    "scripts/*",
    "evals/scripts/*",
    "skills/*/*/scripts/*",
    "dev-skills/*/scripts/*",
    "plugins/*/scripts/*",
)

SH_WRAPPER_PREFIXES = ("nix ", "exec ", "nix run", "nix shell")
SH_WRAPPER_MAX_BYTES = 200
PY_TYPED_LINES = 50
PY_RETURN_ANNOTATION_RE = re.compile(r"def\s+\w+\s*\([^)]*\)\s*->\s")


def _is_sh_wrapper(path: Path) -> bool:
    """Small `nix run` / `exec` shell wrappers are exempt from the bash advisory."""
    try:
        if path.stat().st_size >= SH_WRAPPER_MAX_BYTES:
            return False
        text = path.read_text(errors="replace")
    except OSError:
        return False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        return any(stripped.startswith(pfx) for pfx in SH_WRAPPER_PREFIXES)
    return False


def _is_typed_python(path: Path) -> bool:
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return False
    if "# type: validated" in text:
        return True
    head = text.splitlines()[:PY_TYPED_LINES]
    has_future = any("from __future__ import annotations" in line for line in head)
    has_return_ann = any(PY_RETURN_ANNOTATION_RE.search(line) for line in head)
    return has_future and has_return_ann


def _classify_script(path: Path) -> str | None:
    """Return a warning category for unpreferred scripts, else None."""
    suffix = path.suffix
    if suffix in (".go", ".ts"):
        return None
    if suffix == ".sh":
        return None if _is_sh_wrapper(path) else "bash"
    if suffix == ".py":
        return None if _is_typed_python(path) else "untyped-py"
    return None


def _iter_script_paths() -> list[Path]:
    seen: set[Path] = set()
    out: list[Path] = []
    for pattern in SCRIPT_GLOBS:
        for path in sorted(REPO_ROOT.glob(pattern)):
            if not path.is_file():
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            out.append(path)
    return out


def _check_scripts_advisory(strict: bool) -> tuple[int, int]:
    """Returns (warnings, hard_errors).

    Advisory by default: emits to stderr and never raises the exit code.
    Strict mode promotes warnings to hard errors.
    """
    bash_count = 0
    untyped_py_count = 0
    for path in _iter_script_paths():
        category = _classify_script(path)
        if category is None:
            continue
        rel = path.relative_to(REPO_ROOT)
        if category == "bash":
            bash_count += 1
            print(f"{rel}: bash script; prefer Go > TS+Bun (see docs/script-migrations.md)",
                  file=sys.stderr)
        else:
            untyped_py_count += 1
            print(f"{rel}: untyped-python script; prefer Go > TS+Bun (see docs/script-migrations.md)",
                  file=sys.stderr)

    warnings = bash_count + untyped_py_count
    if warnings:
        print(f"validate.py: scripts: {bash_count} bash, {untyped_py_count} untyped-py (advisory)",
              file=sys.stderr)
    return warnings, (warnings if strict else 0)


# ── Entry point ────────────────────────────────────────────────────────


def main() -> int:
    strict_upstream = "--strict-upstream" in sys.argv[1:]
    strict_scripts = "--strict-scripts" in sys.argv[1:]

    if not SKILLS_DIR.is_dir():
        print(f"validate.py: skills/ not found at {SKILLS_DIR}", file=sys.stderr)
        return 1

    # Two-level glob: skills/<category>/<name>/SKILL.md
    skill_files = sorted(SKILLS_DIR.glob("*/*/SKILL.md"))
    if not skill_files:
        print("validate.py: no skills to validate (skills/ is empty)")
        return 0

    all_errors: list[str] = []
    for skill_md in skill_files:
        all_errors.extend(validate_skill(skill_md))

    all_errors.extend(check_plugin_manifests(skill_files))

    upstream_warnings, upstream_hard = _check_upstream_advisory(skill_files, strict_upstream)
    scripts_warnings, scripts_hard = _check_scripts_advisory(strict_scripts)

    if all_errors:
        for err in all_errors:
            print(err, file=sys.stderr)
        print(f"\nvalidate.py: {len(all_errors)} error(s) across {len(skill_files)} skill(s)", file=sys.stderr)
        return 1

    if upstream_hard:
        print(f"\nvalidate.py: {upstream_hard} upstream advisory error(s) (strict mode)",
              file=sys.stderr)
        return 1

    if scripts_hard:
        print(f"\nvalidate.py: {scripts_hard} scripts advisory error(s) (strict mode)",
              file=sys.stderr)
        return 1

    suffix = ""
    if upstream_warnings:
        suffix += f"; {upstream_warnings} upstream advisory warning(s)"
    if scripts_warnings:
        suffix += f"; {scripts_warnings} scripts advisory warning(s)"
    print(f"validate.py: OK ({len(skill_files)} skill(s)){suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
