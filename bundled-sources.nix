# Upstream skill repos bundled as first-class jstack skills.
#
# Each key MUST match a `flake = false` input in flake.nix. The module
# fragment modules/bundled.nix consumes this file and populates
# `programs.jstack.skillSources` automatically, so downstream consumers
# receive these skills without any additional configuration.
#
# Schema matches `programs.jstack.skillSources.<name>`:
#   subdir    — path inside the upstream repo that contains skill dirs
#   namespace — prefix applied to skill IDs (defaults to the key)
#   include   — explicit list of skill directory names; empty = all
#   exclude   — names to skip (only honoured if include is empty)
#   maxDepth  — discovery recursion limit (default 5)
#
# Adding a new source:
#   1. Add a `flake = false` input to flake.nix
#   2. nix flake lock
#   3. Add an entry here with the desired include list
#   4. just check
{
  promptfoo = {
    namespace = "promptfoo";
    subdir = ".claude/skills";
  };
}
