# Documentation comment formats by language

A quick reference for public-API doc comments. Each language has a canonical format and a tool that renders it.

## Python: docstrings (PEP 257)

A triple-quoted string as the first statement of a module, class, or function. Describe behaviour, args, returns, and raised exceptions. Tools: `help()`, Sphinx, pydoc. Common styles: Google, NumPy, reStructuredText.

```python
def fetch(url: str, *, timeout: float = 5.0) -> bytes:
    """Fetch a URL and return the body.

    Args:
        url: Absolute http(s) URL.
        timeout: Per-request timeout in seconds.

    Returns:
        The response body as bytes.

    Raises:
        TimeoutError: If the request exceeds `timeout`.
    """
```

## JavaScript and TypeScript: JSDoc and TSDoc

A `/** ... */` block above the declaration. In TypeScript, let the types carry the type information and use the comment for intent; do not repeat types in `@param`. Tools: TypeDoc, editor tooltips.

```ts
/**
 * Resolve the active feature flag for a user.
 * @param key - Flag key in kebab-case.
 * @returns Whether the flag is enabled for this user.
 */
function isEnabled(key: string, userId: string): boolean
```

## Go: doc comments

A full-sentence comment immediately above the declaration, starting with the identifier name. Package docs go above the `package` clause. Tools: `go doc`, pkg.go.dev.

```go
// Fetch returns the body of url. It returns an error if the request
// exceeds the context deadline.
func Fetch(ctx context.Context, url string) ([]byte, error)
```

## Rust: rustdoc

`///` documents the following item; `//!` documents the enclosing module or crate. The body is Markdown, and fenced code blocks run as doctests. Tool: `cargo doc`.

```rust
/// Fetches `url` and returns the body.
///
/// # Errors
/// Returns `Err` if the request times out.
///
/// # Examples
/// ```
/// let body = fetch("https://example.com")?;
/// ```
pub fn fetch(url: &str) -> Result<Vec<u8>, FetchError>
```

## Java: Javadoc

A `/** ... */` block with `@param`, `@return`, and `@throws`. Tool: `javadoc`.

```java
/**
 * Fetches the body of the given URL.
 *
 * @param url absolute HTTP(S) URL
 * @return the response body
 * @throws IOException if the request fails
 */
byte[] fetch(String url) throws IOException
```
