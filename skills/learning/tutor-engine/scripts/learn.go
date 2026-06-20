// Command learn is a portable, agent-native spaced-repetition scheduler and
// learner-state store for the tutor-engine skill. It implements the FSRS-5
// algorithm in pure standard-library Go so it runs offline with no module
// download:
//
//	nix run nixpkgs#go -- run learn.go <subcommand> [flags]
//	# or, with a local toolchain:
//	go run learn.go <subcommand> [flags]
//
// State is host-private and lives outside the repo, one JSON file per subject:
//
//	${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/learning/<subject>.json
//
// Subcommands: init, add, due, review, log-error, session, stats.
// Run "learn.go --help" or "learn.go <subcommand> --help" for details.
//
// Contract: stdout is JSON data, stderr is diagnostics. Mutating subcommands
// accept --dry-run. Exit codes: 0 ok, 2 usage, 3 validation, 4 io.
package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

const (
	exitUsage      = 2
	exitValidation = 3
	exitIO         = 4

	decay  = -0.5
	factor = 19.0 / 81.0 // makes R(t=S) == 0.9
)

// defaultParams are the FSRS-5 default weights (19 parameters).
var defaultParams = [19]float64{
	0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
	1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
	2.9898, 0.51655, 0.6621,
}

var subjectRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,40}$`)

// ── data model ─────────────────────────────────────────────────────────

type Card struct {
	ID         string   `json:"id"`
	Front      string   `json:"front"`
	Back       string   `json:"back"`
	Tags       []string `json:"tags,omitempty"`
	State      string   `json:"state"` // new | review | relearning
	Due        string   `json:"due"`   // RFC3339
	Stability  float64  `json:"stability"`
	Difficulty float64  `json:"difficulty"`
	Reps       int      `json:"reps"`
	Lapses     int      `json:"lapses"`
	LastReview string   `json:"last_review,omitempty"`
	Created    string   `json:"created"`
}

type FSRS struct {
	DesiredRetention float64     `json:"desired_retention"`
	Params           [19]float64 `json:"params"`
}

type ErrorEntry struct {
	TS      string `json:"ts"`
	Concept string `json:"concept"`
	Note    string `json:"note,omitempty"`
}

type SessionEntry struct {
	Date    string   `json:"date"`
	Minutes int      `json:"minutes"`
	Covered []string `json:"covered,omitempty"`
	Score   float64  `json:"score"`
}

type Profile struct {
	Level  string   `json:"level,omitempty"`
	Target string   `json:"target,omitempty"`
	Focus  []string `json:"focus,omitempty"`
}

type State struct {
	Subject  string         `json:"subject"`
	Created  string         `json:"created"`
	Profile  Profile        `json:"profile"`
	FSRS     FSRS           `json:"fsrs"`
	Cards    []Card         `json:"cards"`
	ErrorLog []ErrorEntry   `json:"error_log"`
	Sessions []SessionEntry `json:"sessions"`
}

// ── FSRS-5 core ────────────────────────────────────────────────────────

func clampD(d float64) float64 { return math.Min(10, math.Max(1, d)) }

func initStability(w [19]float64, g int) float64 {
	return math.Max(0.01, w[g-1])
}

func initDifficulty(w [19]float64, g int) float64 {
	return clampD(w[4] - math.Exp(w[5]*float64(g-1)) + 1)
}

// retrievability after t days given stability s.
func retrievability(t, s float64) float64 {
	if s <= 0 {
		return 0
	}
	return math.Pow(1+factor*t/s, decay)
}

// nextInterval in (rounded) days for a target retention.
func nextInterval(s, requestRetention float64) int {
	ivl := (s / factor) * (math.Pow(requestRetention, 1/decay) - 1)
	if ivl < 1 {
		return 1
	}
	return int(math.Round(ivl))
}

func nextDifficulty(w [19]float64, d float64, g int) float64 {
	// linear damping (FSRS-5) then mean reversion toward D0(easy=4).
	delta := -w[6] * float64(g-3)
	dp := d + delta*(10-d)/9
	target := initDifficulty(w, 4)
	return clampD(w[7]*target + (1-w[7])*dp)
}

func stabilityAfterRecall(w [19]float64, d, s, r float64, g int) float64 {
	hard, easy := 1.0, 1.0
	if g == 2 {
		hard = w[15]
	}
	if g == 4 {
		easy = w[16]
	}
	inc := math.Exp(w[8]) * (11 - d) * math.Pow(s, -w[9]) *
		(math.Exp((1-r)*w[10]) - 1) * hard * easy
	return math.Max(0.01, s*(1+inc))
}

func stabilityAfterLapse(w [19]float64, d, s, r float64) float64 {
	sp := w[11] * math.Pow(d, -w[12]) * (math.Pow(s+1, w[13]) - 1) * math.Exp((1-r)*w[14])
	if sp > s {
		sp = s // a lapse never increases stability
	}
	return math.Max(0.01, sp)
}

// applyReview mutates a card for grade g (1..4) at time now.
func applyReview(st *State, c *Card, g int, now time.Time) {
	w := st.FSRS.Params
	c.Reps++
	if c.LastReview == "" || c.State == "new" {
		// first review
		c.Stability = initStability(w, g)
		c.Difficulty = initDifficulty(w, g)
	} else {
		last, _ := time.Parse(time.RFC3339, c.LastReview)
		elapsed := now.Sub(last).Hours() / 24
		if elapsed < 0 {
			elapsed = 0
		}
		r := retrievability(elapsed, c.Stability)
		c.Difficulty = nextDifficulty(w, c.Difficulty, g)
		if g == 1 {
			c.Stability = stabilityAfterLapse(w, c.Difficulty, c.Stability, r)
		} else {
			c.Stability = stabilityAfterRecall(w, c.Difficulty, c.Stability, r, g)
		}
	}
	if g == 1 {
		c.Lapses++
		c.State = "relearning"
	} else {
		c.State = "review"
	}
	ivl := nextInterval(c.Stability, st.FSRS.DesiredRetention)
	c.LastReview = now.UTC().Format(time.RFC3339)
	c.Due = now.UTC().AddDate(0, 0, ivl).Format(time.RFC3339)
}

// ── persistence ────────────────────────────────────────────────────────

func stateDir() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(base, "jylhis-skills", "learning")
}

func statePath(subject string) string {
	return filepath.Join(stateDir(), subject+".json")
}

func loadState(subject string) (*State, error) {
	data, err := os.ReadFile(statePath(subject))
	if err != nil {
		return nil, err
	}
	var st State
	if err := json.Unmarshal(data, &st); err != nil {
		return nil, fmt.Errorf("corrupt state file %s: %w", statePath(subject), err)
	}
	return &st, nil
}

func writeState(st *State, dryRun bool) error {
	out, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	if dryRun {
		fmt.Fprintln(os.Stderr, "[dry-run] would write "+statePath(st.Subject))
		return nil
	}
	dir := stateDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(out); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return err
	}
	return os.Rename(tmpName, statePath(st.Subject))
}

// ── helpers ────────────────────────────────────────────────────────────

func fail(code int, format string, args ...any) {
	fmt.Fprintf(os.Stderr, "learn: "+format+"\n", args...)
	os.Exit(code)
}

func emit(v any) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		fail(exitIO, "encoding output: %v", err)
	}
}

func newID() string {
	b := make([]byte, 6)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("c%d", time.Now().UnixNano())
	}
	return "c" + hex.EncodeToString(b)
}

func checkSubject(s string) {
	if !subjectRe.MatchString(s) {
		fail(exitValidation, "invalid --subject %q (use lowercase letters, digits, hyphens)", s)
	}
}

func mustLoad(subject string) *State {
	st, err := loadState(subject)
	if err != nil {
		if os.IsNotExist(err) {
			fail(exitValidation, "no state for subject %q; run `learn init --subject %s` first", subject, subject)
		}
		fail(exitIO, "%v", err)
	}
	return st
}

func parseGrade(g string) int {
	switch strings.ToLower(strings.TrimSpace(g)) {
	case "1", "again":
		return 1
	case "2", "hard":
		return 2
	case "3", "good":
		return 3
	case "4", "easy":
		return 4
	}
	fail(exitValidation, "invalid --grade %q (use again|hard|good|easy or 1..4)", g)
	return 0
}

func splitCSV(s string) []string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if t := strings.TrimSpace(p); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// ── subcommands ────────────────────────────────────────────────────────

func cmdInit(args []string) {
	fs := flag.NewFlagSet("init", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id, e.g. german (required)")
	level := fs.String("level", "", "current level, e.g. A2 (German CEFR) or 'beginner'")
	target := fs.String("target", "", "target level, e.g. B1")
	focus := fs.String("focus", "", "comma-separated focus areas")
	retention := fs.Float64("retention", 0.9, "desired retention (0.7-0.97)")
	force := fs.Bool("force", false, "overwrite existing state")
	dryRun := fs.Bool("dry-run", false, "do not write")
	fs.Parse(args)
	checkSubject(*subject)
	if *retention < 0.7 || *retention > 0.97 {
		fail(exitValidation, "--retention %.2f out of range [0.70, 0.97]", *retention)
	}
	if _, err := loadState(*subject); err == nil && !*force {
		fail(exitValidation, "state for %q already exists; use --force to overwrite", *subject)
	}
	now := time.Now().UTC().Format(time.RFC3339)
	st := &State{
		Subject: *subject,
		Created: now,
		Profile: Profile{Level: *level, Target: *target, Focus: splitCSV(*focus)},
		FSRS:    FSRS{DesiredRetention: *retention, Params: defaultParams},
		Cards:   []Card{}, ErrorLog: []ErrorEntry{}, Sessions: []SessionEntry{},
	}
	if err := writeState(st, *dryRun); err != nil {
		fail(exitIO, "%v", err)
	}
	emit(map[string]any{"ok": true, "subject": *subject, "path": statePath(*subject)})
}

// addInput is the stdin payload for `add`.
type addInput struct {
	Front string   `json:"front"`
	Back  string   `json:"back"`
	Tags  []string `json:"tags"`
}

func cmdAdd(args []string) {
	fs := flag.NewFlagSet("add", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	front := fs.String("front", "", "card front (or pass JSON on stdin)")
	back := fs.String("back", "", "card back")
	tags := fs.String("tags", "", "comma-separated tags")
	dryRun := fs.Bool("dry-run", false, "do not write")
	fs.Parse(args)
	checkSubject(*subject)
	st := mustLoad(*subject)

	var inputs []addInput
	if *front == "" {
		// read JSON from stdin: a single object or an array of objects.
		raw, _ := io.ReadAll(os.Stdin)
		trimmed := strings.TrimSpace(string(raw))
		if trimmed == "" {
			fail(exitUsage, "provide --front or JSON on stdin")
		}
		if strings.HasPrefix(trimmed, "[") {
			if err := json.Unmarshal([]byte(trimmed), &inputs); err != nil {
				fail(exitValidation, "bad stdin JSON: %v", err)
			}
		} else {
			var one addInput
			if err := json.Unmarshal([]byte(trimmed), &one); err != nil {
				fail(exitValidation, "bad stdin JSON: %v", err)
			}
			inputs = []addInput{one}
		}
	} else {
		inputs = []addInput{{Front: *front, Back: *back, Tags: splitCSV(*tags)}}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	created := make([]Card, 0, len(inputs))
	for _, in := range inputs {
		if strings.TrimSpace(in.Front) == "" {
			fail(exitValidation, "each card needs a non-empty front")
		}
		c := Card{
			ID: newID(), Front: in.Front, Back: in.Back, Tags: in.Tags,
			State: "new", Due: now, Created: now,
		}
		st.Cards = append(st.Cards, c)
		created = append(created, c)
	}
	if err := writeState(st, *dryRun); err != nil {
		fail(exitIO, "%v", err)
	}
	emit(map[string]any{"ok": true, "added": len(created), "cards": created})
}

func cmdDue(args []string) {
	fs := flag.NewFlagSet("due", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	limit := fs.Int("limit", 20, "max cards to return")
	tag := fs.String("tag", "", "only cards with this tag")
	fs.Parse(args)
	checkSubject(*subject)
	st := mustLoad(*subject)
	now := time.Now().UTC()

	type scored struct {
		c   Card
		due time.Time
	}
	var pool []scored
	for _, c := range st.Cards {
		if *tag != "" && !contains(c.Tags, *tag) {
			continue
		}
		due, err := time.Parse(time.RFC3339, c.Due)
		if err != nil {
			due = now
		}
		if c.State == "new" || !due.After(now) {
			pool = append(pool, scored{c, due})
		}
	}
	// new cards last so reviews are cleared first; otherwise earliest-due first.
	sort.SliceStable(pool, func(i, j int) bool {
		ni, nj := pool[i].c.State == "new", pool[j].c.State == "new"
		if ni != nj {
			return !ni
		}
		return pool[i].due.Before(pool[j].due)
	})
	out := make([]Card, 0, *limit)
	for _, s := range pool {
		if len(out) >= *limit {
			break
		}
		out = append(out, s.c)
	}
	emit(map[string]any{"subject": *subject, "due_count": len(pool), "returned": len(out), "cards": out})
}

func cmdReview(args []string) {
	fs := flag.NewFlagSet("review", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	id := fs.String("id", "", "card id (required)")
	grade := fs.String("grade", "", "again|hard|good|easy or 1..4 (required)")
	dryRun := fs.Bool("dry-run", false, "compute but do not write")
	fs.Parse(args)
	checkSubject(*subject)
	if *id == "" {
		fail(exitUsage, "--id is required")
	}
	g := parseGrade(*grade)
	st := mustLoad(*subject)
	now := time.Now().UTC()
	idx := -1
	for i := range st.Cards {
		if st.Cards[i].ID == *id {
			idx = i
			break
		}
	}
	if idx < 0 {
		fail(exitValidation, "no card with id %q in subject %q", *id, *subject)
	}
	applyReview(st, &st.Cards[idx], g, now)
	if err := writeState(st, *dryRun); err != nil {
		fail(exitIO, "%v", err)
	}
	emit(map[string]any{"ok": true, "card": st.Cards[idx]})
}

func cmdLogError(args []string) {
	fs := flag.NewFlagSet("log-error", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	concept := fs.String("concept", "", "short concept key, e.g. dative_prepositions (required)")
	note := fs.String("note", "", "free-text note about the mistake")
	dryRun := fs.Bool("dry-run", false, "do not write")
	fs.Parse(args)
	checkSubject(*subject)
	if strings.TrimSpace(*concept) == "" {
		fail(exitUsage, "--concept is required")
	}
	st := mustLoad(*subject)
	st.ErrorLog = append(st.ErrorLog, ErrorEntry{
		TS: time.Now().UTC().Format(time.RFC3339), Concept: *concept, Note: *note,
	})
	if err := writeState(st, *dryRun); err != nil {
		fail(exitIO, "%v", err)
	}
	emit(map[string]any{"ok": true, "logged": *concept, "total_errors": len(st.ErrorLog)})
}

func cmdSession(args []string) {
	fs := flag.NewFlagSet("session", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	minutes := fs.Int("minutes", 0, "session length in minutes")
	covered := fs.String("covered", "", "comma-separated topics covered")
	score := fs.Float64("score", 0, "session performance 0.0-1.0")
	dryRun := fs.Bool("dry-run", false, "do not write")
	fs.Parse(args)
	checkSubject(*subject)
	st := mustLoad(*subject)
	st.Sessions = append(st.Sessions, SessionEntry{
		Date: time.Now().UTC().Format("2006-01-02"), Minutes: *minutes,
		Covered: splitCSV(*covered), Score: *score,
	})
	if err := writeState(st, *dryRun); err != nil {
		fail(exitIO, "%v", err)
	}
	emit(map[string]any{"ok": true, "sessions": len(st.Sessions)})
}

func cmdStats(args []string) {
	fs := flag.NewFlagSet("stats", flag.ExitOnError)
	subject := fs.String("subject", "", "subject id (required)")
	fs.Parse(args)
	checkSubject(*subject)
	st := mustLoad(*subject)
	now := time.Now().UTC()
	var dueNow, newCount, reviewCount, relearn int
	for _, c := range st.Cards {
		switch c.State {
		case "new":
			newCount++
		case "relearning":
			relearn++
		default:
			reviewCount++
		}
		if c.State == "new" {
			dueNow++
			continue
		}
		if due, err := time.Parse(time.RFC3339, c.Due); err == nil && !due.After(now) {
			dueNow++
		}
	}
	// top error concepts by frequency.
	freq := map[string]int{}
	for _, e := range st.ErrorLog {
		freq[e.Concept]++
	}
	emit(map[string]any{
		"subject":      *subject,
		"level":        st.Profile.Level,
		"target":       st.Profile.Target,
		"total_cards":  len(st.Cards),
		"due_now":      dueNow,
		"new":          newCount,
		"review":       reviewCount,
		"relearning":   relearn,
		"sessions":     len(st.Sessions),
		"error_counts": freq,
	})
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

const usage = `learn — agent-native spaced-repetition scheduler (FSRS-5) for tutor-engine

Usage: learn <subcommand> [flags]

Subcommands:
  init       Create state for a subject (--subject, --level, --target, --focus, --retention)
  add        Add card(s): --front/--back/--tags, or JSON object/array on stdin
  due        List cards due for review (--limit, --tag)
  review     Record a grade and reschedule (--id, --grade again|hard|good|easy)
  log-error  Append a mistake to the error log (--concept, --note)
  session    Record a study session (--minutes, --covered, --score)
  stats      Summary counts for a subject

State file: ${XDG_STATE_HOME:-$HOME/.local/state}/jylhis-skills/learning/<subject>.json
stdout is JSON; stderr is diagnostics. Mutating commands accept --dry-run.
Exit codes: 0 ok, 2 usage, 3 validation, 4 io.`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, usage)
		os.Exit(exitUsage)
	}
	switch os.Args[1] {
	case "-h", "--help", "help":
		fmt.Println(usage)
	case "init":
		cmdInit(os.Args[2:])
	case "add":
		cmdAdd(os.Args[2:])
	case "due":
		cmdDue(os.Args[2:])
	case "review":
		cmdReview(os.Args[2:])
	case "log-error":
		cmdLogError(os.Args[2:])
	case "session":
		cmdSession(os.Args[2:])
	case "stats":
		cmdStats(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "learn: unknown subcommand %q\n\n%s\n", os.Args[1], usage)
		os.Exit(exitUsage)
	}
}
