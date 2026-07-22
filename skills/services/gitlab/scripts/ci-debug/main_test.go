package main

import (
	"slices"
	"strings"
	"testing"
)

func TestParsePipeline(t *testing.T) {
	tests := []struct {
		name       string
		in         string
		wantStatus string
		wantJobs   int
		wantErr    bool
	}{
		{"full", `{"status":"failed","jobs":[{"id":1,"name":"build","status":"failed"}]}`, "failed", 1, false},
		{"status only", `{"status":"success"}`, "success", 0, false},
		{"jobs only", `{"jobs":[{"id":2,"name":"test","status":"success"}]}`, "", 1, false},
		{"invalid", `not json`, "", 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p, err := parsePipeline([]byte(tt.in))
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
			}
			if err != nil {
				return
			}
			if p.Status != tt.wantStatus {
				t.Errorf("status = %q, want %q", p.Status, tt.wantStatus)
			}
			if len(p.Jobs) != tt.wantJobs {
				t.Errorf("jobs = %d, want %d", len(p.Jobs), tt.wantJobs)
			}
		})
	}
}

func TestFailedJobs(t *testing.T) {
	tests := []struct {
		name string
		in   pipeline
		want []int
	}{
		{
			"mixed",
			pipeline{Jobs: []job{
				{ID: 1, Name: "build", Status: "failed"},
				{ID: 2, Name: "test", Status: "success"},
				{ID: 3, Name: "lint", Status: "failed"},
			}},
			[]int{1, 3},
		},
		{"none failed", pipeline{Jobs: []job{{ID: 1, Status: "success"}}}, nil},
		{"empty", pipeline{}, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := failedJobs(tt.in)
			var ids []int
			for _, j := range got {
				ids = append(ids, j.ID)
			}
			if !slices.Equal(ids, tt.want) {
				t.Errorf("failed ids = %v, want %v", ids, tt.want)
			}
		})
	}
}

func TestTailLines(t *testing.T) {
	tests := []struct {
		name string
		in   string
		n    int
		want string
	}{
		{"fewer than n", "a\nb", 50, "a\nb"},
		{"more than n", "a\nb\nc\nd", 2, "c\nd"},
		{"exactly n", "a\nb", 2, "a\nb"},
		{"trailing newline", "a\nb\n", 2, "a\nb"},
		{"empty", "", 50, ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tailLines(tt.in, tt.n); got != tt.want {
				t.Errorf("tailLines(%q, %d) = %q, want %q", tt.in, tt.n, got, tt.want)
			}
		})
	}
}

// fakeCommander routes capture() calls by argument shape and records trace ids.
type fakeCommander struct {
	statusJSON string
	jobsJSON   string
	traces     map[string]string
	traceCalls []string
}

func (f *fakeCommander) capture(name string, args ...string) (string, error) {
	if len(args) >= 2 && args[0] == "ci" && args[1] == "trace" {
		f.traceCalls = append(f.traceCalls, args[2])
		return f.traces[args[2]], nil
	}
	if slices.Contains(args, "status") {
		return f.statusJSON, nil
	}
	if slices.Contains(args, "jobs") {
		return f.jobsJSON, nil
	}
	return "", nil
}

func TestRunUsage(t *testing.T) {
	var out strings.Builder
	if code := run(&fakeCommander{}, &out, nil); code != 2 {
		t.Errorf("exit = %d, want 2", code)
	}
	if !strings.Contains(out.String(), "Usage:") {
		t.Errorf("expected usage message, got %q", out.String())
	}
}

func TestRunNoFailedJobs(t *testing.T) {
	f := &fakeCommander{
		statusJSON: `{"status":"success"}`,
		jobsJSON:   `{"jobs":[{"id":1,"name":"build","status":"success"}]}`,
	}
	var out strings.Builder
	if code := run(f, &out, []string{"42"}); code != 0 {
		t.Errorf("exit = %d, want 0", code)
	}
	if !strings.Contains(out.String(), "No failed jobs") {
		t.Errorf("expected no-failed-jobs message, got %q", out.String())
	}
	if len(f.traceCalls) != 0 {
		t.Errorf("trace should not be called, got %v", f.traceCalls)
	}
}

func TestRunTailsFailedJobLogs(t *testing.T) {
	f := &fakeCommander{
		statusJSON: `{"status":"failed"}`,
		jobsJSON:   `{"jobs":[{"id":7,"name":"build","status":"failed"},{"id":8,"name":"test","status":"success"}]}`,
		traces:     map[string]string{"7": "compile error line\n"},
	}
	var out strings.Builder
	code := run(f, &out, []string{"42"})
	if code != 0 {
		t.Fatalf("exit = %d, want 0", code)
	}
	s := out.String()
	if !strings.Contains(s, "Job #7: build") {
		t.Errorf("expected failed job listed, got %q", s)
	}
	if strings.Contains(s, "Job #8") {
		t.Errorf("succeeded job should not be listed, got %q", s)
	}
	if !strings.Contains(s, "compile error line") {
		t.Errorf("expected trace tail in output, got %q", s)
	}
	if !slices.Equal(f.traceCalls, []string{"7"}) {
		t.Errorf("trace calls = %v, want [7]", f.traceCalls)
	}
}
