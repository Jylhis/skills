---
name: learn-rust
description: Tutor the user in the Rust programming language using the Rustlings model — small failing programs the learner fixes — with a focus on the borrow checker (ownership, borrowing, lifetimes). Use when the user wants to learn, study, or practice Rust, is stuck on ownership/borrowing/lifetimes or a specific compiler error, wants graded Rust exercises, or wants their Rust code reviewed for idioms. Verifies solutions with cargo/rustc/clippy. Runs sessions and tracks progress through the tutor-engine skill (subject id `rust`).
---

# learn-rust

Subject expertise for Rust tutoring. **Session mechanics and progress tracking
come from the `tutor-engine` skill** (subject id `rust`) — load it for any
session. This skill supplies *what* to teach, the Rust learning path, and how to
run the compiler-driven exercise loop.

## The method: learn from failing code (Rustlings model)

Don't lecture syntax. Give the learner a **small program that doesn't compile**,
targeting exactly one concept, and coach them to fix it by reading the compiler.
This works because Rust's compiler errors are unusually instructive, and fixing
them is what internalizes ownership rules.

The loop per exercise:
1. Present a minimal failing snippet that isolates **one** concept.
2. Let the learner read the error and attempt a fix. **Don't hand them the answer.**
3. Verify the fix by compiling/running (below).
4. On failure, run `rustc --explain E0382` (etc.) and ask a Socratic question that
   points at the error, not the solution.
5. On success, log the result and move up one step in difficulty.

Templates by topic are in `references/exercises.md`. The canonical path (Book ↔
Rustlings ↔ Rust by Example) is in `references/learning-path.md`.

## The central hurdle: the borrow checker

Most Rust struggle is ownership, borrowing, and lifetimes. Teach the *why*
(memory safety and data-race freedom with no garbage collector), not workarounds.
The mental model, the common errors (E0382 move, E0499/E0502 borrow conflicts,
E0106 missing lifetime), and how to coach each are in
`references/borrow-checker.md`. Spend disproportionate time here.

## Verifying the learner's code

Always verify against the real toolchain — never eyeball Rust. Prefer a scratch
Cargo project so `clippy` and tests work:

```
cargo new --bin scratch && cd scratch     # or `--lib`
# put the exercise in src/main.rs
cargo build        # does it compile?
cargo run          # does it behave?
cargo test         # for exercises with #[test]
cargo clippy -- -D warnings   # idiomatic review
rustc --explain E0382          # expand any error code for teaching
```

For a single throwaway file without deps, `rustc file.rs && ./file` is enough.
Use **`cargo clippy`** to drive idiomatic review — turn its suggestions into
teaching moments (prefer iterators over index loops, `?` over match-on-Result,
`&str` over `&String`, etc.).

## Teaching moves specific to Rust

- **Read the compiler together.** Rust errors name the rule and often suggest the
  fix; train the learner to mine them. `--explain <CODE>` is your friend.
- **Make ownership visible** (dual coding): sketch who owns a value and when it
  moves/borrows. "Whose data is this? Is anyone else looking at it right now?"
- **Idiom cards**: capture corrected idioms as `tutor-engine` cards tagged
  `ownership`, `lifetimes`, `traits`, `error-handling`, `iterators`.
- **One concept per exercise**: don't mix lifetimes and trait objects until each
  is solid; then interleave.

## Verification
- [ ] Every claimed fix was actually compiled/run — no eyeballing.
- [ ] `cargo clippy` was used for idiomatic review where relevant.
- [ ] Recurring errors logged via `tutor-engine` with the error code as concept.
