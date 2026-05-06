---
name: skill-creator-lang
description: >
  Create an opinionated specialist skill for a programming language or stack
  (e.g. Python, Ruby on Rails, ROS2). Meta skill that produces other skills.
---

# Skill Creator: Language & Stack

Generate a new specialist skill that captures expert knowledge for one programming
language or one framework/stack on top of a language. The output is a `SKILL.md`
plus reference docs that Claude can load when working in that ecosystem.

This is a meta skill. It does not write application code. It produces other skills.

## Steps

1. **Identify the target.** Ask the user what language or stack they want a skill for.
   Do not guess. If the user said "Rails", confirm they mean Ruby on Rails and not
   another framework with a similar name. If they named a stack (Rails, ROS2, Next.js,
   Spring Boot, Phoenix), note both the framework and its host language.

2. **Handle layering for stacks.** If the target is a framework on top of a language:
   - Check whether a base language skill already exists in the chosen output location.
   - If not, tell the user that two skills will be created (e.g. `lang-ruby` then
     `lang-ruby-rails`) and confirm before proceeding.
   - The framework skill assumes the language skill is loaded. It only contains
     framework-specific guidance, not language fundamentals.

3. **Pick the version.** Find the currently common versions (latest stable, prior LTS,
   anything still widely deployed). Present them and ask which to target. Record the
   version in the skill, but write guidance that stays valid across recent releases
   unless a feature is version-gated.

4. **Pick the output location.** Ask the user where to write the skill:
   - `skills/<name>/` in the jstack repo (reusable, committed back)
   - `.claude/skills/<name>/` inside the user's current project (project-scoped)

   Do not assume.

5. **Check for an existing skill.** Look in the chosen output location for a skill
   matching this language or stack. If one exists:
   - Read it in full. Treat it as the starting point, not as truth.
   - Still run the full research pass from scratch (step 6). Do not skip research
     just because a skill is already there — versions, tooling, and best practices
     drift.
   - Validate every claim in the existing skill against current sources: tool names,
     commands, version numbers, links, recommended libraries, footguns. Mark each as
     `confirmed`, `outdated`, or `superseded`.
   - Consolidate findings: keep what is still correct, replace what is outdated, add
     what is missing.
   - For any **major difference** (toolchain swap, version jump, idiom reversal,
     dropped or added recommendation), stop and confirm with the user before
     overwriting. List the old value, the new value, and why it changed. Minor edits
     (link updates, command flag tweaks) can proceed without confirmation.
   - When writing the file in step 9, overwrite in place. Do not create a parallel
     skill.

6. **Research.** Use the `Explore` subagent, web search, and Context7 docs tools to
   research the target. Hand it a concrete brief listing every topic in step 7. Ask
   for:
   - Official documentation URLs
   - The dominant idiomatic style guide (community or vendor)
   - The current consensus toolchain (formatter, linter, test runner, build tool,
     package manager)
   - Known footguns and anti-patterns
   - Security advisories and unsafe APIs
   - **LSP servers** for the language. If none exist, say so. If one clearly
     dominates, pick it. If several are viable, list them with a short reason for
     each, recommend one, and ask the user to choose.
   - **MCP servers** relevant to the language or stack (official SDKs, ecosystem
     tools, package registries, docs servers). Same rule: none -> say so;
     one obvious -> pick it; several -> list with reasoning, recommend one, ask
     the user to choose.

   Do not synthesize from training knowledge alone. Verify against current sources.

7. **Cover every topic.** The generated skill must answer all of these for the target
   language or stack:
   - **Paradigm:** dynamic vs static, compiled vs interpreted vs JIT, functional /
     OO / multi-paradigm, memory model
   - **Idiomatic style:** the one canonical style guide, with concrete dos and don'ts
   - **Best practices:** the small set of rules that distinguish expert code from
     beginner code in this ecosystem
   - **Footguns:** the specific traps that bite people, with the safe alternative
   - **Prefer built-ins:** which standard library modules replace common third-party
     dependencies. State this rule explicitly in the generated skill.
   - **Developer tooling:** one recommended formatter, linter, type checker, REPL,
     debugger. Pick one. No menus.
   - **Testing:** the recommended test runner, how a test file looks, how to run a
     single test, how to run the whole suite
   - **Build / lint / validate:** the exact commands to format, lint, type-check,
     compile, and run the project
   - **Package & dependency management:** the recommended package manager, lockfile,
     virtualenv or equivalent, how to add and pin a dependency
   - **Project layout:** the standard directory structure for a library and for an
     application in this ecosystem
   - **Debugging & profiling:** the standard debugger, profiler, and observability
     tools, with the command to start each
   - **Security pitfalls:** language-specific CVE patterns, unsafe APIs to avoid,
     sandboxing notes if relevant
   - **LSP server:** the chosen language server, how to launch it, which editor
     integrations are common. State explicitly if none exists.
   - **MCP servers:** the chosen MCP server(s) for this ecosystem and what each
     exposes. State explicitly if none exist.

8. **Be opinionated.** For every choice, pick one recommendation and commit. Do not
   list alternatives. If the user asks why later, the research notes back the choice.
   Hype-driven choices are out; prefer mature, widely-used tools.

9. **Write the files.** Create the skill directory with:
   - `SKILL.md` — the prompt document, structured like other jstack skills
   - `reference.md` — longer-form notes: links to official docs, the rationale for
     each opinionated pick, and any topic that did not fit cleanly in `SKILL.md`
   - Additional reference files only if a topic genuinely needs its own document
     (e.g. `testing.md`, `tooling.md`). Do not split for the sake of splitting.

   If an existing skill was found in step 5, overwrite the same files in place
   rather than creating a parallel directory.

10. **Include tool detection.** The generated `SKILL.md` must contain a self-contained
    bash block that checks whether each recommended tool is installed and reports what
    is missing. The block should not install anything. Example shape:

    ```bash
    for tool in <tool1> <tool2> <tool3>; do
      command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
    done
    ```

    List the actual tools the skill recommends.

11. **Show the user what was written.** Print the file paths and a one-paragraph
    summary of the choices made (version, toolchain, test runner). If updating an
    existing skill, also list what changed (confirmed / outdated / superseded /
    added). Do not ask for approval after the fact — the choices were already
    confirmed in steps 1-5.

## Generated skill format

Each generated `SKILL.md` follows the jstack convention:

```markdown
---
name: <skill-name>
description: <one sentence: what this skill teaches Claude>
---

# <Language or Stack Name> (<version>)

<one paragraph: paradigm, what this skill covers, when to load it>

## Toolchain

<the picked formatter, linter, type checker, REPL, test runner, package manager, build tool — one each>

## Tool detection

<bash block from step 10>

## Idiomatic style

<concrete dos and don'ts>

## Best practices

<the small expert ruleset>

## Footguns

<traps and safe alternatives>

## Prefer built-ins

<which stdlib modules replace common third-party deps>

## Testing

<how to write, run one, run all>

## Build, lint, validate

<exact commands>

## Package & dependency management

<package manager, lockfile, virtualenv/equivalent, add and pin deps>

## Project layout

<directory structure for lib and app>

## Debugging & profiling

<commands>

## Security

<unsafe APIs, common CVE patterns>

## LSP server

<chosen language server, launch command, editor integration notes — or "none available">

## MCP servers

<chosen MCP server(s) and what they expose — or "none available">

## References

<links to reference.md and official docs>
```

## Output

A new skill directory the user can immediately load. Every recommendation is concrete,
every command runs, and the skill states one opinionated path with no menus.
