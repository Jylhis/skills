---
description: Create an opinionated specialist skill for a programming language or stack (e.g. Python, Ruby on Rails, ROS2).
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

5. **Research.** Delegate research to the `research` skill or the `Explore` subagent.
   Hand it a concrete brief listing every topic in step 6. Ask for:
   - Official documentation URLs
   - The dominant idiomatic style guide (community or vendor)
   - The current consensus toolchain (formatter, linter, test runner, build tool,
     package manager)
   - Known footguns and anti-patterns
   - Security advisories and unsafe APIs

   Do not synthesize from training knowledge alone. Verify against current sources.

6. **Cover every topic.** The generated skill must answer all of these for the target
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

7. **Be opinionated.** For every choice, pick one recommendation and commit. Do not
   list alternatives. If the user asks why later, the research notes back the choice.
   Hype-driven choices are out; prefer mature, widely-used tools.

8. **Write the files.** Create the skill directory with:
   - `SKILL.md` — the prompt document, structured like other jstack skills
   - `reference.md` — longer-form notes: links to official docs, the rationale for
     each opinionated pick, and any topic that did not fit cleanly in `SKILL.md`
   - Additional reference files only if a topic genuinely needs its own document
     (e.g. `testing.md`, `tooling.md`). Do not split for the sake of splitting.

9. **Include tool detection.** The generated `SKILL.md` must contain a self-contained
   bash block that checks whether each recommended tool is installed and reports what
   is missing. The block should not install anything. Example shape:

   ```bash
   for tool in <tool1> <tool2> <tool3>; do
     command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
   done
   ```

   List the actual tools the skill recommends.

10. **Show the user what was written.** Print the file paths and a one-paragraph
    summary of the choices made (version, toolchain, test runner). Do not ask for
    approval after the fact — the choices were already confirmed in steps 1–4.

## Generated skill format

Each generated `SKILL.md` follows the jstack convention:

```markdown
---
description: <one sentence: what this skill teaches Claude>
---

# <Language or Stack Name> (<version>)

<one paragraph: paradigm, what this skill covers, when to load it>

## Toolchain

<the picked formatter, linter, test runner, package manager, build tool — one each>

## Tool detection

<bash block from step 9>

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

## Project layout

<directory structure for lib and app>

## Debugging & profiling

<commands>

## Security

<unsafe APIs, common CVE patterns>

## References

<links to reference.md and official docs>
```

## Output

A new skill directory the user can immediately load. Every recommendation is concrete,
every command runs, and the skill states one opinionated path with no menus.
