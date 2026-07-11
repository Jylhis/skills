# ADR: Claude-only extensions live as plugin-local skills

Status: accepted (2026-07)

Supersedes the plugin `commands/` guidance in `docs/skills-spec-v4.md`
(the sections and trees there that still show a `commands/` directory);
that spec is kept as written for history and is not edited.

## Context

Claude Code merged custom slash commands into skills: a skill named `X`
creates the command, and for plugin-shipped skills the command is
namespaced as `/jylhis-skills-core:X`. Plugin skills accept Claude-only
frontmatter (`allowed-tools`, `argument-hint`, `context: fork`, `agent`,
`disable-model-invocation`, `user-invocable`) and `$ARGUMENTS` in the
body, and a plugin's `skills/` directory may freely mix symlinks and
real directories.

This repo publishes to three targets with different capabilities:
Claude Code (full plugin runtime), Pi (portable `SKILL.md` scanning,
no Claude frontmatter), and claude.ai Skills (per-skill zip uploads of
portable skills only). The portable lint (`scripts/validate.py`)
rejects Claude-only frontmatter and `${CLAUDE_PLUGIN_ROOT}` in the
canonical tree, which is what keeps the pool portable.

## Decision

1. Claude-only frontmatter and invocation controls live at PLUGIN
   level, in real (non-symlink) skill directories under
   `plugins/<plugin>/skills/<name>/`, outside the portable
   `skills/<category>/<name>` tree. The former
   `plugins/jylhis-skills-core/commands/` directory is deleted; its
   three commands are now the plugin-local skills `explore`,
   `lsp-status`, and `remember-correction`, invoked as
   `/jylhis-skills-core:<name>`.

2. The portable lint stays strict. `scripts/validate.py` continues to
   scan only the repo-root `skills/` tree and continues to reject
   target-specific frontmatter there. Plugin-local skills are exempt by
   location, not by exception lists.

3. Plugin-local skills are NEVER listed in `plugin.json` `skills[]`.
   The lint's `check_plugin_manifests` resolves every listed entry and
   requires it to match a `SKILL.md` directory inside the canonical
   `skills/<category>/<name>` tree, so listing a plugin-local real
   directory hard-fails validation. Unlisted directories are invisible
   to the lint, and Claude Code auto-discovers every entry in a
   plugin's `skills/` directory regardless of the manifest, so nothing
   is lost by omitting them.

4. The Pi mirror copies only SYMLINKED entries of a plugin's `skills/`
   directory. `sync_pi_plugin_skills()` in `scripts/install.sh` builds
   an rsync exclude list from the non-symlink entries, so target-native
   artefacts (Claude frontmatter, `$ARGUMENTS`,
   `${CLAUDE_PLUGIN_ROOT}` paths) never reach `~/.pi/agent/skills/`.

5. Helpers a plugin-local skill invokes via `${CLAUDE_PLUGIN_ROOT}` must
   ship as real files inside the plugin directory (a symlink pointing
   outside the plugin dir may not survive plugin install).
   `remember-correction` runs
   `${CLAUDE_PLUGIN_ROOT}/scripts/append-correction.go`, so the
   canonical location of that helper moved INTO the plugin:
   `plugins/jylhis-skills-core/scripts/append-correction.go` is the only
   copy, and repo-root callers run
   `go run plugins/jylhis-skills-core/scripts/append-correction.go`
   directly (no repo-root symlink: duplicate-code analyzers index a
   symlinked Go file as a second identical file). Single-sourced, so
   there is no copy to drift.

## Consequences

- Claude Code users get native command behaviour (namespaced
  invocation, `context: fork` + `agent` for `explore`,
  `disable-model-invocation` for the side-effectful
  `remember-correction`) without any portability compromise in the
  canonical tree.
- Pi keeps seeing exactly the portable skill set it saw before; the
  symlink/real-directory distinction is the single mechanism that
  separates portable from target-native content.
- claude.ai Skills are unaffected: the zip packaging channel draws from
  the portable `skills/<category>/<name>` tree only, and plugin-local
  skills are never packaged.
- Anyone adding a Claude-only capability adds a real directory under
  the plugin's `skills/`, does not touch `plugin.json` `skills[]`, and
  relies on the install script's symlink filter to keep it out of Pi.

## Known limitations

- Plugin-local skills get zero lint today: `scripts/validate.py`
  deliberately scans only the repo-root `skills/` tree, so nothing
  checks their frontmatter or layout. A future advisory pass over real
  directories matching `plugins/*/skills/*/SKILL.md` is the fix.
- The Pi-mirror exclude list interpolates raw directory basenames into
  rsync `--exclude` patterns, so plugin-local skill names must avoid
  rsync wildcard characters (`*`, `?`, `[`).
