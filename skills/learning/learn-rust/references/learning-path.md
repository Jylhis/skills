# Rust learning path

The canonical free resources and how they fit together. Use the Book for theory,
Rustlings for compiler-driven practice, Rust by Example for annotated patterns.

## Primary resources
- **The Rust Programming Language ("the Book")** — https://doc.rust-lang.org/book/
  The comprehensive reference-tutorial. Chapters map closely to Rustlings sections.
- **Rustlings** — https://github.com/rust-lang/rustlings
  Small exercises that don't compile; the learner fixes them. The model this skill
  uses. Install: `cargo install rustlings` then `rustlings init`.
- **Rust by Example** — https://doc.rust-lang.org/rust-by-example/
  Runnable annotated examples; good for "show me the pattern".
- **`rustlings`-style local loop:** `rustlings watch` recompiles on save and walks
  exercises in order — mirror this rhythm when generating your own exercises.

## Progression (Book chapter → concept → what to drill)

| Stage | Book ch. | Concept | Drill focus |
|-------|----------|---------|-------------|
| 1 | 1–3 | basics, variables, functions, control flow | `let`/`mut`, shadowing, types, `if`/`loop`/`for` |
| 2 | 4 | **ownership, borrowing, slices** | moves vs borrows, `&`/`&mut`, slice types |
| 3 | 5–6 | structs, enums, `match`, `Option` | modeling data, exhaustive `match`, `Option` handling |
| 4 | 7–9 | modules, collections, **error handling** | `Vec`/`String`/`HashMap`, `Result`, `?`, panic vs recover |
| 5 | 10 | generics, **traits, lifetimes** | trait bounds, `dyn`, lifetime annotations |
| 6 | 11 | testing | `#[test]`, `assert!`, `cargo test` |
| 7 | 13 | closures, **iterators** | `map`/`filter`/`collect`, iterator over index loops |
| 8 | 15–16 | smart pointers, concurrency | `Box`/`Rc`/`RefCell`, `Arc`/`Mutex`, threads, channels |
| 9 | 17–20 | traits as objects, patterns, async (later) | dynamic dispatch, real projects |

## Sequencing advice
- Don't rush past **stage 2 (ownership)** — it gates everything. Most later
  confusion traces back to a shaky ownership model.
- Pair each Book chapter with hands-on failing exercises (Rustlings or generated).
- After error handling and traits are solid, move learners onto a small real
  project (a CLI parser, a tiny interpreter) — context cements the concepts.

## Toolchain the learner should have
- `rustup` (toolchain manager), the stable toolchain, `cargo`, `clippy`
  (`rustup component add clippy`), `rustfmt`.
- `rustc --explain <CODE>` to expand error codes — use it constantly while teaching.
