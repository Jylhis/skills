default:
    @just --list --justfile {{justfile()}}

# Format every Nix file in the tree
fmt:
    nixfmt .

# Validate evaluation, lint, and shell scripts
check:
    nix-instantiate --eval default.nix > /dev/null
    nix flake check --no-build
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .
    markdownlint-cli2 '**/*.md' '#staging/**' '#docs/history/**' '#.devenv/**' '#result/**'
    shellcheck scripts/install.sh

# Build the skills package (a copy of skills/ in the nix store)
build:
    nix build

# Symlink skills/ and CLAUDE.md into ~/.claude/
install:
    bash scripts/install.sh

# List discovered skills (one SKILL.md per skill directory)
list:
    @find skills -name SKILL.md | sort
