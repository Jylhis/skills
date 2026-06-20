# Rust exercise templates (failing-snippet model)

Each template is a small program that **doesn't compile** (or fails a test),
isolating one concept. Present it, let the learner fix it, then verify with
`cargo build`/`cargo test`/`cargo clippy`. Generate variants by changing types,
names, and surface details. Tag resulting idiom cards by the concept.

Verify any snippet you author yourself before showing it — paste into a scratch
Cargo project and confirm it fails for the intended reason.

## 1. Ownership / moves (tag: ownership, E0382)
```rust
fn main() {
    let greeting = String::from("hello");
    let shout = greeting;
    println!("{greeting} and {shout}");   // fix: borrow, or clone, or reorder
}
```
Concept: a `String` moves on assignment. Discuss which fix fits the intent.

## 2. Shared vs mutable borrow (tag: ownership, E0502)
```rust
fn main() {
    let mut scores = vec![10, 20, 30];
    let top = &scores[0];
    scores.push(40);                       // fix: use `top` before mutating
    println!("top was {top}");
}
```

## 3. Mutable reference in a function (tag: ownership)
```rust
fn add_one(n: i32) { n += 1; }             // fix: take &mut i32 and deref
fn main() {
    let mut x = 41;
    add_one(x);
    assert_eq!(x, 42);
}
```

## 4. Lifetimes on a returning function (tag: lifetimes, E0106)
```rust
fn first_word(s: &str) -> &str {           // compiles via elision — then:
    s.split(' ').next().unwrap()
}
fn longest(a: &str, b: &str) -> &str {     // ERROR: add a lifetime
    if a.len() >= b.len() { a } else { b }
}
```

## 5. Option handling (tag: error-handling)
```rust
fn main() {
    let nums = vec![1, 2, 3];
    let third = nums.get(2);               // returns Option<&i32>
    println!("{}", third + 1);             // fix: match / if let / unwrap_or
}
```

## 6. Result and the `?` operator (tag: error-handling)
```rust
fn parse_sum(a: &str, b: &str) -> i32 {    // fix: -> Result<i32, _> and use ?
    let x = a.parse::<i32>().unwrap();
    let y = b.parse::<i32>().unwrap();      // make it not panic on bad input
    x + y
}
```

## 7. Traits and bounds (tag: traits)
```rust
fn print_all(items: &[T]) {                // fix: generic with Display bound
    for i in items { println!("{i}"); }
}
```
Target: `fn print_all<T: std::fmt::Display>(items: &[T])`.

## 8. Iterators over index loops (tag: iterators, clippy)
```rust
fn main() {
    let v = vec![1, 2, 3, 4];
    let mut sum = 0;
    for i in 0..v.len() { sum += v[i]; }    // clippy: prefer iterator
    println!("{sum}");
}
```
Target: `let sum: i32 = v.iter().sum();` — drive with `cargo clippy`.

## Difficulty ladder
moves → borrow conflicts → mutable refs in fns → lifetimes → Option → Result/`?`
→ traits/bounds → iterators → smart pointers (`Box`/`Rc`/`RefCell`) → concurrency
(`Arc`/`Mutex`, channels). Introduce in isolation; interleave once solid.
