---
name: git-recon
description: >
  Run git diagnostic commands to analyze a repository before reading any code.
  Produces a report covering file churn, bus factor, bug hotspots, firefighting
  frequency, and project velocity. Use when the user says things like "analyze
  this repo", "give me a codebase overview", "who works on this", "what changes
  the most", "run git diagnostics", "bus factor", "bug hotspots", "project
  velocity", "show me the churn", "how healthy is this codebase", "what should
  I read first", "help me understand this codebase", "firefighting frequency",
  "is this project active", or when a user is new to a repository and wants to
  orient themselves or assess codebase health.
---

# Git Recon

Run 5 diagnostic git commands to build a picture of a codebase before reading any source code. These commands reveal which files matter most, who knows the code, where bugs cluster, how often the team firefights, and whether the project is accelerating or dying.

## Prerequisites

Before running any diagnostics, verify:
1. The current directory is inside a git repository
2. The repository has meaningful history (more than a handful of commits)

If either check fails, inform the user and stop.

## Running All Diagnostics

To run the full diagnostic suite, execute the bundled script:

```bash
bash <skill-path>/scripts/git-recon.sh
```

Pass `--since "6 months ago"` to narrow the time window for large repos.

Then interpret each section using the guidance below.

## Individual Diagnostics

Run individual commands when the user asks about a specific aspect rather than a full overview.

### 1. File Churn — What Changes the Most

```bash
git log --format=format: --name-only --since="1 year ago" | grep -v '^$' | sort | uniq -c | sort -nr | head -20
```

Shows the 20 most-changed files in the last year.

**How to interpret:**
- The top file is almost always the one people warn you about
- High-churn files are either core abstractions (expected) or poorly designed code that constantly needs patching
- Config files and lockfiles appearing here are normal noise — focus on source code files
- Files appearing in both churn AND bug hotspots are high-priority refactoring candidates

### 2. Bus Factor — Who Built This

```bash
git shortlog -sn --no-merges
```

Ranks every contributor by commit count, excluding merge commits.

**How to interpret:**
- If one person accounts for 60% or more of commits, that is a bus factor risk — flag it
- Compare the all-time ranking to a recent window (`--since="6 months ago"`). If the top all-time contributor does not appear in the recent window, knowledge drain may be occurring
- In merge-heavy workflows, `--no-merges` might filter too aggressively. Note if the total non-merge count seems unusually low relative to the project's age

### 3. Bug Hotspots — Where Do Bugs Cluster

```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' --since="1 year ago" | grep -v '^$' | sort | uniq -c | sort -nr | head -20
```

Same shape as file churn but filtered to commits with bug-related keywords.

**How to interpret:**
- Files at the top are where defects concentrate — they likely need better tests or a redesign
- This command depends on commit message hygiene. If the team does not mention "fix" or "bug" in commits, results will undercount. Mention this caveat
- Cross-reference with file churn: a file that is high-churn but low-bugs is healthy (active development). A file that is high-bugs but low-churn is concerning (latent defects)

### 4. Firefighting Frequency — How Often Is the Team in Crisis Mode

```bash
git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
```

Counts reverts, hotfixes, and emergency deployments in the last year.

**How to interpret:**
- A handful over a year is normal
- Reverts every couple of weeks means the team does not trust its deploy process
- Frequent hotfixes suggest inadequate testing or CI/CD gaps
- This is a cultural health indicator — high firefighting rates often correlate with rushed releases and poor review practices

### 5. Project Velocity — Is This Project Accelerating or Dying

```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

Commit count by month across the project's entire history.

**How to interpret:**
- **Steady rhythm**: healthy, sustainable pace
- **Count drops by half in a single month**: someone likely left the team
- **Declining curve over 6-12 months**: the team is losing momentum or the project is entering maintenance mode
- **Periodic spikes then quiet**: the team batches work into releases instead of shipping continuously

## Cross-Referencing Signals

Combine diagnostics to surface deeper insights:

- **Churn + Bug hotspot overlap**: files appearing in both lists are the highest-priority refactoring candidates
- **High firefighting + declining velocity**: team is under stress — spending energy on rollbacks instead of features
- **Single-contributor dominance + high churn on the same files**: critical knowledge silo — if that person leaves, those files become unmaintainable
- **Low bug hotspots + steady velocity + distributed contributors**: healthy codebase with good practices

## Output Format

Structure the report as follows:

```
## Git Recon: <repository-name>

### File Churn
<top 10-20 files, with brief interpretation>

### Bus Factor
<contributor ranking, bus factor assessment>

### Bug Hotspots
<top files, cross-referenced with churn>

### Firefighting
<count and assessment, or "minimal — healthy">

### Velocity
<trend description with interpretation>

### Key Takeaways
- <3-5 actionable insights combining the signals above>
- <which files to read first>
- <which people to talk to>
- <any risks flagged>
```

Adjust depth based on what the user asked for. A full overview gets all sections. A targeted question ("who built this?") gets just the relevant section and a one-line summary.
