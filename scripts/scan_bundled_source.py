#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Deterministic security scanner for imported bundled sources.

Adapted from trailofbits/skills-curated `scripts/scan_plugin.py`
<https://github.com/trailofbits/skills-curated/blob/main/scripts/scan_plugin.py>

Scans plugin / skill / agent / command source trees for:
  1. Unicode tricks (bidi overrides, zero-width chars, homoglyphs)
  2. Network access (URLs, curl/wget, Python/Node imports)
  3. Dangerous command chains (safe-chains-inspired shell risk checks)
  4. Code execution (pipe-to-shell, eval/exec, subprocess)
  5. Credential access and hardcoded secrets
  6. Encoded payloads (hex escapes, fromCharCode, atob/btoa)
  7. Agent-skill risks (prompt injection, runtime URLs, persistence)
  8. Compiled bytecode (.pyc, .pyo, __pycache__)

Exit codes: 0 = clean, 1 = usage error, 2 = BLOCK findings,
3 = WARN only.

Typical use: point at a flake-input source path before bumping it
in flake.lock. Example:

    ./scripts/scan_bundled_source.py \\
        $(nix eval --impure --raw --expr \\
            '(import ./_sources.nix).trailofbits-skills-curated')
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import sys
import unicodedata
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal

# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Finding:
    level: Literal["BLOCK", "WARN"]
    category: str
    path: str
    line: int  # 1-indexed, or 0 for whole-file findings.
    detail: str
    reference: str | None = None


@dataclass(frozen=True, slots=True)
class MarkdownContexts:
    code_lines: frozenset[int]
    shell_lines: frozenset[int]


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CODE_EXTENSIONS = frozenset(
    {".py", ".sh", ".bash", ".zsh", ".js", ".ts", ".swift", ".ps1", ".json", ".yml", ".yaml"}
)

SHELL_EXTENSIONS = frozenset({".sh", ".bash", ".zsh"})

SKIP_FILENAMES = frozenset({"LICENSE", "LICENSE.md", "LICENSE.txt"})
SKIP_DIR_NAMES = frozenset({".git", ".hg", ".svn", "node_modules", "vendor"})

# Bidi override codepoints (U+202A-202E, U+2066-2069)
BIDI_CODEPOINTS = frozenset(range(0x202A, 0x202F)) | frozenset(range(0x2066, 0x206A))

# Zero-width characters
ZERO_WIDTH_CODEPOINTS = frozenset({0x200B, 0x200C, 0x200D, 0xFEFF, 0x00AD})

# Network commands in scripts / code blocks
NETWORK_CMD_RE = re.compile(
    r"\b(?:curl|wget|nc|ncat|socat|ssh|scp|rsync)\b"
    r"|openssl\s+s_client"
)

# Python network imports
PY_NETWORK_RE = re.compile(
    r"^\s*(?:import|from)\s+"
    r"(?:requests|httpx|urllib|aiohttp|http\.client|socket|websocket)\b"
)

# Node / JS network patterns
NODE_NETWORK_RE = re.compile(
    r"\bfetch\s*\("
    r"|(?:require|import)\s*\(?['\"](?:axios|node-fetch|http|https)['\"]"
    r"|\b(?:http|https)\.get\s*\("
)

# URL pattern - matches http:// and https:// until whitespace or common
# markdown delimiters.
URL_RE = re.compile(r"https?://[^\s<>\]\"']+")

# GitHub repo URL used as attribution in markdown prose (not fetched)
GITHUB_ATTR_RE = re.compile(r"^https?://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/?$")

# Punycode domain
PUNYCODE_RE = re.compile(r"https?://[^\s/]*xn--")

URL_SHORTENER_RE = re.compile(
    r"https?://(?:bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|ow\.ly|cutt\.ly|"
    r"buff\.ly|rebrand\.ly|shorturl\.at|rb\.gy)/",
    re.IGNORECASE,
)

PASTE_OR_FILE_HOST_RE = re.compile(
    r"https?://(?:pastebin\.com|gist\.githubusercontent\.com|hastebin\.com|"
    r"rentry\.co|transfer\.sh|file\.io|cdn\.discordapp\.com)/",
    re.IGNORECASE,
)

RAW_GITHUB_RE = re.compile(r"https?://raw\.githubusercontent\.com/[^/\s]+/[^/\s]+/[^/\s]+/")

DOWNLOAD_ARTIFACT_RE = re.compile(
    r"https?://\S+\.(?:sh|bash|zsh|ps1|exe|dll|dylib|so|bin|zip|tar|tgz|"
    r"tar\.gz|pkg|dmg|appimage|deb|rpm)(?:[?#]\S*)?$",
    re.IGNORECASE,
)

# Shell/code execution - no legitimate skill import should download and pipe.
PIPE_TO_SHELL_RE = re.compile(
    r"\|\s*(?:bash|sh|zsh|dash|python[23]?|perl|ruby|node)\b"
    r"|\b(?:bash|sh|zsh)\s+-c\s"
    r"|\bsource\s+<\("
    r'|\beval\s+"\$\('
)

DOWNLOAD_AND_EXECUTE_RE = re.compile(
    r"\b(?:curl|wget)\b.*\|\s*(?:bash|sh|zsh|dash|python[23]?|perl|ruby|node)\b",
    re.IGNORECASE,
)

# Eval/exec - legitimate in educational docs, but worth review.
EVAL_EXEC_RE = re.compile(
    r"\beval\s*\("
    r"|\bexec\s*\("
    r"|\bFunction\s*\("
    r"|\b__import__\s*\("
    r"|\bimportlib\.import_module\s*\("
    r'|\bcompile\s*\([^)]*[\'"]exec[\'"]'
)

# Python shell-out - legitimate in helper scripts.
PY_SHELLOUT_RE = re.compile(
    r"\bsubprocess\b"
    r"|\bos\.system\s*\("
    r"|\bos\.popen\s*\("
    r"|\bos\.exec[lv]p?\s*\("
)

# Sensitive credential paths
SENSITIVE_PATH_RE = re.compile(
    r"~/\.ssh\b"
    r"|~/\.aws\b"
    r"|~/\.gnupg\b"
    r"|~/\.config/gh\b"
    r"|~/\.netrc\b"
    r"|/etc/shadow\b"
    r"|\bid_rsa\b"
    r"|\bid_ed25519\b"
)

HARDCODED_SECRET_RES = (
    re.compile(r"-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{36,}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9]{32,}\b"),
    re.compile(
        r"(?i)\b(?:api[_-]?key|access[_-]?token|secret|password)\b"
        r"\s*[:=]\s*['\"][^'\"\s]{16,}['\"]"
    ),
)

INSECURE_CREDENTIAL_HANDLING_RE = re.compile(
    r"(?i)\b(?:print|echo|paste|include|commit|write|return|send)\b.{0,80}"
    r"\b(?:api[_ -]?key|token|secret|password|private key|credential)s?\b"
    r"|\b(?:api[_ -]?key|token|secret|password|private key|credential)s?\b.{0,80}"
    r"\b(?:print|echo|paste|include|commit|write|return|send)\b"
)

# Encoded / obfuscated payloads
ENCODED_PAYLOAD_RE = re.compile(
    r"(?:\\x[0-9a-fA-F]{2}){8,}"
    r"|\bString\.fromCharCode\s*\("
    r"|\bchr\s*\(\s*0x[0-9a-fA-F]"
    r"|\batob\s*\("
    r"|\bbtoa\s*\("
)

PROMPT_INJECTION_RE = re.compile(
    r"(?i)\b(?:ignore|disregard|override|bypass)\b.{0,80}\b"
    r"(?:previous|prior|above|system|developer|safety|security)\b"
    r"|\b(?:system|developer)\s+message\b"
    r"|\breveal\b.{0,80}\b(?:system prompt|hidden instructions|developer message)\b"
    r"|\bexfiltrat(?:e|ion)\b"
)

UNTRUSTED_CONTENT_RE = re.compile(
    r"(?i)\b(?:arbitrary|any|unknown|untrusted|public|user-provided)\b.{0,80}"
    r"\b(?:url|website|web page|webpage|forum|reddit|social media|comments?)\b"
    r"|\b(?:browse|fetch|read|scrape|download|analy[sz]e)\b.{0,80}"
    r"\b(?:any|arbitrary|unknown|untrusted|public|user-provided)\b.{0,40}"
    r"\b(?:url|website|web page|webpage|forum|reddit|social media|comments?)\b"
)

SYSTEM_MODIFICATION_RE = re.compile(
    r"\bsystemctl\s+enable\b"
    r"|\blaunchctl\s+(?:load|bootstrap|enable)\b"
    r"|\bcrontab\b"
    r"|\bcron\.d\b"
    r"|\bLogin Items\b"
    r"|(?:~|\$HOME)/(?:\.bashrc|\.zshrc|\.profile|\.config/autostart)\b"
    r"|\bchmod\s+[ugo]*s\b"
    r"|\bchown\s+root\b"
)

# Compiled bytecode extensions
BYTECODE_EXTENSIONS = frozenset({".pyc", ".pyo"})

# Fenced code block detection in markdown
FENCE_OPEN_RE = re.compile(r"^(`{3,}|~{3,})([A-Za-z0-9_+.-]*)")
SHELL_FENCE_LANGS = frozenset({"bash", "sh", "shell", "zsh", "console", "terminal"})

INERT_COMMANDS = frozenset(
    {
        "awk",
        "bat",
        "cat",
        "cd",
        "cut",
        "diff",
        "direnv",
        "du",
        "echo",
        "env",
        "fd",
        "find",
        "git",
        "grep",
        "head",
        "jq",
        "less",
        "ls",
        "man",
        "nix",
        "pwd",
        "rg",
        "sed",
        "sort",
        "stat",
        "tail",
        "tree",
        "wc",
        "yq",
    }
)

GIT_INERT_SUBCOMMANDS = frozenset(
    {"blame", "branch", "diff", "grep", "log", "ls-files", "remote", "show", "status"}
)

SAFE_COMMAND_SEPARATORS_RE = re.compile(r"\s*(?:&&|\|\||[;|])\s*")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _read_file_text(path: Path) -> str | None:
    """Read a file as UTF-8 text, returning None for binary or unreadable files.

    Detects binary files by checking for null bytes in the first 8 KB.
    """
    try:
        chunk = path.read_bytes()[:8192]
    except OSError:
        print(f"Warning: Cannot read {path}", file=sys.stderr)
        return None
    if b"\x00" in chunk:
        return None
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        print(f"Warning: Cannot read {path}", file=sys.stderr)
        return None


def markdown_contexts(lines: list[str]) -> MarkdownContexts:
    """Return line indices inside fenced code blocks and shell fences."""
    code_lines: set[int] = set()
    shell_lines: set[int] = set()
    fence_start: int | None = None
    fence_char: str = ""
    fence_len: int = 0
    fence_is_shell = False

    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if fence_start is None:
            match = FENCE_OPEN_RE.match(stripped)
            if match:
                fence_start = i
                fence_char = match.group(1)[0]
                fence_len = len(match.group(1))
                fence_is_shell = match.group(2).lower() in SHELL_FENCE_LANGS
            continue

        close = stripped.rstrip()
        if close and all(c == fence_char for c in close) and len(close) >= fence_len:
            for j in range(fence_start, i + 1):
                code_lines.add(j)
                if fence_is_shell:
                    shell_lines.add(j)
            fence_start = None
            fence_char = ""
            fence_len = 0
            fence_is_shell = False

    return MarkdownContexts(frozenset(code_lines), frozenset(shell_lines))


def markdown_code_ranges(lines: list[str]) -> frozenset[int]:
    """Return the set of line indices that fall inside fenced code blocks."""
    return markdown_contexts(lines).code_lines


def _is_code_context(
    line_idx: int,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> bool:
    """Determine whether a line is in a code context."""
    if suffix in CODE_EXTENSIONS:
        return True
    if suffix == ".md" and code_lines is not None:
        return line_idx in code_lines
    return False


def _is_shell_context(
    line_idx: int,
    suffix: str,
    shell_lines: frozenset[int] | None,
) -> bool:
    """Determine whether a line is likely to contain shell commands."""
    if suffix in SHELL_EXTENSIONS:
        return True
    if suffix == ".md" and shell_lines is not None:
        return line_idx in shell_lines
    return False


def _detail(line: str) -> str:
    return line.strip()[:120]


def _clean_url(url: str) -> str:
    return url.rstrip(").,;")


def _split_shell_segments(line: str) -> list[str]:
    """Split a simple shell command chain into leaf command segments.

    This is deliberately conservative and local. It is inspired by
    safe-chains' segment-by-segment model, but does not try to be a complete
    shell parser.
    """
    return [segment.strip() for segment in SAFE_COMMAND_SEPARATORS_RE.split(line) if segment.strip()]


def _shell_words(segment: str) -> list[str]:
    try:
        return shlex.split(segment, comments=True, posix=True)
    except ValueError:
        return []


def _has_flag(words: list[str], short: str, long: str | None = None) -> bool:
    for word in words:
        if long is not None and word == long:
            return True
        if word.startswith("-") and not word.startswith("--") and short in word[1:]:
            return True
    return False


def _command_is_inert(words: list[str]) -> bool:
    if not words:
        return True

    command = Path(words[0]).name
    if command not in INERT_COMMANDS:
        return False

    if command == "git":
        if len(words) == 1:
            return True
        return words[1] in GIT_INERT_SUBCOMMANDS

    if command == "sed":
        return "-i" not in words and "--in-place" not in words

    if command == "find":
        return "-delete" not in words and "-exec" not in words

    if command == "nix":
        return len(words) > 1 and words[1] in {"eval", "flake", "path-info", "show-config"}

    return True


def _rel_path(path: Path, root: Path) -> str:
    if path == root:
        return path.name
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


# ---------------------------------------------------------------------------
# Check functions
# ---------------------------------------------------------------------------


def check_unicode(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check a line for dangerous unicode characters."""
    findings: list[Finding] = []
    lineno = line_idx + 1

    for ch in line:
        cp = ord(ch)

        if cp in BIDI_CODEPOINTS:
            findings.append(
                Finding(
                    "BLOCK",
                    "bidi-override",
                    rel_path,
                    lineno,
                    f"U+{cp:04X} ({unicodedata.name(ch, 'UNKNOWN')})",
                )
            )
        elif cp in ZERO_WIDTH_CODEPOINTS:
            findings.append(
                Finding(
                    "BLOCK",
                    "zero-width-char",
                    rel_path,
                    lineno,
                    f"U+{cp:04X} ({unicodedata.name(ch, 'UNKNOWN')})",
                )
            )
        elif (
            cp > 0x7F
            and unicodedata.category(ch).startswith("L")
            and _is_code_context(line_idx, suffix, code_lines)
        ):
            findings.append(
                Finding(
                    "BLOCK",
                    "homoglyph",
                    rel_path,
                    lineno,
                    f"{unicodedata.name(ch, 'UNKNOWN')} (U+{cp:04X}) in code context",
                )
            )

    return findings


def check_network(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check a line for network access patterns."""
    findings: list[Finding] = []
    lineno = line_idx + 1
    is_code = _is_code_context(line_idx, suffix, code_lines)

    punycode_match = PUNYCODE_RE.search(line)
    if punycode_match:
        findings.append(
            Finding(
                "BLOCK",
                "punycode-url",
                rel_path,
                lineno,
                _clean_url(punycode_match.group(0)),
            )
        )

    for match in URL_RE.finditer(line):
        url = _clean_url(match.group(0))
        if GITHUB_ATTR_RE.match(url) and not is_code:
            continue
        if PUNYCODE_RE.match(url):
            continue
        findings.append(Finding("WARN", "external-url", rel_path, lineno, url))

    if is_code and NETWORK_CMD_RE.search(line):
        findings.append(Finding("WARN", "network-cmd", rel_path, lineno, _detail(line)))

    if PY_NETWORK_RE.search(line):
        findings.append(Finding("WARN", "network-import", rel_path, lineno, _detail(line)))

    if is_code and NODE_NETWORK_RE.search(line):
        findings.append(Finding("WARN", "network-import", rel_path, lineno, _detail(line)))

    return findings


def check_suspicious_downloads(
    line: str,
    line_idx: int,
    rel_path: str,
) -> list[Finding]:
    """Check for suspicious or unverifiable external dependencies."""
    findings: list[Finding] = []
    lineno = line_idx + 1

    if DOWNLOAD_AND_EXECUTE_RE.search(line):
        findings.append(
            Finding(
                "BLOCK",
                "download-and-execute",
                rel_path,
                lineno,
                _detail(line),
                "agent-scan:E006",
            )
        )

    for match in URL_RE.finditer(line):
        url = _clean_url(match.group(0))
        category: str | None = None
        reference = "agent-scan:E005"
        if URL_SHORTENER_RE.match(url):
            category = "suspicious-download-url"
        elif PASTE_OR_FILE_HOST_RE.match(url):
            category = "suspicious-download-url"
        elif RAW_GITHUB_RE.match(url):
            category = "unverifiable-runtime-url"
            reference = "agent-scan:W012"
        elif DOWNLOAD_ARTIFACT_RE.match(url):
            category = "unverifiable-runtime-url"

        if category is not None:
            findings.append(Finding("WARN", category, rel_path, lineno, url, reference))

    return findings


def check_shell_commands(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    shell_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check shell command chains for risky segments and flags."""
    if not _is_shell_context(line_idx, suffix, shell_lines):
        return []

    findings: list[Finding] = []
    lineno = line_idx + 1

    if PIPE_TO_SHELL_RE.search(line):
        findings.append(
            Finding(
                "BLOCK",
                "pipe-to-shell",
                rel_path,
                lineno,
                _detail(line),
                "safe-chains:command-risk",
            )
        )

    for segment in _split_shell_segments(line):
        words = _shell_words(segment)
        if not words or _command_is_inert(words):
            continue

        command = Path(words[0]).name
        category: str | None = None
        level: Literal["BLOCK", "WARN"] = "WARN"

        if command == "rm" and (_has_flag(words, "r", "--recursive") or "-rf" in words):
            category = "destructive-cmd"
        elif command == "git" and len(words) > 2:
            if words[1] == "reset" and "--hard" in words:
                category = "destructive-cmd"
            elif words[1] == "push" and ("--force" in words or "-f" in words):
                category = "destructive-cmd"
            elif words[1] == "clean" and _has_flag(words, "f"):
                category = "destructive-cmd"
            elif words[1] == "branch" and "-D" in words:
                category = "destructive-cmd"
        elif command == "find" and ("-delete" in words or "-exec" in words):
            category = "destructive-cmd"
        elif command == "sed" and ("-i" in words or "--in-place" in words):
            category = "destructive-cmd"
        elif command in {"shred", "unlink", "rmdir", "mkfs"}:
            category = "destructive-cmd"
        elif command in {"sudo", "doas"}:
            category = "privilege-cmd"
        elif command == "chmod" and any(word == "777" or "s" in word for word in words[1:]):
            category = "privilege-cmd"
        elif command in {"bash", "sh", "zsh", "dash"} and "-c" in words:
            category = "shell-exec"
            level = "BLOCK"

        if category is not None:
            findings.append(
                Finding(
                    level,
                    category,
                    rel_path,
                    lineno,
                    segment[:120],
                    "safe-chains:command-risk",
                )
            )

    return findings


def check_code_execution(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check a line for code execution patterns."""
    if not _is_code_context(line_idx, suffix, code_lines):
        return []

    findings: list[Finding] = []
    lineno = line_idx + 1

    if EVAL_EXEC_RE.search(line):
        findings.append(Finding("WARN", "eval-exec", rel_path, lineno, _detail(line)))

    if PY_SHELLOUT_RE.search(line):
        findings.append(Finding("WARN", "py-shellout", rel_path, lineno, _detail(line)))

    return findings


def check_credential_access(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check a line for access to sensitive credential paths."""
    if not _is_code_context(line_idx, suffix, code_lines):
        return []

    if SENSITIVE_PATH_RE.search(line):
        return [
            Finding(
                "BLOCK",
                "credential-access",
                rel_path,
                line_idx + 1,
                _detail(line),
                "agent-scan:W007",
            )
        ]
    return []


def check_hardcoded_secrets(line: str, line_idx: int, rel_path: str) -> list[Finding]:
    """Check for obvious hardcoded secret material."""
    for regex in HARDCODED_SECRET_RES:
        match = regex.search(line)
        if match:
            return [
                Finding(
                    "BLOCK",
                    "hardcoded-secret",
                    rel_path,
                    line_idx + 1,
                    match.group(0)[:120],
                    "agent-scan:W008",
                )
            ]
    return []


def check_insecure_credential_handling(
    line: str,
    line_idx: int,
    rel_path: str,
) -> list[Finding]:
    """Check for instructions that place secrets into output/history."""
    if INSECURE_CREDENTIAL_HANDLING_RE.search(line):
        return [
            Finding(
                "WARN",
                "insecure-credential-handling",
                rel_path,
                line_idx + 1,
                _detail(line),
                "agent-scan:W007",
            )
        ]
    return []


def check_obfuscation(
    line: str,
    line_idx: int,
    rel_path: str,
    suffix: str,
    code_lines: frozenset[int] | None,
) -> list[Finding]:
    """Check a line for encoded or obfuscated payloads."""
    if not _is_code_context(line_idx, suffix, code_lines):
        return []

    if ENCODED_PAYLOAD_RE.search(line):
        return [
            Finding(
                "WARN",
                "encoded-payload",
                rel_path,
                line_idx + 1,
                _detail(line),
                "agent-scan:E006",
            )
        ]
    return []


def check_agent_skill_risks(line: str, line_idx: int, rel_path: str) -> list[Finding]:
    """Check natural-language agent skill risks."""
    findings: list[Finding] = []
    lineno = line_idx + 1

    if PROMPT_INJECTION_RE.search(line):
        findings.append(
            Finding(
                "WARN",
                "prompt-injection-instruction",
                rel_path,
                lineno,
                _detail(line),
                "agent-scan:E004",
            )
        )

    if UNTRUSTED_CONTENT_RE.search(line):
        findings.append(
            Finding(
                "WARN",
                "untrusted-content-exposure",
                rel_path,
                lineno,
                _detail(line),
                "agent-scan:W011",
            )
        )

    if SYSTEM_MODIFICATION_RE.search(line):
        findings.append(
            Finding(
                "WARN",
                "system-modification",
                rel_path,
                lineno,
                _detail(line),
                "agent-scan:W013",
            )
        )

    return findings


# ---------------------------------------------------------------------------
# File / source scanning
# ---------------------------------------------------------------------------


def scan_file(path: Path, rel_path: str) -> list[Finding]:
    """Scan a single file for security findings."""
    if path.name in SKIP_FILENAMES:
        return []

    suffix = path.suffix.lower()
    if suffix in BYTECODE_EXTENSIONS:
        return [
            Finding(
                "BLOCK",
                "compiled-bytecode",
                rel_path,
                0,
                f"compiled Python bytecode ({suffix})",
            )
        ]

    text = _read_file_text(path)
    if text is None:
        return []

    lines = text.splitlines()

    code_lines: frozenset[int] | None = None
    shell_lines: frozenset[int] | None = None
    if suffix == ".md":
        contexts = markdown_contexts(lines)
        code_lines = contexts.code_lines
        shell_lines = contexts.shell_lines

    findings: list[Finding] = []
    for idx, line in enumerate(lines):
        if not line.isascii():
            findings.extend(check_unicode(line, idx, rel_path, suffix, code_lines))
        findings.extend(check_network(line, idx, rel_path, suffix, code_lines))
        findings.extend(check_suspicious_downloads(line, idx, rel_path))
        findings.extend(check_shell_commands(line, idx, rel_path, suffix, shell_lines))
        findings.extend(check_code_execution(line, idx, rel_path, suffix, code_lines))
        findings.extend(check_credential_access(line, idx, rel_path, suffix, code_lines))
        findings.extend(check_hardcoded_secrets(line, idx, rel_path))
        findings.extend(check_insecure_credential_handling(line, idx, rel_path))
        findings.extend(check_obfuscation(line, idx, rel_path, suffix, code_lines))
        findings.extend(check_agent_skill_risks(line, idx, rel_path))

    return findings


def _scan_missing_skill_files(root: Path) -> list[Finding]:
    """Warn on direct children of skills/ that do not contain SKILL.md."""
    if not root.is_dir():
        return []

    findings: list[Finding] = []
    for skills_dir in sorted(path for path in root.rglob("skills") if path.is_dir()):
        for child in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
            if child.name.startswith(".") or child.name in SKIP_DIR_NAMES:
                continue
            if not (child / "SKILL.md").is_file():
                findings.append(
                    Finding(
                        "WARN",
                        "missing-skill-md",
                        _rel_path(child, root),
                        0,
                        "skill directory is missing SKILL.md",
                        "agent-scan:W014",
                    )
                )
    return findings


def scan_target(target: Path) -> list[Finding]:
    """Scan a file or directory target."""
    if target.is_file():
        return scan_file(target, target.name)

    findings: list[Finding] = []
    findings.extend(_scan_missing_skill_files(target))

    for path in sorted(target.rglob("*")):
        if any(part in SKIP_DIR_NAMES for part in path.parts):
            continue
        rel = _rel_path(path, target)
        if path.is_dir() and path.name == "__pycache__":
            findings.append(
                Finding(
                    "BLOCK",
                    "compiled-bytecode",
                    rel,
                    0,
                    "__pycache__ directory (unreviewable bytecode)",
                )
            )
            continue
        if not path.is_file():
            continue
        findings.extend(scan_file(path, rel))

    return findings


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def _escape_md_table(text: str) -> str:
    """Escape pipe characters so text doesn't break markdown tables."""
    return text.replace("|", "\\|")


def _format_markdown(findings: list[Finding]) -> str:
    """Format findings as a GitHub-flavored markdown report."""
    if not findings:
        return "<!-- security-scan -->\nNo security findings."

    blocks = [f for f in findings if f.level == "BLOCK"]
    warns = [f for f in findings if f.level == "WARN"]

    parts: list[str] = [
        "<!-- security-scan -->",
        "## Security Scanner Report",
        "",
        f"**{len(findings)}** finding(s): **{len(blocks)}** BLOCK, **{len(warns)}** WARN",
    ]

    for label, subset in [("BLOCK", blocks), ("WARN", warns)]:
        if not subset:
            continue
        parts.append("")
        parts.append(f"### {label} findings")
        parts.append("")
        parts.append("| Category | Reference | File | Line | Detail |")
        parts.append("|----------|-----------|------|------|--------|")
        for finding in subset:
            detail = _escape_md_table(finding.detail[:80])
            reference = finding.reference or ""
            parts.append(
                f"| {finding.category} | {reference} | {finding.path} | "
                f"{finding.line} | `{detail}` |"
            )

    return "\n".join(parts) + "\n"


def _format_json(findings: list[Finding]) -> str:
    """Format findings as stable JSON."""
    payload = {
        "summary": {
            "total": len(findings),
            "block": sum(1 for finding in findings if finding.level == "BLOCK"),
            "warn": sum(1 for finding in findings if finding.level == "WARN"),
        },
        "findings": [asdict(finding) for finding in findings],
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def _format_text(findings: list[Finding]) -> None:
    """Print findings in plain-text format."""
    if not findings:
        print("No findings.")
        return

    for finding in findings:
        tag = "BLOCK" if finding.level == "BLOCK" else "WARN "
        reference = f" [{finding.reference}]" if finding.reference else ""
        print(
            f"{tag}  {finding.category:<30s} "
            f"{finding.path}:{finding.line:<6d} {finding.detail}{reference}"
        )

    print(
        f"\nSummary: {len(findings)} finding(s) - "
        f"{sum(1 for finding in findings if finding.level == 'BLOCK')} BLOCK, "
        f"{sum(1 for finding in findings if finding.level == 'WARN')} WARN",
        file=sys.stderr,
    )


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deterministic security scanner for imported bundled sources.",
    )
    parser.add_argument(
        "targets",
        type=Path,
        nargs="+",
        help="Source file(s), skill directory(ies), or source tree(s)",
    )
    parser.add_argument(
        "--format",
        choices=["text", "markdown", "json"],
        default="text",
        dest="output_format",
        help="Output format (default: text)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = _parse_args(argv)

    all_findings: list[Finding] = []
    for target in args.targets:
        if not target.exists():
            print(f"Error: {target} does not exist", file=sys.stderr)
            sys.exit(1)
        all_findings.extend(scan_target(target))

    if args.output_format == "markdown":
        print(_format_markdown(all_findings))
    elif args.output_format == "json":
        print(_format_json(all_findings), end="")
    else:
        _format_text(all_findings)

    has_block = any(finding.level == "BLOCK" for finding in all_findings)
    has_warn = any(finding.level == "WARN" for finding in all_findings)

    if has_block:
        sys.exit(2)
    if has_warn:
        sys.exit(3)


if __name__ == "__main__":
    main()
