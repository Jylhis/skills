// sync-fork fetches an upstream remote, fast-forward merges it into a branch,
// and pushes to origin. Faithful Go port of the former sync-fork.sh.
//
// Shells out to `git`. Falls back to a regular merge when fast-forward is not
// possible, and aborts with guidance on conflicts.
//
// Usage: go run sync-fork/main.go [branch] [upstream-remote]
//
//	defaults: branch=main, upstream-remote=upstream
//
// Exit codes: 0 ok, 1 failure (missing remote, conflict, git error).
package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

// commander runs git. capture returns trimmed stdout; stream inherits the
// process stdout/stderr so long-running git output reaches the user live.
// Split out so tests can drive every branch with a fake.
type commander interface {
	capture(name string, args ...string) (string, error)
	stream(name string, args ...string) error
}

type execCommander struct {
	out io.Writer
}

func (e execCommander) capture(name string, args ...string) (string, error) {
	var buf bytes.Buffer
	cmd := exec.Command(name, args...)
	cmd.Stdout = &buf
	err := cmd.Run()
	return strings.TrimSpace(buf.String()), err
}

func (e execCommander) stream(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = e.out
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// resolveArgs applies the branch=main, remote=upstream defaults.
func resolveArgs(args []string) (branch, remote string) {
	branch, remote = "main", "upstream"
	if len(args) > 0 && args[0] != "" {
		branch = args[0]
	}
	if len(args) > 1 && args[1] != "" {
		remote = args[1]
	}
	return branch, remote
}

func syncFork(c commander, out io.Writer, branch, remote string) int {
	fmt.Fprintf(out, "Syncing fork with upstream...\n  Branch: %s\n  Upstream remote: %s\n\n", branch, remote)

	url, err := c.capture("git", "remote", "get-url", remote)
	if err != nil {
		fmt.Fprintf(out, "Upstream remote %q not found.\n", remote)
		fmt.Fprintln(out, "Add it first, e.g.:")
		fmt.Fprintln(out, "  git remote add upstream https://gitlab.com/group/project.git")
		return 1
	}
	fmt.Fprintf(out, "Upstream: %s\n\n", url)

	current, _ := c.capture("git", "branch", "--show-current")
	if current != branch {
		fmt.Fprintf(out, "Switching to %s...\n", branch)
		if err := c.stream("git", "checkout", branch); err != nil {
			fmt.Fprintf(out, "Could not check out %s\n", branch)
			return 1
		}
	}

	fmt.Fprintln(out, "Fetching from upstream...")
	if err := c.stream("git", "fetch", remote); err != nil {
		fmt.Fprintf(out, "Fetch from %q failed\n", remote)
		return 1
	}

	ref := remote + "/" + branch
	fmt.Fprintf(out, "Merging %s into %s...\n", ref, branch)
	if err := c.stream("git", "merge", ref, "--ff-only"); err != nil {
		fmt.Fprintln(out, "Fast-forward failed - attempting a regular merge...")
		if err := c.stream("git", "merge", ref); err != nil {
			fmt.Fprintln(out, "Merge failed - conflicts detected. Resolve them, then:")
			fmt.Fprintln(out, "  git add .")
			fmt.Fprintln(out, "  git commit")
			fmt.Fprintf(out, "  git push origin %s\n", branch)
			return 1
		}
		fmt.Fprintln(out, "Merge successful (with merge commit)")
	} else {
		fmt.Fprintln(out, "Fast-forward merge successful")
	}

	fmt.Fprintf(out, "Pushing to origin/%s...\n", branch)
	if err := c.stream("git", "push", "origin", branch); err != nil {
		fmt.Fprintf(out, "Push to origin/%s failed\n", branch)
		return 1
	}
	fmt.Fprintln(out, "Fork synced successfully.")

	if current != branch && current != "" {
		fmt.Fprintf(out, "Returning to %s...\n", current)
		_ = c.stream("git", "checkout", current)
	}
	return 0
}

func main() {
	branch, remote := resolveArgs(os.Args[1:])
	os.Exit(syncFork(execCommander{out: os.Stdout}, os.Stdout, branch, remote))
}
