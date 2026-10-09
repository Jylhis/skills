# Input Pinning Without (or Alongside) Flakes

How to pin Nixpkgs and other sources reproducibly when flakes are not
wanted, not allowed, or not enough: Nixtamal, npins, niv, lon, plain
`fetchTarball`/`fetchGit` pins, and how each coexists with flake
inputs. Versions and behaviour checked against upstream docs on
2026-10-09.

## Table of Contents

- [Decision Table](#decision-table)
- [What Every Pinning Tool Does](#what-every-pinning-tool-does)
- [Plain Builtin Pins](#plain-builtin-pins)
- [Nixtamal](#nixtamal)
- [npins](#npins)
- [niv](#niv)
- [lon](#lon)
- [Coexisting With Flakes](#coexisting-with-flakes)
- [Sources](#sources)

## Decision Table

| Situation | Pick |
|---|---|
| Already on flakes, inputs are forge-hosted Git or tarballs | Flake inputs (`flakes.md`) |
| No experimental features allowed, a few GitHub/GitLab/channel pins | npins |
| Want an update bot opening PRs/MRs on GitHub, GitLab or Forgejo | lon (`lon bot`) |
| Inputs on Darcs, Pijul or Fossil, mirror failover, declarative patches on inputs, custom "is there an update" logic | Nixtamal |
| Existing niv project that works | Keep niv, or migrate with `npins import-niv` / `lon init --from niv` |
| One or two pins, no tool dependency | Plain `fetchTarball` with `sha256` |
| Library consumed by both flake and non-flake users | Flake inputs + flake-compat shim (`hybrid.md`) |

Rules of thumb:

- One source of truth per repo. Two lock files pinning the same
  Nixpkgs drift; if you must have two (flake + devenv), sync them
  (see `hybrid.md`, "Nixpkgs Pin Synchronization").
- Prefer tools that write SRI hashes and keep the lock file
  machine-written. Hand-edited lock JSON is an easy way to break
  these tools; edit the manifest or use the CLI instead.
- Every non-flake tool here works with stable Nix (`nix-build`,
  `nix-shell`, `nixos-rebuild --file`). None needs
  `experimental-features`.

## What Every Pinning Tool Does

All of them reduce to the same three steps:

1. **Declare** a source (URL, repo + branch, channel).
2. **Lock** it: resolve to an immutable revision/URL and record a
   content hash.
3. **Load** it from Nix: a generated `default.nix`/`sources.nix`
   shim reads the lock JSON and calls a fetcher with the recorded
   hash.

The differences are in which fetchers the shim calls (eval-time
`builtins.fetch*` vs build-time Nixpkgs `pkgs.fetch*`), which source
kinds the tool can resolve, and whether declaration lives in a
separate manifest or only in CLI flags.

Eval-time vs build-time fetching matters:

- **Eval-time** (`builtins.fetchTarball`, `builtins.fetchGit`) blocks
  evaluation until the download finishes, but needs no Nixpkgs. The
  first Nixpkgs must always be fetched this way.
- **Build-time** (`pkgs.fetchzip`, `pkgs.fetchgit`, `pkgs.fetchdarcs`,
  ...) produces fixed-output derivations: fetched in parallel by the
  builder, substitutable from binary caches, and able to use VCSs that
  `builtins` does not support. Using the result in `import` is IFD.

## Plain Builtin Pins

No tool, just a hash in a `.nix` file. Fine for a single Nixpkgs pin.

```nix
# nix/nixpkgs.nix
builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/<rev>.tar.gz";
  sha256 = "<hash>";
}
```

```nix
# default.nix
{ pkgs ? import (import ./nix/nixpkgs.nix) { } }:
pkgs.callPackage ./package.nix { }
```

Get the hash with `nix-prefetch-url --unpack <url>` (the `--unpack`
is required for `fetchTarball`). `builtins.fetchTarball` with a hash short-circuits
on a store path that is already present and, since Nix 2.32, is
substituted from binary caches when possible (see
`flakes/offline-fetching.md`).

Downside: updating is manual (new rev, new hash), and nothing records
which branch the rev came from. Past two or three pins, use a tool.

## Nixtamal

**What it is.** An input pinner by toastal: "Fulfilling input pinning
for Nix". Declarative KDL manifest, JSON lockfile, generated Nix
loader. No experimental Nix features required. Works inside or
outside flakes.

| Fact | Value |
|---|---|
| Author / maintainer | toastal |
| License | GPL-3.0-or-later (site content CC-BY-SA-4.0) |
| Language | OCaml |
| Current version | 2.1.0 (2026-10-02); Nixpkgs unstable ships 2.1.0, NixOS 26.05 ships 1.5.4 |
| Source | Darcs only: `https://darcs.toastal.in.th/nixtamal/stable/`, mirror `https://smeder.ee/~toastal/nixtamal.darcs`. The project states there is no official Git mirror |
| Nixpkgs attr | `nixtamal` (`pkgs/by-name/ni/nixtamal`), outputs `bin data doc lib man out` |
| Announced | NixOS Discourse, 2026-01-27; 1.0.0 on 2026-02-13 |

**Install.**

```bash
nix-shell -p nixtamal.{bin,data,doc,man}   # as on the install page (unstable)
nix run nixpkgs#nixtamal -- --help   # meta.mainProgram is set; needs nix-command + flakes (not tested)
```

The install page warns that NixOS 26.05 carries an older version;
prefer unstable or build from the Darcs source (`nix-build` in a
clone).

**Files.** Everything lives under `$NIXTAMAL_DIRECTORY`, default
`./nix/tamal` (override with `--directory`):

```
nix/tamal/
├── default.nix     # generated lock loader (the Nix shim you import)
├── lock.json       # machine-written lockfile
└── manifest.kdl    # hand-written manifest
```

Commit all three. `nixtamal set-up --blueprint release` (or
`release-split`) additionally scaffolds `default.nix`, `release.nix`,
`shell.nix` and `nix/overlay`, `nix/package` directories.

**Commands** (from `nixtamal(1)`, version 2.1.0):

| Command | Does |
|---|---|
| `set-up` | Create the working directory and manifest; by default also adds Nixpkgs (`--no-nixpkgs` to skip, `--nixpkgs-ref`, `--nixpkgs-channel`, `--use-channels`, `--use-nixpkgs-git-mirrors`, `--fetch-time`, `--hash-algorithm`, `--blueprint`) |
| `tweak` | Open `manifest.kdl` in `$VISUAL`, `$EDITOR` or `vi` |
| `lock [INPUT...]` | Lock inputs that are not locked yet; `--force`/`--relock` re-locks after a URL or hash-algorithm change; `-p PATCH` for patches |
| `refresh [INPUT...]` | Run each non-frozen input's `fresh-cmd` (or the built-in default for Git and some files/archives), then lock the stale ones; `--skip-patches` |
| `list-stale` | Run `fresh-cmd`s and list stale inputs without refreshing |
| `show` | Print inputs as Nixtamal understands the manifest; `--input-names`, `--patch-names` |
| `check-soundness` | Check that manifest and lockfile agree |
| `upgrade` | Upgrade manifest + lockfile to the current schema (`--dry-run`, `--from`, `--to`) |
| `gc` | Experimental: needs `NIXTAMAL_EXPERIMENTAL_GC` set, documented as "probably still broken" |

Distinct exit codes exist per failure (65: not set up, 66: manifest
vs lockfile version mismatch, 67: schema not latest, run `upgrade`;
80: BLAKE3 requested but Nix lacks it), so CI can branch on them.

**Manifest.** KDL. Top-level nodes: `version`, `default-hash-algorithm`,
`default-fetch-time`, `patches`, `inputs`. Each input has one kind node
(`file`, `archive`, `git`, `darcs`, `pijul`, `fossil`) plus optional
`hash`, `fresh-cmd`, `patches`, and props `frozen=#true`, `name=`,
`gc=`. URL-like nodes are Jingoo templates (`{{fresh_value}}` is the
string the input's `fresh-cmd` printed). Excerpt from the homepage
showcase (archive input with a patch, Darcs input with a mirror):

```kdl
version "1.0.0"
default-hash-algorithm BLAKE3
patches {
	chroma-0.22.0 "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/478519.patch" {
		hash algorithm=SHA-512 expected="1mdsfx204bgia572fydnmjy78dkybbcnjx20qn9l4q65r29ry28c"
	}
}
inputs {
	nixpkgs {
		archive {
			url "https://github.com/NixOS/nixpkgs/archive/{{fresh_value}}.tar.gz"
		}
		hash algorithm=SHA-256
		patches chroma-0.22.0
		fresh-cmd {
			$ git ls-remote --branches "https://github.com/NixOS/nixpkgs.git" --refs nixpkgs-unstable
			| cut -f1
		}
	}
	nixtamal {
		darcs {
			repository "https://darcs.toastal.in.th/nixtamal/stable"
			mirrors "https://smeder.ee/~toastal/nixtamal.darcs"
		}
		fresh-cmd {
			$ curl -sL "https://darcs.toastal.in.th/nixtamal/stable/_darcs/weak_hash"
		}
	}
}
```

Git inputs and shared patches, from `nixtamal-manifest(5)`:

```kdl
patches {
	nixpkgs-pr123 "https://github.com/NixOS/nixpkgs/pull/123.diff"
	my-fix "./patches/my-fix.patch"
}
inputs {
	nixpkgs {
		git {
			repository "https://github.com/NixOS/nixpkgs.git"
			ref "refs/heads/nixos-unstable"
		}
		patches "nixpkgs-pr123" "my-fix"
	}
}
```

Eval-time fetch with a mirror, also from `nixtamal-manifest(5)`:

```kdl
mozilla-tls-guidelines {
	file fetch-time=eval {
		url "https://ssl-config.mozilla.org/guidelines/{{fresh_value}}.json"
		mirrors "https://raw.githubusercontent.com/mozilla/ssl-config-generator/refs/tags/v{{fresh_value}}/src/static/guidelines/{{fresh_value}}.json"
	}
	fresh-cmd {
		$ curl -sL "https://wiki.mozilla.org/Security/Server_Side_TLS"
		| htmlq -w -t "table.wikitable:last-of-type > tbody > tr:nth-child(2) > td:first-child"
		| head -n1
	}
}
```

Manifest details worth knowing:

- `fetch-time` (`eval` = `builtins.fetch*`, `build` = `pkgs.fetch*`)
  exists on `file`, `archive` and `git`. Darcs, Pijul and Fossil are
  build-time only (Nixpkgs fetchers). The docs disagree on the
  default (the homepage says build-time, `manifest(5)` says the
  top-level default is `eval`), so set `fetch-time` or
  `default-fetch-time` explicitly.
- Inputs with `patches` cannot use `eval`; Nixtamal enforces this.
- Local patches (`./...`) are read from the repo; remote patches are
  fetched and hashed at `nixtamal lock`.
- The bootstrap Nixpkgs pin must stay SHA-256 so
  `builtins.fetchTarball` can load it. BLAKE3 elsewhere needs the
  `blake3-hashes` experimental feature (Nix 2.31+), which defeats the
  "no experimental features" goal; leave it off for shared repos.
- `git` supports `branch`, `tag` or `ref`, plus `submodules` and `lfs`
  leaf nodes. `fresh-cmd` is any shell pipeline (`$` then `|` nodes)
  that prints a string; if the string is unchanged, `refresh` skips
  the prefetch. The CLI tools it calls (curl, git, htmlq, jq) are not
  pinned by Nixtamal; run it from a dev shell that provides them.

**Consuming inputs.** The loader is a function returning an attrset
of input store paths. Documented (optional) arguments: `system`
(default `builtins.currentSystem`; pass it for pure evaluation),
`bootstrap-nixpkgs`, `bootstrap-nixpkgs-lock-name`, `bootstrap-pkgs`:

```nix
# default.nix / shell.nix
let
  inputs = import ./nix/tamal { };
  pkgs = import inputs.nixpkgs {
    overlays = [ (import "${inputs.our-cool-pkg}/nix/overlay") ];
  };
in
pkgs.mkShell { packages = [ pkgs.hello ]; }
```

Pass `bootstrap-pkgs` when an instantiated Nixpkgs already exists
(for example inside a flake) to skip a second Nixpkgs import.

For a non-flake NixOS configuration (general Nix pattern, not from the
Nixtamal docs), build the system from a file and attribute:

```nix
# system.nix
let
  inputs = import ./nix/tamal { };
in
{
  myhost = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix" {
    modules = [ ./hosts/myhost/configuration.nix ];
    specialArgs = { inherit inputs; };
  };
}
```

```bash
nixos-rebuild switch --file ./system.nix --attr myhost
```

`--file`/`--attr` are documented in the `nixos-rebuild` manpage
shipped in Nixpkgs 26.05. Inside modules, `inputs.<name>` is a store
path (`"${inputs.home-manager}/nixos"` and similar).

**Maturity caveats.**

- Young and fast-moving: 0.1 beta in January 2026, 1.0.0 in February,
  2.x by September. Schema versions (manifest, lockfile, loader move
  in lockstep) bump in minor releases; expect to run `nixtamal
  upgrade` after updating the tool. The binary uses "Pride
  Versioning", the schema uses SemVer.
- Single maintainer, Darcs-only source, no issue tracker (XMPP room
  and direct contact). Weigh that for team or corporate repos where
  contributors expect a Git forge.
- Needs Nixpkgs for bootstrapping and for build-time fetchers, patches,
  Darcs/Pijul/Fossil. `fetch-time=eval` inputs avoid it.
- No importer from `flake.lock`, npins or niv yet (`nixtamal import`
  is listed under "Farther Future" on the roadmap). Signature
  verification is also roadmap only.
- The comparison table on the homepage is the author's own; treat its
  verdicts on other tools as opinion.

## npins

Rust, EUPL-1.2, by andir. Inspired by and comparable to niv. Latest
release 0.5.1 (2026-09-02), actively maintained.

```bash
nix-shell -p npins
npins init                     # npins/default.nix + npins/sources.json, adds a nixpkgs channel pin
npins init --bare              # no initial nixpkgs
npins add github ytdl-org youtube-dl -b master
npins add git https://gitlab.com/simple-nixos-mailserver/nixos-mailserver.git -b "nixos-21.11"
npins add channel nixos-unstable
npins update                   # all pins; or: npins update <name>...
npins update --dry-run         # print the diff only
npins verify                   # re-check hashes, no version changes
npins freeze <name>            # skip on update; unfreeze to thaw
npins upgrade                  # migrate sources.json/default.nix format
```

```nix
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
in
pkgs.hello
```

- Pin kinds: `channel`, `github`, `gitlab`, `forgejo`, `git`, `pypi`,
  `container`, `tarball`, `url`. Git release tracking follows SemVer
  tags (`--upper-bound`, `--pre-releases`, `--release-prefix`);
  `--submodules` for submodules.
- Fetches through `builtins` by default. Passing `pkgs` to a pin
  switches it to Nixpkgs fetchers: `sources.mySource { inherit pkgs; }`.
- Migration: `npins import-niv`, `npins import-flake`, `npins
  import-lon`. Imports keep only the source identity, so follow with
  `npins update`.
- `--lock-file <path>` (lockfile mode) writes only the JSON, no
  generated `default.nix`.

## niv

Haskell, MIT, by nmattia. The original non-flake pinner. Low
activity: 0.2.22 (2023-03-12) was the last release for three years,
then a `v0.3.0` tag on 2026-09-11. Still works and still in Nixpkgs;
not deprecated, but new projects usually pick npins.

```bash
niv init                  # nix/sources.json + nix/sources.nix, tracks nixos-unstable
niv add stedolan/jq       # GitHub owner/repo
niv update nixpkgs        # or: niv update (all)
niv update nixpkgs -b master
niv drop jq
```

```nix
{ sources ? import ./nix/sources.nix }:
import sources.nixpkgs { overlays = [ ]; config = { }; }
```

`sources.json` stores a `sha256` per source; GitHub API calls honour
`GITHUB_TOKEN`/`NIV_GITHUB_TOKEN`. To migrate away:
`npins import-niv nix/sources.json && npins update`, then replace
`import ./nix/sources.nix` with `import ./npins`; or
`lon init --from niv --source nix/sources.json`.

## lon

Rust, MIT, by nikstur. Reached 1.0.0 on 2026-07-26. Focus: SRI-only
hashes, fixed-output `builtins.fetchGit` (cacheable), local overrides,
and a built-in update bot.

```bash
lon init                              # lon.nix + empty lon.lock
lon init --from niv --source nix/sources.json
lon add github nixos/nixpkgs master
lon add git snix https://git.snix.dev/snix/snix.git canon   # --submodules available
lon update                            # or: lon update nixpkgs
lon update --commit                   # commit with an update summary
lon freeze <name> / lon unfreeze <name>
lon bot github                        # also: gitlab, forgejo; opens PRs/MRs
```

```nix
let
  sources = import ./lon.nix;
  pkgs = import sources.nixpkgs { };
in
pkgs.hello
```

- `LON_OVERRIDE_<name>=/path/to/checkout` swaps a source for a local
  path during development (keep names alphanumeric).
- Supports the Lockable HTTP Tarball Protocol (forges that redirect a
  mutable tarball URL to an immutable one).
- `lon bot gitlab` runs from a scheduled pipeline with a project
  access token in `LON_TOKEN` and `LON_PUSH_URL`; see the README for
  the full `.gitlab-ci.yml` snippet.
- Requires Nix >= 2.4.

## Coexisting With Flakes

- **Flake as the source of truth, non-flake entry points via
  flake-compat.** The usual choice for libraries; see `hybrid.md`.
- **Non-flake tool as the source of truth, thin `flake.nix`.** Import
  the pins inside `outputs` so `flake.lock` stays nearly empty:

  ```nix
  {
    outputs = { self }:
      let
        inputs = import ./nix/tamal { system = "x86_64-linux"; };
        pkgs = import inputs.nixpkgs { system = "x86_64-linux"; config = { }; };
      in
      { packages.x86_64-linux.default = pkgs.hello; };
  }
  ```

  (Shape from the Nixtamal FAQ; the same works with
  `import ./npins` or `import ./lon.nix`.) Pure evaluation accepts
  this because every eval-time fetch carries a hash.
  Consumers that add this flake as an input cannot `follows` into
  these pins; expose an overlay instead.
- **Mixed.** Keep `nixpkgs` as a flake input and give the pinner the
  instantiated set: Nixtamal accepts
  `import ./nix/tamal { bootstrap-pkgs = nixpkgs.legacyPackages.${system}; }`,
  and npins pins accept `{ inherit pkgs; }`. Only do this when some
  inputs genuinely cannot be flake inputs (Darcs/Pijul/Fossil, mirrors,
  patched sources).
- **Do not pin the same thing twice.** If both `flake.lock` and a
  pinner track Nixpkgs, add a CI check that the revisions match (the
  `hybrid.md` verify recipe adapts directly).

## Sources

- Nixtamal: <https://nixtamal.toast.al/> (home, install, manpage,
  changelog, FAQs, roadmap), `nixtamal-manifest(5)` at
  <https://nixtamal.toast.al/manpage/nixtamal-manifest.5/>,
  announcement <https://discourse.nixos.org/t/nixtamal-fulfilling-input-pinning-for-nix/74745>,
  Nixpkgs `pkgs/by-name/ni/nixtamal/package.nix`. Manifest excerpts
  above are from the Nixtamal docs by toastal, CC-BY-SA-4.0.
- npins: <https://github.com/andir/npins> (README, releases)
- niv: <https://github.com/nmattia/niv> (README, CHANGELOG, tags)
- lon: <https://github.com/nikstur/lon> (README, releases)
- Nix manual, `builtins.fetchTarball`; Nix 2.32 release notes
  (fetchTarball substitution, #14138)
- Nixpkgs 26.05 `nixos-rebuild` manpage (`--file`, `--attr`)

<!-- Assisted-by: Claude Code:claude-opus-5-5 -->
