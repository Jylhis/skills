// Generate opencode-facing artefacts from the jylhis-skills plugin tree.
//
// opencode auto-discovers, under its config dir (~/.config/opencode):
//
//	skills/**/SKILL.md   - mirrored verbatim by install.sh (same rsync as Pi)
//	agent/<name>.md      - transformed from plugins/*/agents/<name>.md
//	                       (adds mode: subagent, hard read-only permissions)
//	command/<name>.md    - transformed from plugins/*/commands/<name>.md
//	                       (strips Claude-only frontmatter, rewrites paths);
//	                       a sibling <name>.opencode.md, if present, is used
//	                       verbatim instead of the transform
//	plugins/jylhis-lsp.ts - generated from the installed language plugins'
//	                       .lsp.json files; injects them into opencode's LSP
//	                       config via the plugin config hook so the (possibly
//	                       home-manager-managed) opencode.json is never edited
//
// Generated files are tracked in a .jylhis-managed sidecar per target
// directory: re-runs overwrite managed files freely, a pre-existing foreign
// file at a target path is backed up first, and files whose source vanished
// are pruned.
//
// Exit codes: 0 OK, 2 usage, 3 validation, 4 IO.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const (
	exitUsage      = 2
	exitValidation = 3
	exitIO         = 4

	corePlugin = "jylhis-skills-core"
	sidecar    = ".jylhis-managed"
)

func fail(msg string, code int) {
	fmt.Fprintf(os.Stderr, "sync-opencode: %s\n", msg)
	os.Exit(code)
}

// ── managed-file writes ─────────────────────────────────────────────────

// writeManaged writes dir/name with content. A pre-existing file that is not
// listed in the sidecar is moved into backupDir first. current tracks the
// full managed set for this run; call pruneManaged once after all writes.
func writeManaged(dir, name, content, backupDir string, current map[string]bool) {
	target := filepath.Join(dir, name)
	managed := readSidecar(dir)
	if _, err := os.Stat(target); err == nil {
		if !managed[name] {
			if err := os.MkdirAll(backupDir, 0o755); err != nil {
				fail(fmt.Sprintf("cannot create backup dir %s: %v", backupDir, err), exitIO)
			}
			if err := os.Rename(target, filepath.Join(backupDir, name)); err != nil {
				fail(fmt.Sprintf("cannot back up %s: %v", target, err), exitIO)
			}
			fmt.Printf("backup %s (foreign file) -> %s\n", target, backupDir)
		}
	} else if !os.IsNotExist(err) {
		fail(fmt.Sprintf("stat %s: %v", target, err), exitIO)
	}

	if old, err := os.ReadFile(target); err == nil && string(old) == content {
		fmt.Printf("skip %s (unchanged)\n", target)
	} else {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			fail(fmt.Sprintf("cannot create %s: %v", dir, err), exitIO)
		}
		if err := os.WriteFile(target, []byte(content), 0o644); err != nil {
			fail(fmt.Sprintf("cannot write %s: %v", target, err), exitIO)
		}
		fmt.Printf("write %s\n", target)
	}
	current[name] = true
}

// pruneManaged removes previously managed files absent from current and
// rewrites the sidecar to match current. The sidecar itself is removed when
// current is empty.
func pruneManaged(dir string, current map[string]bool) {
	for name := range readSidecar(dir) {
		if current[name] {
			continue
		}
		target := filepath.Join(dir, name)
		if err := os.Remove(target); err != nil && !os.IsNotExist(err) {
			fail(fmt.Sprintf("cannot prune %s: %v", target, err), exitIO)
		}
		fmt.Printf("prune %s (source removed)\n", target)
	}
	sidecarPath := filepath.Join(dir, sidecar)
	if len(current) == 0 {
		if err := os.Remove(sidecarPath); err != nil && !os.IsNotExist(err) {
			fail(fmt.Sprintf("cannot remove %s: %v", sidecarPath, err), exitIO)
		}
		return
	}
	names := make([]string, 0, len(current))
	for name := range current {
		names = append(names, name)
	}
	sort.Strings(names)
	if err := os.WriteFile(sidecarPath, []byte(strings.Join(names, "\n")+"\n"), 0o644); err != nil {
		fail(fmt.Sprintf("cannot write %s: %v", sidecarPath, err), exitIO)
	}
}

func readSidecar(dir string) map[string]bool {
	out := map[string]bool{}
	data, err := os.ReadFile(filepath.Join(dir, sidecar))
	if err != nil {
		return out
	}
	for _, line := range strings.Split(string(data), "\n") {
		if line = strings.TrimSpace(line); line != "" {
			out[line] = true
		}
	}
	return out
}

// ── frontmatter (line-based, keeps original scalars verbatim) ───────────

type fmBlock struct {
	lines []string // includes the opening and closing --- lines
	body  string
}

func splitFrontmatter(text, rel string) fmBlock {
	if !strings.HasPrefix(text, "---\n") {
		fail(rel+": missing YAML frontmatter (must start with ---)", exitValidation)
	}
	rest := text[4:]
	end := strings.Index(rest, "\n---\n")
	if end == -1 {
		fail(rel+": frontmatter not closed by a --- line", exitValidation)
	}
	lines := append([]string{"---"}, strings.Split(rest[:end], "\n")...)
	return fmBlock{
		lines: append(lines, "---"),
		body:  rest[end+5:],
	}
}

// topLevelKey returns the frontmatter key a line belongs to, or "" for
// continuation/blank lines.
func topLevelKey(line string) string {
	if line == "" || line[0] == ' ' || line[0] == '\t' || line == "---" {
		return ""
	}
	key, _, found := strings.Cut(line, ":")
	if !found {
		return ""
	}
	return strings.TrimSpace(key)
}

// keepFrontmatterLines returns the original lines for keys in keep (with
// their indented continuation lines), in original order. Trailing blank
// lines are trimmed so injected keys land flush after the kept block.
func keepFrontmatterLines(block fmBlock, keep map[string]struct{}) []string {
	var out []string
	keeping := false
	for _, line := range block.lines[1 : len(block.lines)-1] { // skip fences
		key := topLevelKey(line)
		if key != "" {
			_, keeping = keep[key]
		}
		if keeping {
			out = append(out, line)
		}
	}
	for len(out) > 0 && strings.TrimSpace(out[len(out)-1]) == "" {
		out = out[:len(out)-1]
	}
	return out
}

// ── subcommand: agents ──────────────────────────────────────────────────

// Agents whose opencode variant hard-enforces read-only behaviour on top of
// the prompt body ("read-only tools only", "never modifies files").
var readOnlyAgents = map[string]bool{"explorer": true, "reviewer": true}

func syncAgents(repo, dest, backupDir string) {
	sources, err := filepath.Glob(filepath.Join(repo, "plugins", "*", "agents", "*.md"))
	if err != nil {
		fail(fmt.Sprintf("glob agents: %v", err), exitIO)
	}
	sort.Strings(sources)

	dir := filepath.Join(dest, "agent")
	current := map[string]bool{}
	seen := map[string]string{}
	for _, src := range sources {
		name := filepath.Base(src) // <agent>.md
		if prev, dup := seen[name]; dup {
			fail(fmt.Sprintf("duplicate agent %s in %s and %s", name, prev, src), exitValidation)
		}
		seen[name] = src
		rel, _ := filepath.Rel(repo, src)

		raw, err := os.ReadFile(src)
		if err != nil {
			fail(fmt.Sprintf("read %s: %v", src, err), exitIO)
		}
		block := splitFrontmatter(string(raw), rel)
		kept := keepFrontmatterLines(block, map[string]struct{}{
			"name": {}, "description": {}, "model": {}, "temperature": {}, "top_p": {},
		})

		agentName := strings.TrimSuffix(name, ".md")
		var b strings.Builder
		b.WriteString("---\n")
		for _, line := range kept {
			b.WriteString(line + "\n")
		}
		b.WriteString("mode: subagent\n")
		if readOnlyAgents[agentName] {
			b.WriteString("permission:\n  edit: deny\n")
		}
		b.WriteString("---\n")
		b.WriteString(block.body)

		writeManaged(dir, name, b.String(), backupDir, current)
	}
	pruneManaged(dir, current)
}

// ── subcommand: commands ────────────────────────────────────────────────

func syncCommands(repo, dest, backupDir string) {
	sources, err := filepath.Glob(filepath.Join(repo, "plugins", "*", "commands", "*.md"))
	if err != nil {
		fail(fmt.Sprintf("glob commands: %v", err), exitIO)
	}
	sort.Strings(sources)

	repoScripts := filepath.Join(repo, "scripts")
	dir := filepath.Join(dest, "command")
	current := map[string]bool{}
	seen := map[string]string{}
	for _, src := range sources {
		name := filepath.Base(src)
		if strings.HasSuffix(name, ".opencode.md") {
			continue // hand-maintained opencode variants, picked up below
		}
		if prev, dup := seen[name]; dup {
			fail(fmt.Sprintf("duplicate command %s in %s and %s", name, prev, src), exitValidation)
		}
		seen[name] = src
		rel, _ := filepath.Rel(repo, src)

		// A sibling <name>.opencode.md is the hand-maintained opencode
		// variant (used verbatim when the target semantics differ, e.g.
		// lsp-status discovers config differently in opencode).
		if variant := strings.TrimSuffix(src, ".md") + ".opencode.md"; fileExists(variant) {
			raw, err := os.ReadFile(variant)
			if err != nil {
				fail(fmt.Sprintf("read %s: %v", variant, err), exitIO)
			}
			writeManaged(dir, name, string(raw), backupDir, current)
			continue
		}

		raw, err := os.ReadFile(src)
		if err != nil {
			fail(fmt.Sprintf("read %s: %v", src, err), exitIO)
		}
		block := splitFrontmatter(string(raw), rel)
		kept := keepFrontmatterLines(block, map[string]struct{}{
			"description": {}, "agent": {}, "model": {}, "variant": {}, "subtask": {},
		})
		if len(kept) == 0 {
			fail(rel+": frontmatter would be empty after transform (missing description?)", exitValidation)
		}

		// Claude plugin paths do not exist under opencode; point repo-level
		// helper scripts at the checkout.
		body := strings.ReplaceAll(block.body, "${CLAUDE_PLUGIN_ROOT}/scripts/", repoScripts+"/")

		var b strings.Builder
		b.WriteString("---\n")
		for _, line := range kept {
			b.WriteString(line + "\n")
		}
		b.WriteString("---\n")
		b.WriteString(body)

		writeManaged(dir, name, b.String(), backupDir, current)
	}
	pruneManaged(dir, current)
}

// ── subcommand: lsp ─────────────────────────────────────────────────────

// lspEntry mirrors the Claude .lsp.json per-language shape.
type lspEntry struct {
	Command             string            `json:"command"`
	Args                []string          `json:"args"`
	ExtensionToLanguage map[string]string `json:"extensionToLanguage"`
}

func syncLsp(repo, dest, backupDir, pluginsArg string) {
	dir := filepath.Join(dest, "plugins")
	current := map[string]bool{}

	plugins := []string{}
	if strings.TrimSpace(pluginsArg) != "" {
		for _, p := range strings.Split(pluginsArg, ",") {
			p = strings.TrimSpace(p)
			if p != "" {
				plugins = append(plugins, p)
			}
		}
	}

	var entries strings.Builder
	for _, plugin := range plugins {
		path := filepath.Join(repo, "plugins", plugin, ".lsp.json")
		raw, err := os.ReadFile(path)
		if err != nil {
			fail(fmt.Sprintf("read %s: %v", path, err), exitValidation)
		}
		var spec map[string]lspEntry
		if err := json.Unmarshal(raw, &spec); err != nil {
			fail(fmt.Sprintf("parse %s: %v", path, err), exitValidation)
		}
		keys := make([]string, 0, len(spec))
		for k := range spec {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, lang := range keys {
			e := spec[lang]
			if e.Command == "" || len(e.Args) == 0 || len(e.ExtensionToLanguage) == 0 {
				fail(fmt.Sprintf("%s: entry %q must set command, args and extensionToLanguage", path, lang), exitValidation)
			}
			cmd := append([]string{e.Command}, e.Args...)
			exts := make([]string, 0, len(e.ExtensionToLanguage))
			for ext := range e.ExtensionToLanguage {
				exts = append(exts, ext)
			}
			sort.Strings(exts)

			quoted := make([]string, len(cmd))
			for i, c := range cmd {
				quoted[i] = strconv.Quote(c)
			}
			quotedExts := make([]string, len(exts))
			for i, ext := range exts {
				quotedExts[i] = strconv.Quote(ext)
			}
			entries.WriteString(fmt.Sprintf("      // %s\n      %s: {\n        command: [%s],\n        extensions: [%s],\n      },\n",
				plugin, lang, strings.Join(quoted, ", "), strings.Join(quotedExts, ", ")))
		}
	}

	if len(plugins) == 0 {
		pruneManaged(dir, current) // drops a stale jylhis-lsp.ts
		fmt.Println("lsp: no language plugins installed; jylhis-lsp.ts not written")
		return
	}

	ts := "// Generated by scripts/sync_opencode.go in jylhis/skills - do not edit.\n" +
		"// Re-run scripts/install.sh to refresh. Sources: plugins/<plugin>/.lsp.json.\n" +
		"// Injects the jylhis-* language servers into opencode's LSP config at\n" +
		"// startup so opencode.json never needs editing for them.\n" +
		"export const JylhisLsp = async () => ({\n" +
		"  config: (cfg) => {\n" +
		"    cfg.lsp = {\n" +
		"      ...(cfg.lsp ?? {}),\n" +
		entries.String() +
		"    }\n" +
		"  },\n" +
		"})\n"
	writeManaged(dir, "jylhis-lsp.ts", ts, backupDir, current)
	pruneManaged(dir, current)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// ── entry point ─────────────────────────────────────────────────────────

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr,
			"usage: sync_opencode.go <agents|commands|lsp> -repo <root> -dest <opencode-config-dir> [-backup <dir>] [-plugins p1,p2]\n"+
				"\n"+
				"  agents   transform plugins/*/agents/*.md      -> <dest>/agent/*.md\n"+
				"  commands transform plugins/*/commands/*.md    -> <dest>/command/*.md\n"+
				"  lsp      convert plugins' .lsp.json           -> <dest>/plugins/jylhis-lsp.ts\n"+
				"           (-plugins lists the installed plugins; empty prunes the file)\n"+
				"Exit codes: 0 OK, 2 usage, 3 validation, 4 IO.\n")
	}
	if len(os.Args) < 2 {
		flag.Usage()
		os.Exit(exitUsage)
	}
	sub := os.Args[1]
	fs := flag.NewFlagSet(sub, flag.ExitOnError)
	repo := fs.String("repo", "", "skills repo root")
	dest := fs.String("dest", "", "opencode config dir (e.g. ~/.config/opencode)")
	backupDir := fs.String("backup", "", "where foreign files at target paths are moved")
	plugins := fs.String("plugins", "", "comma-separated installed plugin names (lsp only)")
	if err := fs.Parse(os.Args[2:]); err != nil {
		os.Exit(exitUsage)
	}
	if *repo == "" || *dest == "" || *backupDir == "" {
		flag.Usage()
		os.Exit(exitUsage)
	}
	absRepo, err := filepath.Abs(*repo)
	if err != nil {
		fail(fmt.Sprintf("cannot resolve repo root %s: %v", *repo, err), exitIO)
	}

	*repo = absRepo

	switch sub {
	case "agents":
		syncAgents(*repo, *dest, *backupDir)
	case "commands":
		syncCommands(*repo, *dest, *backupDir)
	case "lsp":
		syncLsp(*repo, *dest, *backupDir, *plugins)
	default:
		flag.Usage()
		os.Exit(exitUsage)
	}
}
