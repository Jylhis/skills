package main

import (
	"errors"
	"slices"
	"strings"
	"testing"
)

func TestResolveArgs(t *testing.T) {
	tests := []struct {
		name       string
		args       []string
		wantBranch string
		wantRemote string
	}{
		{"defaults", nil, "main", "upstream"},
		{"branch only", []string{"develop"}, "develop", "upstream"},
		{"branch and remote", []string{"develop", "up2"}, "develop", "up2"},
		{"empty strings fall back", []string{"", ""}, "main", "upstream"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			branch, remote := resolveArgs(tt.args)
			if branch != tt.wantBranch || remote != tt.wantRemote {
				t.Errorf("resolveArgs(%v) = (%q, %q), want (%q, %q)",
					tt.args, branch, remote, tt.wantBranch, tt.wantRemote)
			}
		})
	}
}

type fakeGit struct {
	captureOut  map[string]string
	captureErr  map[string]error
	streamErr   map[string]error
	streamCalls []string
}

func key(args ...string) string { return strings.Join(args, " ") }

func (f *fakeGit) capture(_ string, args ...string) (string, error) {
	k := key(args...)
	return f.captureOut[k], f.captureErr[k]
}

func (f *fakeGit) stream(_ string, args ...string) error {
	f.streamCalls = append(f.streamCalls, key(args...))
	return f.streamErr[key(args...)]
}

func TestSyncForkMissingRemote(t *testing.T) {
	f := &fakeGit{captureErr: map[string]error{"remote get-url upstream": errors.New("no such remote")}}
	var out strings.Builder
	if code := syncFork(f, &out, "main", "upstream"); code != 1 {
		t.Errorf("exit = %d, want 1", code)
	}
	if len(f.streamCalls) != 0 {
		t.Errorf("no git mutations expected when remote missing, got %v", f.streamCalls)
	}
	if !strings.Contains(out.String(), "not found") {
		t.Errorf("expected missing-remote guidance, got %q", out.String())
	}
}

func TestSyncForkFastForward(t *testing.T) {
	f := &fakeGit{captureOut: map[string]string{
		"remote get-url upstream": "https://gitlab.com/g/p.git",
		"branch --show-current":   "main",
	}}
	var out strings.Builder
	if code := syncFork(f, &out, "main", "upstream"); code != 0 {
		t.Fatalf("exit = %d, want 0", code)
	}
	want := []string{"fetch upstream", "merge upstream/main --ff-only", "push origin main"}
	if !slices.Equal(f.streamCalls, want) {
		t.Errorf("stream calls = %v, want %v", f.streamCalls, want)
	}
}

func TestSyncForkFallbackMerge(t *testing.T) {
	f := &fakeGit{
		captureOut: map[string]string{
			"remote get-url upstream": "url",
			"branch --show-current":   "main",
		},
		streamErr: map[string]error{"merge upstream/main --ff-only": errors.New("not ff")},
	}
	var out strings.Builder
	if code := syncFork(f, &out, "main", "upstream"); code != 0 {
		t.Fatalf("exit = %d, want 0", code)
	}
	if !slices.Contains(f.streamCalls, "merge upstream/main") {
		t.Errorf("expected fallback regular merge, got %v", f.streamCalls)
	}
	if !slices.Contains(f.streamCalls, "push origin main") {
		t.Errorf("expected push after successful fallback merge, got %v", f.streamCalls)
	}
}

func TestSyncForkConflictAborts(t *testing.T) {
	f := &fakeGit{
		captureOut: map[string]string{
			"remote get-url upstream": "url",
			"branch --show-current":   "main",
		},
		streamErr: map[string]error{
			"merge upstream/main --ff-only": errors.New("not ff"),
			"merge upstream/main":           errors.New("conflict"),
		},
	}
	var out strings.Builder
	if code := syncFork(f, &out, "main", "upstream"); code != 1 {
		t.Fatalf("exit = %d, want 1", code)
	}
	if slices.Contains(f.streamCalls, "push origin main") {
		t.Errorf("push must not run on conflict, got %v", f.streamCalls)
	}
}

func TestSyncForkRestoresOriginalBranch(t *testing.T) {
	f := &fakeGit{captureOut: map[string]string{
		"remote get-url upstream": "url",
		"branch --show-current":   "feature",
	}}
	var out strings.Builder
	if code := syncFork(f, &out, "main", "upstream"); code != 0 {
		t.Fatalf("exit = %d, want 0", code)
	}
	if f.streamCalls[0] != "checkout main" {
		t.Errorf("expected checkout to target branch first, got %v", f.streamCalls)
	}
	if last := f.streamCalls[len(f.streamCalls)-1]; last != "checkout feature" {
		t.Errorf("expected return to original branch last, got %q (%v)", last, f.streamCalls)
	}
}
