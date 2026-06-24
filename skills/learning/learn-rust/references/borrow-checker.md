# The borrow checker: ownership, borrowing, lifetimes

This is the heart of Rust and the main hurdle. Teach the *why* — memory safety and
data-race freedom without a garbage collector — so the rules feel like
consequences, not arbitrary obstacles.

## The mental model (three rules)

1. **Every value has exactly one owner.** When the owner goes out of scope, the
   value is dropped (freed). No double-free, no leaks.
2. **Ownership moves.** Assigning or passing a non-`Copy` value transfers
   ownership; the old binding can't be used. (`Copy` types — integers, bool, char,
   and tuples of them — are duplicated instead.)
3. **You can borrow instead of move** — a reference. Borrowing rules:
   - any number of **shared** borrows `&T` (read-only), **or**
   - exactly one **mutable** borrow `&mut T`,
   - but never both at once, and never outliving the owner.

Coaching questions: *"Who owns this value? Has it moved? Is anyone else looking at
it right now (shared borrow) while you're trying to mutate it?"*

## Common errors and how to coach them

### E0382 — use of moved value
```rust
let s = String::from("hi");
let t = s;            // ownership moves to t
println!("{s}");      // ERROR: s was moved
```
Coach: the value moved into `t`. Options: borrow (`let t = &s;`), clone if you need
two owners (`let t = s.clone();`), or restructure so only one owner is needed. Ask
which is right *here* — cloning is not always the answer.

### E0499 / E0502 — conflicting borrows
```rust
let mut v = vec![1, 2, 3];
let first = &v[0];     // shared borrow
v.push(4);             // ERROR: mutable borrow while `first` is alive
println!("{first}");
```
Coach: a `&mut` (push) can't coexist with a live `&` (first). Why is that unsafe?
(push may reallocate, dangling `first`.) Fix by narrowing the borrow's lifetime —
use `first` before mutating, or copy the value out.

### E0106 / E0621 — missing lifetime specifier
```rust
fn longest(x: &str, y: &str) -> &str {   // ERROR: which input does output borrow?
    if x.len() > y.len() { x } else { y }
}
```
Coach: the compiler can't tell whether the returned reference points into `x` or
`y`. Tie them together with a lifetime: `fn longest<'a>(x: &'a str, y: &'a str) ->
&'a str`. Ask the learner to name *what the output borrows from* before adding
syntax.

### E0505 / E0506 — move/assign while borrowed
A value can't be moved or reassigned while a reference to it is alive. Same fix
pattern: shorten the borrow or restructure ownership.

## Lifetimes (when they finally appear)
- Lifetimes are **descriptive, not prescriptive**: `'a` annotations tell the
  compiler how references relate; they don't change how long data lives.
- Most functions need none (lifetime elision handles them). Annotations show up
  when returning references or storing them in structs.
- Teach elision rules so learners know *why* most code needs no annotations, then
  the cases that do.

## Drill order
moves/`Copy` → shared vs mutable borrows → slices → borrow-conflict resolution →
lifetime annotations on functions → lifetimes in structs. Keep one concept per
exercise; interleave only once each is independently solid.
