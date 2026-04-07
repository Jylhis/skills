#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""
Skill Initializer - Scaffolds a new skill directory from template

Usage:
    python -m scripts.init_skill <skill-name> --path <path>

Examples:
    python -m scripts.init_skill data-analyzer --path ./skills
    python -m scripts.init_skill my-tool --path /absolute/path/to/skills
"""

import sys
import re
from pathlib import Path


SKILL_TEMPLATE = """\
---
name: {skill_name}
description: TODO - Complete and informative explanation of what the skill does and when to use it. Include specific scenarios, file types, or tasks that should trigger it.
---

# {skill_title}

TODO: 1-2 sentences explaining what this skill enables.

## Choosing a Structure

Pick the pattern that best fits the skill, or combine them. Delete this section when done.

**Workflow-Based** — best for sequential processes with clear steps.
Example: DOCX skill with decision tree -> reading -> creating -> editing.
Structure: Overview -> Workflow Decision Tree -> Step 1 -> Step 2...

**Task-Based** — best for tool collections with distinct operations.
Example: PDF skill with merge, split, extract, convert tasks.
Structure: Overview -> Quick Start -> Task Category 1 -> Task Category 2...

**Reference/Guidelines** — best for standards or specifications.
Example: Brand styling with colors, typography, layout rules.
Structure: Overview -> Guidelines -> Specifications -> Usage...

**Capabilities-Based** — best for integrated systems with interrelated features.
Example: Product management with numbered capability list.
Structure: Overview -> Core Capabilities -> 1. Feature -> 2. Feature...

---

## TODO: First Section

Add content here. Useful patterns:
- Code samples for technical skills
- Decision trees for complex workflows
- Concrete examples with realistic user requests
- References to scripts/templates/references as needed
"""

EXAMPLE_SCRIPT = """\
#!/usr/bin/env python3
\"\"\"
Example helper script for {skill_name}

Replace with actual implementation or delete if not needed.
\"\"\"

def main():
    print("Placeholder script for {skill_name}")

if __name__ == "__main__":
    main()
"""

EXAMPLE_REFERENCE = """\
# Reference Documentation for {skill_title}

Replace with actual reference content or delete if not needed.

Reference docs are useful for:
- Comprehensive API documentation
- Detailed workflow guides
- Complex multi-step processes
- Information too lengthy for main SKILL.md
- Content only needed for specific use cases
"""


def title_case(skill_name):
    return " ".join(word.capitalize() for word in skill_name.split("-"))


def init_skill(skill_name, path):
    """Initialize a new skill directory with template files."""
    skill_dir = Path(path).resolve() / skill_name

    if skill_dir.exists():
        print(f"Error: directory already exists: {skill_dir}")
        return None

    # Validate name
    if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", skill_name):
        print(f"Error: name must be kebab-case (e.g., 'my-skill'), got '{skill_name}'")
        return None

    if len(skill_name) > 64:
        print(f"Error: name too long ({len(skill_name)} chars, max 64)")
        return None

    skill_title = title_case(skill_name)

    # Create directories
    skill_dir.mkdir(parents=True)
    (skill_dir / "scripts").mkdir()
    (skill_dir / "references").mkdir()
    (skill_dir / "assets").mkdir()

    # Write SKILL.md
    (skill_dir / "SKILL.md").write_text(
        SKILL_TEMPLATE.format(skill_name=skill_name, skill_title=skill_title)
    )

    # Write example files
    example_script = skill_dir / "scripts" / "example.py"
    example_script.write_text(
        EXAMPLE_SCRIPT.format(skill_name=skill_name)
    )
    example_script.chmod(0o755)

    (skill_dir / "references" / "reference.md").write_text(
        EXAMPLE_REFERENCE.format(skill_title=skill_title)
    )

    print(f"Initialized skill '{skill_name}' at {skill_dir}")
    print()
    print("Next steps:")
    print("  1. Edit SKILL.md — fill in the TODOs and pick a structure")
    print("  2. Add or remove scripts/, references/, assets/ as needed")
    print("  3. Run quick_validate.py to check the skill structure")
    return skill_dir


def main():
    if len(sys.argv) < 4 or sys.argv[2] != "--path":
        print("Usage: python -m scripts.init_skill <skill-name> --path <path>")
        print()
        print("Examples:")
        print("  python -m scripts.init_skill data-analyzer --path ./skills")
        print("  python -m scripts.init_skill my-tool --path /absolute/path")
        sys.exit(1)

    skill_name = sys.argv[1]
    path = sys.argv[3]

    result = init_skill(skill_name, path)
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
