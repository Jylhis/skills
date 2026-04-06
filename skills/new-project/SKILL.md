---
description: Scaffold a greenfield software project from idea to working repo.
---

# New Project

Start a greenfield software project. Go from idea to a working repo the user can build on.

## Steps

1. Ask what the user is building, who it is for, and what problem it solves. Get specific: "a CLI tool" is too vague, "a CLI tool that syncs local markdown files to Notion" is enough.
2. Agree on v1 scope. List what is in, what is out. Write it down before touching any code.
3. Pick the tech stack. Choose based on the problem and what the user already knows. Avoid hype-driven choices.
4. Scaffold the project:
   - Directory structure
   - Package manifest with dependencies
   - Build and dev scripts
   - Test runner configured with one passing test
   - `.gitignore`
   - README with setup instructions
5. Initialize git. Make the first commit.

## Output

A working project the user can `git clone`, install, and run tests on immediately. No placeholder files, no TODO comments. Everything that exists should work.
