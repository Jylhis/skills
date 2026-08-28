# Flatten the two-level skills/<category>/<name>/ tree into a single-level
# directory of skill dirs for harnesses that scan one level deep (Pi,
# OpenHands). Each skill directory is copied wholesale (SKILL.md plus
# references/, scripts/, assets/).
#
# Skill directory names are unique across categories; a collision is a hard
# build error rather than a silent overwrite, and the assembled skill count is
# asserted to equal the number of source SKILL.md files so a flatten bug fails
# the build loudly.
#
# Usage from a consumer (e.g. j10s overlay):
#   flattenSkills { inherit lib runCommand; src = inputs.jylhis-skills; }
#
# This file is importable without a flake: it is a function that takes
# { lib, runCommand } and returns a derivation builder that takes { src }.
{
  lib,
  runCommand,
}:
{ src }:
runCommand "jylhis-skills-flat"
  {
    inherit src;
    meta = {
      description = "jylhis/skills flattened to one-level skill dirs";
      homepage = "https://github.com/Jylhis/skills";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
  ''
    set -euo pipefail
    mkdir -p "$out"

    want=$(find "$src"/skills -mindepth 3 -maxdepth 3 -name SKILL.md | wc -l)

    for skill_md in "$src"/skills/*/*/SKILL.md; do
      dir=$(dirname "$skill_md")
      name=$(basename "$dir")
      dest="$out/$name"
      if [ -e "$dest" ]; then
        echo "ERROR: skill name collision across categories: '$name'" >&2
        exit 1
      fi
      cp -r "$dir" "$dest"
    done

    got=$(find "$out" -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [ "$got" -ne "$want" ] || [ "$got" -eq 0 ]; then
      echo "ERROR: assembled $got skill dirs but found $want SKILL.md sources" >&2
      exit 1
    fi
    echo "assembled $got skills from jylhis/skills" >&2
  ''