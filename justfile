default:
    @just --list --justfile {{justfile()}}

# Lint markdown, shell scripts, and portable skill frontmatter
check:
    markdownlint-cli2 '**/*.md' '#staging/**' '#docs/history/**' '#.devenv/**'
    shellcheck scripts/install.sh
    python3 scripts/validate.py

# Portable skill lint only
validate:
    python3 scripts/validate.py

# Symlink repo root as plugin into each tool's plugin directory
install:
    bash scripts/install.sh

# List discovered skills (one SKILL.md per skill directory)
list:
    @find skills -name SKILL.md | sort
