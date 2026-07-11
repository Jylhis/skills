// Append a single correction entry to the improvement-memory JSONL.
//
// VENDORED COPY: canonical source is scripts/append-correction.go at the repo
// root. This copy exists so ${CLAUDE_PLUGIN_ROOT}/scripts/append-correction.go
// resolves for marketplace installs of jylhis-skills-core. Keep in sync.
//
// Default path: ${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl
//
// Schema v1 keys: schema_version (=1), timestamp (RFC3339 UTC), session_id,
// skill, category (behavior|scope|trigger|output_format|other),
// what_went_wrong, correction, proposed_skill_change.
//
// Exit codes: 0 OK, 2 usage, 3 validation, 4 IO.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

const (
	exitUsage      = 2
	exitValidation = 3
	exitIO         = 4
	schemaVersion  = 1
)

var (
	categories      = map[string]struct{}{"behavior": {}, "scope": {}, "trigger": {}, "output_format": {}, "other": {}}
	requiredKeys    = []string{"schema_version", "timestamp", "session_id", "skill", "category", "what_went_wrong", "correction", "proposed_skill_change"}
	nullableStrKeys = map[string]struct{}{"session_id": {}, "skill": {}, "proposed_skill_change": {}}
	nonNullStrKeys  = map[string]struct{}{"timestamp": {}, "category": {}, "what_went_wrong": {}, "correction": {}}
)

func fail(msg string, code int) {
	fmt.Fprintf(os.Stderr, "append-correction: %s\n", msg)
	os.Exit(code)
}

// keyError returns a sorted comma-joined string of map keys missing
// from `have` (when present=false) or unexpected in `have` (when
// present=true relative to required).
func sortedKeys(s []string) string {
	cp := append([]string(nil), s...)
	sort.Strings(cp)
	return strings.Join(cp, ", ")
}

func validate(obj map[string]any) {
	var missing []string
	for _, k := range requiredKeys {
		if _, ok := obj[k]; !ok {
			missing = append(missing, k)
		}
	}
	if len(missing) > 0 {
		fail("missing required keys: "+sortedKeys(missing), exitValidation)
	}
	required := make(map[string]struct{}, len(requiredKeys))
	for _, k := range requiredKeys {
		required[k] = struct{}{}
	}
	var extra []string
	for k := range obj {
		if _, ok := required[k]; !ok {
			extra = append(extra, k)
		}
	}
	if len(extra) > 0 {
		fail("unknown keys: "+sortedKeys(extra), exitValidation)
	}

	// schema_version
	v, ok := obj["schema_version"].(float64)
	if !ok || int(v) != schemaVersion {
		fail(fmt.Sprintf("schema_version must be %d, got %v", schemaVersion, obj["schema_version"]), exitValidation)
	}

	// category
	cat, ok := obj["category"].(string)
	if !ok {
		fail("category must be a non-empty string", exitValidation)
	}
	if _, ok := categories[cat]; !ok {
		cats := make([]string, 0, len(categories))
		for k := range categories {
			cats = append(cats, k)
		}
		fail(fmt.Sprintf("category must be one of [%s], got %q", sortedKeys(cats), cat), exitValidation)
	}

	for k := range nullableStrKeys {
		val := obj[k]
		if val == nil {
			continue
		}
		if _, ok := val.(string); !ok {
			fail(fmt.Sprintf("%s must be string or null, got %T", k, val), exitValidation)
		}
	}

	for k := range nonNullStrKeys {
		s, ok := obj[k].(string)
		if !ok || s == "" {
			fail(fmt.Sprintf("%s must be a non-empty string", k), exitValidation)
		}
	}

	ts := obj["timestamp"].(string)
	// Accept the Z suffix and any RFC3339 variant Python's
	// datetime.fromisoformat handles.
	parseAttempts := []string{time.RFC3339Nano, time.RFC3339, "2006-01-02T15:04:05Z", "2006-01-02T15:04:05"}
	var parseOK bool
	for _, layout := range parseAttempts {
		if _, err := time.Parse(layout, ts); err == nil {
			parseOK = true
			break
		}
	}
	if !parseOK {
		fail(fmt.Sprintf("timestamp not RFC3339/ISO-8601: %s", ts), exitValidation)
	}
}

func defaultPath() string {
	if base := os.Getenv("XDG_STATE_HOME"); base != "" {
		return filepath.Join(base, "jylhis-skills", "improvement-memory.jsonl")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		fail(fmt.Sprintf("cannot resolve home dir: %v", err), exitIO)
	}
	return filepath.Join(home, ".local", "state", "jylhis-skills", "improvement-memory.jsonl")
}

// appendLine writes `obj` as one canonical JSON line to `path` under an
// fcntl LOCK_EX, creating parent dirs and the file (mode 0600) as needed.
func appendLine(path string, obj map[string]any) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		fail(fmt.Sprintf("cannot create %s: %v", filepath.Dir(path), err), exitIO)
	}
	// Re-encode with sorted keys + compact separators to match the
	// Python implementation byte-for-byte.
	line, err := canonicalJSON(obj)
	if err != nil {
		fail(fmt.Sprintf("re-encode failed: %v", err), exitIO)
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		fail(fmt.Sprintf("cannot open %s: %v", path, err), exitIO)
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		fail(fmt.Sprintf("flock failed on %s: %v", path, err), exitIO)
	}
	if _, err := f.Write(append([]byte(line), '\n')); err != nil {
		fail(fmt.Sprintf("write failed on %s: %v", path, err), exitIO)
	}
}

// canonicalJSON emits compact JSON with map keys sorted, matching
// json.dumps(sort_keys=True, separators=(",",":"), ensure_ascii=False).
func canonicalJSON(v any) (string, error) {
	switch t := v.(type) {
	case nil:
		return "null", nil
	case bool:
		if t {
			return "true", nil
		}
		return "false", nil
	case float64:
		// Integers come through as float64; emit without decimal if exact.
		if t == float64(int64(t)) {
			return fmt.Sprintf("%d", int64(t)), nil
		}
		return fmt.Sprintf("%v", t), nil
	case string:
		b, err := json.Marshal(t)
		return string(b), err
	case []any:
		parts := make([]string, len(t))
		for i, x := range t {
			s, err := canonicalJSON(x)
			if err != nil {
				return "", err
			}
			parts[i] = s
		}
		return "[" + strings.Join(parts, ",") + "]", nil
	case map[string]any:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		parts := make([]string, 0, len(keys))
		for _, k := range keys {
			kj, _ := json.Marshal(k)
			vj, err := canonicalJSON(t[k])
			if err != nil {
				return "", err
			}
			parts = append(parts, string(kj)+":"+vj)
		}
		return "{" + strings.Join(parts, ",") + "}", nil
	default:
		// Fall back to encoding/json for anything unexpected.
		b, err := json.Marshal(v)
		return string(b), err
	}
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr,
			"usage: append-correction --json (-|<inline-json>) [--path <file>]\n"+
				"\n"+
				"Append a schema-v1 correction entry to the improvement-memory JSONL.\n"+
				"Schema v1 keys: schema_version (=1), timestamp (RFC3339 UTC), session_id, skill,\n"+
				"category (behavior|scope|trigger|output_format|other), what_went_wrong,\n"+
				"correction, proposed_skill_change.\n"+
				"Default path: ${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/improvement-memory.jsonl\n"+
				"Exit codes: 0 OK, 2 usage, 3 validation, 4 IO.\n")
	}
	payload := flag.String("json", "", "JSON object to append. Use '-' to read from stdin.")
	path := flag.String("path", "", "Override the default JSONL path.")
	flag.Parse()

	if *payload == "" {
		flag.Usage()
		os.Exit(exitUsage)
	}

	var raw string
	if *payload == "-" {
		b, err := io.ReadAll(os.Stdin)
		if err != nil {
			fail(fmt.Sprintf("read stdin failed: %v", err), exitIO)
		}
		raw = string(b)
	} else {
		raw = *payload
	}
	if strings.TrimSpace(raw) == "" {
		fail("no JSON provided", exitValidation)
	}

	var parsed any
	dec := json.NewDecoder(strings.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(&parsed); err != nil {
		fail(fmt.Sprintf("invalid JSON: %v", err), exitValidation)
	}
	// Normalise json.Number -> float64 so validate's type assertions
	// work the same as the Python version.
	parsed = normaliseNumbers(parsed)

	obj, ok := parsed.(map[string]any)
	if !ok {
		fail("top-level JSON value must be an object", exitValidation)
	}
	validate(obj)

	target := *path
	if target == "" {
		target = defaultPath()
	}
	appendLine(target, obj)
	fmt.Printf("appended to %s\n", target)
}

func normaliseNumbers(v any) any {
	switch t := v.(type) {
	case json.Number:
		if f, err := t.Float64(); err == nil {
			return f
		}
		return string(t)
	case map[string]any:
		for k, val := range t {
			t[k] = normaliseNumbers(val)
		}
		return t
	case []any:
		for i, val := range t {
			t[i] = normaliseNumbers(val)
		}
		return t
	default:
		return v
	}
}
